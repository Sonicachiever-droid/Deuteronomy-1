import SwiftUI
import AVFoundation

// MARK: - BeginnerGameEngine
//
// Owns all gameplay logic extracted from BeginnerGameplayView.
// BeginnerGameplayView becomes a thin coordinator that creates this engine,
// passes configuration in, and reacts to state changes via @Observable.
//
// Dependencies are injected at init so the engine can be instantiated in
// unit tests with mock audio objects.

// MARK: - Audio Dependencies

struct AudioDependencies {
    let guitarNoteEngine: GuitarNotePlaying
    let midiEngine: BackingTrackPlaying
    let gameplayAudioEngine: SpeechEngine
}

// MARK: - BeginnerGameEngine

@Observable
final class BeginnerGameEngine {

    // MARK: - Game State (observable — view reads this directly)
    private(set) var state = BeginnerGameState()

    // MARK: - Audio
    let audio: AudioDependencies

    // MARK: - Configuration (view keeps this in sync when bindings change)
    var selectedMode: RefretMode
    var lessonStyle: LessonStyle
    let layoutMode: LayoutMode = .beginner
    var playRepetitions: Int
    var playInfiniteRepetitions: Bool
    var playStartingFret: Int
    var playDirectionRawValue: String
    var playEnableHighFrets: Bool
    var playProgression: String
    var beatVolume: Double
    var stringVolume: Double
    var audioSettings: AudioSettings
    var availableBackingTracks: [BackingTrack] = []
    let beginnerScaleTemplates: [BeginnerStageTemplate]
    let audioEngineEnabled: Bool
    let consoleSkin: ConsoleSkin

    // MARK: - Wallet (synced back to view via callbacks)
    var walletDollars: Int = 0
    var balanceDollars: Int = 0

    // MARK: - View-side UI state (engine writes, view reads)
    // These are the vars the logic extensions mutate that used to be @State on the view.
    var leftThumbState: ThumbGlowState = .neutral
    var rightThumbState: ThumbGlowState = .neutral
    var beginnerPressedButtonIndex: Int? = nil
    var beginnerPressedButtonCorrect: Bool = false
    var roundStringIndex: Int = 0
    var isCodeScreensaverMode: Bool = true
    var startupSequenceStartDate: Date = .now
    var startupSequenceElapsed: TimeInterval = 0
    var startupSequenceActivated: Bool = false
    var questionBoxAssistActive: Bool = false
    var gameplayMenuExpanded: Bool = false
    var developerPromptText: String = ""
    var beatQuestionDeadline: Date? = nil
    var showFretboardGuide: Bool = false
    var isRoundPaused: Bool = false
    var isBackingTrackPlaying: Bool = false
    var isLaunchTransitionAnimating: Bool = false
    var launchTileScale: CGFloat = 1
    var launchTileOpacity: Double = 1
    var startupNeckVisualsHidden: Bool = false
    var startupStartButtonBlinkOn: Bool = false
    var startupStartButtonNextBlinkDate: Date? = nil
    var startupSpeechPhase: StartupSpeechPhase = .idle
    var assetToNutBottomDelta: CGFloat? = nil
    var introWindowBlack: Bool = true
    var introDidRun: Bool = false
    var showAudioPage: Bool = false
    var directionLockActive: Bool = false

    // MARK: - Callbacks to view for actions the view must own
    var onMenuSelection: ((GameplayMenuOption) -> Void)?
    var onWalletChanged: ((Int, Int) -> Void)? // (walletDollars, balanceDollars)
    var onDirectionLockChanged: ((Bool) -> Void)?

    // MARK: - Note Generators
    let sequentialNoteGenerator = SequentialNoteGenerator()
    let chordGenerator = ChordGenerator()

    // MARK: - Startup speech phase
    enum StartupSpeechPhase {
        case idle
        case pendingSystem
        case pendingPhase
        case pendingArmed
    }

    // MARK: - Constants
    let totalFrets: Int = 20
    var maxFretOffset: Int { totalFrets }
    var minFretOffset: Int { -totalFrets }

    // MARK: - Init

    init(
        audio: AudioDependencies,
        selectedMode: RefretMode = .freestyle,
        lessonStyle: LessonStyle = .sequential,
        playRepetitions: Int = 5,
        playInfiniteRepetitions: Bool = false,
        playStartingFret: Int = 0,
        playDirectionRawValue: String = LessonDirection.ascending.rawValue,
        playEnableHighFrets: Bool = false,
        playProgression: String = "highToLow",
        beatVolume: Double = 0.8,
        stringVolume: Double = 0.8,
        audioSettings: AudioSettings = AudioSettings(),
        beginnerScaleTemplates: [BeginnerStageTemplate] = BeginnerGameEngine.defaultScaleTemplates,
        audioEngineEnabled: Bool = false,
        consoleSkin: ConsoleSkin = .classic,
        walletDollars: Int = 0
    ) {
        self.audio = audio
        self.selectedMode = selectedMode
        self.lessonStyle = lessonStyle
        self.playRepetitions = playRepetitions
        self.playInfiniteRepetitions = playInfiniteRepetitions
        self.playStartingFret = playStartingFret
        self.playDirectionRawValue = playDirectionRawValue
        self.playEnableHighFrets = playEnableHighFrets
        self.playProgression = playProgression
        self.beatVolume = beatVolume
        self.stringVolume = stringVolume
        self.audioSettings = audioSettings
        self.beginnerScaleTemplates = beginnerScaleTemplates
        self.audioEngineEnabled = audioEngineEnabled
        self.consoleSkin = consoleSkin
        self.walletDollars = walletDollars
        self.state.bankDollars = max(walletDollars, 0)
        self.state.displayedBankDollars = self.state.bankDollars
    }

    // MARK: - State accessor (extensions read/write state directly)
    var beginnerRuntime: BeginnerGameState { state }

    // MARK: - Shared computed properties

    var currentGenerator: any NoteSequenceGenerator { sequentialNoteGenerator }

    var beatBPM: Int { audioSettings.startingBPM }

    var isPhaseDescending: Bool { state.isDescendingPhase }

    var modeVariant: GameplayModeVariant {
        if layoutMode == .beginner {
            return lessonStyle == .chord ? .chord : .freestyle
        }
        switch selectedMode {
        case .beat: return .beat
        case .chord: return .chord
        case .mixed:
            switch state.currentRound % 3 {
            case 1: return .beat
            case 2: return .chord
            default: return .freestyle
            }
        case .freestyle, .oneHand, .twoHand: return .freestyle
        }
    }

    // MARK: - Default scale templates
    static let defaultScaleTemplates: [BeginnerStageTemplate] = [
        BeginnerStageTemplate(root: "E", titleSuffix: "m Pentatonic", intervals: [0, 3, 5, 7, 10, 12], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "MINOR", intervals: [0, 3, 7], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "MINOR 7", intervals: [0, 3, 7, 10], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "MINOR ADD 9", intervals: [0, 3, 5, 7], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "MINOR ADD 11", intervals: [0, 5, 3, 7], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "7 SUS 4", intervals: [0, 5, 7, 10], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "E", titleSuffix: "MINOR 11", intervals: [0, 3, 5, 7, 10], bassSemitoneTarget: 0, endsCycle: false),
        BeginnerStageTemplate(root: "G", titleSuffix: "MAJOR", intervals: [0, 4, 7], bassSemitoneTarget: 3, endsCycle: false),
        BeginnerStageTemplate(root: "G", titleSuffix: "6", intervals: [0, 4, 7, 9], bassSemitoneTarget: 3, endsCycle: false),
        BeginnerStageTemplate(root: "G", titleSuffix: "ADD 9", intervals: [0, 2, 4, 7], bassSemitoneTarget: 3, endsCycle: false),
        BeginnerStageTemplate(root: "G", titleSuffix: "6/9", intervals: [0, 2, 4, 7, 9], bassSemitoneTarget: 3, endsCycle: false),
        BeginnerStageTemplate(root: "A", titleSuffix: "SUS 2", intervals: [0, 7, 2], bassSemitoneTarget: 5, endsCycle: false),
        BeginnerStageTemplate(root: "D", titleSuffix: "SUS 4", intervals: [0, 7, 5], bassSemitoneTarget: 10, endsCycle: true)
    ]
}
