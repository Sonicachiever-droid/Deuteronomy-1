import XCTest
import SwiftUI
@testable import Deuteronomy_1

// MARK: - Mock Audio Engines

final class MockGuitarNoteEngine: GuitarNotePlaying {
    var configureCallCount = 0
    var lastConfiguredPreset: GuitarTonePreset?
    var playCallCount = 0
    var playChordCallCount = 0
    var stopAllCallCount = 0
    var setVolumeCallCount = 0

    func configure(preset: GuitarTonePreset, reverbLevel: AudioEffectLevel, delayLevel: AudioEffectLevel) {
        configureCallCount += 1
        lastConfiguredPreset = preset
    }
    func stopAll() { stopAllCallCount += 1 }
    func play(string: Int, fret: Int, velocity: Float) { playCallCount += 1 }
    @discardableResult
    func playChord(midiNotes: [Int], velocity: Float, sustainMultiplier: Double) -> TimeInterval {
        playChordCallCount += 1
        return 0
    }
    func setGuitarVolume(_ volume: Float) { setVolumeCallCount += 1 }
}

final class MockBackingTrackEngine: BackingTrackPlaying {
    var isPlaying: Bool = false
    var activeURL: URL? = nil
    var playCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var stopCallCount = 0
    var stubbedBeatPosition: Double = 0
    var setBassTransposeCallCount = 0
    var lastBassTransposeSemitones: Int = 0
    var setVolumeCallCount = 0

    func play(url: URL, title: String, loop: Bool) {
        playCallCount += 1
        isPlaying = true
        activeURL = url
    }
    func pause() { pauseCallCount += 1; isPlaying = false }
    func resume() { resumeCallCount += 1; isPlaying = true }
    func stop() { stopCallCount += 1; isPlaying = false; activeURL = nil }
    func currentBeatPosition() -> Double { stubbedBeatPosition }
    func setBassTransposeSemitones(_ semitones: Int) {
        setBassTransposeCallCount += 1
        lastBassTransposeSemitones = semitones
    }
    func setBackingTrackVolume(_ volume: Float) { setVolumeCallCount += 1 }
}

// MARK: - Engine Test Helpers

extension BeginnerGameEngineTests {
    func makeEngine(
        lessonStyle: LessonStyle = .sequential,
        playRepetitions: Int = 3,
        playInfiniteRepetitions: Bool = false,
        playStartingFret: Int = 0,
        playDirectionRawValue: String = LessonDirection.ascending.rawValue,
        playEnableHighFrets: Bool = false,
        playProgression: String = "highToLow"
    ) -> BeginnerGameEngine {
        let deps = AudioDependencies(
            guitarNoteEngine: guitar,
            midiEngine: midi,
            gameplayAudioEngine: SpeechEngine()
        )
        return BeginnerGameEngine(
            audio: deps,
            lessonStyle: lessonStyle,
            playRepetitions: playRepetitions,
            playInfiniteRepetitions: playInfiniteRepetitions,
            playStartingFret: playStartingFret,
            playDirectionRawValue: playDirectionRawValue,
            playEnableHighFrets: playEnableHighFrets,
            playProgression: playProgression
        )
    }
}

// MARK: - BeginnerGameEngineTests

final class BeginnerGameEngineTests: XCTestCase {

    var guitar: MockGuitarNoteEngine!
    var midi: MockBackingTrackEngine!
    var engine: BeginnerGameEngine!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guitar = MockGuitarNoteEngine()
        midi = MockBackingTrackEngine()
        engine = makeEngine()
    }

    override func tearDownWithError() throws {
        engine = nil
        guitar = nil
        midi = nil
        try super.tearDownWithError()
    }

    // MARK: - Init defaults

    func testEngineInitDefaultState() {
        XCTAssertTrue(engine.isCodeScreensaverMode, "Engine starts in screensaver mode")
        XCTAssertTrue(engine.state.isRoundArmed, "Round starts armed")
        XCTAssertFalse(engine.state.answerBoxReady, "Answer box not ready on init")
        XCTAssertEqual(engine.state.currentRound, 0, "Current round starts at 0")
        XCTAssertEqual(engine.state.bankDollars, 0, "Bank starts at 0")
        XCTAssertFalse(engine.isRoundPaused, "Round not paused on init")
        XCTAssertFalse(engine.gameplayMenuExpanded, "Menu starts collapsed")
        XCTAssertFalse(engine.showAudioPage, "Audio page starts hidden")
        XCTAssertFalse(engine.showFretboardGuide, "Fretboard guide starts hidden")
    }

    func testEngineInitWalletIsSynced() {
        let deps = AudioDependencies(guitarNoteEngine: guitar, midiEngine: midi, gameplayAudioEngine: SpeechEngine())
        let eng = BeginnerGameEngine(audio: deps, walletDollars: 42)
        XCTAssertEqual(eng.walletDollars, 42)
        XCTAssertEqual(eng.state.bankDollars, 42)
        XCTAssertEqual(eng.state.displayedBankDollars, 42)
    }

    // MARK: - nextThumbState state machine

    func testNextThumbStateNeutralGoesToGreen() {
        XCTAssertEqual(engine.nextThumbState(after: .neutral), .green)
    }

    func testNextThumbStateOrangeGoesToGreen() {
        XCTAssertEqual(engine.nextThumbState(after: .orange), .green)
    }

    func testNextThumbStateGreenGoesToRed() {
        XCTAssertEqual(engine.nextThumbState(after: .green), .red)
    }

    func testNextThumbStateRedGoesToNeutral() {
        XCTAssertEqual(engine.nextThumbState(after: .red), .neutral)
    }

    // MARK: - effectivePlayRepetitions

    func testEffectivePlayRepetitionsUsesPlayRepetitions() {
        engine = makeEngine(playRepetitions: 5)
        XCTAssertEqual(engine.effectivePlayRepetitions, 5)
    }

    func testEffectivePlayRepetitionsMinimumIsOne() {
        engine = makeEngine(playRepetitions: 0)
        XCTAssertEqual(engine.effectivePlayRepetitions, 1)
    }

    func testEffectivePlayRepetitionsInfiniteIsIntMax() {
        engine = makeEngine(playInfiniteRepetitions: true)
        XCTAssertEqual(engine.effectivePlayRepetitions, Int.max)
    }

    // MARK: - beginnerTargetScaleRepetitionsRemaining

    func testTargetRepetitionsRemainingAscendingPhase() {
        engine = makeEngine(playRepetitions: 4)
        engine.state.isDescendingPhase = false
        XCTAssertEqual(engine.beginnerTargetScaleRepetitionsRemaining(), 4)
    }

    func testTargetRepetitionsRemainingDescendingPhaseSubtractsAnswers() {
        engine = makeEngine(playRepetitions: 4)
        engine.state.isDescendingPhase = true
        engine.state.correctAnswersAtCurrentFret = 2
        XCTAssertEqual(engine.beginnerTargetScaleRepetitionsRemaining(), 2)
    }

    func testTargetRepetitionsRemainingDescendingPhaseMinimumIsOne() {
        engine = makeEngine(playRepetitions: 3)
        engine.state.isDescendingPhase = true
        engine.state.correctAnswersAtCurrentFret = 10
        XCTAssertEqual(engine.beginnerTargetScaleRepetitionsRemaining(), 1)
    }

    // MARK: - applyLivePlayRepetitionChangeIfNeeded

    func testApplyLiveRepetitionChangeUpdatesRemainingWhenActive() {
        engine = makeEngine(lessonStyle: .sequential, playRepetitions: 5)
        engine.state.isRoundArmed = false
        engine.isRoundPaused = false
        engine.state.isDescendingPhase = false
        engine.state.scaleRepetitionsRemaining = 99 // stale value
        engine.applyLivePlayRepetitionChangeIfNeeded()
        XCTAssertEqual(engine.state.scaleRepetitionsRemaining, 5)
    }

    func testApplyLiveRepetitionChangeDoesNothingWhenArmed() {
        engine = makeEngine(playRepetitions: 5)
        engine.state.isRoundArmed = true
        engine.state.scaleRepetitionsRemaining = 99
        engine.applyLivePlayRepetitionChangeIfNeeded()
        XCTAssertEqual(engine.state.scaleRepetitionsRemaining, 99, "Should not change when round is armed")
    }

    func testApplyLiveRepetitionChangeDoesNothingWhenPaused() {
        engine = makeEngine(playRepetitions: 5)
        engine.state.isRoundArmed = false
        engine.isRoundPaused = true
        engine.state.scaleRepetitionsRemaining = 99
        engine.applyLivePlayRepetitionChangeIfNeeded()
        XCTAssertEqual(engine.state.scaleRepetitionsRemaining, 99, "Should not change when round is paused")
    }

    func testApplyLiveRepetitionChangeDoesNothingInChordMode() {
        engine = makeEngine(lessonStyle: .chord, playRepetitions: 5)
        engine.state.isRoundArmed = false
        engine.isRoundPaused = false
        engine.state.scaleRepetitionsRemaining = 99
        engine.applyLivePlayRepetitionChangeIfNeeded()
        XCTAssertEqual(engine.state.scaleRepetitionsRemaining, 99, "Should not change in chord mode")
    }

    // MARK: - shiftFretSpan

    func testShiftFretSpanIncrements() {
        engine.state.currentFretStart = 3
        engine.shiftFretSpan(by: 2)
        XCTAssertEqual(engine.state.currentFretStart, 5)
    }

    func testShiftFretSpanDecrements() {
        engine.state.currentFretStart = 5
        engine.shiftFretSpan(by: -3)
        XCTAssertEqual(engine.state.currentFretStart, 2)
    }

    func testShiftFretSpanClampsToMax() {
        engine.state.currentFretStart = 18
        engine.shiftFretSpan(by: 10)
        XCTAssertEqual(engine.state.currentFretStart, engine.maxFretOffset)
    }

    func testShiftFretSpanClampsToMin() {
        engine.state.currentFretStart = -18
        engine.shiftFretSpan(by: -10)
        XCTAssertEqual(engine.state.currentFretStart, engine.minFretOffset)
    }

    func testShiftFretSpanByZeroDoesNothing() {
        engine.state.currentFretStart = 5
        engine.shiftFretSpan(by: 0)
        XCTAssertEqual(engine.state.currentFretStart, 5)
    }

    // MARK: - handleFretboardButtonPress

    func testFretboardButtonPressTogglesGuide() {
        XCTAssertFalse(engine.showFretboardGuide)
        engine.handleFretboardButtonPress()
        XCTAssertTrue(engine.showFretboardGuide)
        engine.handleFretboardButtonPress()
        XCTAssertFalse(engine.showFretboardGuide)
    }

    // MARK: - handleGameplayMenuSelection

    func testMenuSelectionAudioOpensAudioPage() {
        engine.handleGameplayMenuSelection(.audio)
        XCTAssertTrue(engine.showAudioPage)
    }

    func testMenuSelectionCollapsesMenu() {
        engine.gameplayMenuExpanded = true
        engine.handleGameplayMenuSelection(.audio)
        XCTAssertFalse(engine.gameplayMenuExpanded)
    }

    // MARK: - syncBackingTrackPlayback (no tracks → stop)

    func testSyncBackingTrackStopsWhenNoTracksAvailable() {
        engine.availableBackingTracks = []
        midi.isPlaying = true
        engine.syncBackingTrackPlayback()
        XCTAssertGreaterThan(midi.stopCallCount, 0, "Should stop MIDI when no tracks available")
        XCTAssertFalse(engine.isBackingTrackPlaying)
    }

    func testSyncBackingTrackStopsInScreensaverMode() {
        // backingTrackShouldPlayInGameplay returns false when isCodeScreensaverMode = true
        engine.isCodeScreensaverMode = true
        engine.availableBackingTracks = [] // trigger early return path
        midi.isPlaying = true
        engine.syncBackingTrackPlayback()
        XCTAssertGreaterThan(midi.stopCallCount, 0)
        XCTAssertFalse(engine.isBackingTrackPlaying)
    }

    // MARK: - shouldLockPlayDirection

    func testShouldLockDirectionWhenRoundActive() {
        engine.state.isRoundArmed = false
        XCTAssertTrue(engine.shouldLockPlayDirection)
    }

    func testShouldNotLockDirectionWhenRoundArmed() {
        engine.state.isRoundArmed = true
        XCTAssertFalse(engine.shouldLockPlayDirection)
    }

    // MARK: - canPressStopButton

    func testCanPressStopButtonWhenActive() {
        engine.state.isRoundArmed = false
        engine.isCodeScreensaverMode = false
        engine.isRoundPaused = false
        XCTAssertTrue(engine.canPressStopButton)
    }

    func testCannotPressStopButtonWhenArmed() {
        engine.state.isRoundArmed = true
        engine.isCodeScreensaverMode = false
        engine.isRoundPaused = false
        XCTAssertFalse(engine.canPressStopButton)
    }

    func testCannotPressStopButtonInScreensaverMode() {
        engine.state.isRoundArmed = false
        engine.isCodeScreensaverMode = true
        engine.isRoundPaused = false
        XCTAssertFalse(engine.canPressStopButton)
    }

    // MARK: - activeStringOrder

    func testActiveStringOrderSequentialHasSixStrings() {
        engine = makeEngine(lessonStyle: .sequential)
        XCTAssertEqual(engine.activeStringOrder.count, 6)
        XCTAssertEqual(engine.activeStringOrder, [1, 2, 3, 4, 5, 6])
    }

    func testActiveStringOrderChordModeHasThreeStrings() {
        engine = makeEngine(lessonStyle: .chord)
        // chord mode: even-indexed elements of [1,2,3,4,5,6] → [1,3,5]
        XCTAssertEqual(engine.activeStringOrder, [1, 3, 5])
    }

    // MARK: - beginnerUpperFretBoundary

    func testUpperFretBoundaryNormalIs12() {
        engine = makeEngine(playEnableHighFrets: false)
        XCTAssertEqual(engine.beginnerUpperFretBoundary, 12)
    }

    func testUpperFretBoundaryHighFretsIs19() {
        engine = makeEngine(playEnableHighFrets: true)
        XCTAssertEqual(engine.beginnerUpperFretBoundary, 19)
    }

    // MARK: - isProgressionLowToHigh

    func testProgressionLowToHigh() {
        engine = makeEngine(playProgression: "lowToHigh")
        XCTAssertTrue(engine.isProgressionLowToHigh)
    }

    func testProgressionHighToLow() {
        engine = makeEngine(playProgression: "highToLow")
        XCTAssertFalse(engine.isProgressionLowToHigh)
    }

    // MARK: - beginnerUsesFlats

    func testBeginnerUsesFlatsInDescendingPhase() {
        engine.state.isDescendingPhase = true
        XCTAssertTrue(engine.beginnerUsesFlats)
    }

    func testBeginnerDoesNotUseFlatsinAscendingPhase() {
        engine.state.isDescendingPhase = false
        XCTAssertFalse(engine.beginnerUsesFlats)
    }

    // MARK: - beginnerStartupArmedText

    func testStartupArmedTextSequential() {
        engine = makeEngine(lessonStyle: .sequential)
        XCTAssertEqual(engine.beginnerStartupArmedText, "SEQUENTIAL MODE ARMED")
    }

    func testStartupArmedTextChord() {
        engine = makeEngine(lessonStyle: .chord)
        XCTAssertEqual(engine.beginnerStartupArmedText, "CHORD MODE ARMED")
    }

    // MARK: - handleMainTimerTick — startup blink

    func testTimerTickInitiatesStartButtonBlink() {
        // Conditions: screensaver mode, not activated → attention active → blink starts
        engine.isCodeScreensaverMode = true
        engine.startupSequenceActivated = false
        engine.isLaunchTransitionAnimating = false
        XCTAssertTrue(engine.startupStartButtonAttentionActive, "Attention should be active")

        let now = Date()
        engine.handleMainTimerTick(now)
        XCTAssertTrue(engine.startupStartButtonBlinkOn, "Blink should turn on at first tick")
        XCTAssertNotNil(engine.startupStartButtonNextBlinkDate, "Next blink date should be set")
    }

    func testTimerTickTogglesBlinkAtNextDate() {
        engine.isCodeScreensaverMode = true
        engine.startupSequenceActivated = false
        engine.isLaunchTransitionAnimating = false

        let t0 = Date()
        engine.handleMainTimerTick(t0)
        XCTAssertTrue(engine.startupStartButtonBlinkOn)

        // Advance past next blink date
        let t1 = t0.addingTimeInterval(0.5)
        engine.handleMainTimerTick(t1)
        XCTAssertFalse(engine.startupStartButtonBlinkOn, "Blink should toggle off at next date")
    }

    func testTimerTickTurnsOffBlinkWhenAttentionInactive() {
        // Blink was on, but now round has started — attention should be inactive
        engine.startupStartButtonBlinkOn = true
        engine.isCodeScreensaverMode = false // round started, no longer screensaver
        engine.handleMainTimerTick(Date())
        XCTAssertFalse(engine.startupStartButtonBlinkOn, "Blink should turn off when attention inactive")
        XCTAssertNil(engine.startupStartButtonNextBlinkDate)
    }

    // MARK: - startGameFromBeginning

    func testStartGameFromBeginningResetsWallet() {
        engine.state.bankDollars = 50
        engine.walletDollars = 50
        engine.state.isRoundArmed = false
        engine.isCodeScreensaverMode = false
        engine.startGameFromBeginning()
        XCTAssertEqual(engine.state.bankDollars, 0)
        XCTAssertEqual(engine.walletDollars, 0)
    }

    func testStartGameFromBeginningResetsStringIndex() {
        engine.roundStringIndex = 4
        engine.state.isRoundArmed = false
        engine.isCodeScreensaverMode = false
        engine.startGameFromBeginning()
        XCTAssertEqual(engine.roundStringIndex, 0)
    }

    func testStartGameFromBeginningUsesStartingFret() {
        engine = makeEngine(playStartingFret: 3)
        engine.state.isRoundArmed = false
        engine.isCodeScreensaverMode = false
        engine.startGameFromBeginning()
        XCTAssertEqual(engine.state.currentRound, 3)
    }

    // MARK: - updateDirectionLockState

    func testUpdateDirectionLockWhenRoundActive() {
        engine.state.isRoundArmed = false
        engine.updateDirectionLockState()
        XCTAssertTrue(engine.directionLockActive)
    }

    func testUpdateDirectionLockWhenRoundArmed() {
        engine.state.isRoundArmed = true
        engine.updateDirectionLockState()
        XCTAssertFalse(engine.directionLockActive)
    }
}
