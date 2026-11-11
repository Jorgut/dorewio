import Foundation

/// 播放计划中的单个音符：起始与时长都已换算成秒。
public struct ScorePlaybackEvent: Hashable, Identifiable, Sendable {
    /// 对应乐谱原始音符的索引，便于界面高亮。
    public let id: Int
    public let midiNote: Int
    public let startSeconds: Double
    public let durationSeconds: Double

    public init(id: Int, midiNote: Int, startSeconds: Double, durationSeconds: Double) {
        self.id = id
        self.midiNote = midiNote
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
    }
}

/// 节拍器拍点：`seconds` 从播放开始算起，预备拍也计入其中。
public struct ScoreClick: Hashable, Sendable {
    /// 距离播放开始的时间（含预备拍）。
    public let seconds: Double
    /// 是否为小节起点（重拍）。
    public let isDownbeat: Bool

    public init(seconds: Double, isDownbeat: Bool) {
        self.seconds = seconds
        self.isDownbeat = isDownbeat
    }
}

/// 可直接交给播放器的按谱时间轴。
public struct ScorePlaybackTimeline: Sendable, Equatable {
    public let events: [ScorePlaybackEvent]
    public let totalSeconds: Double
    public let tempoScale: Double
    /// 预备拍时长（秒）；音符事件的 `startSeconds` 不含这一段。
    public let leadInSeconds: Double
    /// 节拍器拍点，包含预备拍与正曲；`seconds` 均从播放开始算起。
    public let clicks: [ScoreClick]

    public init(
        events: [ScorePlaybackEvent],
        totalSeconds: Double,
        tempoScale: Double,
        leadInSeconds: Double = 0,
        clicks: [ScoreClick] = []
    ) {
        self.events = events
        self.totalSeconds = max(0, totalSeconds)
        self.tempoScale = tempoScale
        self.leadInSeconds = max(0, leadInSeconds)
        self.clicks = clicks
    }

    /// 返回当前时间正在发声（或刚结束）的音符 ID。
    /// 预备拍期间返回 nil；正曲时间会先减去预备拍再查找。
    public func eventIndex(at time: Double) -> Int? {
        guard let first = events.first else { return nil }
        guard time >= leadInSeconds else { return nil }
        let scoreTime = time - leadInSeconds
        guard scoreTime + 0.000_1 >= first.startSeconds else { return nil }

        var low = 0
        var high = events.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if events[middle].startSeconds <= scoreTime + 0.000_1 {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return events[low].id
    }
}

/// 把导入的乐谱换算成播放时间轴，并渲染成可播放的采样。
public enum ScorePlayback {
    /// 最低与最高播放速度（相对乐谱标记速度）。
    public static let minimumTempoScale = 0.4
    public static let maximumTempoScale = 1.2
    /// 预备拍最多一小节。
    public static let maximumCountInMeasures = 1

    /// 预备拍 click 时长与音量；短促指数衰减，便于和琴声区分。
    private static let clickDurationSeconds = 0.025
    private static let clickDecaySeconds = 0.008
    private static let clickAttackSeconds = 0.001
    private static let clickAmplitude = 0.25
    private static let downbeatClickFrequency = 1_760.0
    private static let beatClickFrequency = 1_200.0

    public static func timeline(
        score: ImportedScore,
        tempoScale: Double = 1,
        loopMeasures: ClosedRange<Int>? = nil,
        countInMeasures: Int = 0
    ) -> ScorePlaybackTimeline {
        let scale = min(maximumTempoScale, max(minimumTempoScale, tempoScale))
        let bpm = min(300, max(20, score.bpm))
        let secondsPerBeat = 60 / (bpm * scale)

        var regionStartBeat = 0.0
        var regionEndBeat = max(score.endBeat, score.measureStartBeats.last ?? 0)

        if let range = loopMeasures, score.measureCount > 0 {
            let startMeasure = min(max(1, range.lowerBound), score.measureCount)
            let endMeasure = min(max(startMeasure, range.upperBound), score.measureCount)
            regionStartBeat = score.measureStartBeats[startMeasure - 1]
            if endMeasure < score.measureCount {
                regionEndBeat = score.measureStartBeats[endMeasure]
            } else {
                regionEndBeat = max(score.endBeat, regionStartBeat)
            }
        }

        // 预备拍：取第一小节的拍数，超出上限时按上限处理。
        let countIn = min(maximumCountInMeasures, max(0, countInMeasures))
        let leadInBeats = countIn > 0 ? firstMeasureBeats(of: score) : 0
        let leadInSeconds = leadInBeats * secondsPerBeat
        let leadInClicks = countInClicks(leadInBeats: leadInBeats, secondsPerBeat: secondsPerBeat)

        guard regionEndBeat > regionStartBeat else {
            return ScorePlaybackTimeline(
                events: [],
                totalSeconds: leadInSeconds,
                tempoScale: scale,
                leadInSeconds: leadInSeconds,
                clicks: leadInClicks
            )
        }

        var events: [ScorePlaybackEvent] = []
        for (index, note) in score.notes.enumerated() {
            guard note.startBeat >= regionStartBeat - 0.000_1,
                  note.startBeat < regionEndBeat - 0.000_1 else { continue }

            let noteEnd = min(note.startBeat + note.durationBeats, regionEndBeat)
            let durationBeats = max(0.05, noteEnd - note.startBeat)
            events.append(ScorePlaybackEvent(
                id: index,
                midiNote: note.midiNote,
                startSeconds: (note.startBeat - regionStartBeat) * secondsPerBeat,
                durationSeconds: durationBeats * secondsPerBeat
            ))
        }

        let regionSeconds = (regionEndBeat - regionStartBeat) * secondsPerBeat
        let clicks = leadInClicks + beatClicks(
            score: score,
            regionStartBeat: regionStartBeat,
            regionEndBeat: regionEndBeat,
            secondsPerBeat: secondsPerBeat,
            leadInSeconds: leadInSeconds
        )

        return ScorePlaybackTimeline(
            events: events,
            totalSeconds: leadInSeconds + regionSeconds,
            tempoScale: scale,
            leadInSeconds: leadInSeconds,
            clicks: clicks
        )
    }

    /// 用与指板、示范音一致的音色把时间轴渲染为单声道采样。
    ///
    /// - `metronomeEnabled == true` 时渲染全部拍点；否则只保留预备拍的拍点。
    public static func renderSamples(
        timeline: ScorePlaybackTimeline,
        sampleRate: Double,
        metronomeEnabled: Bool = false
    ) -> [Float] {
        guard sampleRate > 0 else { return [] }
        let tailSeconds = 0.06
        let frameCount = Int(((timeline.totalSeconds + tailSeconds) * sampleRate).rounded(.up))
        guard frameCount > 0 else { return [] }

        var samples = [Float](repeating: 0, count: frameCount)

        // 音符事件的时间相对正曲起点，渲染时要补上预备拍。
        for event in timeline.events {
            let tone = PracticeToneGenerator.samples(
                frequency: PitchName.frequency(for: event.midiNote),
                duration: event.durationSeconds,
                sampleRate: sampleRate
            )
            let offset = Int(((timeline.leadInSeconds + event.startSeconds) * sampleRate).rounded())
            guard offset < frameCount else { continue }
            let count = min(tone.count, frameCount - offset)
            for index in 0..<count {
                samples[offset + index] += tone[index]
            }
        }

        for click in timeline.clicks {
            // 关闭节拍器时仍保留预备拍，方便跟着数拍进曲。
            guard metronomeEnabled || click.seconds < timeline.leadInSeconds else { continue }
            let clickTone = clickSamples(isDownbeat: click.isDownbeat, sampleRate: sampleRate)
            let offset = Int((click.seconds * sampleRate).rounded())
            guard offset < frameCount else { continue }
            let count = min(clickTone.count, frameCount - offset)
            for index in 0..<count {
                samples[offset + index] += clickTone[index]
            }
        }

        // 多个音或 click 偶然叠加时避免削波。
        for index in samples.indices {
            samples[index] = min(0.98, max(-0.98, samples[index]))
        }
        return samples
    }

    // MARK: - 拍点计算

    /// 第一小节的拍数；只有一个拍位时回退到 4 拍。
    private static func firstMeasureBeats(of score: ImportedScore) -> Double {
        let starts = score.measureStartBeats
        if starts.count >= 2 {
            let length = starts[1] - starts[0]
            if length > 0.000_1 { return length }
        }
        return 4
    }

    /// 预备拍拍点：从播放开始到正曲起点，每个拍一下，第一拍是重拍。
    private static func countInClicks(
        leadInBeats: Double,
        secondsPerBeat: Double
    ) -> [ScoreClick] {
        guard leadInBeats > 0.000_1, secondsPerBeat > 0 else { return [] }
        var clicks: [ScoreClick] = []
        var beat = 0.0
        while beat < leadInBeats - 0.000_1 {
            clicks.append(ScoreClick(seconds: beat * secondsPerBeat, isDownbeat: beat < 0.000_1))
            beat += 1
        }
        return clicks
    }

    /// 正曲拍点：每个小节从起点开始每个拍一下，小节起点是重拍。
    private static func beatClicks(
        score: ImportedScore,
        regionStartBeat: Double,
        regionEndBeat: Double,
        secondsPerBeat: Double,
        leadInSeconds: Double
    ) -> [ScoreClick] {
        let starts = score.measureStartBeats.isEmpty ? [0.0] : score.measureStartBeats
        var clicks: [ScoreClick] = []
        for measureIndex in starts.indices {
            let measureStart = starts[measureIndex]
            guard measureStart < regionEndBeat - 0.000_1 else { break }

            let measureEnd: Double
            if measureIndex + 1 < starts.count {
                measureEnd = min(starts[measureIndex + 1], regionEndBeat)
            } else {
                measureEnd = regionEndBeat
            }
            guard measureEnd > max(measureStart, regionStartBeat) + 0.000_1 else { continue }

            var beat = measureStart
            while beat < measureEnd - 0.000_1 {
                if beat >= regionStartBeat - 0.000_1 {
                    clicks.append(ScoreClick(
                        seconds: leadInSeconds + (beat - regionStartBeat) * secondsPerBeat,
                        isDownbeat: abs(beat - measureStart) <= 0.000_1
                    ))
                }
                beat += 1
            }
        }
        return clicks
    }

    /// 单个 click 的短促采样：正弦 + 快速指数衰减，重拍音高更高。
    private static func clickSamples(isDownbeat: Bool, sampleRate: Double) -> [Float] {
        guard sampleRate > 0 else { return [] }
        let frameCount = max(1, Int((clickDurationSeconds * sampleRate).rounded()))
        let frequency = isDownbeat ? downbeatClickFrequency : beatClickFrequency
        return (0..<frameCount).map { frame in
            let time = Double(frame) / sampleRate
            let attack = min(1, time / clickAttackSeconds)
            let envelope = attack * exp(-time / clickDecaySeconds)
            return Float(sin(2 * Double.pi * frequency * time) * envelope * clickAmplitude)
        }
    }
}
