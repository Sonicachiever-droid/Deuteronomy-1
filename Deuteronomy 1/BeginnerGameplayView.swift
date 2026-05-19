import SwiftUI
import Combine
import AVFoundation

// MARK: - Types and components from extracted files
// Types.swift contains: GameplayMenuOption, RefretMode, GameplayModeVariant, AnswerSide, LayoutMode, BeginnerCoursePhase, BeginnerRoundZeroIntroDisplayPhase, HighlightWindowShape, FretMath, GuitarStringLayout, baselineNutTargetY, resolvedNeckTopY
// ViewComponents.swift contains: StringLineOverlay, MiniTVFrame, ThumbButtonView
// BeginnerSubviews.swift contains: WhiteNoteBoxOverlay, StartupSequenceView, + BeginnerGameplayView extension (fretIndicatorOverlay, beatPulseOverlay, developerConsoleFrame, maestroThumbOverlay, transportButtonPanelOverlay, beginnerButtonPanelOverlay, beginnerButtonState)
// DeveloperViews.swift contains: DeveloperCodeRunnerView, DeveloperConsoleFrame, DeveloperTVStreakMeterView


struct BeginnerGameplayView: View {
    // MARK: - External bindings / configuration (passed in from parent)
    let onMenuSelection: ((GameplayMenuOption) -> Void)?
    let selectedMode: RefretMode
    let beatVolume: Double
    let stringVolume: Double
    @Binding var playStartingFret: Int
    @Binding var playRepetitions: Int
    @Binding var playInfiniteRepetitions: Bool
    @Binding var playDirectionRawValue: String
    @Binding var playEnableHighFrets: Bool
    @Binding var playLessonStyle: String
    @Binding var playProgression: String
    @Binding var walletDollars: Int
    @Binding var balanceDollars: Int
    let consoleSkin: ConsoleSkin
    @AppStorage("numbers3.runtime.directionLockActive") var directionLockActive: Bool = false

    @Environment(\.displayScale) private var displayScale

    // MARK: - Engine (owns all gameplay state and logic)
    @State var engine: BeginnerGameEngine

    // MARK: - View-only state not owned by the engine
    @State var beatPulseActive: Bool = false

    // MARK: - Constants
    let layoutMode: LayoutMode = .beginner
    let totalFrets: Int = 20
    var maxFretOffset: Int { totalFrets }
    var minFretOffset: Int { -totalFrets }
    let codenameNemoEnabled: Bool = false
    private let scaleLengthInches: Double = 25.5
    private let debugGridRows: Int = 8
    private var maxWindowRow: Int { (debugGridRows - 1) * 2 }

    // MARK: - Forwarding properties to engine (view body + BeginnerSubviews read these by name)

    var beginnerRuntime: BeginnerGameState { engine.state }
    var audioSettings: AudioSettings {
        get { engine.audioSettings }
        nonmutating set { engine.audioSettings = newValue }
    }
    var showAudioPage: Bool {
        get { engine.showAudioPage }
        nonmutating set { engine.showAudioPage = newValue }
    }
    var availableBackingTracks: [BackingTrack] { engine.availableBackingTracks }
    var leftThumbState: ThumbGlowState { engine.leftThumbState }
    var rightThumbState: ThumbGlowState { engine.rightThumbState }
    var beginnerPressedButtonIndex: Int? { engine.beginnerPressedButtonIndex }
    var beginnerPressedButtonCorrect: Bool { engine.beginnerPressedButtonCorrect }
    var roundStringIndex: Int { engine.roundStringIndex }
    var introWindowBlack: Bool { engine.introWindowBlack }
    var introDidRun: Bool { engine.introDidRun }
    var isCodeScreensaverMode: Bool { engine.isCodeScreensaverMode }
    var startupSequenceStartDate: Date { engine.startupSequenceStartDate }
    var startupSequenceElapsed: TimeInterval { engine.startupSequenceElapsed }
    var startupSequenceActivated: Bool { engine.startupSequenceActivated }
    var assetToNutBottomDelta: CGFloat? { engine.assetToNutBottomDelta }
    var questionBoxAssistActive: Bool { engine.questionBoxAssistActive }
    var gameplayMenuExpanded: Bool { engine.gameplayMenuExpanded }
    var developerPromptText: String { engine.developerPromptText }
    var beatQuestionDeadline: Date? { engine.beatQuestionDeadline }
    var showFretboardGuide: Bool { engine.showFretboardGuide }
    var isRoundPaused: Bool { engine.isRoundPaused }
    var isBackingTrackPlaying: Bool { engine.isBackingTrackPlaying }
    var isLaunchTransitionAnimating: Bool { engine.isLaunchTransitionAnimating }
    var launchTileScale: CGFloat { engine.launchTileScale }
    var launchTileOpacity: Double { engine.launchTileOpacity }
    var startupNeckVisualsHidden: Bool { engine.startupNeckVisualsHidden }
    var startupStartButtonBlinkOn: Bool { engine.startupStartButtonBlinkOn }
    var startupStartButtonNextBlinkDate: Date? { engine.startupStartButtonNextBlinkDate }

    // StartupSpeechPhase is declared on BeginnerGameEngine — forward via typealias
    typealias StartupSpeechPhase = BeginnerGameEngine.StartupSpeechPhase
    var startupSpeechPhase: BeginnerGameEngine.StartupSpeechPhase { engine.startupSpeechPhase }

    // Audio objects — forward to engine
    var guitarNoteEngine: GuitarNotePlaying { engine.audio.guitarNoteEngine }
    var midiEngine: BackingTrackPlaying { engine.audio.midiEngine }
    var audioEngineEnabled: Bool { engine.audioEngineEnabled }
    let speakBeatTicks: Bool = false
    let speakGameplayPrompts: Bool = false

    // Note generators — forward to engine
    var sequentialNoteGenerator: SequentialNoteGenerator { engine.sequentialNoteGenerator }
    var chordGenerator: ChordGenerator { engine.chordGenerator }
    var currentGenerator: any NoteSequenceGenerator { engine.currentGenerator }

    // Computed properties that delegate to engine
    var beatBPM: Int { engine.beatBPM }
    var lessonStyle: LessonStyle { LessonStyle(rawValue: playLessonStyle) ?? .sequential }
    var modeVariant: GameplayModeVariant { engine.modeVariant }
    var isPhaseDescending: Bool { engine.isPhaseDescending }
    var showMaestroOverlays: Bool { layoutMode == .maestro }
    var isProgressionLowToHigh: Bool { engine.isProgressionLowToHigh }
    var activeStringOrder: [Int] { engine.activeStringOrder }

    // Engine-owned helpers also used by BeginnerSubviews extension
    var beginnerStartupArmedText: String { engine.beginnerStartupArmedText }
    var beginnerCurrentScaleNotes: [String] { engine.beginnerCurrentScaleNotes }
    var beginnerUsesFlats: Bool { engine.beginnerUsesFlats }
    var chordNoteStringMap: [Int] { engine.chordNoteStringMap }
    var beginnerRoundStatusText: String? { engine.beginnerRoundStatusText }
    var beginnerCenteredStatusMessage: String? { engine.beginnerCenteredStatusMessage }
    var canPressStopButton: Bool { engine.canPressStopButton }
    var startupStartButtonAttentionActive: Bool { engine.startupStartButtonAttentionActive }

    func getWalletColor() -> Color { engine.getWalletColor() }
    func getRepetitionCountColor() -> Color { engine.getRepetitionCountColor() }
    func textWidth(for text: String, font: UIFont) -> CGFloat { engine.textWidth(for: text, font: font) }
    func guitarNoteName(forString stringNumber: Int, fret: Int, useFlats: Bool) -> String {
        Deuteronomy_1.guitarNoteName(forString: stringNumber, fret: fret, useFlats: useFlats)
    }
    func guitarNoteDisplayText(_ note: String) -> String {
        Deuteronomy_1.guitarNoteDisplayText(note)
    }
    func guitarNoteContainsAccidental(_ note: String) -> Bool {
        Deuteronomy_1.guitarNoteContainsAccidental(note)
    }
    func submitAnswer(_ side: AnswerSide, force: Bool = false) { engine.submitAnswer(side, force: force) }
    func handleStartButtonPress() { engine.handleStartButtonPress() }
    func handleRoundStopButton() { engine.handleRoundStopButton() }
    func handleRoundResetButton() { engine.handleRoundResetButton() }
    func resumeRoundFromTransportStop(forceIfPaused: Bool = false) { engine.resumeRoundFromTransportStop(forceIfPaused: forceIfPaused) }
    func handleBeginnerConsoleButtonPress(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        engine.handleBeginnerConsoleButtonPress(selectedNote: selectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
    }

    private func syncAndStartEngine() {
        engine.onMenuSelection = onMenuSelection
        engine.lessonStyle = LessonStyle(rawValue: playLessonStyle) ?? .sequential
        engine.playRepetitions = playRepetitions
        engine.playInfiniteRepetitions = playInfiniteRepetitions
        engine.playStartingFret = playStartingFret
        engine.playDirectionRawValue = playDirectionRawValue
        engine.playEnableHighFrets = playEnableHighFrets
        engine.playProgression = playProgression
        engine.walletDollars = walletDollars
        engine.balanceDollars = balanceDollars
        engine.handleContentOnAppear()
    }

    // MARK: - Init

    init(
        onMenuSelection: ((GameplayMenuOption) -> Void)? = nil,
        selectedMode: RefretMode = .freestyle,
        beatVolume: Double = 0.8,
        stringVolume: Double = 0.8,
        playStartingFret: Binding<Int> = .constant(0),
        playRepetitions: Binding<Int> = .constant(5),
        playInfiniteRepetitions: Binding<Bool> = .constant(false),
        playDirectionRawValue: Binding<String> = .constant(LessonDirection.ascending.rawValue),
        playEnableHighFrets: Binding<Bool> = .constant(false),
        playLessonStyle: Binding<String> = .constant("sequential"),
        playProgression: Binding<String> = .constant("highToLow"),
        walletDollars: Binding<Int> = .constant(0),
        balanceDollars: Binding<Int> = .constant(0),
        consoleSkin: ConsoleSkin = .classic
    ) {
        self.onMenuSelection = onMenuSelection
        self.selectedMode = selectedMode
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
        let audio = AudioDependencies(
            guitarNoteEngine: SharedAudioEngine.shared,
            midiEngine: SharedAudioEngine.shared,
            gameplayAudioEngine: SpeechEngine()
        )
        self._engine = State(initialValue: BeginnerGameEngine(
            audio: audio,
            selectedMode: selectedMode,
            lessonStyle: LessonStyle(rawValue: playLessonStyle.wrappedValue) ?? .sequential,
            playRepetitions: playRepetitions.wrappedValue,
            playInfiniteRepetitions: playInfiniteRepetitions.wrappedValue,
            playStartingFret: playStartingFret.wrappedValue,
            playDirectionRawValue: playDirectionRawValue.wrappedValue,
            playEnableHighFrets: playEnableHighFrets.wrappedValue,
            playProgression: playProgression.wrappedValue,
            beatVolume: beatVolume,
            stringVolume: stringVolume,
            audioEngineEnabled: false,
            consoleSkin: consoleSkin,
            walletDollars: walletDollars.wrappedValue
        ))
    }

    var body: some View {
        GeometryReader { proxy in bodyContent(proxy: proxy) }
    }

    @ViewBuilder
    func bodyContent(proxy: GeometryProxy) -> some View {
        let g = BeginnerLayout(proxy: proxy, view: self)
        ZStack {
            buildLayout(g, proxy: proxy)
            lifecycleModifiersA()
            lifecycleModifiersB()
        }
    }

    // MARK: - Layout geometry struct (keeps let-bindings out of @ViewBuilder context)

    private struct BeginnerLayout {
        let padding: CGFloat
        let neckWidth: CGFloat
        let fretRatios: [CGFloat]
        let visibleClipHeight: CGFloat
        let neckHeight: CGFloat
        let nutVisualHeight: CGFloat
        let gridRowHeight: CGFloat
        let globalContentShiftY: CGFloat
        let rowOneBottomLineY: CGFloat
        let highlightHeight: CGFloat
        let highlightTopGridLineY: CGFloat
        let highlightCenterYSnapped: CGFloat
        let pipingCenterY: CGFloat
        let orangeGreenUnitCenterY: CGFloat
        let holeCenterY: CGFloat
        let highlightWidth: CGFloat
        let highlightCornerRadius: CGFloat
        let displayedFretStatusLabel: String
        let displayedStringStatusLabel: String
        let screenBannerWidth: CGFloat
        let screenBannerHeight: CGFloat
        let lowerScreenWidth: CGFloat
        let lowerScreenHeight: CGFloat
        let thumbDiameter: CGFloat
        let buttonCenterY: CGFloat
        let screenPairSpacing: CGFloat
        let windowBottomY: CGFloat
        let topScreenY: CGFloat
        let leftAnswerCenterX: CGFloat
        let rightAnswerCenterX: CGFloat
        let buttonTopY: CGFloat
        let buttonBottomY: CGFloat
        let upperWhitePipingY: CGFloat
        let lowerWhitePipingY: CGFloat
        let whitePipingWidth: CGFloat
        let noteChoiceY: CGFloat
        let topStatusOuterWidth: CGFloat
        let topStatusOuterHeight: CGFloat
        let topStatusCenterY: CGFloat
        let leftFretIndicatorX: CGFloat
        let rightFretIndicatorX: CGFloat
        let fretIndicatorText: String
        let finalNeckOffsetY: CGFloat
        let stringTopY: CGFloat
        let startupState: (text: String, color: Color, isVisible: Bool, phase: StartupSequenceView.Phase)
        let effectiveLeftThumbState: ThumbGlowState
        let effectiveRightThumbState: ThumbGlowState
        let initialGameplayDimOpacity: CGFloat
        let transportCenterY: CGFloat

        init(proxy: GeometryProxy, view: BeginnerGameplayView) {
            let scale = view.displayScale
            padding = 24
            neckWidth = (proxy.size.width - padding * 2) * 0.8
            fretRatios = FretMath.fretPositionRatios(totalFrets: view.totalFrets, scaleLength: 25.5)
            let visibleFrets = min(view.totalFrets, 5)
            let visibleFretIndex = min(visibleFrets, fretRatios.count - 1)
            let visibleRatio = max(fretRatios[visibleFretIndex], 0.05)
            visibleClipHeight = proxy.size.height * 0.96
            let unclippedHeight = visibleClipHeight / visibleRatio
            let minimumNeckHeight = proxy.size.height * 1.35
            neckHeight = max(unclippedHeight, minimumNeckHeight)
            let nutHeight = max(neckHeight * 0.02, 18)
            nutVisualHeight = nutHeight * 0.4
            let debugGridRows: CGFloat = 8
            gridRowHeight = proxy.size.height / debugGridRows
            globalContentShiftY = gridRowHeight * 0.25
            rowOneBottomLineY = gridRowHeight
            highlightHeight = 2 * gridRowHeight
            let lockedWindowTopRowIndex: CGFloat = 1.0
            highlightTopGridLineY = lockedWindowTopRowIndex * gridRowHeight
            let rawHighlightCenter = highlightTopGridLineY + highlightHeight / 2
            highlightCenterYSnapped = (rawHighlightCenter * scale).rounded() / scale
            let viewingWindowShiftY: CGFloat = gridRowHeight * 0.5
            pipingCenterY = highlightCenterYSnapped + viewingWindowShiftY
            orangeGreenUnitCenterY = pipingCenterY - (gridRowHeight * 0.5)
            holeCenterY = highlightCenterYSnapped
            let highlightAvailableWidth = max(proxy.size.width - padding * 2, 0)
            let highlightExtraWidth = max(highlightAvailableWidth - neckWidth, 0)
            highlightWidth = neckWidth + highlightExtraWidth / 2
            highlightCornerRadius = min(24, highlightWidth * 0.08)
            let currentTargetString = view.activeStringOrder[min(max(view.roundStringIndex, 0), view.activeStringOrder.count - 1)]
            let promptStrings = view.beginnerRuntime.currentPromptStrings.isEmpty ? [currentTargetString] : view.beginnerRuntime.currentPromptStrings
            let fretStatusLabel = "FRET \(view.beginnerRuntime.currentRound)"
            let stringStatusLabel = promptStrings.count > 1
                ? "STRINGS \(promptStrings.map(String.init).joined(separator: "+"))"
                : "STRING \(promptStrings[0])"
            let isGameplayStarted = !view.isCodeScreensaverMode
            displayedFretStatusLabel = isGameplayStarted ? fretStatusLabel : ""
            displayedStringStatusLabel = {
                if view.lessonStyle == .sequential { return "SEQUENTIAL MODE" }
                return isGameplayStarted ? stringStatusLabel : ""
            }()
            let screenBannerFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let screenMeasuredWidth = max(
                view.textWidth(for: fretStatusLabel, font: screenBannerFont),
                view.textWidth(for: stringStatusLabel, font: screenBannerFont),
                view.textWidth(for: "STRING 6", font: screenBannerFont)
            )
            screenBannerWidth = screenMeasuredWidth + 32
            screenBannerHeight = max(min(gridRowHeight * 0.72, 52), 44)
            lowerScreenWidth = screenBannerWidth * 0.5
            lowerScreenHeight = screenBannerHeight
            thumbDiameter = min(proxy.size.width, proxy.size.height) * 0.336
            let virtualRows: CGFloat = 40
            let vRowH: CGFloat = proxy.size.height / virtualRows
            buttonCenterY = (26 - 2.0) * vRowH
            screenPairSpacing = 16
            let buttonPairSpacing: CGFloat = 28
            windowBottomY = holeCenterY + highlightHeight / 2
            topScreenY = windowBottomY + screenBannerHeight * 0.72
            let halfButtonCenterGap = (thumbDiameter + buttonPairSpacing) / 2
            leftAnswerCenterX = (proxy.size.width / 2) - halfButtonCenterGap
            rightAnswerCenterX = (proxy.size.width / 2) + halfButtonCenterGap
            buttonTopY = buttonCenterY - (thumbDiameter / 2)
            buttonBottomY = buttonCenterY + (thumbDiameter / 2)
            let whitePipingGap = max(gridRowHeight * 0.32, 14)
            upperWhitePipingY = buttonTopY - whitePipingGap
            lowerWhitePipingY = buttonBottomY + whitePipingGap - (gridRowHeight * GuitarConstants.gridRowHeightRatio)
            whitePipingWidth = max(proxy.size.width - 7, 0)
            noteChoiceY = upperWhitePipingY - (lowerScreenHeight / 2) - 2
            let windowTopY = holeCenterY - highlightHeight / 2
            topStatusOuterWidth = highlightWidth
            topStatusOuterHeight = max(min(gridRowHeight * 1.35, 120), 74)
            let topStatusBottomGap = max(gridRowHeight * GuitarConstants.gridRowHeightRatio, 10)
            topStatusCenterY = (windowTopY - topStatusBottomGap) - (topStatusOuterHeight / 2)
            let sideWindowGap = max((proxy.size.width - highlightWidth) / 4, 18)
            leftFretIndicatorX = (proxy.size.width / 2) - (highlightWidth / 2) - sideWindowGap
            rightFretIndicatorX = (proxy.size.width / 2) + (highlightWidth / 2) + sideWindowGap
            fretIndicatorText = "\(max(view.beginnerRuntime.currentRound, 0))"
            let unsignedN = abs(view.beginnerRuntime.currentFretStart)
            let activeMidpointIndex: Int = view.beginnerRuntime.currentFretStart > 0
                ? max(view.beginnerRuntime.currentFretStart - 1, 0)
                : unsignedN
            let clampedN = min(activeMidpointIndex, fretRatios.count - 2)
            let topRatio = fretRatios[clampedN]
            let bottomRatio = fretRatios[clampedN + 1]
            let midRatio = (topRatio + bottomRatio) / 2.0
            let sign: CGFloat = view.beginnerRuntime.currentFretStart >= 0 ? 1.0 : -1.0
            let activeMidpoint = midRatio * neckHeight * sign
            let nutTargetY = baselineNutTargetY(highlightTopGridLineY: highlightTopGridLineY, gridRowHeight: gridRowHeight)
            let neckTopY = resolvedNeckTopY(
                currentFretStart: view.beginnerRuntime.currentFretStart,
                nutTargetY: nutTargetY,
                highlightCenterY: pipingCenterY,
                activeMidpoint: activeMidpoint
            )
            let rawNeckOffset: CGFloat
            if view.beginnerRuntime.currentFretStart == 0 {
                rawNeckOffset = (neckTopY - proxy.size.height / 2 + neckHeight / 2)
            } else {
                rawNeckOffset = (pipingCenterY - activeMidpoint - proxy.size.height / 2 + neckHeight / 2)
            }
            let neckOffsetY = (rawNeckOffset * scale).rounded() / scale
            let manualBlueAdjustment: CGFloat = -gridRowHeight * 0.5
            finalNeckOffsetY = neckOffsetY + manualBlueAdjustment
            let neckVisualOffsetAdjustment = finalNeckOffsetY - neckOffsetY
            let nutBottomY = neckTopY + neckVisualOffsetAdjustment + (nutVisualHeight * GuitarConstants.nutHeightOffset)
            let stringStopInset = max(1.0, 2.0 / max(scale, 1.0))
            stringTopY = nutBottomY + stringStopInset
            let computedStartupState: (text: String, color: Color, isVisible: Bool, phase: StartupSequenceView.Phase)
            if !view.startupSequenceActivated {
                computedStartupState = ("", .clear, false, .systemOnline)
            } else {
                computedStartupState = StartupSequenceView.state(
                    for: view.startupSequenceElapsed,
                    showFullSequence: view.layoutMode != .beginner,
                    armedText: view.layoutMode == .beginner ? view.beginnerStartupArmedText : "Memorization Sequence Armed"
                )
            }
            startupState = computedStartupState
            let screensaverGlowState: ThumbGlowState
            switch computedStartupState.phase {
            case .systemOnline: screensaverGlowState = computedStartupState.isVisible ? .orange : .neutral
            case .phaseOne: screensaverGlowState = computedStartupState.isVisible ? .red : .neutral
            case .armed: screensaverGlowState = computedStartupState.isVisible ? .green : .neutral
            }
            effectiveLeftThumbState = view.isCodeScreensaverMode ? screensaverGlowState : view.leftThumbState
            effectiveRightThumbState = view.isCodeScreensaverMode ? screensaverGlowState : view.rightThumbState
            initialGameplayDimOpacity = (view.isCodeScreensaverMode && !view.startupSequenceActivated) ? 0.42 : 1.0
            transportCenterY = buttonBottomY + (proxy.size.height - buttonBottomY) / 2 + 43
        }
    }

    @ViewBuilder
    private func buildLayout(_ g: BeginnerLayout, proxy: GeometryProxy) -> some View {
        ZStack {
                neckAndBackgroundLayer(
                    proxySize: proxy.size,
                    padding: g.padding,
                    neckWidth: g.neckWidth,
                    neckHeight: g.neckHeight,
                    nutVisualHeight: g.nutVisualHeight,
                    finalNeckOffsetY: g.finalNeckOffsetY,
                    visibleClipHeight: g.visibleClipHeight,
                    stringTopY: g.stringTopY,
                    highlightWidth: g.highlightWidth,
                    highlightHeight: g.highlightHeight,
                    highlightCornerRadius: g.highlightCornerRadius,
                    orangeGreenUnitCenterY: g.orangeGreenUnitCenterY,
                    pipingCenterY: g.pipingCenterY,
                    fretRatios: g.fretRatios
                )

                fretIndicatorOverlay(
                    leftX: g.leftFretIndicatorX,
                    rightX: g.rightFretIndicatorX,
                    centerY: g.orangeGreenUnitCenterY,
                    text: g.fretIndicatorText,
                    isHidden: isCodeScreensaverMode
                )

                if showFretboardGuide && !isCodeScreensaverMode {
                    let guideBoxHeight = g.topStatusOuterHeight * 0.5
                    let guideBoxWidth = g.neckWidth
                    let guideBoxCornerRadius = guideBoxHeight * 0.35
                    let guideBoxCenterY = g.windowBottomY - (guideBoxHeight / 2) - 4
                    let stringCenters = GuitarStringLayout.stringCenters(containerWidth: proxy.size.width, neckWidth: g.neckWidth)
                    let fretboardStrings = (0..<GuitarStringLayout.totalStrings).map { GuitarStringLayout.highestStringNumber - $0 }
                    let minGuideSpacing = zip(stringCenters.dropFirst(), stringCenters).map(-).min() ?? (guideBoxWidth / CGFloat(max(fretboardStrings.count, 1)))
                    let guideTileWidth = max(minGuideSpacing * 0.82, 18)
                    let guideTileHeight = guideBoxHeight * 0.86
                    ZStack {
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

                beatPulseOverlay(centerX: proxy.size.width / 2, centerY: g.topStatusCenterY, isHidden: isCodeScreensaverMode)

#if DEBUG
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: proxy.size.width / 2, y: g.holeCenterY)
                    .allowsHitTesting(false)
                    .opacity(0)
#endif

                developerConsoleFrame(
                    proxyWidth: proxy.size.width,
                    topStatusCenterY: g.topStatusCenterY,
                    topStatusOuterWidth: g.topStatusOuterWidth,
                    topStatusOuterHeight: g.topStatusOuterHeight
                )

                questionUILayer(
                    proxySize: proxy.size,
                    screenBannerWidth: g.screenBannerWidth,
                    screenBannerHeight: g.screenBannerHeight,
                    lowerScreenWidth: g.lowerScreenWidth,
                    lowerScreenHeight: g.lowerScreenHeight,
                    screenPairSpacing: g.screenPairSpacing,
                    topScreenY: g.topScreenY,
                    leftAnswerCenterX: g.leftAnswerCenterX,
                    rightAnswerCenterX: g.rightAnswerCenterX,
                    noteChoiceY: g.noteChoiceY,
                    orangeGreenUnitCenterY: g.orangeGreenUnitCenterY,
                    gridRowHeight: g.gridRowHeight,
                    neckWidth: g.neckWidth,
                    initialGameplayDimOpacity: g.initialGameplayDimOpacity,
                    displayedStringStatusLabel: g.displayedStringStatusLabel,
                    displayedFretStatusLabel: g.displayedFretStatusLabel
                )

                if consoleSkin != .tweed {
                    GoldHorizontalPipingLine(width: g.whitePipingWidth)
                        .position(x: proxy.size.width / 2, y: g.upperWhitePipingY)
                        .allowsHitTesting(false)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? 1 : 0))

                    GoldHorizontalPipingLine(width: g.whitePipingWidth)
                        .position(x: proxy.size.width / 2, y: g.lowerWhitePipingY)
                        .allowsHitTesting(false)
                        .opacity(codenameNemoEnabled ? 0 : (showMaestroOverlays ? 1 : 0))
                }

                if consoleSkin == .tweed {
                    WhitePipingBorder(bottomInset: 0)
                        .allowsHitTesting(false)
                        .offset(y: -g.globalContentShiftY)
                        .zIndex(100)
                } else {
                    GoldPipingBorder(bottomInset: 0)
                        .allowsHitTesting(false)
                        .offset(y: -g.globalContentShiftY)
                        .zIndex(100)
                }

                // Dedicated control layer with all components restored
                ZStack(alignment: .bottom) {
                    // Buttons (thumb + beginner panel)
                    maestroThumbOverlay(
                        proxyWidth: proxy.size.width,
                        buttonCenterY: g.buttonCenterY,
                        thumbDiameter: g.thumbDiameter,
                        leftThumbState: g.effectiveLeftThumbState,
                        rightThumbState: g.effectiveRightThumbState,
                        dimOpacity: g.initialGameplayDimOpacity
                    )
                    .zIndex(0)

                    if layoutMode == .beginner {
                        beginnerButtonPanelOverlay(
                            proxyWidth: proxy.size.width,
                            proxyHeight: proxy.size.height,
                            buttonCenterY: g.buttonCenterY,
                            lowerScreenHeight: g.lowerScreenHeight,
                            transportCenterY: g.transportCenterY,
                            dimOpacity: g.initialGameplayDimOpacity,
                            startupState: g.startupState
                        )
                        .zIndex(0)
                    }

                    // Transport
                    transportButtonPanelOverlay(
                        proxyWidth: proxy.size.width,
                        transportCenterY: g.transportCenterY,
                        startupState: g.startupState
                    )
                    .zIndex(1)

                    // Menu - always on top when expanded
                    GameplayControlPlateShell(
                        isMenuExpanded: engine.gameplayMenuExpanded,
                        isStartupInputLockActive: false,
                        isAutoplayActive: beginnerRuntime.autoPlayEnabled,
                        onAutoplay: {
                            beginnerRuntime.autoPlayEnabled.toggle()
                        },
                        onFretboard: {
                            engine.handleFretboardButtonPress()
                        },
                        onToggleMenu: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                engine.gameplayMenuExpanded.toggle()
                            }
                        },
                        onSelectMenuOption: { option in
                            engine.handleGameplayMenuSelection(option)
                        },
                        consoleSkin: consoleSkin
                    )
                    .frame(maxWidth: min((proxy.size.width - 24) * 0.88, 370))
                    .padding(.bottom, 12)
                    .zIndex(engine.gameplayMenuExpanded ? 2 : 0)
                }
            }
            .offset(y: g.globalContentShiftY)
    }

    // MARK: - Lifecycle modifiers (split to prevent type-checker timeout)

    @ViewBuilder
    private func lifecycleModifiersA() -> some View {
        Color.clear
            .allowsHitTesting(false)
            .onAppear(perform: syncAndStartEngine)
            .onDisappear { engine.audio.midiEngine.stop() }
            .sheet(isPresented: Bindable(engine).showAudioPage, onDismiss: engine.handleAudioPageDismiss) {
                AudioPageView(
                    audioSettings: engine.audioSettings,
                    availableBackingTracks: engine.availableBackingTracks,
                    onDone: { engine.showAudioPage = false }
                )
            }
            .onChange(of: engine.audioSettings.guitarTonePreset) { _, newValue in
                engine.audio.guitarNoteEngine.configure(preset: newValue, reverbLevel: engine.audioSettings.reverbLevel, delayLevel: engine.audioSettings.delayLevel)
            }
            .onChange(of: engine.audioSettings.reverbLevel) { _, newValue in
                engine.audio.guitarNoteEngine.configure(preset: engine.audioSettings.guitarTonePreset, reverbLevel: newValue, delayLevel: engine.audioSettings.delayLevel)
            }
            .onChange(of: engine.audioSettings.delayLevel) { _, newValue in
                engine.audio.guitarNoteEngine.configure(preset: engine.audioSettings.guitarTonePreset, reverbLevel: engine.audioSettings.reverbLevel, delayLevel: newValue)
            }
            .onChange(of: engine.audioSettings.guitarVolume) { _, newValue in engine.audio.guitarNoteEngine.setGuitarVolume(newValue) }
            .onChange(of: engine.audioSettings.backingTrackVolume) { _, newValue in engine.audio.midiEngine.setBackingTrackVolume(newValue) }
            .onChange(of: engine.audioSettings.selectedBackingTrackID) { _, _ in engine.syncBackingTrackPlayback() }
            .onChange(of: engine.audioSettings.selectedBackingArrangement) { _, _ in engine.syncBackingTrackPlayback() }
            .onChange(of: engine.state.scaleStageIndex) { _, _ in engine.applyBeginnerBassTransposeForCurrentStage() }
            .onChange(of: engine.state.scaleCycleSemitoneOffset) { _, _ in engine.applyBeginnerBassTransposeForCurrentStage() }
    }

    @ViewBuilder
    private func lifecycleModifiersB() -> some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: engine.isCodeScreensaverMode) { _, isScreensaverMode in
                engine.updateDirectionLockState()
                engine.syncBackingTrackPlayback()
                if isScreensaverMode {
                    engine.state.beatLightFlashOn = false
                    engine.state.beatLightLastProcessedBeat = nil
                    engine.state.beatLightIntroMeasureSkipped = false
                }
            }
            .onChange(of: engine.state.currentRound) { _, _ in
                engine.applyBeginnerBassTransposeForCurrentStage()
                engine.state.rewardNoteTextByString?.removeAll()
                engine.state.lastPickedNote = nil
            }
            .onChange(of: playRepetitions) { _, newValue in
                engine.playRepetitions = newValue
                guard layoutMode == .beginner else { return }
                if engine.state.isRoundArmed || engine.isRoundPaused {
                    engine.state.scaleRepetitionsRemaining = engine.beginnerTargetScaleRepetitionsRemaining()
                    return
                }
                engine.applyLivePlayRepetitionChangeIfNeeded()
            }
            .onChange(of: playInfiniteRepetitions) { _, newValue in engine.playInfiniteRepetitions = newValue }
            .onChange(of: playStartingFret) { _, newValue in engine.playStartingFret = newValue }
            .onChange(of: playDirectionRawValue) { _, newValue in engine.playDirectionRawValue = newValue }
            .onChange(of: playEnableHighFrets) { _, newValue in engine.playEnableHighFrets = newValue }
            .onChange(of: playLessonStyle) { _, newValue in engine.lessonStyle = LessonStyle(rawValue: newValue) ?? .sequential }
            .onChange(of: playProgression) { _, newValue in engine.playProgression = newValue }
            .onChange(of: engine.walletDollars) { _, newValue in walletDollars = newValue }
            .onChange(of: engine.balanceDollars) { _, newValue in balanceDollars = newValue }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { date in engine.handleMainTimerTick(date) }
            .onChange(of: engine.state.autoPlayEnabled) { _, isEnabled in
                if layoutMode != .beginner {
                    engine.state.autoPlayEnabled = false
                    engine.state.autoPlayNextDate = nil
                    return
                }
                guard isEnabled else { engine.state.autoPlayNextDate = nil; return }
                let revealReady = !engine.state.roundOneIntroActive
                    && engine.state.pentatonicRevealCount >= engine.beginnerCurrentScaleNotes.count
                engine.state.autoPlayNextDate = revealReady ? engine.nextOnAndThreeBeatDate(after: Date(), waitForDownbeat: true) : nil
            }
    }

    // shiftFretSpan, shiftWindow, nextThumbState, textWidth, handleStartupSpeech,
    // syncBackingTrackPlayback, postponeBeatDeadlineForAssist, showDeveloperPrompt, midiNoteValue
    // — moved to BeginnerGameplayLogic.swift (Step 5)

    // MARK: - Extracted view builders to reduce body complexity

    @ViewBuilder
    func neckAndBackgroundLayer(
        proxySize: CGSize,
        padding: CGFloat,
        neckWidth: CGFloat,
        neckHeight: CGFloat,
        nutVisualHeight: CGFloat,
        finalNeckOffsetY: CGFloat,
        visibleClipHeight: CGFloat,
        stringTopY: CGFloat,
        highlightWidth: CGFloat,
        highlightHeight: CGFloat,
        highlightCornerRadius: CGFloat,
        orangeGreenUnitCenterY: CGFloat,
        pipingCenterY: CGFloat,
        fretRatios: [CGFloat]
    ) -> some View {
        Group {
            if consoleSkin == .tweed {
                FullScreenTweedBackground()
                    .ignoresSafeArea()
                RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .frame(width: highlightWidth, height: highlightHeight)
                    .position(x: proxySize.width / 2, y: orangeGreenUnitCenterY)
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
                                MapleSegmentedBackground(fretRatios: fretRatios, cornerRadius: 18)
                            } else {
                                RosewoodSegmentedBackground(fretRatios: fretRatios, cornerRadius: 18)
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

            StringLineOverlay(neckWidth: neckWidth, horizontalPadding: padding, stringTopY: stringTopY)
                .opacity(startupNeckVisualsHidden ? 0 : 1)

            RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                .fill(Color.black)
                .frame(width: highlightWidth, height: highlightHeight)
                .position(x: proxySize.width / 2, y: pipingCenterY)
                .allowsHitTesting(false)
                .opacity(introWindowBlack ? 1 : 0)

            if consoleSkin == .tweed {
                TweedWindowView(canvasSize: proxySize, highlightWidth: highlightWidth, highlightHeight: highlightHeight,
                    highlightCenter: CGPoint(x: proxySize.width / 2, y: orangeGreenUnitCenterY), highlightCornerRadius: highlightCornerRadius)
                    .allowsHitTesting(false)
            } else {
                ElephantWindowView(canvasSize: proxySize, highlightWidth: highlightWidth, highlightHeight: highlightHeight,
                    highlightCenter: CGPoint(x: proxySize.width / 2, y: orangeGreenUnitCenterY), highlightCornerRadius: highlightCornerRadius)
                    .allowsHitTesting(false)
            }

            if isCodeScreensaverMode {
                ZStack {
                    if consoleSkin == .tweed {
                        Image("Refret tweed logo")
                            .resizable().scaledToFill()
                            .scaleEffect(x: 1.15, y: 1.0, anchor: .center)
                            .frame(width: highlightWidth, height: highlightHeight)
                            .clipped().clipShape(HighlightWindowShape(cornerRadius: highlightCornerRadius))
                        HighlightWindowChromeBorder(width: highlightWidth, height: highlightHeight, cornerRadius: highlightCornerRadius)
                    } else {
                        Image("REFRETLOGOSET")
                            .resizable().scaledToFill()
                            .scaleEffect(x: 1.15, y: 1.0, anchor: .center)
                            .frame(width: highlightWidth, height: highlightHeight)
                            .clipped().clipShape(HighlightWindowShape(cornerRadius: highlightCornerRadius))
                        HighlightWindowGoldBorder(width: highlightWidth, height: highlightHeight, cornerRadius: highlightCornerRadius)
                    }
                }
                .scaleEffect(isLaunchTransitionAnimating ? launchTileScale : 1)
                .opacity(isLaunchTransitionAnimating ? launchTileOpacity : 1)
                .position(x: proxySize.width / 2, y: orangeGreenUnitCenterY)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    func questionUILayer(
        proxySize: CGSize,
        screenBannerWidth: CGFloat,
        screenBannerHeight: CGFloat,
        lowerScreenWidth: CGFloat,
        lowerScreenHeight: CGFloat,
        screenPairSpacing: CGFloat,
        topScreenY: CGFloat,
        leftAnswerCenterX: CGFloat,
        rightAnswerCenterX: CGFloat,
        noteChoiceY: CGFloat,
        orangeGreenUnitCenterY: CGFloat,
        gridRowHeight: CGFloat,
        neckWidth: CGFloat,
        initialGameplayDimOpacity: CGFloat,
        displayedStringStatusLabel: String,
        displayedFretStatusLabel: String
    ) -> some View {
        let introProgress = beginnerRuntime.questionBoxIntroProgress
        let introScale: CGFloat = max(introProgress, 0.001)
        let introOffsetY = (1 - introProgress) * ((proxySize.height / 2) - topScreenY)
        let questionBoxOffsetY = (1 - introProgress) * ((proxySize.height / 2) - orangeGreenUnitCenterY)
        let shouldShowQuestionUI: Bool = !isCodeScreensaverMode && !startupSequenceActivated && introProgress > 0.0
        let hasBeginnerSelectedNote: Bool = !(beginnerRuntime.lastPickedNote?.isEmpty ?? true)
            || !(beginnerRuntime.rewardNoteTextByString?.isEmpty ?? true)
        let shouldShowWhiteAnswerBox: Bool = shouldShowQuestionUI && {
            if layoutMode != .beginner { return true }
            if hasBeginnerSelectedNote && beginnerRuntime.answerBoxReady { return true }
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
            .animation(.easeInOut(duration: 0.5), value: introProgress)
            .offset(y: introOffsetY)
            .frame(width: proxySize.width, height: screenBannerHeight)
            .position(x: proxySize.width / 2, y: topScreenY)
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
                    availableSize: proxySize,
                    boxHeight: gridRowHeight * 0.9,
                    neckWidth: neckWidth,
                    activeStringNumbers: beginnerRuntime.activePickedStringNumbers,
                    answerFeedback: beginnerRuntime.activeAnswerFeedback,
                    revealedNoteText: layoutMode == .beginner
                        ? (hasBeginnerSelectedNote ? beginnerRuntime.lastPickedNote : nil)
                        : (beginnerRuntime.activeAnswerFeedback == .green ? beginnerRuntime.currentCorrectNote : nil),
                    revealedNoteTextByString: layoutMode == .beginner
                        ? (beginnerRuntime.rewardNoteTextByString ?? beginnerRuntime.answeredNotesByStringAtCurrentFret)
                        : nil,
                    revealedNoteTextColor: Color.black.opacity(0.96)
                )
                .allowsHitTesting(false)
                .offset(y: questionBoxOffsetY)
                .opacity(codenameNemoEnabled ? 0 : initialGameplayDimOpacity)
            }
        }
    }
}

