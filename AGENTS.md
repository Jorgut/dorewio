# dorewio agent instructions

- Product: **dorewio.**, a native iOS-first interactive violin learning app.
- SwiftUI is the platform choice. Do not replace it with Web, React Native or Flutter without explicit approval.
- Musical accuracy: F5 means F natural (MIDI 77), E string, low first finger. F#5 is a distinct pitch.
- Open strings are G3, D4, A4, E5. Fixed-do solfège is the default; label it explicitly.
- Fingerboard: scroll/nut at top, body at bottom. G / D / A / E shown left-to-right in the teaching diagram.
- Note positions are pedagogical approximations, not calibration markers or frets.
- Audio currently uses a synthesized sine wave, not sampled violin tone.
- Add VoiceOver labels and avoid relying only on color to indicate correct answers.
- Do not claim Xcode build or simulator success without actually running them.
- Never commit credentials, provisioning profiles or certificates.
- Use focused branches and PRs for changes after initial setup.
