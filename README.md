# dorewio.

**Learn music. Play with confidence.**

dorewio. is a native iOS-first violin-learning app built using SwiftUI.

## First lesson / 第一课

For absolute beginners: connect scientific note names (such as **F5**), fixed-do solfège (**Fa**), the four violin strings (**G3, D4, A4, E5**) and actual first-position fingering (**low first finger on E**).

## MVP

- Interactive violin fingerboard, scroll at top and body at bottom
- String and finger selection with immediate feedback
- Eight beginner note exercises
- Reference tone playback (synthesized sine wave, not sampled violin)
- iOS 17+, SwiftUI, AVFoundation, no backend or user accounts

## Opening the project

Open `dorewio.xcodeproj` on macOS in Xcode 15 or later. Choose an iPhone simulator and run the `dorewio` scheme. On device, select your own Apple Development Team for signing.

**Validation:** macOS build and simulator run verified on 2026-11-11 with Xcode 27.2 (iPhone 18 Pro, iOS 27.2). `xcodebuild` for the iOS Simulator succeeded, the app launched, and the first lesson rendered. The simulator pass surfaced two M0 issues, fixed in this change: the open-string row sat outside the fingerboard panel, and the string/finger buttons only had a 33 pt hit area. Buttons now expose a 44 pt hit area and every dot sits inside the fingerboard. Real-device testing has not been completed yet.

![First lesson on iPhone simulator](docs/screenshots/m0-first-lesson.png)

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md).

## License

All rights reserved. No open-source license has been granted.