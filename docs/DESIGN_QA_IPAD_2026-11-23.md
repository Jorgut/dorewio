# Design Roundtrip QA — iPad layout (dorewio 1.1)

Date: 2026-11-23 · Build **1.1 (19)** · iPad Pro 13-inch (M5), iPadOS 26.5 simulator

## Source

- Material: user-owned screenshots of the pre-change dorewio iPad build, captured at 2064 × 2752 (`docs/screenshots/app-1.1/ipad/before/`).
- Ownership: user-owned product UI; no third-party reference material.
- Target: native SwiftUI rebuild for iPadOS, following the Human Interface Guidelines; not a pixel clone of another product.

## Fidelity

- Classification: high-fidelity shipping UI.
- Known uncertainty: landscape, Split View, Slide Over and Stage Manager were not captured on this machine (no rotatable Simulator.app); the rebuild is verified in iPad portrait only.
- This is a **structural redesign**, not a reference-lock reproduction. No pixel overlay/diff is claimed; before/after screenshots are the evidence.

## Design contract

- Frame: iPad regular width; 20 pt outer margins; content max width 1100 pt; two columns with 24 pt gutter.
- Layout: two columns in regular width; single stacked column in compact width (iPhone, Slide Over, narrow Split View).
- Navigation: top tab bar for 3–5 peer sections, with the system convertible sidebar (`tabViewStyle(.sidebarAdaptable)`, iOS 18+) in regular width; toolbar actions at the top.
- Typography: semantic text styles; no new fixed font ramp.
- Controls: ≥ 44 pt targets; primary action capped at 560 pt on iPad instead of stretching edge to edge.
- Components: native SwiftUI controls, `TabView`, `NavigationStack`, `ContentUnavailableView`, PDFKit; no hand-drawn system chrome.

## Target rebuild

- Keep: existing visual language (paper cards, accent red, rounded 7/18 pt surfaces), semantic colors, light/dark support, existing copy.
- Normalize: card widths, section spacing (20/24/26), content margins, bottom action width.
- Do not infer: no new brand assets, no third-party screenshots, no changes to musical content or pedagogy.
- Implementation mapping:
  - `PracticeTwoColumn` switches on `horizontalSizeClass` (regular = two columns, compact = stack).
  - `practiceReadableWidth` caps content at 780–1100 pt; `practiceActionWidth` caps primary buttons at 560 pt.
  - Today / 曲目 / 进度 become dashboards; 第一课 and 调音 become master-detail two-column screens.
  - 学习 / 训练 stay two-column and widen to 1100 pt.
  - `IPadNavigationStyle` adds the convertible sidebar on iPadOS 18+.

## Visual QA (before → after)

| Area | Before | After | Status |
|---|---|---|---|
| Today | one centered 780 pt column, full-width onboarding | two balanced columns; onboarding in the left rail | fixed |
| 学习 / 训练 | two columns but phone-sized content block | two columns at 1100 pt; same stacking on iPhone | fixed |
| 曲目 | score, PDF and audio stacked full width | score left; PDF + audio right | fixed |
| 进度 | one column | summary/chart left; skills/goal/recent right | fixed |
| 第一课 | card, fingerboard, feedback stacked with large empty bottom | note + note strip + steps left; fingerboard right | improved |
| 调音 | full-width dial, controls and 1100 pt action | dial left; strings/calibration/help right; 560 pt action | improved |
| Navigation | top tab bar only | top tab bar + system sidebar toggle (regular width) | improved |

## Blocking differences (not yet pass)

1. **Landscape / Split View / Slide Over** were not captured or checked at 1/3, 1/2, 2/3 widths. The code is size-class adaptive, but evidence is portrait-only.
2. **Keyboard shortcuts** for primary actions are not implemented (e.g. Cmd+1…5 tab switching, Cmd+, settings).
3. **Pointer hover** is not customised on card-style links; standard controls get system hover only.
4. **Sidebar**: the system toggle is present, but the expanded sidebar state is not visually verified.

## Acceptable approximations

- Short pages (调音, 第一课) still leave unused vertical space; this is intentional for a focused practice task and avoids filling the screen with invented content.
- The top tab bar (with sidebar toggle) is kept instead of a permanently visible sidebar; for five peer sections this is an allowed iPad pattern.

## Verdict

**revise** — the stretched-iPhone layout is fixed and the iPad portrait composition now follows the regular-width, multi-column HIG pattern. Do not call the iPad work complete until landscape/Split View is tested, keyboard shortcuts are added, and pointer hover is verified.

## References

- Apple HIG Layout: <https://developer.apple.com/design/human-interface-guidelines/layout>
- Apple HIG Designing for iPadOS: <https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados>
- Apple HIG Tab bars: <https://developer.apple.com/design/human-interface-guidelines/tab-bars>
- Apple UIKit — Multitasking on iPad, Mac, and Apple Vision Pro: <https://developer.apple.com/documentation/uikit/multitasking-on-ipad-mac-and-apple-vision-pro>
- Apple UIKit — Elevating your iPad app with a tab bar and sidebar: <https://developer.apple.com/documentation/uikit/elevating-your-ipad-app-with-a-tab-bar-and-sidebar>
- Secondary iPad checklist (community, used as a worklist, not authority): <https://github.com/dirnbauer/webconsulting-skills/blob/main/skills/ipados-design/SKILL.md>
