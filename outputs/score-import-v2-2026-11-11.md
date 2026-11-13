# 乐谱导入第二轮：MXL 自动解压 + 节拍器/预备拍

2026-11-11 · 承接 [首版实现说明](score-import-implementation-2026-11-10.md)，未重新打包或上传 TestFlight。

## 本轮目标

首版已经能导入单声部 MusicXML 并按谱发声，但真实下载到的乐谱大多是压缩的 `.mxl`，
首版会直接提示「请先解压」。本轮把「导入现成谱子 → 直接演奏」补成可用的闭环：

1. `.mxl`（压缩 MusicXML）直接导入，不再要求用户先解压；
2. 播放时可选节拍器，并可先听一小节预备拍再进曲，便于跟拍练习；
3. 乐谱工作台显示预备拍状态，文件选择器能筛出 `.mxl` / `.musicxml`。

## 实现说明

### 1. MXL 自动解压（VibratoCore）

- `Sources/VibratoCore/MXLArchive.swift`（新增）
  - 纯内存 ZIP 读取，不解压到磁盘、不依赖系统解压工具：
    扫描 EOCD → 解析 central directory → 定位 local header payload。
  - 入口选择：优先 `META-INF/container.xml` 的 `<rootfile full-path="…">`；
    container 缺失或无效时回退第一个 `.musicxml` / `.xml` 条目（跳过 `META-INF/`）。
  - 压缩方式：store（method 0）与 deflate（method 8，`Compression` 框架
    `compression_decode_buffer` + `COMPRESSION_ZLIB`，Apple 平台为 raw DEFLATE）。
  - 安全边界：拒绝加密条目、ZIP64、多卷、未知压缩方式；条目数上限 4096、
    文件名上限 1024 字节、单个条目解压后上限 8 MB；损坏数据抛 `MXLImportError`
    而不是崩溃或死循环。未做 CRC32 校验（坏 CRC 但能 inflate 的载荷会在 XML 层报错）。
- `Sources/VibratoCore/MusicXMLParser.swift`
  - 检测 ZIP 魔数后先经 `MXLArchive.extractMusicXML` 解压再解析；
    `parse(contentsOf:)` 对 `.mxl` 扩展名同样生效；`MXLImportError` 原样透传。
  - 移除已被取代的 `MusicXMLImportError.compressedArchive`（App 层通过
    `LocalizedError.errorDescription` 显示中文原因）。
- 错误类型：`MXLImportError`
  `invalidArchive / missingMusicXMLEntry / unsupportedCompression / entryTooLarge /
  encryptedEntry / zip64NotSupported`，均为中文文案。

### 2. 节拍器与预备拍（VibratoCore + App）

- `Sources/VibratoCore/ScorePlayback.swift`
  - 新增 `ScoreClick { seconds, isDownbeat }`；`ScorePlaybackTimeline` 增加
    `leadInSeconds` 与 `clicks`（默认 0 / 空，保持旧调用兼容）。
  - `timeline(...)` 增加 `countInMeasures`（最多一小节）：预备拍取第一小节拍数
    （只有一个小节时回退 4 拍），`totalSeconds = 预备拍 + 正曲`，
    音符事件 `startSeconds` 仍相对正曲起点；拍点按小节网格逐拍生成，
    小节起点为重拍，支持 3/4 与中途换拍。
  - `eventIndex(at:)` 在预备拍期间返回 nil（不错误高亮音符），之后先减去预备拍再查找。
  - `renderSamples(timeline:sampleRate:metronomeEnabled:)`：`false` 只渲染预备拍拍点，
    `true` 渲染全部拍点；click 为 25ms 正弦、1ms attack、指数衰减（τ=8ms）、
    振幅 0.25，重拍 1760 Hz、普通拍 1200 Hz，最终统一 clamp ±0.98。
- `VibratoCoach/ScorePracticeSession.swift`
  - 新增 `metronomeEnabled` / `countInEnabled` 与对应 setter（沿用既有 rebuild：
    改设置后重建音频缓冲，正在播放则从头继续）；新增 `isCountingIn`。
- `VibratoCoach/ScoreWorkbenchView.swift`
  - 传输区新增「节拍器」「预备拍」开关与说明文案；播放时显示「预备拍… 准备跟奏」；
    空状态改为「导入乐谱（MusicXML / MXL）」，说明支持 `.mxl`（自动解压）。
- `VibratoCoach/PracticeStudioView.swift`
  - 文件选择器增加 `.mxl` / `.musicxml` 动态 UTType（系统未声明这两种类型，
    用扩展名生成动态类型筛选），保留 `.xml`。

### 3. 真实样例

- `outputs/sample-twinkle-d-major.mxl`：由 `sample-twinkle-d-major.musicxml` 打包，
  含 `META-INF/container.xml` 与 deflate 压缩的 `score.musicxml`，供手工导入验证。

## 验证证据

- Swift Package：`swift test` **72 tests / 17 suites 全部通过**（原 53 + MXL 8 + 节拍器/预备拍 11）。
  - 覆盖：store/deflate 解压、container rootfile、无 container 回退、无乐谱条目、
    损坏/加密/ZIP64/超限、真实 `.mxl` 样例逐字节一致；预备拍时长与事件偏移、
    拍点重音位置、预备拍内不高亮、关闭节拍器只响预备拍、循环片段 + 预备拍边界。
- App target：`xcodebuild -destination 'generic/platform=iOS Simulator' -derivedDataPath … build`
  → **BUILD SUCCEEDED**（Xcode 27.2，arm64，无代码警告）。
  注意：SwiftUI 宏插件在会话文件沙箱下会报 `SwiftUIMacros.StateMacro … malformed response`，
  需在放宽文件访问的环境运行 xcodebuild，这是环境限制而非代码问题。
- 运行时冒烟：构建产物安装到 iPhone 18 Pro（iOS 27.2）模拟器可启动并渲染「今天」页，
  截图 `work/sim-launch-2026-11-11.png`。
- 未完成：在模拟器/真机上手动走一遍「文件」导入 `.mxl`、听节拍器与预备拍、
  长按/短按交互与真实音频路由验证；TestFlight 仍停留在 `0.1 (3)`。

## 已知边界与后续

- 预备拍在循环模式下每轮循环都会重放（与循环音频缓冲一致）；若产品希望
  「只有第一轮预备拍」，需在 session 层对循环偏移另做映射。
- MXL 不支持 ZIP64/多卷/加密；未校验 CRC32；极端大乐谱（>8 MB 解压后或 >4 分钟播放）
  仍需先用片段循环或换更小的谱。
- 仍只解析单声部：多声部、和弦、反复/跳转、装饰音、力度与速度变化尚未处理，
  复杂乐谱听起来可能与记谱不同。
- 下一步候选：乐谱曲库持久化（导入后保留在「曲目」里）、音符点按试听、
  反复记号与速度变化、以及把导入乐谱接到逐句练习/左手跟练。
