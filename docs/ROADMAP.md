# Roadmap / 开发阶段

Shipping app: dorewio. (App Store record: 小提琴自学, bundle `com.archintera.VibratoCoach`)

## M0 — Native iOS starter
- [x] Product brand and iOS-first platform confirmed
- [x] Initial SwiftUI and Xcode project committed
- [x] Verify successful build using Xcode on macOS
- [x] Run on iPhone simulator and check tap targets

## M1 — First-position fundamentals
- [x] Model all first-position pitches and high/low finger positions (`FingerboardPosition`, `FirstPositionFingering`)
- [x] Add deterministic music and fingering unit tests
- [ ] Verify string/finger layout with a violin specialist
- [ ] Show a first-person / mirrored orientation option

## M2 — Audio and tuning
- [x] Stable reference-tone playback and audio session behavior
- [x] Microphone permission and pitch detection
- [x] Live tuning accuracy and cents feedback
- [ ] Accessibility review (VoiceOver labels exist; full audit pending)

## M3 — Learning experience
- [x] First lesson: pitch names, solfège, strings, first-position fingering
- [x] Short daily lessons (with-violin / without-violin 10-minute plans)
- [x] Import single-voice MusicXML / MXL and play back with fingering, tempo, loop, metronome and count-in
- [x] Audio import, slow-down and melody extraction
- [x] Local progress persistence
- [x] Simplified Chinese UI
- [ ] Full staff notation editing / multi-voice scores

## M4 — Release
- [x] App icon and store screenshots
- [x] Privacy policy and support pages
- [ ] TestFlight QA and real-device testing of build 7+
- [ ] App Store review and release

## M5 — Monetization (next)
- [x] Competitor and pricing research (`docs/BUSINESS_MODEL_RESEARCH_2026-11-13.md`)
- [ ] Decide buyout vs subscription
- [ ] Implement StoreKit 2, paywall, restore purchases
- [ ] App 备案 (ICP filing) for mainland China
- [ ] Submit 1.0 for review
