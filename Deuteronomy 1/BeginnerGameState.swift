import Foundation

// MARK: - Beginner Game State
// Single observable model replacing BeginnerRuntimeState struct + 15+ @State bools.
// All game logic mutations go through BeginnerGameEngine; this is pure data.

@Observable
final class BeginnerGameState {

    // MARK: Round
    var correctAnswersAtCurrentFret: Int = 0
    var scaleRepetitionsRemaining: Int = 1

    // MARK: Unified Reveal System (one set of counters for all lesson styles)
    var revealCount: Int = 0
    var revealStartBeatBucket: Int? = nil
    var roundOneIntroActive: Bool = false
    var roundOneSequenceStartDate: Date? = nil
    var answerBoxReady: Bool = false
    var pendingSequentialRepeatResetBeatPosition: Double? = nil
    var pendingSequentialRepeatDisplayText: String? = nil

    // MARK: Reveal aliases (sequential shares the unified counters)
    var sequentialRevealCount: Int {
        get { revealCount }
        set { revealCount = newValue }
    }
    var sequentialRevealStartBeatBucket: Int? {
        get { revealStartBeatBucket }
        set { revealStartBeatBucket = newValue }
    }

    // MARK: Round Shift
    var pendingRoundShiftBeatPosition: Double? = nil
    var pendingRewardStageAdvance: Bool = false
    var rewardTargetBeatPosition: Double? = nil
    var rewardSelectedString: Int? = nil

    // MARK: Autoplay
    var autoPlayEnabled: Bool = false
    var autoPlayNextDate: Date? = nil
    var isAutoPlayTriggered: Bool = false

    // MARK: Beat Light
    var beatLightFlashOn: Bool = false
    var beatLightLastProcessedBeat: Int? = nil
    var beatLightIntroMeasureSkipped: Bool = false

    // MARK: Answer / Reward Display
    var lastPickedNote: String? = nil
    var rewardNoteTextByString: [Int: String]? = nil
    var rewardScheduledStrings: [Int] = []
    var rewardScheduledMIDINotes: [Int] = []
    var rewardScheduledNoteTextByString: [Int: String] = [:]
    var rewardSustainMultiplier: Double = 3.0

    // MARK: Scale / Chord State (chord mode)
    var scaleSequenceIndex: Int = 0
    var scaleStageIndex: Int = 0
    var scaleCycleSemitoneOffset: Int = 0
    var pentatonicRevealCount: Int = 0
    var revealBeatBucket: Int? = nil        // chord-mode specific reveal bucket
    var introStartBeatBucket: Int? = nil
    var showRoundZeroIntroSequence: Bool = false

    // MARK: MIDI Stop
    var pendingMidiStopDate: Date? = nil

    // MARK: Reset

    func reset() {
        correctAnswersAtCurrentFret = 0
        scaleRepetitionsRemaining = 1
        clearReveal()
        clearAutoPlay()
        clearReward()
    }

    func clearReveal() {
        revealCount = 0
        revealStartBeatBucket = nil
        roundOneIntroActive = false
        roundOneSequenceStartDate = nil
        answerBoxReady = false
        pendingSequentialRepeatResetBeatPosition = nil
        pendingSequentialRepeatDisplayText = nil
        pentatonicRevealCount = 0
        revealBeatBucket = nil
        introStartBeatBucket = nil
        showRoundZeroIntroSequence = false
    }

    func clearAutoPlay() {
        autoPlayNextDate = nil
    }

    func clearReward() {
        pendingRewardStageAdvance = false
        rewardTargetBeatPosition = nil
        rewardSelectedString = nil
        rewardNoteTextByString = nil
        rewardScheduledStrings = []
        rewardScheduledMIDINotes = []
        rewardScheduledNoteTextByString = [:]
        rewardSustainMultiplier = 3.0
        lastPickedNote = nil
    }
}
