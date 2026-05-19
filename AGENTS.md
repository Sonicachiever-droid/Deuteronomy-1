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
- **Chord mode wrong answer handling**: Fixed — wrong answer flashes red. Previously-correct string boxes remain visible (activePickedStringNumbers restored from answeredNotesByStringAtCurrentFret). scaleSequenceIndex unchanged — user retries the same note. Pre-validation assignment of activePickedStringNumbers removed from handleBeginnerConsoleButtonPress to eliminate flicker on every button press.
- **Startup audio clipping**: Fixed — added `guitarVolume = 0.70` to AudioConstants and set `guitarSampler.volume` in SharedAudioEngine init alongside all other samplers. All samplers now gain-staged below unity at init (guitar 0.70, keys 0.65, bass 0.85, drums 0.70, master 0.72). Also added ghost note (silent MIDI note velocity 1) played 0.1s after instrument load to prime the audio hardware and prevent first-note clipping.
- **Chord mode stale pentatonic state**: Fixed — in `updateBeginnerRoundOneRevealSequence`, the pentatonic→chord transition block now guards on `!answerBoxReady` so it only runs once. Previously it fired on every timer tick after reveal completed, wiping `answeredNotesByStringAtCurrentFret` and `lastPickedNote` — clearing any chord answers already submitted.
