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
