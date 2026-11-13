# dorewio.

**Learn music. Play with confidence.**

dorewio. is a native iOS-first violin-learning app built with SwiftUI. It is offline-first: no account, no backend, no data collection — practice history, recordings and imported scores stay on the device.

This repository is the **shipping app** for the App Store record **「小提琴自学」** (Apple ID `6827607435`, bundle ID `com.archintera.VibratoCoach`). The Xcode project and target are named `dorewio`; the bundle ID must not change.

## The name

**dorewio.** — **do–re** is the solfège starting point (and the first lesson), and the **w** is two **V**s for **Violin** and **Viola**; the trailing period is part of the wordmark.

The project began in August 2026 as **VibratoCoach**, a vibrato-practice experiment, before growing into a full daily-practice app. Read [docs/BRAND.md](docs/BRAND.md) for the full story — including why the bundle ID still contains the old name.

## Features

- **第一课 / First lesson** — connect scientific pitch names (F5 = Fa), fixed-do solfège, the four violin strings (G3/D4/A4/E5) and first-position fingering (low first finger on E).
- **调音 / Tuner** — real-time pitch detection for G/D/A/E open strings, cents display, adjustable A4.
- **音准与揉弦 / Intonation & vibrato** — live pitch trace and vibrato analysis.
- **运弓 / Bowing** — bow distribution, speed and string-crossing basics.
- **节奏 / Rhythm** — tap along to a target tempo and get a regularity score.
- **识谱 / Sight reading** — staff notation to pitch-name drills.
- **第一把位 / Fingerboard** — string + finger position quiz.
- **听辨 / Ear training** — open-string listening drills.
- **曲目工作室 / Score studio** — import single-voice MusicXML (`.musicxml`, `.xml` or compressed `.mxl`), play it back with first-position fingering, 0.5×–1.0× tempo, measure loop, metronome and count-in; or import audio, slow it down and extract a melody.
- **今天 / Daily plan & progress** — with-violin and without-violin 10-minute plans, streaks and per-skill progress.

## Opening the project

Open `dorewio.xcodeproj` on macOS (Xcode 26 or later). Choose an iPhone simulator and run the `dorewio` scheme. On device, select your Apple Development Team for signing.

```bash
# Simulator build (no signing)
xcodebuild -project dorewio.xcodeproj -scheme dorewio \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build
```

```bash
# Core unit tests
TMPDIR="$PWD/.tmp/TMPDIR" CLANG_MODULE_CACHE_PATH="$PWD/.tmp/clang-module-cache" \
  swift test --scratch-path .build --cache-path .swiftpm-cache --disable-sandbox
```

## Repository layout

```
dorewio.xcodeproj          Xcode project (scheme: dorewio, bundle: com.archintera.VibratoCoach)
dorewio/                   App target (SwiftUI views, sessions, assets, PrivacyInfo.xcprivacy)
Sources/VibratoCore/       Testable music core: tuner math, MusicXML/MXL parsing, fingering, playback
Tests/dorewioTests/        Swift Testing suite for VibratoCore
outputs/                   Sample MusicXML scores and implementation notes
docs/                      Product docs, release state, business research, screenshots
```

## Release state

Current App Store state (2026-11-13): version **1.0 Prepare for Submission**, build **1.0 (7)** uploaded and attached, listing name `dorewio`, subtitle `小提琴 · 调音 · 识谱 · 跟奏`, 5 App Store screenshots, privacy policy and support pages hosted in this repository at <https://jorgut.github.io/dorewio/PRIVACY.html> and <https://jorgut.github.io/dorewio/SUPPORT.html>. **Not yet submitted for review.**

See [docs/RELEASE_STATE.md](docs/RELEASE_STATE.md) for the detailed checklist.

## Free vs Pro

The app is free to download. **dorewio Pro** is a one-time (non-consumable) purchase, product ID `com.archintera.VibratoCoach.pro.lifetime`:

- **Free:** tuner, metronome, first lesson, daily plan, basic rhythm / sight-reading / fingerboard / ear-training.
- **Pro:** all technique training (bow, vibrato, intonation), score studio (MusicXML/MXL import and playback, audio import and melody extraction) and full practice statistics. Restore purchases is available on the Pro screen.

No subscription, no account, no server. See `docs/RELEASE_STATE.md` for the current App Store state.

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md). Monetization research (buyout vs subscription) lives in [docs/BUSINESS_MODEL_RESEARCH_2026-11-13.md](docs/BUSINESS_MODEL_RESEARCH_2026-11-13.md).

## License

All rights reserved. No open-source license has been granted.
