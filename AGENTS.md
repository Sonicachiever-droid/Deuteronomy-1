# Deuteronomy 1 - Build Notes

## Current Shipped Build
- **Version**: 1.2
- **Build**: 3
- **Status**: Shipped (frozen)

## Next Build Target
- **Version**: 1.3
- **Build**: 4
- **Status**: In Development

## Completed Fixes (for next build)
- **Chord mode E string validation**: Fixed — added string validation check to `handleBeginnerChordProgressionIfNeeded` in BeginnerGameplayLogic+Answers.swift. Now validates both note AND string (similar to sequential mode's `isValidAnswer`).
- **Button flash cleanup on game restart**: Fixed — added missing cleanup of `beginnerPressedButtonIndex` and `beginnerPressedButtonCorrect` to `startGameFromBeginning` in BeginnerGameplayLogic+Timing.swift. Prevents buttons from continuing to flash after game restart.
- **OverviewPageView documentation**: Added volume to Audio tab description in Learn to Play page SETTINGS section.
- **Chord mode wrong answer handling**: Fixed — wrong answer flashes red and clears the wrong note's box (removes selected string from `answeredNotesByStringAtCurrentFret`, sets `answerBoxReady = false` if empty). Correct answer advances to next orange prompt normally. Wrong note boxes no longer persist.
- **Startup audio clipping**: Fixed — added `guitarVolume` constant (0.70) to AudioConstants and set guitar sampler volume in SharedAudioEngine init. Previously defaulted to 1.0 (full volume) causing clipping on startup when combined with other samplers. Now all samplers are gain-staged below unity (guitar 0.70, keys 0.65, bass 0.85, drums 0.70, master 0.72). Also added ghost note (silent MIDI note with velocity 1) played 0.1s after engine start to prime the audio hardware and prevent first-note clipping.
