# Deuteronomy 1 - Build Notes

## Current Shipped Build
- **Version**: 1.3
- **Build**: 6
- **Status**: Shipped (frozen)

## Next Build Target
- **Version**: 1.4
- **Build**: 5
- **Status**: Ready for submission

## Completed in 1.4 (Build 5)
- **BeginnerGameEngine refactor**: Extracted all logic from `extension BeginnerGameplayView` into a standalone `BeginnerGameEngine` class. Uses `@Observable`. 42 unit tests added (`BeginnerGameEngineTests`). View is now a thin coordinator.
- **Speed Run mode**: New Maestro lesson style. Races the player through every fret 0→max→0 against the clock. Records (best time per High Frets / Progression combo) shown on HOME tab. Scoring, streaks, and multipliers all apply. 35 unit tests added (`SpeedRunTests`).
  - Key invariant: `speedRunBestTime` is written to `@AppStorage` in `advanceGame` *before* `speedRunFinished = true`. The overlay's `isNewBest` computed property (`elapsed > 0 && elapsed == bestTime`) exploits this ordering — do not change sequence.
  - `speedRunIsNewBest(elapsed:bestTime:)` free function is used in `advanceGame` for the write decision. The overlay uses its own computed property (not this function).
  - Direction state (`playDirectionRawValue`) is never mutated during Speed Run — only the local `isDescendingPhase` flag changes.
  - Timer starts on first correct player answer (not on game start).
- **Note name unicode**: All note name data uses ♯/♭ characters consistently.

## Completed Fixes in 1.3 (Build 4)
- **Chord mode E string validation**: Fixed — added string validation check to `handleBeginnerChordProgressionIfNeeded` in BeginnerGameplayLogic+Answers.swift. Now validates both note AND string (similar to sequential mode's `isValidAnswer`).
- **Button flash cleanup on game restart**: Fixed — added missing cleanup of `beginnerPressedButtonIndex` and `beginnerPressedButtonCorrect` to `startGameFromBeginning` in BeginnerGameplayLogic+Timing.swift. Prevents buttons from continuing to flash after game restart.
- **Chord mode wrong answer handling**: Fixed — wrong answer flashes red. Previously-correct string boxes remain visible (activePickedStringNumbers restored from answeredNotesByStringAtCurrentFret). scaleSequenceIndex unchanged — user retries the same note. Pre-validation assignment of activePickedStringNumbers removed from handleBeginnerConsoleButtonPress to eliminate flicker on every button press.
- **Startup audio clipping**: Fixed — added `guitarVolume = 0.70` to AudioConstants and set `guitarSampler.volume` in SharedAudioEngine init alongside all other samplers. All samplers now gain-staged below unity at init (guitar 0.70, keys 0.65, bass 0.85, drums 0.70, master 0.72). Also added ghost note (silent MIDI note velocity 1) played 0.1s after instrument load to prime the audio hardware and prevent first-note clipping.
- **Chord mode stale pentatonic state**: Fixed — in `updateBeginnerRoundOneRevealSequence`, the pentatonic→chord transition block now guards on `!answerBoxReady` so it only runs once. Previously it fired on every timer tick after reveal completed, wiping `answeredNotesByStringAtCurrentFret` and `lastPickedNote` — clearing any chord answers already submitted.
- **Chord mode neck shift missing on fret advance**: Fixed — `withAnimation(.easeInOut(duration: 1.3)) { beginnerRuntime.currentFretStart = nextFret }` was never called in `advanceBeginnerScaleStage`. The neck stayed at the previous fret for the entire next intro sequence. Was a migration bug from Numbers 3 → Deuteronomy.
- **Audio engine crash on Audio button press**: Fixed — `play(url:)` and `resume()` in SharedAudioEngine.swift were calling `sequencer.start()` without first calling `startEngineIfNeeded()`. After any iOS audio system interruption or overload (HALC_ProxyIOContext), the engine stopped and the next sequencer start crashed with "no output node". Also added AVAudioSession interruption observer to automatically restart and resume after phone calls, Siri, etc.
- **Chord mode repetition counter resetting upward**: Fixed — three bugs: (1) `applyLivePlayRepetitionChangeIfNeeded` in the timer loop was overwriting `scaleRepetitionsRemaining` every tick in chord mode, cancelling any countdown — fixed by guarding with `lessonStyle != .chord`. (2) `advanceBeginnerScaleStage` was resetting `scaleRepetitionsRemaining` to `effectivePlayRepetitions` unconditionally before decrementing at cycle end, so it always reached zero after one cycle regardless of the repetitions setting — fixed by removing the unconditional reset. (3) `scaleRepetitionsRemaining` was not being reset to `effectivePlayRepetitions` when advancing to a new fret — fixed by adding reset in the `nextFret` branch. One repetition = completing all chord stages through the full cycle (endsCycle). Counter decrements at cycle end; hits zero; fret advances.

## Shared State — Cross-Cutting Concerns

These are the places most likely to cause subtle bugs when adding new features.
**Check all of these before committing any UI or game-logic change.**

### `lessonStyleRawValue` (`@AppStorage "numbers3.setup.lessonStyle"`)
- Single key shared by both consoles.
- Valid Beginner values: `"sequential"`, `"chord"`
- Valid Maestro values: `"sequential"`, `"speedRun"`
- `"chord"` is Beginner-only. `"speedRun"` is Maestro-only. `"sequential"` is valid in both.
- Both Style pickers use a coercing `Binding` (in `Deuteronomy_1App.swift`) that maps an out-of-console value to `"sequential"` on read.
- **Risk**: any new lesson style added to either console must be added to both coercion guards, or the other console's picker will show no selection.
- **Test after every style-related change**: switch Beginner→Maestro→Beginner and confirm the Style picker always has one button highlighted.

### `playDirectionRawValue` (`@AppStorage "numbers3.setup.direction"`)
- Shared by Standard and Speed Run.
- Speed Run must NEVER write to this key — it uses only the local `isDescendingPhase` flag for traversal.
- Standard mode writes it at direction reversal boundaries.
- **Risk**: any refactor of `advanceGame` that removes the `!isSpeedRunMode` guard on the direction write will corrupt the user's stored direction setting after a Speed Run.

### `repetitionsRemainingAtFret` / `playInfiniteRepetitions`
- Speed Run hardcodes 1 rep per fret. Any path through `startGameFromBeginning`, `advanceGame`, or `restartAtCurrentFret` that resets this must guard on `isSpeedRunMode`.
- Three locations currently guarded: `startGameFromBeginning`, `advanceGame` (rep decrement branch), `restartAtCurrentFret`.

### `speedRunBestTime` write ordering in `advanceGame`
- The four keyed `@AppStorage` vars are written **before** `speedRunFinished = true`.
- The overlay's `isNewBest` computed property (`elapsed > 0 && elapsed == bestTime`) depends on this ordering.
- **Do not reorder** these two operations.

### `DeveloperConsoleFrame` parameters
- Added `streakMultiplier` and `speedRunClockText` in v1.4. Any new console display feature needs a parameter here.
- Called from two sites in `MaestroGameplayView.swift` (portrait and landscape). Both must be kept in sync.

### Picker `disabled` state in PLAY tab
- Speed Run locks: Repetitions, Starting Fret, Direction.
- Speed Run does NOT lock: Progression (affects which record slot is written).
- Beginner Chord locks: Progression.
- Check the `speedRunLocked` and `progressionLocked` locals in the PLAY tab body whenever adding new pickers.

---

## Build Commands
```
xcodebuild -project "\`.xcodeproj" -scheme "Deuteronomy 1" -destination "platform=iOS Simulator,id=1FE2357C-1F63-49AC-B9AE-E38A4A98C85A" build
```
