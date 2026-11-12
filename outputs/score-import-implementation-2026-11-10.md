# 乐谱导入与直接演奏：首版实现说明

2026-11-10 · 对应现有构建 `0.1 (3)` 之后的一轮功能开发，未重新打包或上传 TestFlight。

> 2026-11-11 更新：MXL 自动解压、节拍器与预备拍已在[第二轮实现说明](score-import-v2-2026-11-11.md)中完成；本文「MXL 是压缩包，需先解压」的描述已被取代。

## 目标与验收范围

用户需求：导入现成乐谱后，能像 StringFlow 一样按谱直接演奏。

首版覆盖：

- 导入单声部 MusicXML（`.musicxml` / `.xml`），读取标题、速度、小节和音符时值；
- 按谱发声：与指板、示范音相同的带泛音小提琴音色；
- 每个音显示第一把位的弦与指号（0 空弦、低 1、1、低 2、2、3、高 3、4 指）；
- 播放时高亮当前音并自动滚动；
- 播放速度 0.5×–1.0×（改变速度时重新渲染，不改变音高）；
- 片段循环：按小节选择循环范围，或整首循环；
- MXL 是压缩包，导入时明确提示先解压。

未纳入本轮：MXL 自动解压、MIDI、PDF/图片识谱、双声部/和弦、反复记号和装饰音、真琴音准评分、乐谱导入后的持久化曲库。

## 实现结构

### VibratoCore（可单测）

- `Sources/VibratoCore/MusicXMLParser.swift`
  - `ImportedScore`：标题、BPM、`[ScoreNote]`、每小节起始拍位、divisions。
  - `MusicXMLParser`：`XMLParser` 事件流解析 `score-partwise`；只读第一个 `part`，休止符推进拍位，和弦保留首个音，连音线把延音并入前一个同音，倚音跳过，`backup`/`forward` 修正拍位。
  - 速度优先取 `<sound tempo>`，其次 `<per-minute>`，否则 80 BPM；BPM 限定 20–300。
- `Sources/VibratoCore/ScoreFingering.swift`
  - `FirstPositionFingering`：音高 → 弦 + 半音偏移 + 指号；偏移 0–7 对应 0/低1/1/低2/2/3/高3/4。
  - 同音可由多根弦按出时选择偏移更小（更靠近空弦）的位置，例如 D4 选 D 空弦而不是 G 弦四指。
  - `PitchName`：统一音名与频率换算。
- `Sources/VibratoCore/ScorePlayback.swift`
  - `ScorePlayback.timeline`：按 BPM 与速度倍率把拍换算成秒；片段循环按小节切片并重置起点；时长上限按 240 秒在会话层拦截。
  - `ScorePlayback.renderSamples`：逐音渲染、按起始采样叠加，输出单声道 0.98 上限。

### App

- `VibratoCoach/ScorePracticeSession.swift`
  - 导入、播放/暂停/停止、速度与循环设置；用 `AVAudioPlayerNode` 播放预渲染缓冲，循环使用 `.loops`，进度用 `playerTime` 计算。
  - 修改速度或循环方式会重建缓冲；正在播放时从头继续。
- `VibratoCoach/ScoreWorkbenchView.swift`
  - 空状态导入卡、乐谱信息、音符/指法横条、播放控制、速度菜单、循环小节步进器、超范围提示。
- `VibratoCoach/PracticeStudioView.swift`
  - 「曲目」页顶部接入乐谱工作台与 MusicXML 文件选择；乐谱播放与音频播放互斥暂停，二者都计入曲目练习时长。

## 验证证据

- `swift test`：53 项测试、15 suites 全部通过；新增覆盖解析、指法、时间轴、降速、片段循环、采样渲染与两份样例文件。
- 样例：`outputs/sample-d-major-scale.musicxml`、`outputs/sample-twinkle-d-major.musicxml`，均通过 `xmllint --noout`。
- `xcodebuild -destination 'generic/platform=iOS Simulator'`：`BUILD SUCCEEDED`（Xcode 27.2）。
- 未完成：模拟器或真机上的文件导入、实际听感与循环交互手测；TestFlight 仍停留在 `0.1 (3)`。

## 已知边界

- 第一把位之外（低于 G3 或高于 B5）的音会照常发声，但不显示指法，并在界面上提示数量。
- 多声部、和弦、反复/跳转、装饰音和力度符号未处理；复杂乐谱可能听起来与记谱不同。
- 速度变化通过重新渲染实现，切换有短暂准备时间；长乐谱（>240 秒）需先用片段循环缩短。
- 音频播放与乐谱播放互斥，但不会互相同步。
