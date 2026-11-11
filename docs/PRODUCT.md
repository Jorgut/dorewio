# Product definition / 产品定义

**Brand:** dorewio.  
**Category:** Violin learning  
**First platform:** iOS native, SwiftUI  
**Audience:** Complete beginners learning how A-G pitch names, Do-Re-Mi, strings and first-position left-hand finger positions connect.

## Primary user journey

1. See a target pitch, for example F5 (Fa).
2. See a vertical violin fingerboard, scroll above and body below.
3. Select E string and low first finger.
4. Hear a reference pitch and see correct/incorrect feedback.
5. Move to the next short exercise.

## Music rules

- Octave number (F5) is not the finger number (1).
- F natural and F-sharp must be clearly distinguished.
- For the diagram, string position and scale length are schematically proportioned; not a millimeter ruler.

## Score workspace (beyond the starter)

A second tab imports an existing single-voice score (`.musicxml`, `.xml`, compressed `.mxl`) and plays it back with:

1. the first-position string and finger printed on every note,
2. the currently sounding note highlighted while it plays,
3. tempo from 0.5× to 1.0×, measure-range looping, and an optional metronome with one measure of count-in.

It is a play-along tool, not a notation editor or an accuracy grader. Multi-voice scores, repeats/jumps, ornaments, dynamics and tempo changes are not interpreted; the app plays the first part's pitches and durations as read.

## Out of scope for starter

Payments, accounts, cloud sync, AI listening, microphone input, actual violin sample playback and full sheet music reading.
