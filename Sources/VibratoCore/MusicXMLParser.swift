import Foundation

/// 从 MusicXML 导入的单声部乐谱。
public struct ImportedScore: Sendable, Equatable {
    public let title: String
    public let bpm: Double
    public let notes: [ScoreNote]
    public let measureStartBeats: [Double]
    public let divisions: Int

    public var measureCount: Int { measureStartBeats.count }

    /// 全曲最后一个音结束的位置（以拍计）。
    public var endBeat: Double {
        notes.reduce(0) { max($0, $1.startBeat + $1.durationBeats) }
    }

    public init(
        title: String,
        bpm: Double,
        notes: [ScoreNote],
        measureStartBeats: [Double],
        divisions: Int
    ) {
        self.title = title
        self.bpm = bpm
        self.notes = notes
        self.measureStartBeats = measureStartBeats
        self.divisions = divisions
    }
}

public enum MusicXMLImportError: LocalizedError, Equatable {
    case unreadableFile
    case unsupportedFormat
    case emptyScore

    public var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "无法读取这个乐谱文件，请确认是有效的 MusicXML"
        case .unsupportedFormat:
            "只支持 score-partwise 格式的 MusicXML"
        case .emptyScore:
            "乐谱里没有可用的音符"
        }
    }
}

/// 轻量 MusicXML（score-partwise、单声部）解析器。
///
/// 支持未压缩的 `.musicxml` 与 ZIP 压缩的 `.mxl`（自动识别 ZIP 魔数并在内存中解压）。
/// 只读取第一个 part 的音高与时值；和弦只保留首个音，倚音跳过，
/// 连音线会把延音并入前一个同音。速度优先取 `<sound tempo="…">`，
/// 次选取节拍器标记，否则回退到 80 BPM。
public enum MusicXMLParser {
    public static func parse(data: Data, fallbackTitle: String = "导入乐谱") throws -> ImportedScore {
        guard !data.isEmpty else { throw MusicXMLImportError.unreadableFile }

        // .mxl 是 ZIP 压缩包：先取出主 MusicXML，再走同一套解析流程。
        let xmlData = data.starts(with: [0x50, 0x4B])
            ? try MXLArchive.extractMusicXML(from: data)
            : data
        guard !xmlData.isEmpty else { throw MusicXMLImportError.unreadableFile }

        let delegate = MusicXMLParserDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            throw delegate.sawScorePartwise ? MusicXMLImportError.unreadableFile : MusicXMLImportError.unsupportedFormat
        }
        guard delegate.sawScorePartwise else { throw MusicXMLImportError.unsupportedFormat }
        guard !delegate.notes.isEmpty else { throw MusicXMLImportError.emptyScore }

        let title = delegate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bpm = min(300, max(20, delegate.tempo))
        let measureStarts = delegate.measureStartBeats.isEmpty ? [0] : delegate.measureStartBeats
        return ImportedScore(
            title: title.isEmpty ? fallbackTitle : title,
            bpm: bpm,
            notes: delegate.notes,
            measureStartBeats: measureStarts,
            divisions: max(1, delegate.divisions)
        )
    }

    public static func parse(contentsOf url: URL) throws -> ImportedScore {
        let fallback = url.deletingPathExtension().lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            return try parse(data: data, fallbackTitle: fallback)
        } catch let error as MusicXMLImportError {
            throw error
        } catch let error as MXLImportError {
            throw error
        } catch {
            throw MusicXMLImportError.unreadableFile
        }
    }
}

private final class MusicXMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var title = ""
    private(set) var tempo: Double = 80
    private(set) var notes: [ScoreNote] = []
    private(set) var measureStartBeats: [Double] = []
    private(set) var divisions = 1
    private(set) var sawScorePartwise = false

    private var partCount = 0
    private var isFirstPart = false
    private var beatPosition = 0.0
    private var hasSoundTempo = false

    private var isInBackup = false
    private var isInForward = false
    private var backupDivisions = 0.0

    private var isInNote = false
    private var isRest = false
    private var isChord = false
    private var isGrace = false
    private var noteDurationDivisions = 0.0
    private var noteStep: String?
    private var noteAlter = 0
    private var noteOctave: Int?
    private var tieStop = false
    private var lastNoteIndex: Int?

    private var textBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        textBuffer = ""

        switch elementName {
        case "score-partwise":
            sawScorePartwise = true
        case "part":
            partCount += 1
            isFirstPart = partCount == 1
        case "measure":
            if isFirstPart { measureStartBeats.append(beatPosition) }
        case "sound":
            if isFirstPart, !hasSoundTempo, let value = attributeDict["tempo"], let bpm = Double(value) {
                tempo = bpm
                hasSoundTempo = true
            }
        case "backup":
            isInBackup = true
            backupDivisions = 0
        case "forward":
            isInForward = true
        case "note":
            isInNote = true
            isRest = false
            isChord = false
            isGrace = false
            noteDurationDivisions = 0
            noteStep = nil
            noteAlter = 0
            noteOctave = nil
            tieStop = false
        case "rest":
            isRest = true
        case "chord":
            isChord = true
        case "grace":
            isGrace = true
        case "tie":
            if attributeDict["type"] == "stop" { tieStop = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        textBuffer = ""

        switch elementName {
        case "work-title", "movement-title":
            if title.isEmpty { title = text }
        case "divisions":
            if isFirstPart, let value = Int(text), value > 0 { divisions = value }
        case "step":
            noteStep = text
        case "alter":
            noteAlter = Int(text) ?? 0
        case "octave":
            noteOctave = Int(text)
        case "duration":
            let value = Double(text) ?? 0
            if isInNote {
                noteDurationDivisions = value
            } else if isInBackup {
                backupDivisions = value
            } else if isInForward {
                beatPosition += beats(fromDivisions: value)
            }
        case "per-minute":
            if isFirstPart, !hasSoundTempo, let bpm = Double(text), bpm > 0 {
                tempo = bpm
            }
        case "backup":
            isInBackup = false
            beatPosition = max(0, beatPosition - beats(fromDivisions: backupDivisions))
            backupDivisions = 0
        case "forward":
            isInForward = false
        case "note":
            finishNote()
        default:
            break
        }
    }

    private func beats(fromDivisions value: Double) -> Double {
        divisions > 0 ? value / Double(divisions) : 0
    }

    private func finishNote() {
        defer {
            isInNote = false
            isRest = false
            isChord = false
            isGrace = false
            noteDurationDivisions = 0
            noteStep = nil
            noteAlter = 0
            noteOctave = nil
            tieStop = false
        }

        guard isFirstPart, isInNote, !isGrace else { return }
        let durationBeats = beats(fromDivisions: noteDurationDivisions)

        if isRest {
            beatPosition += durationBeats
            return
        }

        // 和弦只保留第一个音，后续和弦音不推进节拍。
        if isChord { return }

        guard let step = noteStep,
              let octave = noteOctave,
              let midiNote = Self.midiNote(step: step, alter: noteAlter, octave: octave) else {
            beatPosition += durationBeats
            return
        }

        let startBeat = beatPosition
        if tieStop,
           let lastIndex = lastNoteIndex,
           notes.indices.contains(lastIndex),
           notes[lastIndex].midiNote == midiNote,
           abs(notes[lastIndex].startBeat + notes[lastIndex].durationBeats - startBeat) < 0.000_1 {
            let previous = notes[lastIndex]
            notes[lastIndex] = ScoreNote(
                id: previous.id,
                midiNote: previous.midiNote,
                startBeat: previous.startBeat,
                durationBeats: previous.durationBeats + durationBeats
            )
        } else if durationBeats > 0 {
            notes.append(ScoreNote(
                midiNote: midiNote,
                startBeat: startBeat,
                durationBeats: durationBeats
            ))
            lastNoteIndex = notes.count - 1
        }

        beatPosition += durationBeats
    }

    private static func midiNote(step: String, alter: Int, octave: Int) -> Int? {
        let stepSemitones: [String: Int] = [
            "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
        ]
        guard let base = stepSemitones[step.uppercased()] else { return nil }
        return (octave + 1) * 12 + base + alter
    }
}
