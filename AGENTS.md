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

## Build Commands
```
xcodebuild -project "\`.xcodeproj" -scheme "Deuteronomy 1" -destination "platform=iOS Simulator,id=1FE2357C-1F63-49AC-B9AE-E38A4A98C85A" build
```
