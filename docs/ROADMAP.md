# Roadmap / 开发阶段

## M0 — Native iOS starter
- [x] Product brand and iOS-first platform confirmed
- [x] Initial SwiftUI and Xcode project committed
- [x] Verify successful build using Xcode on macOS
- [x] Run on iPhone simulator and check tap targets

Simulator check (2026-11-11, Xcode 27.2 / iOS 27.2): build and launch verified. Fixed the open-string row sitting outside the fingerboard panel and raised string/finger hit areas to 44 pt. A real-device pass is still pending.

## M1 — First-position fundamentals
- [ ] Verify string/finger layout with a violin specialist
- [ ] Model all first-position pitches and high/low finger positions
- [ ] Show a first-person / mirrored orientation option
- [ ] Add deterministic music and fingering unit tests

## M2 — Audio and tuning
- [ ] Stable reference-tone playback and audio session behavior
- [ ] Microphone permission and pitch detection
- [ ] Live tuning accuracy and cents feedback
- [ ] Accessibility review

## M3 — Learning experience
- [x] Import single-voice MusicXML / MXL and play it back with first-position fingering, tempo, loop, metronome and count-in (shipped ahead of the rest of M3)
- [ ] Short lessons and spaced practice
- [ ] Staff notation, solfège and numbered notation
- [ ] Local progress persistence
- [ ] Simplified Chinese / English UI

## M4 — Release
- [ ] App icon and store screenshots
- [ ] Privacy policy
- [ ] TestFlight QA and real-device testing
- [ ] App Store review and release
