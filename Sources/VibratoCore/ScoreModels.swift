import Foundation

/// 乐谱中的单个音符：音高与以拍为单位的时值。
///
/// 从 PracticeTools 中抽出，供 MusicXML 解析、指法映射与播放时间轴共用。
public struct ScoreNote: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let midiNote: Int
    public let startBeat: Double
    public let durationBeats: Double

    public init(id: UUID = UUID(), midiNote: Int, startBeat: Double, durationBeats: Double) {
        self.id = id
        self.midiNote = midiNote
        self.startBeat = startBeat
        self.durationBeats = durationBeats
    }
}
