# dorewio agent instructions

- Product: **dorewio.**, a native iOS-first interactive violin-learning app. This repository is the shipping app for the App Store record 「小提琴自学」 (Apple ID `6827607435`).
- **Bundle ID is fixed**: `com.archintera.VibratoCoach`. Never change it — it is tied to the live App Store Connect record. The Xcode project/target/scheme are named `dorewio`; product file is `dorewio.app`.
- SwiftUI is the platform choice. Do not replace it with Web, React Native or Flutter without explicit approval.
- Musical accuracy: F5 means F natural (MIDI 77), E string, low first finger. F#5 is a distinct pitch.
- Open strings are G3, D4, A4, E5. Fixed-do solfège is the default; label it explicitly.
- Fingerboard: scroll/nut at top, body at bottom. G / D / A / E shown left-to-right in the teaching diagram.
- Note positions are pedagogical approximations, not calibration markers or frets.
- Audio currently uses synthesized tones only: sine-wave reference tones in the lesson, and a harmonic-violin-style synthesized buffer for score playback. No sampled violin recordings are bundled.
- Add VoiceOver labels and avoid relying only on color to indicate correct answers.
- Do not claim Xcode build or simulator success without actually running them.
- Never commit credentials, provisioning profiles, certificates, `.p8` keys or App Store Connect API keys.
- Use focused branches and PRs for changes after initial setup.
- Do not upload builds to App Store Connect, change pricing, or submit for review without explicit approval.

## Build and test

```bash
# App build (simulator, no signing)
xcodebuild -project dorewio.xcodeproj -scheme dorewio \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build

# Core tests (Swift Testing)
TMPDIR="$PWD/.tmp/TMPDIR" CLANG_MODULE_CACHE_PATH="$PWD/.tmp/clang-module-cache" \
  swift test --scratch-path .build --cache-path .swiftpm-cache --disable-sandbox
```

- Archive/export/upload is documented in `docs/RELEASE_STATE.md`; it requires the team's App Store Connect API key and must only be run on explicit request.
- Xcode builds inside the DSH file sandbox may fail with `SwiftUIMacros … malformed response`; run with full file access when verifying locally.
- Release notes and screenshots live under `docs/`; keep them in sync with the shipped build.

## Release conventions

- Keep `CFBundleDisplayName = dorewio`, `ITSAppUsesNonExemptEncryption = NO`, microphone usage description and `PrivacyInfo.xcprivacy` intact.
- App Store screenshots: 1320×2868 (iPhone 6.9"/6.7"), 3–10 images, show real app UI.
- Privacy policy: <https://jorgut.github.io/vibratocoach/PRIVACY.html> · Support: <https://jorgut.github.io/vibratocoach/SUPPORT.html>.
