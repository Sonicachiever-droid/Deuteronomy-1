import SwiftUI
import Combine
import AVFoundation

// MARK: - Types and components from extracted files
// Types.swift contains: GameplayMenuOption, RefretMode, GameplayModeVariant, AnswerSide, LayoutMode, BeginnerCoursePhase, BeginnerRoundZeroIntroDisplayPhase, HighlightWindowShape, FretMath, GuitarStringLayout, baselineNutTargetY, resolvedNeckTopY
// ViewComponents.swift contains: StringLineOverlay, MiniTVFrame, ThumbButtonView
// BeginnerSubviews.swift contains: WhiteNoteBoxOverlay, StartupSequenceView, + BeginnerGameplayView extension (fretIndicatorOverlay, beatPulseOverlay, developerConsoleFrame, maestroThumbOverlay, transportButtonPanelOverlay, beginnerButtonPanelOverlay, beginnerButtonState)
// DeveloperViews.swift contains: DeveloperCodeRunnerView, DeveloperConsoleFrame, DeveloperTVStreakMeterView


struct BeginnerGameplayView: View {
    let onMenuSelection: ((GameplayMenuOption) -> Void)?
    let selectedMode: RefretMode
    let beatBPM: Int
    let beatVolume: Double
    let stringVolume: Double
    @Binding var playStartingFret: Int
    @Binding var playRepetitions: Int
    @Binding var playInfiniteRepetitions: Bool
    @Binding var playDirectionRawValue: String
    @Binding var playEnableHighFrets: Bool
    @Binding var playLessonStyle: String
    var lessonStyle: LessonStyle { LessonStyle(rawValue: playLessonStyle) ?? .chord }
    @Binding var playProgression: String
    @Binding var walletDollars: Int
    @Binding var balanceDollars: Int
    let consoleSkin: ConsoleSkin
    @AppStorage("numbers3.runtime.directionLockActive") private var directionLockActive: Bool = false

    @State var audioSettings = AudioSettings()
    @State var showAudioPage: Bool = false
    let layoutMode: LayoutMode = .beginner

    @Environment(\.displayScale) private var displayScale
    private let totalFrets: Int = 20
    private var maxFretOffset: Int { totalFrets }
    private var minFretOffset: Int { -totalFrets }
    var modeVariant: GameplayModeVariant {
        if layoutMode == .beginner {
            return lessonStyle == .chord ? .chord : .freestyle
        }

        switch selectedMode {
        case .beat:
            return .beat
        case .chord:
            return .chord
        case .mixed:
            switch beginnerRuntime.currentRound % 3 {
            case 1:
                return .beat
            case 2:
                return .chord
            default:
                return .freestyle
            }
        case .freestyle, .oneHand, .twoHand:
            return .freestyle
        }
    }

    private var isPhaseDescending: Bool {
        beginnerRuntime.isDescendingPhase
    }

    var showMaestroOverlays: Bool {
        layoutMode == .maestro
    }

    private var isProgressionLowToHigh: Bool { playProgression == "lowToHigh" }

    var activeStringOrder: [Int] {
        let baseOrder: [Int] = {
            let base: [Int] = selectedMode == .oneHand ? [1, 2, 3, 4] : [1, 2, 3, 4, 5, 6]
            return (modeVariant == .freestyle && isProgressionLowToHigh) ? base.reversed() : base
        }()

        switch modeVariant {
        case .chord:
            return Array(baseOrder.enumerated().compactMap { index, value in
                index.isMultiple(of: 2) ? value : nil
            })
        case .freestyle, .beat:
            return baseOrder
        }
    }

    private var modePayoutMultiplier: Double {
        switch selectedMode {
        case .freestyle:
            return 1.0
        case .beat:
            return 1.25
        case .chord:
            return 1.4
        case .mixed:
            return 1.6
        case .oneHand, .twoHand:
            return 1.15
        }
    }
    // chromaticSharps, chromaticFlats, openNoteByString — use module-level globals from GuitarHelpers.swift
    let codenameNemoEnabled: Bool = false
    private let scaleLengthInches: Double = 25.5
    private let debugGridRows: Int = 8
    private var maxWindowRow: Int { (debugGridRows - 1) * 2 } // half-step increments across rows
    // beginnerRuntime.currentFretStart, beginnerRuntime.currentWindowRow, beginnerRuntime.currentRound, beginnerRuntime.isDescendingPhase,
    // beginnerRuntime.leftChoiceNote, beginnerRuntime.rightChoiceNote, beginnerRuntime.correctAnswerSide, beginnerRuntime.currentCorrectNote,
    // beginnerRuntime.currentQuestionIsAccidental, beginnerRuntime.currentPromptStrings, beginnerRuntime.bankDollars, beginnerRuntime.displayedBankDollars,
    // beginnerRuntime.isRoundArmed, beginnerRuntime.transportStoppedForResume, beginnerRuntime.isResolvingAnswer,
    // beginnerRuntime.activePickedStringNumbers, beginnerRuntime.answeredNotesByStringAtCurrentFret,
    // beginnerRuntime.autoPlayLastStringByNote, beginnerRuntime.activeAnswerFeedback — moved to BeginnerGameState (Step 3)
    // (Step 2 vars also live in BeginnerGameState)
    @State private var leftThumbState: ThumbGlowState = .neutral
    @State private var rightThumbState: ThumbGlowState = .neutral
    @State var beginnerPressedButtonIndex: Int? = nil
    @State var beginnerPressedButtonCorrect: Bool = false
    @State var roundStringIndex: Int = 0

    // Chord system integration
    @StateObject private var chordGenerator = ChordGenerator()
    // Sequential style integration
    @StateObject var sequentialNoteGenerator = SequentialNoteGenerator()
    // Unified generator access — no more if/else chains at callsites
    private var currentGenerator: any NoteSequenceGenerator {
        sequentialNoteGenerator
    }
    @State private var introWindowBlack: Bool = true
    @State private var introDidRun: Bool = false
    @State var isCodeScreensaverMode: Bool = true
    @State var startupSequenceStartDate: Date = .now
    @State var startupSequenceElapsed: TimeInterval = 0
    @State var startupSequenceActivated: Bool = false
    @State private var assetToNutBottomDelta: CGFloat? = nil
    @State private var questionBoxAssistActive: Bool = false
    @State var gameplayMenuExpanded: Bool = false
    @State var developerPromptText: String = ""
    @State private var beatQuestionDeadline: Date? = nil
    @State var showFretboardGuide: Bool = false
    @State var isRoundPaused: Bool = false
    @State var isBackingTrackPlaying: Bool = false
    @State var isLaunchTransitionAnimating: Bool = false
    @State var launchTileScale: CGFloat = 1
    @State var launchTileOpacity: Double = 1
    @State var startupNeckVisualsHidden: Bool = false
    @State var startupStartButtonBlinkOn: Bool = false
    @State private var startupStartButtonNextBlinkDate: Date? = nil
    @State var beatPulseActive: Bool = false
    @State var beginnerRuntime = BeginnerGameState()

    enum StartupSpeechPhase {
        case idle
        case pendingSystem
        case pendingPhase
        case pendingArmed
    }

    private struct BeginnerStageTemplate {
        let root: String
        let titleSuffix: String
        let intervals: [Int]
        let bassSemitoneTarget: Int
        let endsCycle: Bool
    }

    private struct BeginnerScaleStage {
        let title: String
        let notes: [String]
        let bassSemitoneTarget: Int
        let endsCycle: Bool
    }


    private struct BeginnerRewardPolicyKey: Hashable {
        let stageIndex: Int
        let fret: Int?
    }

    private struct BeginnerRewardPolicy {
        let isRewardEnabled: Bool
        let delayBeats: Double
        let sustainMultiplier: Double
        let preferredStrings: [Int]?
    }

    @State var startupSpeechPhase: StartupSpeechPhase = .idle
    @State var availableBackingTracks: [BackingTrack] = []

    private let gameplayAudioEngine = SpeechEngine()
    private let guitarNoteEngine: GuitarNotePlaying = SharedAudioEngine.shared
    let midiEngine: BackingTrackPlaying = SharedAudioEngine.shared
    private let audioEngineEnabled: Bool = false
    private let speakBeatTicks: Bool = false
    private let speakGameplayPrompts: Bool = false
    private let beginnerScaleTemplates: [BeginnerStageTemplate] = [
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

    private func beginnerChordSuffixDisplay(_ rawSuffix: String) -> String {
        switch rawSuffix {
        case "m Pentatonic": return "m Pentatonic"
        case "MINOR": return "m"
        case "MINOR 7": return "m7"
        case "MINOR ADD 9": return "madd9"
        case "MINOR ADD 11": return "madd11"
        case "7 SUS 4": return "7sus4"
        case "MINOR 11": return "m11"
        case "MAJOR": return "Maj"
        case "6": return "6"
        case "ADD 9": return "add9"
        case "6/9": return "6/9"
        case "SUS 2": return "sus2"
        case "SUS 4": return "sus4"
        default: return rawSuffix
        }
    }

    private var beginnerScaleStages: [BeginnerScaleStage] {
        beginnerScaleTemplates.map { template in
            let root = transposedNote(template.root, by: beginnerRuntime.scaleCycleSemitoneOffset, useFlats: beginnerUsesFlats)
            let notes = template.intervals.map { interval in
                transposedNote(template.root, by: beginnerRuntime.scaleCycleSemitoneOffset + interval, useFlats: beginnerUsesFlats)
            }
            let stageTitle = "\(root)\(beginnerChordSuffixDisplay(template.titleSuffix))"

            return BeginnerScaleStage(
                title: stageTitle,
                notes: notes,
                bassSemitoneTarget: template.bassSemitoneTarget + beginnerRuntime.scaleCycleSemitoneOffset,
                endsCycle: template.endsCycle
            )
        }
    }

    private var beginnerCurrentScaleStage: BeginnerScaleStage {
        let clampedIndex = min(max(beginnerRuntime.scaleStageIndex, 0), max(beginnerScaleStages.count - 1, 0))
        return beginnerScaleStages[clampedIndex]
    }

    var beginnerCurrentScaleNotes: [String] {
        beginnerCurrentScaleStage.notes
    }

    private var beginnerCurrentScaleTitle: String {
        beginnerCurrentScaleStage.title
    }

    var chordNoteStringMap: [Int] {
        let notes = beginnerCurrentScaleNotes
        let fret = max(beginnerRuntime.currentRound, 0)
        var map: [Int] = []
        var usedStrings: Set<Int> = []

        for note in notes {
            var foundString: Int?
            // Search strings in low-to-high order (6,5,4,3,2,1), skipping already-used strings
            for stringNumber in stride(from: 6, through: 1, by: -1) {
                if !usedStrings.contains(stringNumber) && guitarNoteName(forString: stringNumber, fret: fret, useFlats: beginnerUsesFlats) == note {
                    foundString = stringNumber
                    usedStrings.insert(stringNumber)
                    break
                }
            }
            // If note not found on any unused string, skip it (shouldn't happen for valid scales)
            if let stringNum = foundString {
                map.append(stringNum)
            }
        }
        return map
    }

    private var beginnerCurrentBassSemitoneTarget: Int {
        beginnerCurrentScaleStage.bassSemitoneTarget
    }

    private var beginnerRewardPolicies: [BeginnerRewardPolicyKey: BeginnerRewardPolicy] {
        var table: [BeginnerRewardPolicyKey: BeginnerRewardPolicy] = [:]
        let defaultPolicy = BeginnerRewardPolicy(
            isRewardEnabled: true,
            delayBeats: 3.0,
            sustainMultiplier: 3.0,
            preferredStrings: nil
        )
        for stageIndex in 1..<max(beginnerScaleStages.count, 1) {
            table[BeginnerRewardPolicyKey(stageIndex: stageIndex, fret: nil)] = defaultPolicy
        }
        return table
    }

    private var beginnerPentatonicProgressText: String {
        let notes = beginnerCurrentScaleNotes
        let count = min(max(beginnerRuntime.pentatonicRevealCount, 0), notes.count)
        return notes.prefix(count).joined(separator: " ")
    }


    private var shouldShowLegacyRoundZeroIntro: Bool {
        beginnerRoundOneStartingFret == 0
    }

    func getWalletColor() -> Color {
        .green
    }

    func getRepetitionCountColor() -> Color {
        .pink
    }

    var beginnerRoundStatusText: String? {
        guard layoutMode == .beginner else { return nil }

        // Sequential style: show revealed notes one by one
        if lessonStyle == .sequential {
            guard !isCodeScreensaverMode else { return nil }

            if let pendingSequentialRepeatDisplayText = beginnerRuntime.pendingSequentialRepeatDisplayText {
                return pendingSequentialRepeatDisplayText
            }

            let revealCount = min(beginnerRuntime.sequentialRevealCount, sequentialNoteGenerator.currentNoteSequence.count)
            let revealedNotes = sequentialNoteGenerator.currentNoteSequence
                .prefix(revealCount)
                .map(guitarNoteDisplayText)
                .joined(separator: " ")
            return revealedNotes
        }

        // Chord style: existing behavior
        if !beginnerRuntime.answerBoxReady,
           !beginnerRuntime.roundOneIntroActive {
            return nil
        }
        switch beginnerRoundZeroIntroDisplayPhase {
        case .centeredRoundZeroChordMode:
            return nil
        case .roundZeroHeader:
            return beginnerCurrentScaleTitle
        case .roundZeroScaleTitle:
            return beginnerCurrentScaleTitle
        case .noteReveal, .inactive:
            break
        }
        let progressLine = beginnerPentatonicProgressText
        if progressLine.isEmpty {
            return guitarNoteDisplayText(beginnerCurrentScaleTitle)
        }
        return "\(guitarNoteDisplayText(beginnerCurrentScaleTitle))\n\(guitarNoteDisplayText(progressLine))"
    }

    var beginnerCenteredStatusMessage: String? {
        guard layoutMode == .beginner else { return nil }

        // Sequential style: show intro message during startup
        if lessonStyle == .sequential {
            if isCodeScreensaverMode && startupSequenceActivated {
                let startupState = StartupSequenceView.state(
                    for: startupSequenceElapsed,
                    showFullSequence: false,
                    armedText: "SEQUENTIAL MODE ARMED"
                )
                if startupState.phase == .armed {
                    return "SEQUENTIAL MODE\nARMED"
                }
            }
            return nil
        }

        return nil
    }

    private var beginnerCenteredStatusColor: Color {
        Color.green.opacity(0.98)
    }

    private var beginnerRoundZeroIntroDisplayPhase: BeginnerRoundZeroIntroDisplayPhase {
        guard layoutMode == .beginner,
              beginnerRuntime.roundOneIntroActive,
              beginnerRuntime.showRoundZeroIntroSequence
        else {
            return .inactive
        }

        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        let startBeatBucket = beginnerRuntime.introStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - startBeatBucket, 0)

        if elapsedBeatBuckets < 2 {
            return .roundZeroHeader
        }
        if elapsedBeatBuckets < 4 {
            return .roundZeroScaleTitle
        }
        return .noteReveal
    }

    private var beginnerAcceptsGameplayAnswers: Bool {
        return !beginnerRuntime.roundOneIntroActive
    }

    private var playDirection: LessonDirection {
        LessonDirection(rawValue: playDirectionRawValue) ?? .ascending
    }

    private var effectivePlayRepetitions: Int {
        if playInfiniteRepetitions {
            return Int.max // Use very large number for infinite mode
        }
        return max(playRepetitions, 1)
    }

    private var beginnerRoundTwoStartsDescending: Bool {
        playDirection == .descending
    }

    private var beginnerLowerFretBoundary: Int {
        0
    }

    private var beginnerUpperFretBoundary: Int {
        playEnableHighFrets ? 19 : 12
    }

    private var clampedBeginnerStartingFret: Int {
        min(max(playStartingFret, beginnerLowerFretBoundary), beginnerUpperFretBoundary)
    }

    private var beginnerRoundOneStartingFret: Int {
        clampedBeginnerStartingFret
    }

    private var beginnerRoundTwoStartingFret: Int {
        clampedBeginnerStartingFret
    }

    private var beginnerRoundOneStartsDescending: Bool {
        playDirection == .descending
    }

    var beginnerUsesFlats: Bool {
        guard layoutMode == .beginner else { return false }
        return beginnerRuntime.isDescendingPhase
    }

    private var backingTrackShouldPlayInGameplay: Bool {
        guard layoutMode == .beginner else { return false }
        guard !isCodeScreensaverMode else { return false }
        return true
    }

    var startupStartButtonAttentionActive: Bool {
        guard layoutMode == .beginner else { return false }
        guard isCodeScreensaverMode else { return false }
        guard !isLaunchTransitionAnimating else { return false }

        if !startupSequenceActivated {
            return true
        }

        let startupState = StartupSequenceView.state(
            for: startupSequenceElapsed,
            showFullSequence: layoutMode != .beginner,
            armedText: beginnerStartupArmedText
        )
        return startupState.phase == .armed
    }

    var canPressStopButton: Bool {
        !beginnerRuntime.isRoundArmed && !isCodeScreensaverMode && !isRoundPaused
    }

    private var shouldLockPlayDirection: Bool {
        guard layoutMode == .beginner else { return false }
        return !beginnerRuntime.isRoundArmed
    }

    var beginnerStartupArmedText: String {
        if layoutMode == .beginner {
            if lessonStyle == .sequential { return "SEQUENTIAL MODE ARMED" }
            return "CHORD MODE ARMED"
        }
        return "Memorization Sequence Armed"
    }

    init(
        onMenuSelection: ((GameplayMenuOption) -> Void)? = nil,
        selectedMode: RefretMode = .freestyle,
        beatBPM: Int = 80,
        beatVolume: Double = 0.8,
        stringVolume: Double = 0.8,
        playStartingFret: Binding<Int> = .constant(0),
        playRepetitions: Binding<Int> = .constant(5),
        playInfiniteRepetitions: Binding<Bool> = .constant(false),
        playDirectionRawValue: Binding<String> = .constant(LessonDirection.ascending.rawValue),
        playEnableHighFrets: Binding<Bool> = .constant(false),
        playLessonStyle: Binding<String> = .constant("chord"),
        playProgression: Binding<String> = .constant("highToLow"),
        walletDollars: Binding<Int> = .constant(0),
        balanceDollars: Binding<Int> = .constant(0),
        consoleSkin: ConsoleSkin = .classic
    ) {
        self.onMenuSelection = onMenuSelection
        self.selectedMode = selectedMode
        self.beatBPM = beatBPM
        self.beatVolume = beatVolume
        self.stringVolume = stringVolume
        self._playStartingFret = playStartingFret
        self._playRepetitions = playRepetitions
        self._playInfiniteRepetitions = playInfiniteRepetitions
        self._playDirectionRawValue = playDirectionRawValue
        self._playEnableHighFrets = playEnableHighFrets
        self._playLessonStyle = playLessonStyle
        self._playProgression = playProgression
        self._walletDollars = walletDollars
        self._balanceDollars = balanceDollars
        self.consoleSkin = consoleSkin
    }

    var body: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 24
            let neckWidth = (proxy.size.width - padding * 2) * 0.8
            let fretRatios = FretMath.fretPositionRatios(totalFrets: totalFrets, scaleLength: scaleLengthInches)
            let visibleFrets = min(totalFrets, 5)
            let visibleFretIndex = min(visibleFrets, fretRatios.count - 1)
            let visibleRatio = max(fretRatios[visibleFretIndex], 0.05)
            let visibleClipHeight = proxy.size.height * 0.96
            let unclippedHeight = visibleClipHeight / visibleRatio
            let minimumNeckHeight = proxy.size.height * 1.35
            let neckHeight = max(unclippedHeight, minimumNeckHeight)
            let nutHeight = max(neckHeight * 0.02, 18)
            let nutVisualHeight = nutHeight * 0.4
            let debugGridColumns = 5
            let debugGridRows = 8
            let _ = proxy.size.width / CGFloat(debugGridColumns)
            let gridRowHeight = proxy.size.height / CGFloat(debugGridRows)
            let globalContentShiftY = gridRowHeight * 0.25
            let rowOneBottomLineY = gridRowHeight
            let highlightHeight = 2 * gridRowHeight
            let lockedWindowTopRowIndex: CGFloat = 1.0
            let highlightTopGridLineY = lockedWindowTopRowIndex * gridRowHeight
            
            let scale = displayScale
            
            let highlightCenterYSnapped: CGFloat = {
                let raw = highlightTopGridLineY + highlightHeight / 2
                return (raw * scale).rounded() / scale
            }()
            let viewingWindowShiftY: CGFloat = gridRowHeight * 0.5
            let viewingWindowCenterY = highlightCenterYSnapped + viewingWindowShiftY

            let pipingCenterY = viewingWindowCenterY
            let orangeGreenUnitCenterY = pipingCenterY - (gridRowHeight * 0.5)
            let holeCenterY = highlightCenterYSnapped
            let highlightAvailableWidth = max(proxy.size.width - padding * 2, 0)
            let highlightExtraWidth = max(highlightAvailableWidth - neckWidth, 0)
            let highlightWidth = neckWidth + highlightExtraWidth / 2
            let highlightCornerRadius = min(24, highlightWidth * 0.08)
            let currentTargetString = activeStringOrder[min(max(roundStringIndex, 0), activeStringOrder.count - 1)]
            let promptStrings = beginnerRuntime.currentPromptStrings.isEmpty ? [currentTargetString] : beginnerRuntime.currentPromptStrings
            let fretStatusLabel = "FRET \(beginnerRuntime.currentRound)"
            let stringStatusLabel = promptStrings.count > 1
                ? "STRINGS \(promptStrings.map(String.init).joined(separator: "+"))"
                : "STRING \(promptStrings[0])"
            let isGameplayStarted = !isCodeScreensaverMode
            let displayedFretStatusLabel = isGameplayStarted ? fretStatusLabel : ""
            let displayedStringStatusLabel: String = {
                if lessonStyle == .sequential { return "SEQUENTIAL MODE" }
                return isGameplayStarted ? stringStatusLabel : ""
            }()
            let screenBannerFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let screenMeasuredWidth = max(
                textWidth(for: fretStatusLabel, font: screenBannerFont),
                textWidth(for: stringStatusLabel, font: screenBannerFont),
                textWidth(for: "STRING 6", font: screenBannerFont)
            )
            let screenBannerWidth = screenMeasuredWidth + 32
            let screenBannerHeight = max(min(gridRowHeight * 0.72, 52), 44)
            let lowerScreenWidth = screenBannerWidth * 0.5
            let lowerScreenHeight = screenBannerHeight
            let thumbDiameter = min(proxy.size.width, proxy.size.height) * 0.336
            let virtualRows: CGFloat = 40
            let vRowH: CGFloat = proxy.size.height / virtualRows
            let buttonCenterY: CGFloat = (28 - 0.5) * vRowH
            let screenPairSpacing: CGFloat = 16
            let buttonPairSpacing: CGFloat = 28
            let windowBottomY = holeCenterY + highlightHeight / 2
            let topScreenY = windowBottomY + screenBannerHeight * 0.72
            let _ = (proxy.size.width / 2) - (screenBannerWidth / 2) - (screenPairSpacing / 2)
            let _ = (proxy.size.width / 2) + (screenBannerWidth / 2) + (screenPairSpacing / 2)
            let halfButtonCenterGap = (thumbDiameter + buttonPairSpacing) / 2
            let leftButtonCenterX = (proxy.size.width / 2) - halfButtonCenterGap
            let rightButtonCenterX = (proxy.size.width / 2) + halfButtonCenterGap
            let leftAnswerCenterX = leftButtonCenterX
            let rightAnswerCenterX = rightButtonCenterX
            let buttonTopY = buttonCenterY - (thumbDiameter / 2)
            let buttonBottomY = buttonCenterY + (thumbDiameter / 2)
            let whitePipingGap = max(gridRowHeight * 0.32, 14)
            let upperWhitePipingY = buttonTopY - whitePipingGap
            let lowerWhitePipingY = buttonBottomY + whitePipingGap - (gridRowHeight * GuitarConstants.gridRowHeightRatio)
            let transportCenterY = min(
                windowBottomY + max(gridRowHeight * 1.15, 24),
                upperWhitePipingY - max(gridRowHeight * 0.95, 20)
            )
            let whitePipingWidth = max(proxy.size.width - 7, 0)
            let noteChoiceY = upperWhitePipingY - (lowerScreenHeight / 2) - 2
            let windowTopY = holeCenterY - highlightHeight / 2
            let topStatusOuterWidth = highlightWidth
            let topStatusOuterHeight = max(min(gridRowHeight * 1.35, 120), 74)
            let topStatusBottomGap = max(gridRowHeight * GuitarConstants.gridRowHeightRatio, 10)
            let topStatusCenterY = (windowTopY - topStatusBottomGap) - (topStatusOuterHeight / 2)
            let sideWindowGap = max((proxy.size.width - highlightWidth) / 4, 18)
            let leftFretIndicatorX = (proxy.size.width / 2) - (highlightWidth / 2) - sideWindowGap
            let rightFretIndicatorX = (proxy.size.width / 2) + (highlightWidth / 2) + sideWindowGap
            let fretIndicatorText = "\(max(beginnerRuntime.currentRound, 0))"

            let unsignedN = abs(beginnerRuntime.currentFretStart)
            let activeMidpointIndex: Int = {
                if beginnerRuntime.currentFretStart > 0 {
                    return max(beginnerRuntime.currentFretStart - 1, 0)
                }
                return unsignedN
            }()
            let clampedN = min(activeMidpointIndex, fretRatios.count - 2)
            let topRatio = fretRatios[clampedN]
            let bottomRatio = fretRatios[clampedN + 1]
            let midRatio = (topRatio + bottomRatio) / 2.0
            let sign: CGFloat = beginnerRuntime.currentFretStart >= 0 ? 1.0 : -1.0
            let activeMidpoint = midRatio * neckHeight * sign
            
            let nutTargetY = baselineNutTargetY(highlightTopGridLineY: highlightTopGridLineY, gridRowHeight: gridRowHeight)
            let neckTopY = resolvedNeckTopY(
                currentFretStart: beginnerRuntime.currentFretStart,
                nutTargetY: nutTargetY,
                highlightCenterY: pipingCenterY,
                activeMidpoint: activeMidpoint
            )
            
            let neckOffsetY: CGFloat = {
                if beginnerRuntime.currentFretStart == 0 {
                    let raw = neckTopY - proxy.size.height / 2 + neckHeight / 2
                    return (raw * scale).rounded() / scale
                } else {
                    let raw = pipingCenterY - activeMidpoint - proxy.size.height / 2 + neckHeight / 2
                    return (raw * scale).rounded() / scale
                }
            }()
            
            let manualBlueAdjustment: CGFloat = -gridRowHeight * 0.5
            let finalNeckOffsetY = neckOffsetY + manualBlueAdjustment
            let neckVisualOffsetAdjustment = finalNeckOffsetY - neckOffsetY
            let nutBottomY = neckTopY + neckVisualOffsetAdjustment + (nutVisualHeight * GuitarConstants.nutHeightOffset)
            let stringStopInset = max(1.0, 2.0 / max(scale, 1.0))
            let stringTopY = nutBottomY + stringStopInset
            let calibratedAssetToNutDelta = assetToNutBottomDelta ?? 0
            let _ = (nutBottomY + calibratedAssetToNutDelta) - rowOneBottomLineY
            let startupState: (text: String, color: Color, isVisible: Bool, phase: StartupSequenceView.Phase) = {
                guard startupSequenceActivated else {
                    return ("", .clear, false, .systemOnline)
                }
                return StartupSequenceView.state(
                    for: startupSequenceElapsed,
                    showFullSequence: layoutMode != .beginner,
                    armedText: layoutMode == .beginner ? beginnerStartupArmedText : "Memorization Sequence Armed"
                )
            }()
            let screensaverThumbState: ThumbGlowState = {
                switch startupState.phase {
                case .systemOnline: return startupState.isVisible ? .orange : .neutral
                case .phaseOne: return startupState.isVisible ? .red : .neutral
                case .armed: return startupState.isVisible ? .green : .neutral
                }
            }()
            let effectiveLeftThumbState = isCodeScreensaverMode ? screensaverThumbState : leftThumbState
            let effectiveRightThumbState = isCodeScreensaverMode ? screensaverThumbState : rightThumbState
            let initialGameplayDimOpacity: CGFloat = (isCodeScreensaverMode && !startupSequenceActivated) ? 0.42 : 1.0

            ZStack {
                if consoleSkin == .tweed {
                    FullScreenTweedBackground()
                        .ignoresSafeArea()
                    // Black fill so the window hole reveals a dark background, not more tweed
                    RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                        .fill(Color.black)
                        .frame(width: highlightWidth, height: highlightHeight)
                        .position(x: proxy.size.width / 2, y: orangeGreenUnitCenterY)
                        .allowsHitTesting(false)
                } else {
                    FullScreenElephantBackground()
                        .ignoresSafeArea()
                }

                HStack {
                    Spacer()
                    ZStack {
                        ZStack(alignment: .top) {
                            ZStack {
                                if consoleSkin == .tweed {
                                    MapleSegmentedBackground(
                                        fretRatios: fretRatios,
                                        cornerRadius: 18
                                    )
                                } else {
                                    RosewoodSegmentedBackground(
                                        fretRatios: fretRatios,
                                        cornerRadius: 18
                                    )
                                }
                                BindingLayer()
                                FretWireLayer(fretRatios: fretRatios)
                                FretMarkerLayer(fretRatios: fretRatios)
                            }
                            .frame(width: neckWidth, height: neckHeight)

                            NutLayer(width: neckWidth * GuitarConstants.nutWidthRatio, height: nutVisualHeight)
                                .frame(width: neckWidth * GuitarConstants.nutWidthRatio, height: nutVisualHeight)
                                .offset(y: -nutVisualHeight * 0.85)
                        }
                        .frame(width: neckWidth, height: neckHeight)
                        .offset(y: finalNeckOffsetY)
                    }
                    .frame(width: neckWidth, height: visibleClipHeight)
                    .clipped()
                    Spacer()
                }
                .padding(.horizontal, padding)
                .opacity(startupNeckVisualsHidden ? 0 : 1)

                StringLineOverlay(
                    neckWidth: neckWidth,
                    horizontalPadding: padding,
                    stringTopY: stringTopY
                )
                .opacity(startupNeckVisualsHidden ? 0 : 1)

                RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .frame(width: highlightWidth, height: highlightHeight)
                    .position(x: proxy.size.width / 2, y: pipingCenterY)
                    .allowsHitTesting(false)
                    .opacity(introWindowBlack ? 1 : 0)

                if consoleSkin == .tweed {
                    TweedWindowView(
                        canvasSize: proxy.size,
                        highlightWidth: highlightWidth,
                        highlightHeight: highlightHeight,
                        highlightCenter: CGPoint(x: proxy.size.width / 2, y: orangeGreenUnitCenterY),
                        highlightCornerRadius: highlightCornerRadius
                    )
                    .allowsHitTesting(false)
                } else {
                    ElephantWindowView(
                        canvasSize: proxy.size,
                        highlightWidth: highlightWidth,
                        highlightHeight: highlightHeight,
                        highlightCenter: CGPoint(x: proxy.size.width / 2, y: orangeGreenUnitCenterY),
                        highlightCornerRadius: highlightCornerRadius
                    )
                    .allowsHitTesting(false)
                }

                if isCodeScreensaverMode {
                    ZStack {
                        if consoleSkin == .tweed {
                            Image("Refret tweed logo")
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(x: 1.15, y: 1.0, anchor: .center)
                                .frame(width: highlightWidth, height: highlightHeight)
                                .clipped()
                                .clipShape(HighlightWindowShape(cornerRadius: highlightCornerRadius))

                            HighlightWindowChromeBorder(
                                width: highlightWidth,
                                height: highlightHeight,
                                cornerRadius: highlightCornerRadius
                            )
                        } else {
                            Image("REFRETLOGOSET")
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(x: 1.15, y: 1.0, anchor: .center)
                                .frame(width: highlightWidth, height: highlightHeight)
                                .clipped()
                                .clipShape(HighlightWindowShape(cornerRadius: highlightCornerRadius))

                            HighlightWindowGoldBorder(
                                width: highlightWidth,
                                height: highlightHeight,
                                cornerRadius: highlightCornerRadius
                            )
                        }
                    }
                    .scaleEffect(isLaunchTransitionAnimating ? launchTileScale : 1)
                    .opacity(isLaunchTransitionAnimating ? launchTileOpacity : 1)
                    .position(x: proxy.size.width / 2, y: orangeGreenUnitCenterY)
                    .allowsHitTesting(false)
                }

                fretIndicatorOverlay(
                    leftX: leftFretIndicatorX,
                    rightX: rightFretIndicatorX,
                    centerY: orangeGreenUnitCenterY,
                    text: fretIndicatorText,
                    isHidden: isCodeScreensaverMode
                )

                if showFretboardGuide && !isCodeScreensaverMode {
                    let guideBoxHeight = topStatusOuterHeight * 0.5
                    let guideBoxWidth = neckWidth
                    let guideBoxCornerRadius = guideBoxHeight * 0.35
                    let guideBoxCenterY = windowBottomY - (guideBoxHeight / 2) - 4
                    let stringCenters = GuitarStringLayout.stringCenters(containerWidth: proxy.size.width, neckWidth: neckWidth)
                    let fretboardStrings = (0..<GuitarStringLayout.totalStrings).map { GuitarStringLayout.highestStringNumber - $0 }
                    let minGuideSpacing = zip(stringCenters.dropFirst(), stringCenters).map(-).min() ?? (guideBoxWidth / CGFloat(max(fretboardStrings.count, 1)))
                    let guideTileWidth = max(minGuideSpacing * 0.82, 18)
                    let guideTileHeight = guideBoxHeight * 0.86
                    ZStack {
                        // Six individual translucent backgrounds matching each note box
                        ForEach(Array(fretboardStrings.enumerated()), id: \.offset) { index, _ in
                            RoundedRectangle(cornerRadius: UIConstants.answerBoxRadius, style: .continuous)
                                .fill(Color.black.opacity(0.42))
                                .frame(width: guideTileWidth, height: guideTileHeight)
                                .position(x: stringCenters[index], y: guideBoxCenterY)
                        }

                        ForEach(Array(fretboardStrings.enumerated()), id: \.offset) { index, stringNumber in
                            let note = guitarNoteName(forString: stringNumber, fret: max(beginnerRuntime.currentRound, 0), useFlats: beginnerUsesFlats)
                            let displayNote = guitarNoteDisplayText(note)
                            let noteIsAccidental = guitarNoteContainsAccidental(note)
                            let tileFill = noteIsAccidental ? Color.black.opacity(0.94) : Color.white.opacity(0.96)
                            let tileStroke = noteIsAccidental ? Color.white.opacity(0.7) : Color.black.opacity(0.68)
                            let textColor = noteIsAccidental ? Color.white.opacity(0.98) : Color.black.opacity(0.95)
                            let noteFontSize = min(guideBoxHeight * 0.44, 24)

                            RoundedRectangle(cornerRadius: guideBoxCornerRadius * 0.45, style: .continuous)
                                .fill(tileFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: guideBoxCornerRadius * 0.45, style: .continuous)
                                        .stroke(tileStroke, lineWidth: 1.2)
                                )
                                .frame(width: guideTileWidth, height: guideTileHeight)
                                .overlay {
                                    Text(displayNote)
                                        .font(.system(size: noteFontSize, weight: .black, design: .monospaced))
                                        .minimumScaleFactor(0.45)
                                        .lineLimit(1)
                                        .foregroundStyle(textColor)
                                }
                                .position(x: stringCenters[index], y: guideBoxCenterY)
                        }
                    }
                    .allowsHitTesting(false)
                }

                beatPulseOverlay(centerX: proxy.size.width / 2, centerY: topStatusCenterY, isHidden: isCodeScreensaverMode)

#if DEBUG
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: proxy.size.width / 2, y: holeCenterY)
                    .allowsHitTesting(false)
                    .opacity(0)
#endif

                developerConsoleFrame(
                    proxyWidth: proxy.size.width,
                    topStatusCenterY: topStatusCenterY,
                    topStatusOuterWidth: topStatusOuterWidth,
                    topStatusOuterHeight: topStatusOuterHeight
                )

                let introScale = max(beginnerRuntime.questionBoxIntroProgress, 0.001)
                let introOffsetY = (1 - beginnerRuntime.questionBoxIntroProgress) * ((proxy.size.height / 2) - topScreenY)
                let questionBoxOffsetY = (1 - beginnerRuntime.questionBoxIntroProgress) * ((proxy.size.height / 2) - orangeGreenUnitCenterY)
                let shouldShowQuestionUI = !isCodeScreensaverMode && !startupSequenceActivated && beginnerRuntime.questionBoxIntroProgress > 0.0
                let hasBeginnerSelectedNote = !(beginnerRuntime.lastPickedNote?.isEmpty ?? true)
                    || !(beginnerRuntime.rewardNoteTextByString?.isEmpty ?? true)
                let shouldShowWhiteAnswerBox = shouldShowQuestionUI && {
                    if layoutMode != .beginner { return true }
                    // Show answer box when note is selected, regardless of game state
                    if hasBeginnerSelectedNote && beginnerRuntime.answerBoxReady {
                        return true
                    }
                    // Chord mode: need pentatonic reveal complete
                    return beginnerRuntime.answerBoxReady
                        && beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count
                        && hasBeginnerSelectedNote
                }()

                if shouldShowQuestionUI {
                    HStack(spacing: screenPairSpacing) {
                        MiniTVFrame(
                            text: displayedStringStatusLabel,
                            width: screenBannerWidth,
                            height: screenBannerHeight,
                            fontScale: 0.82,
                            glowTint: questionBoxAssistActive ? .orange : nil,
                            hitTestingEnabled: false,
                            consoleSkin: consoleSkin
                        )
                        MiniTVFrame(
                            text: displayedFretStatusLabel,
                            width: screenBannerWidth,
                            height: screenBannerHeight,
                            fontScale: 0.82,
                            glowTint: questionBoxAssistActive ? .orange : nil,
                            hitTestingEnabled: false,
                            consoleSkin: consoleSkin
                        )
                    }
                    .scaleEffect(introScale)
                    .animation(.easeInOut(duration: 0.5), value: beginnerRuntime.questionBoxIntroProgress)
                    .offset(y: introOffsetY)
                    .frame(width: proxy.size.width, height: screenBannerHeight)
                    .position(x: proxy.size.width / 2, y: topScreenY)
                    .allowsHitTesting(showMaestroOverlays)
                    .accessibilityHidden(!showMaestroOverlays)
                    .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? initialGameplayDimOpacity * introScale : 0))

                    MiniTVFrame(text: guitarNoteDisplayText(beginnerRuntime.leftChoiceNote), width: lowerScreenWidth, height: lowerScreenHeight, fontScale: 1.0, consoleSkin: consoleSkin)
                        .position(x: leftAnswerCenterX, y: noteChoiceY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(!showMaestroOverlays)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? introScale : 0))

                    MiniTVFrame(text: guitarNoteDisplayText(beginnerRuntime.rightChoiceNote), width: lowerScreenWidth, height: lowerScreenHeight, fontScale: 1.0, consoleSkin: consoleSkin)
                        .position(x: rightAnswerCenterX, y: noteChoiceY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(!showMaestroOverlays)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? introScale : 0))

                    if shouldShowWhiteAnswerBox {
                        WhiteNoteBoxOverlay(
                            centerY: orangeGreenUnitCenterY,
                            availableSize: proxy.size,
                            boxHeight: gridRowHeight * 0.9,
                            neckWidth: neckWidth,
                            activeStringNumbers: beginnerRuntime.activePickedStringNumbers,
                            answerFeedback: beginnerRuntime.activeAnswerFeedback,
                            revealedNoteText: layoutMode == .beginner
                                ? (hasBeginnerSelectedNote ? beginnerRuntime.lastPickedNote : nil)
                                : (beginnerRuntime.activeAnswerFeedback == .green ? beginnerRuntime.currentCorrectNote : nil),
                            revealedNoteTextByString: layoutMode == .beginner ? (beginnerRuntime.rewardNoteTextByString ?? beginnerRuntime.answeredNotesByStringAtCurrentFret) : nil,
                            revealedNoteTextColor: Color.black.opacity(0.96)
                        )
                        .allowsHitTesting(false)
                        .offset(y: questionBoxOffsetY)
                        .opacity(codenameNemoEnabled ? 0 : initialGameplayDimOpacity)
                    }
                }

                if consoleSkin != .tweed {
                    GoldHorizontalPipingLine(width: whitePipingWidth)
                        .position(x: proxy.size.width / 2, y: upperWhitePipingY)
                        .allowsHitTesting(false)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? 1 : 0))

                    GoldHorizontalPipingLine(width: whitePipingWidth)
                        .position(x: proxy.size.width / 2, y: lowerWhitePipingY)
                        .allowsHitTesting(false)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? 1 : 0))
                }

                if consoleSkin == .tweed {
                    WhitePipingBorder(bottomInset: 0)
                        .allowsHitTesting(false)
                        .offset(y: -globalContentShiftY)
                        .zIndex(100)
                } else {
                    GoldPipingBorder(bottomInset: 0)
                        .allowsHitTesting(false)
                        .offset(y: -globalContentShiftY)
                        .zIndex(100)
                }
            }
            .overlay(alignment: .bottom) {
                GameplayControlPlateShell(
                    isMenuExpanded: gameplayMenuExpanded,
                    isStartupInputLockActive: false,
                    isAutoplayActive: beginnerRuntime.autoPlayEnabled,
                    onAutoplay: {
                        beginnerRuntime.autoPlayEnabled.toggle()
                    },
                    onFretboard: {
                        handleFretboardButtonPress()
                    },
                    onToggleMenu: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            gameplayMenuExpanded.toggle()
                        }
                    },
                    onSelectMenuOption: { option in
                        handleGameplayMenuSelection(option)
                    },
                    consoleSkin: consoleSkin
                )
                    .frame(maxWidth: min((proxy.size.width - 24) * 0.88, 370))
                    .padding(.bottom, 12)
                    .opacity(codenameNemoEnabled ? 0 : 1)
            }
            .overlay(alignment: .topLeading) {
                // No AUTO button overlay
            }
            .overlay(alignment: .topLeading) {
                maestroThumbOverlay(
                    proxyWidth: proxy.size.width,
                    buttonCenterY: buttonCenterY,
                    thumbDiameter: thumbDiameter,
                    leftThumbState: effectiveLeftThumbState,
                    rightThumbState: effectiveRightThumbState,
                    dimOpacity: initialGameplayDimOpacity
                )
            }
            .overlay(alignment: .topLeading) {
                if layoutMode == .beginner {
                    beginnerButtonPanelOverlay(
                        proxyWidth: proxy.size.width,
                        proxyHeight: proxy.size.height,
                        buttonCenterY: buttonCenterY,
                        lowerScreenHeight: lowerScreenHeight,
                        transportCenterY: transportCenterY,
                        dimOpacity: initialGameplayDimOpacity,
                        startupState: startupState
                    )
                }
            }
            .overlay {
                transportButtonPanelOverlay(
                    proxyWidth: proxy.size.width,
                    transportCenterY: transportCenterY,
                    startupState: startupState
                )
            }
            .overlay {
                EmptyView()
            }
            .onAppear(perform: handleContentOnAppear)
            .onDisappear {
                midiEngine.stop()
            }
            .sheet(isPresented: $showAudioPage, onDismiss: handleAudioPageDismiss) {
                AudioPageView(
                    audioSettings: audioSettings,
                    availableBackingTracks: availableBackingTracks,
                    onDone: {
                        showAudioPage = false
                    }
                )
            }
            .onChange(of: audioSettings.guitarTonePreset) { _, newValue in
                guitarNoteEngine.configure(
                    preset: newValue,
                    reverbLevel: audioSettings.reverbLevel,
                    delayLevel: audioSettings.delayLevel
                )
            }
            .onChange(of: audioSettings.reverbLevel) { _, newValue in
                guitarNoteEngine.configure(
                    preset: audioSettings.guitarTonePreset,
                    reverbLevel: newValue,
                    delayLevel: audioSettings.delayLevel
                )
            }
            .onChange(of: audioSettings.delayLevel) { _, newValue in
                guitarNoteEngine.configure(
                    preset: audioSettings.guitarTonePreset,
                    reverbLevel: audioSettings.reverbLevel,
                    delayLevel: newValue
                )
            }
            .onChange(of: audioSettings.selectedBackingTrackID) { _, _ in
                syncBackingTrackPlayback()
            }
            .onChange(of: audioSettings.selectedBackingArrangement) { _, _ in
                syncBackingTrackPlayback()
            }
            .onChange(of: beginnerRuntime.scaleStageIndex) { _, _ in
                applyBeginnerBassTransposeForCurrentStage()
            }
            .onChange(of: beginnerRuntime.scaleCycleSemitoneOffset) { _, _ in
                applyBeginnerBassTransposeForCurrentStage()
            }
            .onChange(of: isCodeScreensaverMode) { _, isScreensaverMode in
                updateDirectionLockState()
                syncBackingTrackPlayback()
                if isScreensaverMode {
                    beginnerRuntime.beatLightFlashOn = false
                    beginnerRuntime.beatLightLastProcessedBeat = nil
                    beginnerRuntime.beatLightIntroMeasureSkipped = false
                }
            }
            .onChange(of: beginnerRuntime.currentRound) { _, newValue in
                _ = newValue
                applyBeginnerBassTransposeForCurrentStage()
            }
            .onChange(of: playRepetitions) { _, _ in
                guard layoutMode == .beginner else { return }

                if beginnerRuntime.isRoundArmed || isRoundPaused {
                    beginnerRuntime.scaleRepetitionsRemaining = beginnerTargetScaleRepetitionsRemaining()
                    return
                }

                applyLivePlayRepetitionChangeIfNeeded()
            }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { date in
                handleMainTimerTick(date)
            }
            .onChange(of: beginnerRuntime.autoPlayEnabled) { _, isEnabled in
                if layoutMode != .beginner {
                    beginnerRuntime.autoPlayEnabled = false
                    beginnerRuntime.autoPlayNextDate = nil
                    return
                }
                guard isEnabled else {
                    beginnerRuntime.autoPlayNextDate = nil
                    return
                }
                let revealReady = !beginnerRuntime.roundOneIntroActive
                    && beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count
                beginnerRuntime.autoPlayNextDate = revealReady ? Date().addingTimeInterval(0.2) : nil
            }
            .offset(y: globalContentShiftY)
        }
    }

    private func shiftFretSpan(by delta: Int) {
        guard delta != 0 else { return }
        withAnimation(.easeInOut(duration: 1.3)) {
            beginnerRuntime.currentFretStart = min(max(beginnerRuntime.currentFretStart + delta, minFretOffset), maxFretOffset)
        }
    }

    private func shiftWindow(by delta: Int) {
        let proposed = beginnerRuntime.currentWindowRow + delta
        let clamped = min(max(proposed, 0), 7)
        guard clamped != beginnerRuntime.currentWindowRow else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            beginnerRuntime.currentWindowRow = clamped
        }
    }

    private func nextThumbState(after state: ThumbGlowState) -> ThumbGlowState {
        switch state {
        case .neutral: return .green
        case .orange: return .green
        case .green: return .red
        case .red: return .neutral
        }
    }
    // fretIndicatorOverlay — moved to BeginnerSubviews.swift
    // beatPulseOverlay — moved to BeginnerSubviews.swift

    private func handleMainTimerTick(_ date: Date) {
        let shouldBlinkStartupStartButton = startupStartButtonAttentionActive && !startupSequenceActivated

        if shouldBlinkStartupStartButton {
            if startupStartButtonNextBlinkDate == nil {
                startupStartButtonBlinkOn = true
                startupStartButtonNextBlinkDate = date.addingTimeInterval(0.45)
            } else if let nextBlinkDate = startupStartButtonNextBlinkDate, date >= nextBlinkDate {
                startupStartButtonBlinkOn.toggle()
                startupStartButtonNextBlinkDate = date.addingTimeInterval(0.45)
            }
        } else {
            startupStartButtonBlinkOn = false
            startupStartButtonNextBlinkDate = nil
        }

        if startupSequenceActivated {
            startupSequenceElapsed = max(date.timeIntervalSince(startupSequenceStartDate), 0)
            let startupState = StartupSequenceView.state(for: startupSequenceElapsed, showFullSequence: layoutMode != .beginner, armedText: beginnerStartupArmedText)
            handleStartupSpeech(for: startupState.phase)
        }

        handlePendingMidiStopIfNeeded()

        if beginnerRuntime.isRoundArmed || isRoundPaused {
            beginnerRuntime.beatLightFlashOn = false
            beginnerRuntime.roundRevealLastTickDate = nil
            return
        }

        if beginnerRuntime.roundRevealLastTickDate == nil {
            beginnerRuntime.roundRevealLastTickDate = date
        } else if let lastTick = beginnerRuntime.roundRevealLastTickDate {
            let delta = max(date.timeIntervalSince(lastTick), 0)
            let beatsPerSecond = Double(max(beatBPM, 60)) / 60.0
            beginnerRuntime.roundRevealElapsedBeats += delta * beatsPerSecond
            beginnerRuntime.roundRevealLastTickDate = date
        }

        handlePendingBeginnerRewardPlaybackIfNeeded()
        handlePendingSequentialRepeatResetIfNeeded()
        handlePendingRoundShiftIfNeeded()
        ensureBeginnerRoundOneRevealSequenceStarted(currentDate: date)
        updateBeginnerRoundOneRevealSequence(currentDate: date)
        updateNoteRevealProgressionIfNeeded()
        handleBeginnerAutoPlayIfNeeded(currentDate: date)

        let trackPlayingNow = midiEngine.isPlaying
        if isBackingTrackPlaying != trackPlayingNow {
            isBackingTrackPlaying = trackPlayingNow
        }

        let shouldRunBeatLight = layoutMode == .beginner && !isCodeScreensaverMode && trackPlayingNow
        if shouldRunBeatLight {
            let currentBeatBucket = Int(floor(midiEngine.currentBeatPosition()))

            if beginnerRuntime.beatLightLastProcessedBeat == nil {
                beginnerRuntime.beatLightLastProcessedBeat = currentBeatBucket
                beginnerRuntime.beatLightFlashOn = false
                return
            }

            if beginnerRuntime.beatLightLastProcessedBeat != currentBeatBucket {
                beginnerRuntime.beatLightLastProcessedBeat = currentBeatBucket

                if !beginnerRuntime.beatLightIntroMeasureSkipped {
                    if currentBeatBucket >= 4 {
                        beginnerRuntime.beatLightIntroMeasureSkipped = true
                    } else {
                        beginnerRuntime.beatLightFlashOn = false
                        return
                    }
                }

                beginnerRuntime.beatLightFlashOn = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    beginnerRuntime.beatLightFlashOn = false
                }
            }
        } else {
            beginnerRuntime.beatLightFlashOn = false
            beginnerRuntime.beatLightLastProcessedBeat = nil
            beginnerRuntime.beatLightIntroMeasureSkipped = false
        }
    }

    private func applyLivePlayRepetitionChangeIfNeeded() {
        guard layoutMode == .beginner,
              !beginnerRuntime.isRoundArmed,
              !isRoundPaused
        else { return }

        beginnerRuntime.scaleRepetitionsRemaining = beginnerTargetScaleRepetitionsRemaining()
    }

    private func beginnerTargetScaleRepetitionsRemaining() -> Int {
        if beginnerRuntime.isDescendingPhase {
            return max(effectivePlayRepetitions - beginnerRuntime.correctAnswersAtCurrentFret, 1)
        }
        return effectivePlayRepetitions
    }

    func updateDirectionLockState() {
        directionLockActive = shouldLockPlayDirection
    }

    private func handleContentOnAppear() {
        initializeGameplaySession()
        updateDirectionLockState()
    }

    private func initializeGameplaySession() {
        audioSettings = AudioSettings()
        availableBackingTracks = BackingTrack.discoverBundledTracks()
        audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
        guitarNoteEngine.configure(
            preset: audioSettings.guitarTonePreset,
            reverbLevel: audioSettings.reverbLevel,
            delayLevel: audioSettings.delayLevel
        )
        syncBackingTrackPlayback()
        if assetToNutBottomDelta == nil {
            assetToNutBottomDelta = 0
        }
        introDidRun = true
        startupSequenceStartDate = .now
        startupSequenceElapsed = 0
        startupSequenceActivated = false
        introWindowBlack = false
        beginnerRuntime.currentFretStart = 0
        beginnerRuntime.bankDollars = max(walletDollars, 0)
        beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
        showDeveloperPrompt("MODE: \(selectedMode.rawValue.uppercased())")
        beginnerRuntime.questionBoxIntroProgress = isCodeScreensaverMode ? 0 : 1
        beginnerRuntime.answerBoxReady = layoutMode == .beginner ? false : !isCodeScreensaverMode
        beginnerRuntime.isRoundArmed = layoutMode == .beginner
        isRoundPaused = false
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil
    }

    func startGameFromBeginning(animateNeckSlideFromStartup: Bool = false) {
        if layoutMode == .beginner {
            beginnerRuntime.currentRound = beginnerRoundOneStartingFret
            beginnerRuntime.isDescendingPhase = beginnerRoundOneStartsDescending
        } else {
            beginnerRuntime.currentRound = isPhaseDescending ? 12 : 0
            beginnerRuntime.isDescendingPhase = isPhaseDescending
        }
        if animateNeckSlideFromStartup {
            startupNeckVisualsHidden = true
            beginnerRuntime.currentFretStart = beginnerRuntime.isDescendingPhase ? maxFretOffset : minFretOffset
            DispatchQueue.main.async {
                startupNeckVisualsHidden = false
                withAnimation(.easeInOut(duration: 0.78)) {
                    beginnerRuntime.currentFretStart = beginnerRuntime.currentRound
                }
            }
        } else {
            startupNeckVisualsHidden = false
            beginnerRuntime.currentFretStart = beginnerRuntime.currentRound
        }
        roundStringIndex = 0
        beginnerRuntime.bankDollars = 0
        beginnerRuntime.displayedBankDollars = 0
        walletDollars = 0
        beatQuestionDeadline = nil
        beginnerRuntime.currentPromptStrings = [1]
        beginnerRuntime.activePickedStringNumbers = [1]
        beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
        beginnerRuntime.beatCountInRemaining = modeVariant == .beat ? 4 : 0
        beginnerRuntime.nextBeatTickDate = nil
        leftThumbState = .neutral
        rightThumbState = .neutral
        beginnerRuntime.activeAnswerFeedback = nil
        beginnerRuntime.isResolvingAnswer = false
        isRoundPaused = false
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil
        gameplayMenuExpanded = false
        developerPromptText = ""
        beginnerRuntime.currentCorrectNote = ""
        beginnerRuntime.lastResolvedCorrectNote = nil
        beginnerRuntime.streakMeterLitColumns = 0
        beginnerRuntime.streakMeterFailureActive = false
        beginnerRuntime.streakMeterFailureVisibleColumns = 0
        beginnerRuntime.correctAnswersAtCurrentFret = 0
        beginnerRuntime.lastPromptedCorrectNote = nil
        beginnerRuntime.lastPromptedStringHalf = nil
        beginnerRuntime.lastPromptedStringNumber = nil
        beginnerRuntime.recentPromptedCorrectNotes = []
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.answerBoxReady = layoutMode != .beginner
        beginnerRuntime.autoPlayNextDate = nil
        beginnerRuntime.beatLightFlashOn = false
        beginnerRuntime.beatLightLastProcessedBeat = nil
        beginnerRuntime.roundOneIntroActive = false
        beginnerRuntime.roundOneSequenceStartDate = nil
        beginnerRuntime.beatLightIntroMeasureSkipped = false
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        beginnerRuntime.pendingRoundShiftBeatPosition = nil
        beginnerRuntime.scaleSequenceIndex = 0
        beginnerRuntime.scaleStageIndex = 0
        beginnerRuntime.scaleCycleSemitoneOffset = beginnerRuntime.currentRound
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.revealStartBeatBucket = nil
        beginnerRuntime.introStartBeatBucket = nil
        beginnerRuntime.showRoundZeroIntroSequence = false
        beginnerRuntime.pendingRewardStageAdvance = false
        beginnerRuntime.rewardTargetBeatPosition = nil
        beginnerRuntime.rewardSelectedString = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.rewardScheduledStrings = []
        beginnerRuntime.rewardScheduledMIDINotes = []
        beginnerRuntime.rewardScheduledNoteTextByString = [:]
        beginnerRuntime.rewardSustainMultiplier = 3.0

        // Initialize Sequential style state if needed
        if lessonStyle == .sequential {
            sequentialNoteGenerator.generateNoteSequence(for: beginnerRuntime.currentRound, useFlats: beginnerUsesFlats, lowToHigh: isProgressionLowToHigh)
            beginnerRuntime.sequentialRevealCount = 0
            beginnerRuntime.sequentialRevealStartBeatBucket = nil
            beginnerRuntime.roundOneIntroActive = true
            beginnerRuntime.roundOneSequenceStartDate = Date()
        }

        applyBeginnerBassTransposeForCurrentStage()
        prepareCurrentQuestion()
    }

    private func beginnerRewardPolicyForCurrentStage() -> BeginnerRewardPolicy? {
        guard layoutMode == .beginner else { return nil }

        let currentFret = max(beginnerRuntime.currentRound, 0)
        let specificKey = BeginnerRewardPolicyKey(stageIndex: beginnerRuntime.scaleStageIndex, fret: currentFret)
        if let policy = beginnerRewardPolicies[specificKey], policy.isRewardEnabled {
            return policy
        }

        let fallbackKey = BeginnerRewardPolicyKey(stageIndex: beginnerRuntime.scaleStageIndex, fret: nil)
        if let policy = beginnerRewardPolicies[fallbackKey], policy.isRewardEnabled {
            return policy
        }

        return nil
    }

    private func beginnerRewardStringAssignments(forChordNotes chordNotes: [String], preferredStrings: [Int]?) -> [(Int, String)] {
        let allStringsDescending = [6, 5, 4, 3, 2, 1]
        let preferredSequence = preferredStrings ?? []
        let fallbackSequence = allStringsDescending.filter { !preferredSequence.contains($0) }
        let candidateSequence = preferredSequence + fallbackSequence
        let rewardDisplayFret = max(beginnerRuntime.currentRound, 0)
        var unusedStrings = candidateSequence
        var assignments: [(Int, String)] = []
        let strictStringPriority = [1, 6, 5, 4, 3, 2]

        for chordNote in chordNotes {
            let matchingStrings = unusedStrings.filter {
                guitarNoteName(forString: $0, fret: rewardDisplayFret, useFlats: false) == chordNote
                    || guitarNoteName(forString: $0, fret: rewardDisplayFret, useFlats: beginnerUsesFlats) == chordNote
            }

            guard let matchedString = strictStringPriority.first(where: { matchingStrings.contains($0) }) else {
                continue
            }
            assignments.append((matchedString, chordNote))
            unusedStrings.removeAll { $0 == matchedString }
        }

        return assignments
    }

    private func beginnerRewardChordPayloadForCurrentStage(
        policy: BeginnerRewardPolicy
    ) -> (strings: [Int], notesByString: [Int: String], midiNotes: [Int]) {
        let chordNotes = Array(beginnerCurrentScaleNotes.prefix(5))
        let rewardPairs = beginnerRewardStringAssignments(forChordNotes: chordNotes, preferredStrings: policy.preferredStrings)

        var strings: [Int] = []
        var notesByString: [Int: String] = [:]
        var midiNotes: [Int] = []

        let rewardDisplayFret = max(beginnerRuntime.currentRound, 0)

        for (stringNumber, _) in rewardPairs {
            let displayedNote = guitarNoteName(forString: stringNumber, fret: rewardDisplayFret, useFlats: beginnerUsesFlats)
            guard let midiNote = beginnerRewardMIDINote(for: displayedNote, stringNumber: stringNumber) else { continue }
            strings.append(stringNumber)
            notesByString[stringNumber] = displayedNote
            midiNotes.append(midiNote)
        }

        return (strings, notesByString, midiNotes)
    }

    private func beginnerRewardMIDINote(for noteName: String, stringNumber: Int) -> Int? {
        let openMIDINoteByString: [Int: Int] = [6: 40, 5: 45, 4: 50, 3: 55, 2: 59, 1: 64]
        guard let openMIDINote = openMIDINoteByString[stringNumber] else { return nil }

        let targetPitchClass = chromaticSharps.firstIndex(of: noteName)
            ?? chromaticFlats.firstIndex(of: noteName)
        guard let targetPitchClass else { return nil }

        let openPitchClass = openMIDINote % 12
        let fretOffset = (targetPitchClass - openPitchClass + 12) % 12
        return openMIDINote + fretOffset
    }

    private func scheduleBeginnerRewardChordThenAdvance(selectedString: Int, policy: BeginnerRewardPolicy) {
        let rewardPayload = beginnerRewardChordPayloadForCurrentStage(policy: policy)
        guard !rewardPayload.midiNotes.isEmpty else {
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
            return
        }

        beginnerRuntime.pendingRewardStageAdvance = true
        beginnerRuntime.rewardSelectedString = selectedString
        beginnerRuntime.rewardTargetBeatPosition = beginnerRuntime.roundRevealElapsedBeats + policy.delayBeats
        beginnerRuntime.rewardScheduledStrings = rewardPayload.strings
        beginnerRuntime.rewardScheduledMIDINotes = rewardPayload.midiNotes
        beginnerRuntime.rewardScheduledNoteTextByString = rewardPayload.notesByString
        beginnerRuntime.rewardSustainMultiplier = policy.sustainMultiplier
        beginnerRuntime.rewardNoteTextByString = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString,
                  beginnerRuntime.rewardTargetBeatPosition != nil else { return }
            beginnerRuntime.activePickedStringNumbers = []
            beginnerRuntime.lastPickedNote = nil
            beginnerRuntime.answerBoxReady = false
        }
    }

    private func scheduleBeginnerAdvanceAfterFinalNoteHold(selectedString: Int, holdSeconds: Double = 0.65) {
        beginnerRuntime.pendingRewardStageAdvance = true
        beginnerRuntime.rewardSelectedString = selectedString
        beginnerRuntime.rewardTargetBeatPosition = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString,
                  beginnerRuntime.rewardTargetBeatPosition == nil else { return }
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
        }
    }

    private func handlePendingBeginnerRewardPlaybackIfNeeded() {
        guard layoutMode == .beginner,
              beginnerRuntime.pendingRewardStageAdvance,
              let targetBeatPosition = beginnerRuntime.rewardTargetBeatPosition,
              let selectedString = beginnerRuntime.rewardSelectedString else { return }

        let currentBeatPosition = beginnerRuntime.roundRevealElapsedBeats
        guard currentBeatPosition >= targetBeatPosition else { return }

        beginnerRuntime.rewardTargetBeatPosition = nil

        guard !beginnerRuntime.rewardScheduledMIDINotes.isEmpty else {
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            beginnerRuntime.rewardScheduledStrings = []
            beginnerRuntime.rewardScheduledMIDINotes = []
            beginnerRuntime.rewardScheduledNoteTextByString = [:]
            beginnerRuntime.rewardSustainMultiplier = 3.0
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
            return
        }

        beginnerRuntime.activePickedStringNumbers = beginnerRuntime.rewardScheduledStrings
        beginnerRuntime.answerBoxReady = true
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = beginnerRuntime.rewardScheduledNoteTextByString
        let rewardChordRingDuration = guitarNoteEngine.playChord(
            midiNotes: beginnerRuntime.rewardScheduledMIDINotes,
            velocity: 0.98,
            sustainMultiplier: beginnerRuntime.rewardSustainMultiplier
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + rewardChordRingDuration) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString else { return }
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            beginnerRuntime.rewardScheduledStrings = []
            beginnerRuntime.rewardScheduledMIDINotes = []
            beginnerRuntime.rewardScheduledNoteTextByString = [:]
            beginnerRuntime.rewardSustainMultiplier = 3.0
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
        }
    }

    private func handlePendingSequentialRepeatResetIfNeeded() {
        guard lessonStyle == .sequential,
              let targetBeatPosition = beginnerRuntime.pendingSequentialRepeatResetBeatPosition else { return }

        guard beginnerRuntime.roundRevealElapsedBeats >= targetBeatPosition else { return }

        beginnerRuntime.pendingSequentialRepeatResetBeatPosition = nil
        sequentialNoteGenerator.resetForNewFret()
        beginnerRuntime.sequentialRevealCount = 0
        beginnerRuntime.sequentialRevealStartBeatBucket = nil
        beginnerRuntime.answerBoxReady = false
        // Clear all answer-display state so the new repetition starts blank.
        // Without this, beginnerRuntime.activePickedStringNumbers and lastPickedNote leak from
        // the just-completed repetition, causing every string to show the
        // previous final answer when beginnerRuntime.answeredNotesByStringAtCurrentFret is empty.
        beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
        beginnerRuntime.activePickedStringNumbers = []
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil

        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        sequentialNoteGenerator.generateNoteSequence(
            for: max(beginnerRuntime.currentRound, 0),
            useFlats: useFlats,
            lowToHigh: isProgressionLowToHigh
        )
        prepareCurrentQuestion()

        DispatchQueue.main.async {
            beginnerRuntime.pendingSequentialRepeatDisplayText = nil
        }
    }

    private func handlePendingRoundShiftIfNeeded() {
        guard lessonStyle == .sequential,
              let targetBeatPosition = beginnerRuntime.pendingRoundShiftBeatPosition else { return }

        let currentBeatPosition = beginnerRuntime.roundRevealElapsedBeats
        guard currentBeatPosition >= targetBeatPosition else { return }

        // 2-beat delay has passed - clear the pending shift and execute
        beginnerRuntime.pendingRoundShiftBeatPosition = nil

        // Clear white note box immediately before shift
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.answerBoxReady = false

        // Reset mode state for new fret
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        sequentialNoteGenerator.resetForNewFret()
        beginnerRuntime.sequentialRevealCount = 0
        beginnerRuntime.sequentialRevealStartBeatBucket = nil

        // Advance to next fret (or reverse direction at boundary)
        if !beginnerRuntime.isDescendingPhase {
            if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                beginnerRuntime.currentRound += 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            } else {
                // At boundary - reverse direction
                beginnerRuntime.isDescendingPhase = true
                playDirectionRawValue = LessonDirection.descending.rawValue
                beginnerRuntime.currentRound = beginnerUpperFretBoundary - 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            }
        } else {
            if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                beginnerRuntime.currentRound -= 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            } else {
                beginnerRuntime.isDescendingPhase = false
                playDirectionRawValue = LessonDirection.ascending.rawValue
                beginnerRuntime.currentRound = 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            }
        }

        // Generate new sequence for new fret and apply bass transpose
        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        sequentialNoteGenerator.generateNoteSequence(for: max(beginnerRuntime.currentRound, 0), useFlats: useFlats, lowToHigh: isProgressionLowToHigh)
        applyBeginnerBassTransposeForCurrentStage()
        prepareCurrentQuestion()
    }

    private func handlePendingMidiStopIfNeeded() {
        guard layoutMode == .beginner,
              let stopDate = beginnerRuntime.pendingMidiStopDate else { return }
        guard Date() >= stopDate else { return }

        // 3-beat delay has passed - stop the MIDI playback
        beginnerRuntime.pendingMidiStopDate = nil
        midiEngine.stop()
        isBackingTrackPlaying = false
    }

    private func advanceBeginnerScaleStage(afterCompletionFromString selectedString: Int, playTransitionNote: Bool = true) {
        beginnerRuntime.autoPlayLastStringByNote = [:]
        let completedStageWasCycleEnd = beginnerCurrentScaleStage.endsCycle
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.rewardScheduledStrings = []
        beginnerRuntime.rewardScheduledMIDINotes = []
        beginnerRuntime.rewardScheduledNoteTextByString = [:]
        beginnerRuntime.rewardSustainMultiplier = 3.0
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        if completedStageWasCycleEnd {
            beginnerRuntime.scaleRepetitionsRemaining -= 1
            if beginnerRuntime.scaleRepetitionsRemaining > 0 {
                beginnerRuntime.scaleStageIndex = 0
                beginnerRuntime.scaleSequenceIndex = 0
                beginnerRuntime.pentatonicRevealCount = 0
                beginnerRuntime.roundOneIntroActive = true
                beginnerRuntime.roundOneSequenceStartDate = Date()
                beginnerRuntime.roundRevealElapsedBeats = 0
                if lessonStyle == .chord {
                    beginnerRuntime.showRoundZeroIntroSequence = true
                    beginnerRuntime.introStartBeatBucket = 0
                }
                return
            }
        }
        if completedStageWasCycleEnd {
            let nextFret: Int?
            if beginnerRuntime.isDescendingPhase {
                nextFret = beginnerRuntime.currentRound > beginnerLowerFretBoundary ? beginnerRuntime.currentRound - 1 : nil
            } else {
                nextFret = beginnerRuntime.currentRound < beginnerUpperFretBoundary ? beginnerRuntime.currentRound + 1 : nil
            }

            if let nextFret {
                beginnerRuntime.currentRound = nextFret
                beginnerRuntime.scaleCycleSemitoneOffset = nextFret
                beginnerRuntime.scaleStageIndex = 0
                beginnerRuntime.scaleSequenceIndex = 0
                beginnerRuntime.pentatonicRevealCount = 0
                beginnerRuntime.roundOneIntroActive = false
                beginnerRuntime.roundOneSequenceStartDate = nil
                beginnerRuntime.revealStartBeatBucket = nil
                beginnerRuntime.introStartBeatBucket = nil
                beginnerRuntime.rewardSelectedString = nil
            } else {
                // At boundary - reverse direction and keep the shared binding aligned
                if beginnerRuntime.isDescendingPhase {
                    beginnerRuntime.isDescendingPhase = false
                    playDirectionRawValue = LessonDirection.ascending.rawValue
                    beginnerRuntime.currentRound = 1
                } else {
                    beginnerRuntime.isDescendingPhase = true
                    playDirectionRawValue = LessonDirection.descending.rawValue
                    beginnerRuntime.currentRound = beginnerUpperFretBoundary - 1
                }
            }
        } else {
            beginnerRuntime.scaleStageIndex = min(beginnerRuntime.scaleStageIndex + 1, beginnerScaleStages.count - 1)
        }
        beginnerRuntime.scaleSequenceIndex = 0
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.roundOneIntroActive = true
        beginnerRuntime.roundOneSequenceStartDate = Date()
        beginnerRuntime.roundRevealElapsedBeats = 0
        if lessonStyle == .chord {
            beginnerRuntime.showRoundZeroIntroSequence = true
            beginnerRuntime.introStartBeatBucket = 0
        }
        beginnerRuntime.roundRevealLastTickDate = nil
        beginnerRuntime.answerBoxReady = false
        beginnerRuntime.lastPickedNote = nil
        applyBeginnerBassTransposeForCurrentStage()
        if playTransitionNote {
            playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
        }
    }

    private func transposedSharpNote(_ note: String, by semitones: Int) -> String {
        transposedNote(note, by: semitones, useFlats: false)
    }

    private func transposedNote(_ note: String, by semitones: Int, useFlats: Bool) -> String {
        guard let index = chromaticSharps.firstIndex(of: note) else { return note }
        let wrapped = (index + semitones % chromaticSharps.count + chromaticSharps.count) % chromaticSharps.count
        let scale = useFlats ? chromaticFlats : chromaticSharps
        return scale[wrapped]
    }

    private func applyBeginnerBassTransposeForCurrentStage() {
        guard layoutMode == .beginner else {
            midiEngine.setBassTransposeSemitones(0)
            return
        }

        if !beginnerRuntime.isDescendingPhase {
            if lessonStyle == .sequential {
                let transposeSemitones = playEnableHighFrets ? max(beginnerRuntime.currentRound, 0) % 12 : max(beginnerRuntime.currentRound, 0)
                midiEngine.setBassTransposeSemitones(transposeSemitones)
            } else {
                midiEngine.setBassTransposeSemitones(beginnerCurrentBassSemitoneTarget)
            }
            return
        }

        if beginnerRuntime.isDescendingPhase {
            midiEngine.setBassTransposeSemitones(max(beginnerRuntime.currentRound, 0) % 12)
            return
        }

        midiEngine.setBassTransposeSemitones(0)
    }

    private func ensureBeginnerRoundOneRevealSequenceStarted(currentDate: Date) {
        guard layoutMode == .beginner,
              !isCodeScreensaverMode,
              !startupSequenceActivated,
              lessonStyle == .chord,
              beginnerRuntime.questionBoxIntroProgress > 0,
              beginnerRuntime.roundOneSequenceStartDate == nil,
              beginnerRuntime.pentatonicRevealCount == 0,
              !beginnerRuntime.answerBoxReady,
              !beginnerRuntime.isRoundArmed
        else { return }

        beginnerRuntime.roundOneIntroActive = true
        beginnerRuntime.roundOneSequenceStartDate = currentDate
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.revealStartBeatBucket = nil
        beginnerRuntime.introStartBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        beginnerRuntime.showRoundZeroIntroSequence = lessonStyle == .chord ? true : shouldShowLegacyRoundZeroIntro
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.answerBoxReady = false
    }

    private func updateBeginnerRoundOneRevealSequence(currentDate _: Date) {
        guard beginnerRuntime.roundOneIntroActive,
              beginnerRuntime.roundOneSequenceStartDate != nil,
              layoutMode == .beginner,
              lessonStyle == .chord,
              !isCodeScreensaverMode,
              !startupSequenceActivated
        else { return }

        guard beginnerRoundZeroIntroDisplayPhase == .noteReveal else { return }
        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        if beginnerRuntime.revealStartBeatBucket == nil {
            beginnerRuntime.revealStartBeatBucket = currentBeatBucket
        }
        let revealStartBeatBucket = beginnerRuntime.revealStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - revealStartBeatBucket, 0)
        let revealedCount: Int = {
            guard elapsedBeatBuckets >= 0 else { return 0 }
            return elapsedBeatBuckets + 1
        }()
        let clampedRevealCount = min(max(revealedCount, 0), beginnerCurrentScaleNotes.count)

        if clampedRevealCount != beginnerRuntime.pentatonicRevealCount {
            beginnerRuntime.pentatonicRevealCount = clampedRevealCount
        }

        if clampedRevealCount >= beginnerCurrentScaleNotes.count {
            beginnerRuntime.roundOneIntroActive = false
            beginnerRuntime.roundOneSequenceStartDate = nil
            beginnerRuntime.revealStartBeatBucket = nil
            beginnerRuntime.introStartBeatBucket = nil
            beginnerRuntime.showRoundZeroIntroSequence = false
            beginnerRuntime.answerBoxReady = true
        }
    }

    private func updateNoteRevealProgressionIfNeeded() {
        guard layoutMode == .beginner,
              lessonStyle == .sequential,
              !isCodeScreensaverMode,
              !startupSequenceActivated
        else { return }

        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        if beginnerRuntime.revealStartBeatBucket == nil {
            beginnerRuntime.revealStartBeatBucket = currentBeatBucket
        }
        let startBucket = beginnerRuntime.revealStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - startBucket, 0)
        let clampedRevealCount = min(elapsedBeatBuckets + 1, GameConstants.maxRevealCount)

        if clampedRevealCount != beginnerRuntime.revealCount {
            beginnerRuntime.revealCount = clampedRevealCount
        }
        if clampedRevealCount >= GameConstants.maxRevealCount {
            beginnerRuntime.answerBoxReady = true
        }
        if elapsedBeatBuckets >= GameConstants.maxRevealCount {
            beginnerRuntime.roundOneIntroActive = false
            beginnerRuntime.roundOneSequenceStartDate = nil
        }
    }

    private func handleBeginnerAutoPlayIfNeeded(currentDate: Date) {
        guard layoutMode == .beginner,
              beginnerRuntime.autoPlayEnabled,
              !isCodeScreensaverMode,
              !startupSequenceActivated,
              !beginnerRuntime.isResolvingAnswer,
              !beginnerRuntime.pendingRewardStageAdvance,
              beginnerRuntime.pendingRoundShiftBeatPosition == nil
        else {
            if layoutMode != .beginner || !beginnerRuntime.autoPlayEnabled {
                beginnerRuntime.autoPlayNextDate = nil
            }
            return
        }

        let fret = max(beginnerRuntime.currentRound, 0)

        if lessonStyle == .sequential {
            guard beginnerRuntime.revealCount >= GameConstants.maxRevealCount else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let revealElapsed = Int(floor(beginnerRuntime.roundRevealElapsedBeats)) - (beginnerRuntime.revealStartBeatBucket ?? Int(floor(beginnerRuntime.roundRevealElapsedBeats)))
            guard revealElapsed >= GameConstants.maxRevealCount + 1 else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            guard !currentGenerator.isSequenceComplete() else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let idx = currentGenerator.sequenceProgressIndex
            guard let nextString = currentGenerator.expectedString,
                  currentGenerator.currentNoteSequence.indices.contains(idx)
            else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let nextNote = currentGenerator.currentNoteSequence[idx]
            if beginnerRuntime.autoPlayNextDate == nil {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(GameConstants.autoPlayInterval)
                return
            }
            guard let nextDate = beginnerRuntime.autoPlayNextDate, currentDate >= nextDate else { return }
            let buttonIndex = nextString >= 4 ? (nextString - 4) : (6 - nextString)
            beginnerRuntime.isAutoPlayTriggered = true
            handleBeginnerConsoleButtonPress(selectedNote: nextNote, selectedString: nextString, buttonIndex: buttonIndex)
            beginnerRuntime.isAutoPlayTriggered = false
            beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(GameConstants.autoPlayInterval)
            return
        } else {
            // Chord style: existing behavior
            guard lessonStyle == .chord,
                  !beginnerRuntime.roundOneIntroActive,
                  beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count,
                  !beginnerCurrentScaleNotes.isEmpty
            else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let safeSequenceIndex = min(max(beginnerRuntime.scaleSequenceIndex, 0), beginnerCurrentScaleNotes.count - 1)
            if safeSequenceIndex != beginnerRuntime.scaleSequenceIndex {
                beginnerRuntime.scaleSequenceIndex = safeSequenceIndex
            }
            let expectedNote = beginnerCurrentScaleNotes[safeSequenceIndex]

            if beginnerRuntime.autoPlayNextDate == nil {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
                return
            }
            guard let nextDate = beginnerRuntime.autoPlayNextDate, currentDate >= nextDate else { return }
            let preferredStringOrder = beginnerAutoPlayPreferredStringOrder(for: expectedNote)
            let matchedString = preferredStringOrder.first {
                guitarNoteName(forString: $0, fret: fret, useFlats: false) == expectedNote
            } ?? preferredStringOrder.first {
                guitarNoteName(forString: $0, fret: fret, useFlats: beginnerUsesFlats) == expectedNote
            }
            guard let selectedString = matchedString else {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
                return
            }
            beginnerRuntime.autoPlayLastStringByNote[expectedNote] = selectedString
            let buttonIndex = selectedString <= 3 ? (6 - selectedString) : (selectedString - 4)
            beginnerRuntime.isAutoPlayTriggered = true
            handleBeginnerConsoleButtonPress(selectedNote: expectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
            beginnerRuntime.isAutoPlayTriggered = false
            beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
        }
    }

    private func beginnerAutoPlayPreferredStringOrder(for expectedNote: String) -> [Int] {
        let lowToHigh = [6, 5, 4, 3, 2, 1]
        let highToLow = [1, 2, 3, 4, 5, 6]
        let stageTitle = beginnerCurrentScaleStage.title.uppercased()
        let stageTokens = stageTitle.split(separator: " ")
        let stageRoot = stageTokens.first.map(String.init) ?? ""

        if stageTitle.hasPrefix("G ") && expectedNote == "E" {
            return highToLow
        }

        let isFinalNoteInStage = beginnerRuntime.scaleSequenceIndex == max(beginnerCurrentScaleNotes.count - 1, 0)
        if stageTitle.contains("MINOR PENTATONIC")
            && !stageRoot.isEmpty
            && expectedNote == stageRoot
            && isFinalNoteInStage {
            return highToLow
        }

        // Force alternation between string 1 and 6 for notes that appear on both
        if let lastString = beginnerRuntime.autoPlayLastStringByNote[expectedNote] {
            if lastString == 6 { return highToLow }
            if lastString == 1 { return lowToHigh }
        }

        return lowToHigh
    }

    func submitAnswer(_ side: AnswerSide, force: Bool = false) {
        if layoutMode == .beginner && beginnerRuntime.isRoundArmed {
            handleRoundStartButton()
            return
        }
        if layoutMode == .beginner && isRoundPaused {
            return
        }
        if isCodeScreensaverMode {
            if !startupSequenceActivated {
                startupSequenceActivated = true
                startupSequenceStartDate = .now
                startupSequenceElapsed = 0
                startupSpeechPhase = layoutMode == .beginner ? .pendingArmed : .pendingSystem
                beginnerRuntime.questionBoxIntroProgress = 0
                return
            }

            let startupState = StartupSequenceView.state(
                for: startupSequenceElapsed,
                showFullSequence: layoutMode != .beginner,
                armedText: beginnerStartupArmedText
            )
            guard startupState.phase == .armed else { return }
            guard !isLaunchTransitionAnimating else { return }

            isLaunchTransitionAnimating = true
            startupNeckVisualsHidden = true
            launchTileScale = 1
            launchTileOpacity = 1
            withAnimation(.easeIn(duration: 0.4725)) {
                launchTileScale = 0.1
                launchTileOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4725) {
                isCodeScreensaverMode = false
                startupSequenceActivated = false
                startupSequenceElapsed = 0
                startupSpeechPhase = .idle
                startGameFromBeginning(animateNeckSlideFromStartup: true)
                isLaunchTransitionAnimating = false
                launchTileScale = 1
                launchTileOpacity = 1
                withAnimation(.easeOut(duration: 0.6)) {
                    beginnerRuntime.questionBoxIntroProgress = 1
                }
            }
            return
        }

        if isRoundPaused {
            return
        }

        if layoutMode == .beginner {
            return
        }

        guard force || !beginnerRuntime.isResolvingAnswer else { return }
        beginnerRuntime.isResolvingAnswer = true
        beatQuestionDeadline = nil
        playCurrentPromptedGuitarNotes(velocity: force ? 0.82 : 0.94)

        let isCorrect = side == beginnerRuntime.correctAnswerSide
        if isCorrect {
            if side == .left {
                leftThumbState = .green
            } else {
                rightThumbState = .green
            }
            beginnerRuntime.activeAnswerFeedback = .green
            beginnerRuntime.lastResolvedCorrectNote = beginnerRuntime.currentCorrectNote
            beginnerRuntime.lastResolvedCorrectString = beginnerRuntime.currentPromptStrings.first
        } else {
            if side == .left {
                leftThumbState = .red
            } else {
                rightThumbState = .red
            }
            beginnerRuntime.activeAnswerFeedback = .red
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            leftThumbState = .neutral
            rightThumbState = .neutral
            questionBoxAssistActive = false
            if isCorrect {
                beginnerRuntime.isResolvingAnswer = false
                advanceGame(afterCorrectAnswer: true)
            } else {
                advanceGame(afterCorrectAnswer: false)
            }
        }
    }

    private func advanceGame(afterCorrectAnswer isCorrect: Bool) {
        if !isCorrect {
            beginnerRuntime.isResolvingAnswer = false
            prepareCurrentQuestion()
            return
        }

        // Skip point earning for autoplay
        guard !beginnerRuntime.isAutoPlayTriggered else {
            prepareCurrentQuestion()
            return
        }

        beginnerRuntime.correctAnswersAtCurrentFret = min(beginnerRuntime.correctAnswersAtCurrentFret + 1, 20)
        let payout = payoutForRound(beginnerRuntime.currentRound)
        beginnerRuntime.bankDollars += payout
        beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
        walletDollars = beginnerRuntime.bankDollars
        balanceDollars += payout

        if layoutMode == .beginner {
            if beginnerRuntime.isDescendingPhase {
                let requiredCorrectAnswers = effectivePlayRepetitions
                let completedAtCurrentFret = beginnerRuntime.correctAnswersAtCurrentFret

                if completedAtCurrentFret >= requiredCorrectAnswers {
                    beginnerRuntime.correctAnswersAtCurrentFret = 0
                    // Reset repetitions for the new chord after this note completes
                    // This will be set in the advance logic, not here

                    if beginnerRoundTwoStartsDescending {
                        if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                            beginnerRuntime.currentRound -= 1
                            prepareCurrentQuestion()
                        } else {
                            startGameFromBeginning()
                            return
                        }
                    } else {
                        if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                            beginnerRuntime.currentRound += 1
                            beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                            prepareCurrentQuestion()
                        } else {
                            startGameFromBeginning()
                            return
                        }
                    }
                    
                    // Reset repetitions for the new chord
                    beginnerRuntime.scaleRepetitionsRemaining = requiredCorrectAnswers
                } else {
                    beginnerRuntime.scaleRepetitionsRemaining = max(requiredCorrectAnswers - completedAtCurrentFret, 1)
                }
            }

            prepareCurrentQuestion()
            return
        }

        if roundStringIndex < activeStringOrder.count - 1 {
            roundStringIndex += 1
        } else {
            roundStringIndex = 0
            if !beginnerRuntime.isDescendingPhase {
                if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                    beginnerRuntime.currentRound += 1
                    beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                } else {
                    startGameFromBeginning()
                    return
                }
            } else {
                if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                    beginnerRuntime.currentRound -= 1
                    beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                } else {
                    startGameFromBeginning()
                    return
                }
            }
        }
    }
    
        
    private func prepareCurrentQuestion() {
        if lessonStyle == .sequential {
        // Sequential style: use SequentialNoteGenerator
        let idx = sequentialNoteGenerator.sequenceProgressIndex
        guard idx < sequentialNoteGenerator.currentNoteSequence.count,
              let nextString = sequentialNoteGenerator.expectedString else { return }
        let correctNote = sequentialNoteGenerator.currentNoteSequence[idx]
        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        let incorrectNote = randomIncorrectNote(excluding: correctNote, useFlats: useFlats)
        let correctOnLeft = Bool.random()
        if correctOnLeft {
            beginnerRuntime.leftChoiceNote = correctNote
            beginnerRuntime.rightChoiceNote = incorrectNote
        } else {
            beginnerRuntime.leftChoiceNote = incorrectNote
            beginnerRuntime.rightChoiceNote = correctNote
        }
        beginnerRuntime.correctAnswerSide = correctOnLeft ? .left : .right
        beginnerRuntime.currentPromptStrings = [nextString]
        beginnerRuntime.lastPromptedCorrectNote = correctNote
        beginnerRuntime.lastPromptedStringHalf = .left
        beginnerRuntime.lastPromptedStringNumber = nextString
        withAnimation(.easeInOut(duration: 1.3)) {
            beginnerRuntime.currentFretStart = max(beginnerRuntime.currentRound, 0)
        }
        } else {
        // Chord style: existing behavior
        let fret = max(beginnerRuntime.currentRound, 0)
        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        let targetString = activeStringOrder.isEmpty ? 1 : activeStringOrder.randomElement() ?? 1
        let correctNote = guitarNoteName(forString: targetString, fret: fret, useFlats: useFlats)
        let incorrectNote = randomIncorrectNote(excluding: correctNote, useFlats: useFlats)
        let correctOnLeft = Bool.random()

        if correctOnLeft {
            beginnerRuntime.leftChoiceNote = correctNote
            beginnerRuntime.rightChoiceNote = incorrectNote
        } else {
            beginnerRuntime.leftChoiceNote = incorrectNote
            beginnerRuntime.rightChoiceNote = correctNote
        }

        beginnerRuntime.currentPromptStrings = [targetString]
        beginnerRuntime.lastPromptedCorrectNote = correctNote
        withAnimation(.easeInOut(duration: 1.3)) {
            beginnerRuntime.currentFretStart = fret
        }
    }
}

    private func payoutForRound(_ round: Int) -> Int {
        _ = round
        return 1
    }


    private func randomIncorrectNote(excluding correct: String, useFlats: Bool) -> String {
        let source = useFlats ? chromaticFlats : chromaticSharps
        let pool = source.filter { $0 != correct }
        return pool.randomElement() ?? "C"
    }

    private func textWidth(for text: String, font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return ceil(text.size(withAttributes: attributes).width)
    }

    // handleGameplayMenuSelection, handleHintButtonPress, handleAudioPageDismiss
    // — moved to BeginnerGameplayLogic.swift (Step 4a)

    // developerConsoleFrame — moved to BeginnerSubviews.swift

    private func handleStartupSpeech(for phase: StartupSequenceView.Phase) {
        guard audioEngineEnabled else { return }
        switch phase {
        case .systemOnline:
            if startupSpeechPhase == .pendingSystem {
                gameplayAudioEngine.speakStartupAlert("SYSTEM ONLINE", volume: stringVolume)
                startupSpeechPhase = .pendingPhase
            }
        case .phaseOne:
            if startupSpeechPhase == .pendingPhase {
                gameplayAudioEngine.speakStartupAlert("PHASE ONE", volume: stringVolume)
                startupSpeechPhase = .pendingArmed
            }
        case .armed:
            if startupSpeechPhase == .pendingArmed {
                gameplayAudioEngine.speakStartupAlert(layoutMode == .beginner ? beginnerStartupArmedText : "MEMORIZATION SEQUENCE ARMED", volume: stringVolume)
                startupSpeechPhase = .idle
            }
        }
    }

    // maestroThumbOverlay — moved to BeginnerSubviews.swift

    // transportButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonState — moved to BeginnerSubviews.swift

    func handleBeginnerConsoleButtonPress(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard layoutMode == .beginner else { return }
        if beginnerRuntime.isRoundArmed {
            handleRoundStartButton()
            return
        }
        if isCodeScreensaverMode {
            submitAnswer(.left)
            return
        }

        let canAdvanceBeginnerProgression = !beginnerRuntime.isResolvingAnswer
            && !beginnerRuntime.pendingRewardStageAdvance
            && !beginnerRuntime.roundOneIntroActive

        if lessonStyle == .sequential {
            // In sequential mode, only commit the string to the visible answered set
            // after correctness is confirmed — handled inside handleBeginnerRoundOneProgressionIfNeeded.
            // Keep beginnerRuntime.activePickedStringNumbers to already-answered strings only.
            beginnerRuntime.activePickedStringNumbers = Array(beginnerRuntime.answeredNotesByStringAtCurrentFret.keys)
        } else {
            beginnerRuntime.activePickedStringNumbers = [selectedString]
        }
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.lastPickedNote = lessonStyle == .sequential ? nil : selectedNote
        // Non-sequential: track immediately. Sequential: deferred to success path below.
        if lessonStyle != .sequential {
            beginnerRuntime.answeredNotesByStringAtCurrentFret[selectedString] = selectedNote
        }
        beginnerRuntime.answerBoxReady = true
        beginnerRuntime.activeAnswerFeedback = nil
        questionBoxAssistActive = false

        guard canAdvanceBeginnerProgression else {
            playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
            return
        }

        if lessonStyle == .sequential {
            handleBeginnerRoundOneProgressionIfNeeded(selectedNote: selectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
        } else if lessonStyle == .chord {
            handleBeginnerChordProgressionIfNeeded(selectedNote: selectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
        }

        playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
    }

    private func handleBeginnerRoundOneProgressionIfNeeded(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard lessonStyle == .sequential else { return }

        // Sequential style: check against sequential note sequence
        guard !sequentialNoteGenerator.currentNoteSequence.isEmpty else { return }
        guard !sequentialNoteGenerator.isSequenceComplete() else { return }

        // Validate: note must match AND must not reuse an already-played string for that note
        guard sequentialNoteGenerator.isValidAnswer(note: selectedNote, string: selectedString) else {
            // Wrong answer — restart the sequence so all notes light up again from the top
            let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
            sequentialNoteGenerator.resetForNewFret()
            sequentialNoteGenerator.generateNoteSequence(
                for: max(beginnerRuntime.currentRound, 0),
                useFlats: useFlats,
                lowToHigh: isProgressionLowToHigh
            )
            beginnerRuntime.sequentialRevealCount = 0
            beginnerRuntime.sequentialRevealStartBeatBucket = nil
            beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            beginnerRuntime.activePickedStringNumbers = []
            beginnerRuntime.lastPickedNote = nil
            beginnerRuntime.answerBoxReady = false
            return
        }

        // Correct answer — commit to answered set and show the box
        beginnerRuntime.answeredNotesByStringAtCurrentFret[selectedString] = selectedNote
        beginnerRuntime.activePickedStringNumbers = Array(beginnerRuntime.answeredNotesByStringAtCurrentFret.keys)
        beginnerRuntime.lastPickedNote = selectedNote

        // Light up the button
        beginnerPressedButtonIndex = buttonIndex
        beginnerPressedButtonCorrect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            beginnerPressedButtonIndex = nil
            beginnerPressedButtonCorrect = false
        }
        if !beginnerRuntime.isAutoPlayTriggered {
            let payout = payoutForRound(beginnerRuntime.currentRound)
            beginnerRuntime.bankDollars += payout
            beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
            walletDollars = beginnerRuntime.bankDollars
            balanceDollars += payout
        }
        sequentialNoteGenerator.advanceSequence()

        if sequentialNoteGenerator.isSequenceComplete() {
            if beginnerRuntime.scaleRepetitionsRemaining <= 1 {
                if beginnerRuntime.pendingRoundShiftBeatPosition == nil {
                    beginnerRuntime.pendingRoundShiftBeatPosition = beginnerRuntime.roundRevealElapsedBeats + 2.0
                }
            } else {
                beginnerRuntime.scaleRepetitionsRemaining -= 1
                beginnerRuntime.pendingSequentialRepeatDisplayText = sequentialNoteGenerator.currentNoteSequence
                    .map(guitarNoteDisplayText)
                    .joined(separator: " ")
                beginnerRuntime.pendingSequentialRepeatResetBeatPosition = beginnerRuntime.roundRevealElapsedBeats + 2.0
            }
        }

        return
    }

    private func handleBeginnerChordProgressionIfNeeded(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard lessonStyle == .chord,
              beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count
        else { return }

        let currentScaleNotes = beginnerCurrentScaleNotes
        guard !currentScaleNotes.isEmpty else { return }

        let safeSequenceIndex = min(max(beginnerRuntime.scaleSequenceIndex, 0), currentScaleNotes.count - 1)
        if safeSequenceIndex != beginnerRuntime.scaleSequenceIndex {
            beginnerRuntime.scaleSequenceIndex = safeSequenceIndex
        }

        let expectedNote = currentScaleNotes[safeSequenceIndex]
        if selectedNote == expectedNote {
            beginnerPressedButtonIndex = buttonIndex
            beginnerPressedButtonCorrect = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                beginnerPressedButtonIndex = nil
                beginnerPressedButtonCorrect = false
            }
            if !beginnerRuntime.isAutoPlayTriggered {
                let payout = payoutForRound(beginnerRuntime.currentRound)
                beginnerRuntime.bankDollars += payout
                beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
                walletDollars = beginnerRuntime.bankDollars
                balanceDollars += payout
            }
            if safeSequenceIndex == currentScaleNotes.count - 1 {
                if let rewardPolicy = beginnerRewardPolicyForCurrentStage() {
                    playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
                    scheduleBeginnerRewardChordThenAdvance(selectedString: selectedString, policy: rewardPolicy)
                } else {
                    playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
                    scheduleBeginnerAdvanceAfterFinalNoteHold(selectedString: selectedString)
                }
                return
            } else {
                beginnerRuntime.scaleSequenceIndex += 1
            }
        } else {
            beginnerPressedButtonIndex = buttonIndex
            beginnerPressedButtonCorrect = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                beginnerPressedButtonIndex = nil
                beginnerPressedButtonCorrect = false
            }
            beginnerRuntime.scaleSequenceIndex = (selectedNote == currentScaleNotes[0]) ? 1 : 0
        }
    }

    private func playCurrentPromptedGuitarNotes(velocity: Float) {
        let fret = max(beginnerRuntime.currentRound, 0)
        let promptStrings = beginnerRuntime.currentPromptStrings.isEmpty ? [1] : beginnerRuntime.currentPromptStrings
        for (index, stringNumber) in promptStrings.enumerated() {
            let delay = Double(index) * 0.035
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playGuitarNote(forString: stringNumber, fret: fret, velocity: velocity)
            }
        }
    }

    private func playGuitarNote(forString stringNumber: Int, fret: Int, velocity: Float) {
        guitarNoteEngine.play(string: stringNumber, fret: max(fret, 0), velocity: velocity)
    }

    func syncBackingTrackPlayback(allowResumeFromPause: Bool = false) {
        guard !availableBackingTracks.isEmpty else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
        guard backingTrackShouldPlayInGameplay else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        guard !beginnerRuntime.transportStoppedForResume else {
            isBackingTrackPlaying = false
            return
        }

        guard let selectedTrackID = audioSettings.selectedBackingTrackID,
              let selectedTrack = availableBackingTracks.first(where: { $0.id == selectedTrackID }),
              let trackURL = selectedTrack.resourceURL() else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        applyBeginnerBassTransposeForCurrentStage()
        
        // If allowed and same track was paused, resume from that position
        if allowResumeFromPause {
            midiEngine.resume()
            isBackingTrackPlaying = midiEngine.isPlaying
            return
        }

        // Skip restart if the same URL is already playing — avoids mid-beat click
        if midiEngine.isPlaying, midiEngine.activeURL == trackURL {
            isBackingTrackPlaying = true
            return
        }

        midiEngine.play(url: trackURL, title: selectedTrack.title, loop: true)
        isBackingTrackPlaying = midiEngine.isPlaying
    }

    // handleFretboardButtonPress, handleRoundStartButton, handleStartButtonPress,
    // handleRoundStopButton, resumeRoundFromTransportStop, handleRoundResetButton
    // — moved to BeginnerGameplayLogic.swift (Step 4a)

    func postponeBeatDeadlineForAssist() {
        guard !isCodeScreensaverMode, modeVariant == .beat else { return }
        let bpm = Double(max(beatBPM, 60))
        beatQuestionDeadline = .now.addingTimeInterval(max(1.0, 120.0 / bpm))
    }

    func showDeveloperPrompt(_ text: String) {
        developerPromptText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if developerPromptText == text {
                developerPromptText = ""
            }
        }
    }

    // MARK: - Private Helper Methods
    
    private func midiNoteValue(forNote note: String) -> Int? {
        let noteToMIDI: [String: Int] = [
            "C": 60, "C#": 61, "Db": 61,
            "D": 62, "D#": 63, "Eb": 63,
            "E": 64,
            "F": 65, "F#": 66, "Gb": 66,
            "G": 67, "G#": 68, "Ab": 68,
            "A": 69, "A#": 70, "Bb": 70,
            "B": 71
        ]
        return noteToMIDI[note]
    }
}

