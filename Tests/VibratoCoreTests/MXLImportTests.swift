import Compression
import Foundation
import Testing
@testable import VibratoCore

// MARK: - 测试用最小 ZIP 构造器

/// 直接拼出 local header + central directory + EOCD，便于构造各种边角情况。
private struct TestZIPArchive {
    private struct Entry {
        let name: String
        let contents: Data
        let method: UInt16
        let flags: UInt16
        let declaredUncompressedSize: UInt32?
    }

    private var entries: [Entry] = []

    mutating func add(
        name: String,
        data: Data,
        compressed: Bool = false,
        flags: UInt16 = 0,
        methodOverride: UInt16? = nil,
        declaredUncompressedSize: UInt32? = nil
    ) {
        entries.append(Entry(
            name: name,
            contents: data,
            method: methodOverride ?? (compressed ? 8 : 0),
            flags: flags,
            declaredUncompressedSize: declaredUncompressedSize
        ))
    }

    mutating func add(name: String, xml: String, compressed: Bool = false) {
        add(name: name, data: Data(xml.utf8), compressed: compressed)
    }

    func build() -> Data {
        var localBytes: [UInt8] = []
        var centralBytes: [UInt8] = []
        var fileOffset: UInt32 = 0

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let payload = entry.method == 8 ? deflate(entry.contents) : entry.contents
            let compressedSize = UInt32(payload.count)
            let uncompressedSize = entry.declaredUncompressedSize ?? UInt32(entry.contents.count)
            let checksum = crc32(entry.contents)
            let localOffset = fileOffset

            var local: [UInt8] = []
            local += le32(0x0403_4B50)          // local file header signature
            local += le16(20)                    // version needed
            local += le16(entry.flags)           // general purpose flags
            local += le16(entry.method)          // compression method
            local += le16(0)                     // mod time
            local += le16(0)                     // mod date
            local += le32(checksum)              // crc32
            local += le32(compressedSize)
            local += le32(uncompressedSize)
            local += le16(UInt16(nameBytes.count))
            local += le16(0)                     // extra field length
            local += nameBytes
            local += [UInt8](payload)

            localBytes += local
            fileOffset += UInt32(local.count)

            centralBytes += le32(0x0201_4B50)    // central directory signature
            centralBytes += le16(20)             // version made by
            centralBytes += le16(20)             // version needed
            centralBytes += le16(entry.flags)
            centralBytes += le16(entry.method)
            centralBytes += le16(0)              // mod time
            centralBytes += le16(0)              // mod date
            centralBytes += le32(checksum)
            centralBytes += le32(compressedSize)
            centralBytes += le32(uncompressedSize)
            centralBytes += le16(UInt16(nameBytes.count))
            centralBytes += le16(0)              // extra field length
            centralBytes += le16(0)              // comment length
            centralBytes += le16(0)              // disk number start
            centralBytes += le16(0)              // internal attributes
            centralBytes += le32(0)              // external attributes
            centralBytes += le32(localOffset)    // local header offset
            centralBytes += nameBytes
        }

        var archive = localBytes
        let centralOffset = UInt32(archive.count)
        archive += centralBytes
        archive += le32(0x0605_4B50)             // end of central directory
        archive += le16(0)                       // disk number
        archive += le16(0)                       // central directory disk
        archive += le16(UInt16(entries.count))
        archive += le16(UInt16(entries.count))
        archive += le32(UInt32(centralBytes.count))
        archive += le32(centralOffset)
        archive += le16(0)                       // comment length
        return Data(archive)
    }
}

private func le16(_ value: UInt16) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
}

private func le32(_ value: UInt32) -> [UInt8] {
    [
        UInt8(value & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 24) & 0xFF)
    ]
}

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
    }
    return crc ^ 0xFFFF_FFFF
}

/// 用和运行时解压相同的 COMPRESSION_ZLIB（Apple 平台为 raw DEFLATE）压缩。
private func deflate(_ input: Data) -> Data {
    guard !input.isEmpty else { return Data() }
    let capacity = max(64, input.count + input.count / 2 + 64)
    var output = Data(count: capacity)
    let written = output.withUnsafeMutableBytes { destination in
        input.withUnsafeBytes { source in
            guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                  let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_encode_buffer(
                destinationBase,
                capacity,
                sourceBase,
                input.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
    }
    guard written > 0 else { return input }
    output.count = written
    return output
}

// MARK: - MXL 导入测试

struct MXLImportTests {
    private var scoreXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <work><work-title>压缩包小星星</work-title></work>
          <part-list><score-part id="P1"><part-name>Violin</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>2</divisions></attributes>
              <direction><sound tempo="96"/></direction>
              <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration></note>
              <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration></note>
            </measure>
          </part>
        </score-partwise>
        """
    }

    private func containerXML(rootPath: String = "score.musicxml") -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container>
          <rootfiles>
            <rootfile full-path="\(rootPath)" media-type="application/vnd.recordare.musicxml+xml"/>
          </rootfiles>
        </container>
        """
    }

    private func sampleURL(_ name: String) -> URL? {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent("Examples").appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: store

    @Test("store 压缩包按 container.xml 指向解析出标题、速度与音符")
    func parsesStoredArchiveUsingContainer() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML(rootPath: "scores/score.musicxml"))
        archive.add(name: "scores/decoy.musicxml", xml: scoreXML.replacingOccurrences(of: "压缩包小星星", with: "干扰乐谱"))
        archive.add(name: "scores/score.musicxml", xml: scoreXML)

        let score = try MusicXMLParser.parse(data: archive.build())

        #expect(score.title == "压缩包小星星")
        #expect(score.bpm == 96)
        #expect(score.notes.map(\.midiNote) == [62, 69])
        #expect(score.notes.map(\.startBeat) == [0, 1])
        #expect(score.measureCount == 1)
    }

    @Test("deflate 压缩的乐谱条目可解析")
    func parsesDeflatedScoreEntry() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML(), compressed: true)
        archive.add(name: "score.musicxml", xml: scoreXML, compressed: true)

        let score = try MusicXMLParser.parse(data: archive.build())

        #expect(score.title == "压缩包小星星")
        #expect(score.notes.count == 2)
        #expect(score.bpm == 96)
    }

    @Test("没有 container.xml 时取第一个 MusicXML 条目")
    func fallsBackToFirstMusicXMLEntry() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/readme.txt", data: Data("说明".utf8))
        archive.add(name: "readme.txt", data: Data("不是乐谱".utf8))
        archive.add(name: "first.musicxml", xml: scoreXML)
        archive.add(name: "second.musicxml", xml: scoreXML.replacingOccurrences(of: "压缩包小星星", with: "第二首"))

        let score = try MusicXMLParser.parse(data: archive.build())
        #expect(score.title == "压缩包小星星")
    }

    @Test("没有 container.xml 时也接受第一个 .xml 乐谱条目")
    func fallsBackToFirstXMLEntry() throws {
        var archive = TestZIPArchive()
        archive.add(name: "score.xml", xml: scoreXML)

        let score = try MusicXMLParser.parse(data: archive.build())
        #expect(score.title == "压缩包小星星")
        #expect(score.notes.count == 2)
    }

    // MARK: 错误

    @Test("压缩包里没有乐谱条目时抛出 missingMusicXMLEntry")
    func rejectsArchiveWithoutMusicXML() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML(rootPath: "missing.musicxml"))
        archive.add(name: "readme.txt", data: Data("说明".utf8))

        #expect(throws: MXLImportError.missingMusicXMLEntry) {
            try MXLArchive.extractMusicXML(from: archive.build())
        }
        #expect(throws: MXLImportError.missingMusicXMLEntry) {
            try MusicXMLParser.parse(data: archive.build())
        }
    }

    @Test("损坏或非 ZIP 数据抛出 invalidArchive")
    func rejectsCorruptArchive() throws {
        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: Data("not a zip at all".utf8))
        }
        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: Data([0x50, 0x4B, 0x03, 0x04]))
        }
        #expect(throws: MXLImportError.invalidArchive) {
            try MusicXMLParser.parse(data: Data([0x50, 0x4B, 0x03, 0x04]))
        }

        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML())
        archive.add(name: "score.musicxml", xml: scoreXML)
        let full = archive.build()
        let truncated = Data(full.prefix(full.count - 10))

        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: truncated)
        }
    }

    @Test("拒绝加密、不支持的压缩方式与超大条目")
    func rejectsEncryptedUnsupportedAndOversizedEntries() throws {
        var encrypted = TestZIPArchive()
        encrypted.add(name: "score.musicxml", data: Data(scoreXML.utf8), flags: 0x0001)
        #expect(throws: MXLImportError.encryptedEntry) {
            try MXLArchive.extractMusicXML(from: encrypted.build())
        }

        var unsupported = TestZIPArchive()
        unsupported.add(name: "score.musicxml", data: Data(scoreXML.utf8), methodOverride: 9)
        #expect(throws: MXLImportError.unsupportedCompression) {
            try MXLArchive.extractMusicXML(from: unsupported.build())
        }

        var oversized = TestZIPArchive()
        oversized.add(
            name: "score.musicxml",
            data: Data(scoreXML.utf8),
            declaredUncompressedSize: UInt32(MXLArchive.maximumEntryBytes) + 1
        )
        #expect(throws: MXLImportError.entryTooLarge) {
            try MXLArchive.extractMusicXML(from: oversized.build())
        }
    }

    // MARK: 真实样例

    @Test("解析随项目提供的 MXL 小星星样例")
    func parsesBundledMXLSample() throws {
        guard let url = sampleURL("sample-twinkle-d-major.mxl") else { return }
        let data = try Data(contentsOf: url)

        let extracted = try MXLArchive.extractMusicXML(from: data)
        let score = try MusicXMLParser.parse(contentsOf: url)

        #expect(score.title == "小星星（D 大调，第一把位）")
        #expect(score.bpm == 88)
        #expect(score.measureCount == 4)
        #expect(score.notes.count == 14)
        #expect(score.notes.map(\.startBeat).prefix(4) == [0, 1, 2, 3])
        #expect(extracted.starts(with: Data("<?xml".utf8)))

        // 从 .mxl 解出的内容应与同目录下未压缩的 .musicxml 样例一致。
        guard let plainURL = sampleURL("sample-twinkle-d-major.musicxml") else { return }
        #expect(extracted == (try Data(contentsOf: plainURL)))
    }

    // MARK: 边界与健壮性

    @Test("单个条目解压上限为 8 MB")
    func exposesMaximumEntrySize() {
        #expect(MXLArchive.maximumEntryBytes == 8 * 1024 * 1024)
    }

    @Test("空压缩包抛出 missingMusicXMLEntry")
    func rejectsEmptyArchive() {
        let archive = TestZIPArchive()
        #expect(throws: MXLImportError.missingMusicXMLEntry) {
            try MXLArchive.extractMusicXML(from: archive.build())
        }
    }

    @Test("EOCD 尾部注释不影响解析")
    func toleratesZipArchiveComment() throws {
        var archive = TestZIPArchive()
        archive.add(name: "score.musicxml", xml: scoreXML)
        var data = archive.build()
        guard let endOffset = endOfCentralDirectoryOffset(in: data) else {
            Issue.record("未找到 EOCD")
            return
        }
        let comment = Data("MuseScore 导出的压缩包".utf8)
        patchUInt16(&data, at: endOffset + 20, to: UInt16(comment.count))
        data.append(comment)

        let score = try MusicXMLParser.parse(data: data)
        #expect(score.title == "压缩包小星星")
    }

    @Test("ZIP64 哨兵值抛出 zip64NotSupported")
    func rejectsZip64Sentinel() {
        var archive = TestZIPArchive()
        archive.add(name: "score.musicxml", xml: scoreXML)
        var data = archive.build()
        guard let endOffset = endOfCentralDirectoryOffset(in: data) else {
            Issue.record("未找到 EOCD")
            return
        }
        // 条目总数写成 ZIP64 哨兵 0xFFFF。
        patchUInt16(&data, at: endOffset + 10, to: 0xFFFF)

        #expect(throws: MXLImportError.zip64NotSupported) {
            try MXLArchive.extractMusicXML(from: data)
        }
    }

    @Test("条目名超过上限时抛出 invalidArchive")
    func rejectsOversizedEntryName() {
        var archive = TestZIPArchive()
        archive.add(
            name: String(repeating: "a", count: 1_025) + ".musicxml",
            xml: scoreXML
        )
        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: archive.build())
        }
    }

    @Test("local header 与 central directory 的压缩方式不一致时拒绝")
    func rejectsMismatchedLocalHeaderMethod() {
        var archive = TestZIPArchive()
        archive.add(name: "score.musicxml", xml: scoreXML)
        var data = archive.build()
        // 第一个条目的 local file header 从 0 开始，压缩方式在偏移 8。
        patchUInt16(&data, at: 8, to: 9)

        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: data)
        }
    }

    @Test("local header 的加密标记也会被拒绝")
    func rejectsEncryptedLocalHeader() {
        var archive = TestZIPArchive()
        archive.add(name: "score.musicxml", xml: scoreXML)
        var data = archive.build()
        patchUInt16(&data, at: 6, to: 0x0001)

        #expect(throws: MXLImportError.encryptedEntry) {
            try MXLArchive.extractMusicXML(from: data)
        }
    }

    @Test("store 条目声明大小与实际不符时抛出 invalidArchive")
    func rejectsMismatchedStoredSize() {
        var archive = TestZIPArchive()
        archive.add(
            name: "score.musicxml",
            data: Data(scoreXML.utf8),
            declaredUncompressedSize: UInt32(scoreXML.utf8.count) + 10
        )
        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: archive.build())
        }
    }

    @Test("container.xml 指向不存在的条目时回退到第一个乐谱条目")
    func fallsBackWhenContainerRootfileIsMissing() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML(rootPath: "missing.musicxml"))
        archive.add(name: "scores/score.musicxml", xml: scoreXML)

        let score = try MusicXMLParser.parse(data: archive.build())
        #expect(score.title == "压缩包小星星")
    }

    @Test("container.xml 中带 ./ 前缀的 rootfile 路径可归一化")
    func normalizesContainerRootfilePath() throws {
        var archive = TestZIPArchive()
        archive.add(name: "META-INF/container.xml", xml: containerXML(rootPath: "./score.musicxml"))
        archive.add(name: "score.musicxml", xml: scoreXML)

        let score = try MusicXMLParser.parse(data: archive.build())
        #expect(score.title == "压缩包小星星")
    }

    @Test("deflate 载荷被截断时抛出 invalidArchive")
    func rejectsTruncatedDeflatePayload() {
        var archive = TestZIPArchive()
        archive.add(name: "score.musicxml", xml: scoreXML, compressed: true)
        var data = archive.build()
        guard let endOffset = endOfCentralDirectoryOffset(in: data) else {
            Issue.record("未找到 EOCD")
            return
        }
        // 先读取 central directory 起始位置，再把该条目的压缩后大小改为 1 字节。
        guard let centralOffset = readUInt32(data, at: endOffset + 16) else {
            Issue.record("未找到 central directory")
            return
        }
        patchUInt32(&data, at: Int(centralOffset) + 20, to: 1)

        #expect(throws: MXLImportError.invalidArchive) {
            try MXLArchive.extractMusicXML(from: data)
        }
    }
}

// MARK: - 二进制改写辅助

/// 直接改写生成的 ZIP 字节，用于构造各种损坏/边角情况。
private func patchUInt16(_ data: inout Data, at offset: Int, to value: UInt16) {
    let base = data.startIndex + offset
    guard base + 1 < data.endIndex else { return }
    data[base] = UInt8(value & 0xFF)
    data[base + 1] = UInt8((value >> 8) & 0xFF)
}

private func patchUInt32(_ data: inout Data, at offset: Int, to value: UInt32) {
    let base = data.startIndex + offset
    guard base + 3 < data.endIndex else { return }
    data[base] = UInt8(value & 0xFF)
    data[base + 1] = UInt8((value >> 8) & 0xFF)
    data[base + 2] = UInt8((value >> 16) & 0xFF)
    data[base + 3] = UInt8((value >> 24) & 0xFF)
}

private func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
    let base = data.startIndex + offset
    guard base + 3 < data.endIndex else { return nil }
    return UInt32(data[base])
        | (UInt32(data[base + 1]) << 8)
        | (UInt32(data[base + 2]) << 16)
        | (UInt32(data[base + 3]) << 24)
}

private func endOfCentralDirectoryOffset(in data: Data) -> Int? {
    guard data.count >= 22 else { return nil }
    var offset = data.count - 22
    while offset >= 0 {
        let base = data.startIndex + offset
        if data[base] == 0x50,
           data[base + 1] == 0x4B,
           data[base + 2] == 0x05,
           data[base + 3] == 0x06 {
            return offset
        }
        offset -= 1
    }
    return nil
}
