# Deuteronomy 1 - Build Notes

## Standing Orders — Read This First, Every Session

These are non-negotiable rules. They apply to every task, every session, without exception.

### 1. Never commit unless explicitly told to
Do not run `git add` or `git commit` for any reason until the user says "commit" or "go ahead and commit". Not after a fix. Not after a build succeeds. Not after an audit. Wait to be told.

### 2. Never assume a change is isolated
Every change to shared state, shared UI components, or shared keys has side effects in both consoles, both orientations, and all lesson styles. Before touching anything, ask: what else reads or writes this? Walk through the full surface area before and after the change.

### 3. Before any UI change — walk all pickers in both consoles
Open the OPTIONS tab mentally for Beginner and Maestro. Confirm every picker still has a valid selection. Confirm disabled states are correct for every style combination. This must be done before marking a task complete, not after the user finds a problem during testing.

### 4. Build before AND after every change
A passing build before confirms the baseline. A passing build after confirms nothing was broken. Do not skip either.

### 5. Do not add code without considering what it breaks
When adding a new enum case, a new parameter, a new key, or a new mode — immediately enumerate every site that already handles the existing cases and check whether the new case is handled correctly there too.

### 6. Audits are not optional
When the user asks for an audit, read every modified file in full. Do not skim. Do not summarise from memory. Actually read the current state of the file.

### 7. Do not make assumptions about desired behavior
Execute exactly as specified. When details are ambiguous, ask for clarification before doing anything.

### 8. Do not make code changes without explicit user confirmation
State the plan with all explicit directions given. Ask for permission before implementing. Never switch from planning to code without confirmation.

### 9. Do not modify Beginner mode against clear instructions
Beginner mode is separate from Maestro. Changes to one must not bleed into the other unless explicitly requested.

### 10. Never lie about what the user said
If unsure what was asked, say so. Do not paraphrase instructions in a way that changes their meaning.

### 11. Before fixing any error — investigate first
- Read the compiler error carefully. What is it actually complaining about?
- Check the actual function/struct signature in the source files.
- Verify types match what is expected.
- Do not guess. Find the root cause before touching code.
- Start with the simplest diagnostic step.

### 12. First-principles engineering (always active)
- Reason explicitly from first principles: break problems down to fundamental truths before proposing solutions.
- Question every assumption. Never accept conventions without justification.
- Prefer the simplest, most robust solution that preserves existing behavior. Complexity is the enemy.
- Avoid novelty for its own sake — no clever one-liners, over-abstractions, or tricks unless they provably reduce risk.
- Be concise. Do not ramble or enter reasoning loops.
- For every code change: explain impact, which invariants are preserved, how to test it, how to roll it back, and why it is the minimal change.
- If a problem is simple, give the boring, obvious, safe answer first. Only escalate if clearly justified.

---

## Current Shipped Build
- **Version**: 1.5
- **Build**: 5
- **Status**: Shipped (frozen)

## Next Build Target
- **Version**: 1.6
- **Build**: 1
- **Status**: In progress

## Completed in 1.6 (Build 1)
- **Maestro portrait accidental screens**: `MaestroGameplayView.swift` portrait answer choice `MiniTVFrame` calls were missing `isDarkScreen: guitarNoteContainsAccidental(...)`. Added to both `leftChoiceNote` and `rightChoiceNote`. Landscape already had this correctly. Beginner unaffected.
- **Control panel button text weight**: `GameplayControlViews.swift` `plateButton` text changed from `size: 10.35 / .regular / .compressed / kerning 0.8` to `size: 12 / .bold` to match the transport buttons (START/PAUSE/RESET) in both consoles. Applies to AUTOPLAY, FRETBOARD, MENU, and all menu tab buttons.
- **Screensaver source file**: Added `ContentViewSource.txt` (copy of `DeveloperViews.swift`, 734 lines) to the app bundle. `DeveloperCodeRunnerView` now loads this reliably on all builds including TestFlight/App Store. Previously the `#filePath` fallback failed in release builds, causing the 5-6 line repeat.
- **Screensaver viewport windowing**: `DeveloperCodeRunnerView` now renders only the lines visible in the viewport (~57) rather than all lines typed so far. Prevents unbounded `ForEach` growth during the 17-minute cycle. Visual output and cursor behavior unchanged. Color assignment uses original line index for stability.

## Completed in 1.5 (Build 5)
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
- Coercing `Binding` is applied in **three places** in `Deuteronomy_1App.swift` — all three must be kept in sync:
  1. `playLessonStyle` passed to `BeginnerGameplayView` construction (line ~91) — coerces to `"sequential"` if value is not a valid Beginner style
  2. `playLessonStyle` passed to `MaestroGameplayView` construction (line ~113) — coerces to `"sequential"` if value is not a valid Maestro style
  3. The Style pickers inside `Deuteronomy1MenuSheet` — same coercion for display
- **Risk**: if coercion is only applied to the picker and not the view construction binding, the picker looks correct but the game launches with the wrong style.
- **Risk**: any new lesson style added to either console must be added to all three coercion guards.
- **Test after every style-related change**: switch Beginner→Maestro→Beginner, launch the game each time, and confirm the correct mode actually runs (not just that the picker looks right).

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

### Picker `disabled` state in OPTIONS tab
- Speed Run locks: Repetitions, Starting Fret, Direction.
- Speed Run does NOT lock: Progression (affects which record slot is written).
- Beginner Chord locks: Progression.
- Check the `speedRunLocked` and `progressionLocked` locals in the OPTIONS tab body whenever adding new pickers.

---

## Build Commands
```
xcodebuild -project "Deuteronomy 1.xcodeproj" -scheme "Deuteronomy 1" -destination "platform=iOS Simulator,id=1FE2357C-1F63-49AC-B9AE-E38A4A98C85A" build
```
