import Compression
import Foundation

/// 读取 .mxl（ZIP 压缩的 MusicXML）时可能出现的错误。
public enum MXLImportError: LocalizedError, Equatable, Sendable {
    /// 不是有效的 ZIP 压缩包，或压缩包结构损坏、被截断。
    case invalidArchive
    /// 压缩包里找不到 MusicXML 乐谱文件。
    case missingMusicXMLEntry
    /// 条目使用了不支持的压缩方式（目前只支持 store 与 deflate）。
    case unsupportedCompression
    /// 乐谱文件解压后超过 ``MXLArchive/maximumEntryBytes`` 上限。
    case entryTooLarge
    /// 条目被加密，无法在内存中读取。
    case encryptedEntry
    /// 使用了 ZIP64 格式，暂不支持。
    case zip64NotSupported

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            "这不是有效的 MXL 压缩包，文件可能已损坏"
        case .missingMusicXMLEntry:
            "压缩包里没有找到 MusicXML 乐谱文件"
        case .unsupportedCompression:
            "压缩包使用了不支持的压缩方式，请重新导出为 .mxl 或 .musicxml"
        case .entryTooLarge:
            "乐谱文件解压后超过 8 MB 上限，请换用更小的乐谱"
        case .encryptedEntry:
            "不支持加密的压缩包，请先解除密码再导入"
        case .zip64NotSupported:
            "不支持 ZIP64 格式的压缩包，请用常规 ZIP 重新打包"
        }
    }
}

/// 纯内存读取 .mxl：解析 ZIP 目录，按 `META-INF/container.xml` 找到主乐谱并解压。
///
/// 不解压到磁盘、不依赖系统解压工具；支持 store（method 0）与 deflate（method 8），
/// 拒绝加密条目与 ZIP64，并对条目数量、文件名长度和解压后大小设上限，
/// 遇到损坏数据时抛出明确的 ``MXLImportError`` 而不是崩溃或死循环。
public enum MXLArchive {
    /// 单个条目解压后的最大字节数（8 MB）。
    public static let maximumEntryBytes = 8 * 1024 * 1024

    private static let maximumEntryCount = 4_096
    private static let maximumNameBytes = 1_024
    private static let maximumContainerBytes = 1 * 1024 * 1024

    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let zip64Sentinel16: UInt16 = 0xFFFF
    private static let zip64Sentinel32: UInt32 = 0xFFFF_FFFF
    private static let encryptionFlag: UInt16 = 0x0001
    private static let utf8NameFlag: UInt16 = 0x0800

    /// 从 .mxl 数据中取出主 MusicXML 文本（未经 XML 解析）。
    ///
    /// 优先读取 `META-INF/container.xml` 中 `<rootfile full-path="…">` 指向的条目；
    /// 没有可用的 container.xml 时，回退到第一个 `.musicxml` / `.xml` 条目。
    public static func extractMusicXML(from data: Data) throws -> Data {
        guard data.count >= 22, data.starts(with: [0x50, 0x4B]) else {
            throw MXLImportError.invalidArchive
        }

        let endOffset = try locateEndOfCentralDirectory(in: data)
        let entries = try readCentralDirectory(in: data, endOffset: endOffset)
        let entry = try selectMusicXMLEntry(from: entries, in: data)
        return try extract(entry, from: data, limit: maximumEntryBytes)
    }

    // MARK: - ZIP 目录

    private struct CentralEntry {
        let name: String
        let flags: UInt16
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static func locateEndOfCentralDirectory(in data: Data) throws -> Int {
        let lastPossible = data.count - 22
        guard lastPossible >= 0 else { throw MXLImportError.invalidArchive }

        let maximumCommentLength = 0xFFFF
        let minimumOffset = max(0, data.count - 22 - maximumCommentLength)
        var lenientCandidate: Int?

        var offset = lastPossible
        while offset >= minimumOffset {
            if readUInt32(data, at: offset) == endOfCentralDirectorySignature,
               let commentLength = readUInt16(data, at: offset + 20) {
                let expectedEnd = offset + 22 + Int(commentLength)
                if expectedEnd == data.count {
                    return offset
                }
                if lenientCandidate == nil, expectedEnd <= data.count {
                    lenientCandidate = offset
                }
            }
            offset -= 1
        }

        guard let candidate = lenientCandidate else { throw MXLImportError.invalidArchive }
        return candidate
    }

    private static func readCentralDirectory(in data: Data, endOffset: Int) throws -> [CentralEntry] {
        guard let diskNumber = readUInt16(data, at: endOffset + 4),
              let directoryDisk = readUInt16(data, at: endOffset + 6),
              let entriesOnDisk = readUInt16(data, at: endOffset + 8),
              let totalEntries = readUInt16(data, at: endOffset + 10),
              let directorySize = readUInt32(data, at: endOffset + 12),
              let directoryOffset = readUInt32(data, at: endOffset + 16) else {
            throw MXLImportError.invalidArchive
        }

        if diskNumber == zip64Sentinel16
            || directoryDisk == zip64Sentinel16
            || totalEntries == zip64Sentinel16
            || entriesOnDisk == zip64Sentinel16
            || directorySize == zip64Sentinel32
            || directoryOffset == zip64Sentinel32 {
            throw MXLImportError.zip64NotSupported
        }
        guard diskNumber == 0, directoryDisk == 0, entriesOnDisk == totalEntries else {
            throw MXLImportError.invalidArchive
        }

        let entryCount = Int(totalEntries)
        guard entryCount <= maximumEntryCount else { throw MXLImportError.invalidArchive }

        let start = Int(directoryOffset)
        let size = Int(directorySize)
        guard start >= 0, size >= 0, start + size <= endOffset else {
            throw MXLImportError.invalidArchive
        }

        var entries: [CentralEntry] = []
        entries.reserveCapacity(entryCount)
        var cursor = start
        let directoryEnd = start + size

        for _ in 0..<entryCount {
            guard cursor + 46 <= directoryEnd, cursor + 46 <= data.count,
                  readUInt32(data, at: cursor) == centralHeaderSignature,
                  let flags = readUInt16(data, at: cursor + 8),
                  let method = readUInt16(data, at: cursor + 10),
                  let compressedSize = readUInt32(data, at: cursor + 20),
                  let uncompressedSize = readUInt32(data, at: cursor + 24),
                  let nameLength = readUInt16(data, at: cursor + 28),
                  let extraLength = readUInt16(data, at: cursor + 30),
                  let commentLength = readUInt16(data, at: cursor + 32),
                  let entryDisk = readUInt16(data, at: cursor + 34),
                  let localHeaderOffset = readUInt32(data, at: cursor + 42) else {
                throw MXLImportError.invalidArchive
            }

            if compressedSize == zip64Sentinel32
                || uncompressedSize == zip64Sentinel32
                || localHeaderOffset == zip64Sentinel32
                || entryDisk == zip64Sentinel16 {
                throw MXLImportError.zip64NotSupported
            }
            guard entryDisk == 0 else { throw MXLImportError.invalidArchive }
            guard nameLength <= maximumNameBytes else { throw MXLImportError.invalidArchive }
            if flags & encryptionFlag != 0 { throw MXLImportError.encryptedEntry }

            let headerEnd = cursor + 46 + Int(nameLength) + Int(extraLength) + Int(commentLength)
            guard headerEnd <= directoryEnd, headerEnd <= data.count else {
                throw MXLImportError.invalidArchive
            }

            let nameStart = data.startIndex + cursor + 46
            let nameData = Data(data[nameStart..<(nameStart + Int(nameLength))])
            let name = decodeName(nameData, utf8Flag: flags & utf8NameFlag != 0)

            entries.append(CentralEntry(
                name: name,
                flags: flags,
                method: method,
                compressedSize: Int(compressedSize),
                uncompressedSize: Int(uncompressedSize),
                localHeaderOffset: Int(localHeaderOffset)
            ))
            cursor = headerEnd
        }

        return entries
    }

    // MARK: - 选择乐谱条目

    private static func selectMusicXMLEntry(from entries: [CentralEntry], in data: Data) throws -> CentralEntry {
        // 1. META-INF/container.xml 的 rootfile 是 MXL 规范指定的主乐谱入口。
        if let container = entries.first(where: { $0.name.lowercased() == "meta-inf/container.xml" }),
           let containerData = try? extract(container, from: data, limit: maximumContainerBytes),
           let rootPath = containerRootfilePath(from: containerData) {
            let normalized = normalizedEntryName(rootPath)
            if let match = entries.first(where: { $0.name == normalized })
                ?? entries.first(where: { $0.name.lowercased() == normalized.lowercased() }) {
                return match
            }
        }

        // 2. 没有可用的 container.xml 时，退而取第一个 MusicXML / XML 条目。
        if let fallback = entries.first(where: isMusicXMLCandidate) {
            return fallback
        }
        throw MXLImportError.missingMusicXMLEntry
    }

    private static func containerRootfilePath(from data: Data) -> String? {
        let delegate = ContainerXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return delegate.rootfilePath
    }

    private static func normalizedEntryName(_ rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        while name.hasPrefix("./") { name.removeFirst(2) }
        while name.hasPrefix("/") { name.removeFirst() }
        return name
    }

    private static func isMusicXMLCandidate(_ entry: CentralEntry) -> Bool {
        let name = entry.name
        guard !name.hasSuffix("/") else { return false }
        let lowered = name.lowercased()
        guard !lowered.hasPrefix("meta-inf/") else { return false }
        return lowered.hasSuffix(".musicxml") || lowered.hasSuffix(".xml")
    }

    // MARK: - 解压条目

    private static func extract(_ entry: CentralEntry, from data: Data, limit: Int) throws -> Data {
        guard entry.method == 0 || entry.method == 8 else {
            throw MXLImportError.unsupportedCompression
        }
        guard entry.uncompressedSize <= limit else { throw MXLImportError.entryTooLarge }
        guard entry.compressedSize >= 0, entry.uncompressedSize >= 0 else {
            throw MXLImportError.invalidArchive
        }

        let payload = try compressedPayload(of: entry, in: data)
        switch entry.method {
        case 0:
            guard payload.count == entry.uncompressedSize else { throw MXLImportError.invalidArchive }
            return payload
        case 8:
            return try inflate(payload, expectedSize: entry.uncompressedSize)
        default:
            throw MXLImportError.unsupportedCompression
        }
    }

    private static func compressedPayload(of entry: CentralEntry, in data: Data) throws -> Data {
        let localHeader = entry.localHeaderOffset
        guard localHeader >= 0, localHeader + 30 <= data.count,
              readUInt32(data, at: localHeader) == localHeaderSignature,
              let localFlags = readUInt16(data, at: localHeader + 6),
              let localMethod = readUInt16(data, at: localHeader + 8),
              let nameLength = readUInt16(data, at: localHeader + 26),
              let extraLength = readUInt16(data, at: localHeader + 28) else {
            throw MXLImportError.invalidArchive
        }
        if localFlags & encryptionFlag != 0 { throw MXLImportError.encryptedEntry }
        guard localMethod == entry.method else { throw MXLImportError.invalidArchive }

        let payloadStart = localHeader + 30 + Int(nameLength) + Int(extraLength)
        guard payloadStart >= 0, payloadStart <= data.count,
              entry.compressedSize <= data.count - payloadStart else {
            throw MXLImportError.invalidArchive
        }
        guard entry.compressedSize > 0 else { return Data() }

        let start = data.startIndex + payloadStart
        return Data(data[start..<(start + entry.compressedSize)])
    }

    private static func inflate(_ payload: Data, expectedSize: Int) throws -> Data {
        guard expectedSize <= maximumEntryBytes else { throw MXLImportError.entryTooLarge }
        guard expectedSize > 0 else {
            guard payload.isEmpty else { throw MXLImportError.invalidArchive }
            return Data()
        }
        guard !payload.isEmpty else { throw MXLImportError.invalidArchive }

        var output = Data(count: expectedSize)
        let decoded = output.withUnsafeMutableBytes { destination in
            payload.withUnsafeBytes { source in
                guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destinationBase,
                    expectedSize,
                    sourceBase,
                    payload.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decoded == expectedSize else { throw MXLImportError.invalidArchive }
        return output
    }

    // MARK: - 辅助

    private static func decodeName(_ data: Data, utf8Flag: Bool) -> String {
        if utf8Flag, let name = String(data: data, encoding: .utf8) {
            return name
        }
        if !utf8Flag, let name = String(data: data, encoding: .isoLatin1) {
            return name
        }
        if let name = String(data: data, encoding: .utf8) {
            return name
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        let index = data.startIndex + offset
        return UInt16(data[index]) | (UInt16(data[index + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let index = data.startIndex + offset
        return UInt32(data[index])
            | (UInt32(data[index + 1]) << 8)
            | (UInt32(data[index + 2]) << 16)
            | (UInt32(data[index + 3]) << 24)
    }
}

/// 读取 `META-INF/container.xml`，取出第一个 rootfile 的 full-path。
private final class ContainerXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var rootfilePath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard rootfilePath == nil else { return }
        guard elementName == "rootfile" || elementName.hasSuffix(":rootfile") else { return }
        guard let path = attributeDict["full-path"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return }
        rootfilePath = path
    }
}
