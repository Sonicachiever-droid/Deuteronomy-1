//
//  LandscapeMaestroGameplayView.swift
//  Exodus 11
//

import SwiftUI
import AVFoundation

struct LandscapeMaestroGameplayView: View {
    let onMenuSelection: ((GameplayMenuOption) -> Void)?
    let selectedMode: RefretMode
    let selectedPhase: Int
    let beatBPM: Int
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

    @State private var currentRound: Int = 0
    @State private var leftThumbState: ThumbGlowState = .neutral
    @State private var rightThumbState: ThumbGlowState = .neutral
    @State private var currentCorrectNote: String = ""
    @State private var leftChoiceNote: String = ""
    @State private var rightChoiceNote: String = ""
    @State private var correctAnswerSide: AnswerSide = .left
    @State private var bankDollars: Int = 0
    @State private var displayedBankDollars: Int = 0
    @State private var autoPlayEnabled: Bool = false
    @State private var isRoundPaused: Bool = false
    @State private var gameplayMenuExpanded: Bool = false
    @State private var isCodeScreensaverMode: Bool = true
    @State private var startupSequenceActivated: Bool = false
    @State private var startupSequenceElapsed: TimeInterval = 0
    
    private let midiEngine = SimpleMIDIEngine()
    
    init(onMenuSelection: ((GameplayMenuOption) -> Void)? = nil,
         selectedMode: RefretMode = .freestyle,
         selectedPhase: Int = 1,
         beatBPM: Int = 100,
         beatVolume: Double = 0.5,
         stringVolume: Double = 0.8,
         playStartingFret: Binding<Int>,
         playRepetitions: Binding<Int>,
         playInfiniteRepetitions: Binding<Bool>,
         playDirectionRawValue: Binding<String>,
         playEnableHighFrets: Binding<Bool>,
         playLessonStyle: Binding<String>,
         playProgression: Binding<String>,
         walletDollars: Binding<Int>,
         balanceDollars: Binding<Int>) {
        self.onMenuSelection = onMenuSelection
        self.selectedMode = selectedMode
        self.selectedPhase = selectedPhase
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
    }
    
    var body: some View {
        GeometryReader { proxy in
            let totalFrets = 20
            let scaleLengthInches = 25.5
            let padding: CGFloat = 24
            let fretRatios = FretMath.fretPositionRatios(totalFrets: totalFrets, scaleLength: scaleLengthInches)
            let visibleFrets = 5
            let visibleRatio = max(fretRatios[min(visibleFrets, fretRatios.count - 1)], 0.05)
            // In portrait: gridRowHeight = screenHeight/8, window = 2 rows tall, neckWidth = screenWidth*0.8
            // In landscape the screen is rotated — use proxy.size.height (short side) as the portrait "width"
            // and proxy.size.width (long side) as the portrait "height"
            let portraitWidth = proxy.size.height  // short side = portrait width
            let portraitHeight = proxy.size.width  // long side = portrait height
            let gridRowHeight = portraitHeight / 8.0
            let neckWidth = (portraitWidth - padding * 2) * 0.8
            let highlightHeight = 2 * gridRowHeight
            let highlightTopY = 1 * gridRowHeight
            let highlightCenterY = portraitHeight / 2  // center on screen
            let visibleClipHeight = portraitWidth * 0.96
            let unclippedHeight = visibleClipHeight / visibleRatio
            let neckHeight = max(unclippedHeight, portraitWidth * 1.35)
            let nutHeight = max(neckHeight * 0.02, 18)
            let nutVisualHeight = nutHeight * 0.4
            let highlightWidth = neckWidth
            let highlightCornerRadius = min(24, highlightWidth * 0.08)
            let screenCenterY = proxy.size.height / 2
            let screenCenterX = proxy.size.width / 2
            let neckOffsetY = screenCenterY - neckHeight / 2
            let stringTopY = screenCenterY - highlightHeight / 2 - gridRowHeight * 0.1

            ZStack {
                FullScreenElephantBackground()
                    .ignoresSafeArea()

                // Neck behind the window
                HStack {
                    Spacer()
                    ZStack(alignment: .top) {
                        ZStack {
                            RosewoodSegmentedBackground(fretRatios: fretRatios, cornerRadius: 18)
                            BindingLayer()
                            FretWireLayer(fretRatios: fretRatios)
                            FretMarkerLayer(fretRatios: fretRatios)
                        }
                        .frame(width: neckWidth, height: neckHeight)

                        NutLayer(width: neckWidth * 0.99, height: nutVisualHeight)
                            .frame(width: neckWidth * 0.99, height: nutVisualHeight)
                            .offset(y: -nutVisualHeight * 0.85)
                    }
                    .frame(width: neckWidth, height: neckHeight)
                    .offset(y: neckOffsetY)
                    .frame(width: neckWidth, height: visibleClipHeight)
                    .clipped()
                    Spacer()
                }
                .padding(.horizontal, padding)

                // String lines
                StringLineOverlay(neckWidth: neckWidth, horizontalPadding: (proxy.size.width - neckWidth) / 2, stringTopY: stringTopY)

                // Elephant overlay with hole cut out + gold window border
                ElephantWindowView(
                    canvasSize: proxy.size,
                    highlightWidth: highlightWidth,
                    highlightHeight: highlightHeight,
                    highlightCenter: CGPoint(x: screenCenterX, y: screenCenterY),
                    highlightCornerRadius: highlightCornerRadius
                )
                .allowsHitTesting(false)

                // Refret logo in window (screensaver style)
                ZStack {
                    Image("REFRETLOGOSET")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(x: 1.15, y: 1.0, anchor: .center)
                        .frame(width: highlightWidth, height: highlightHeight)
                        .clipped()
                        .clipShape(HighlightWindowShape(cornerRadius: highlightCornerRadius))

                    HighlightWindowGoldBorder(width: highlightWidth, height: highlightHeight, cornerRadius: highlightCornerRadius)
                }
                .position(x: screenCenterX, y: screenCenterY)
                .allowsHitTesting(false)

                // Developer console above neck window
                // Use a fixed fraction of screen height — independent of gridRowHeight
                let windowHalfH = proxy.size.height * 0.28  // approx half the visible neck window height
                let consoleHeight: CGFloat = 74
                let consoleBottomGap: CGFloat = 10
                let rawConsoleCenterY = screenCenterY - windowHalfH - consoleBottomGap - consoleHeight / 2
                let consoleCenterY = max(rawConsoleCenterY, consoleHeight / 2 + 8)

                LandscapeDevConsoleFrame(
                    width: highlightWidth,
                    height: consoleHeight,
                    isScreensaverMode: isCodeScreensaverMode,
                    scaleRepetitionText: "\(currentRound + 1)X",
                    currentRoundInPhase: currentRound + 1,
                    bankText: "$\(displayedBankDollars)",
                    repetitionCountColor: .white,
                    startupElapsed: startupSequenceElapsed,
                    showStartupSequence: startupSequenceActivated
                )
                .position(x: screenCenterX, y: consoleCenterY)
                .allowsHitTesting(false)

                // Transport bar below neck window
                let windowHalfHBelow = proxy.size.height * 0.22
                let windowBottomY = screenCenterY + windowHalfHBelow
                let transportScale: CGFloat = 0.8
                let transportHeight: CGFloat = 40 * transportScale
                let transportGap: CGFloat = 6
                let transportCenterY = windowBottomY + transportGap + transportHeight / 2

                HStack(spacing: 6) {
                    Button("START") { handleMaestroStart() }
                        .frame(minWidth: 46, minHeight: 27, maxHeight: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.black.opacity(0.34), lineWidth: 1.0))
                        )
                    Button(isRoundPaused ? "RESUME" : "PAUSE") {
                        isRoundPaused ? handleMaestroStart() : handleMaestroStop()
                    }
                        .frame(minWidth: 46, minHeight: 27, maxHeight: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isRoundPaused ? Color.orange.opacity(0.85) : Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.black.opacity(0.34), lineWidth: 1.0))
                        )
                    Button("RESET") { handleMaestroReset() }
                        .frame(minWidth: 46, minHeight: 27, maxHeight: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.black.opacity(0.34), lineWidth: 1.0)
                        )
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.92))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.94, green: 0.82, blue: 0.53), Color(red: 0.78, green: 0.6, blue: 0.22), Color(red: 0.94, green: 0.82, blue: 0.53)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.26), lineWidth: 1.2))
                )
                .frame(width: highlightWidth * 0.72, height: transportHeight)
                .position(x: screenCenterX, y: transportCenterY)

                // Gold perimeter
                GoldPipingBorder(bottomInset: 0)

                // Debug grid
                debugGridOverlay(size: proxy.size, columns: 5, rows: 8)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                GameplayControlPlateShell(
                    isMenuExpanded: gameplayMenuExpanded,
                    isStartupInputLockActive: false,
                    isAutoplayActive: autoPlayEnabled,
                    onAutoplay: { autoPlayEnabled.toggle() },
                    onFretboard: { },
                    onToggleMenu: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            gameplayMenuExpanded.toggle()
                        }
                    },
                    onSelectMenuOption: { option in handleMenuSelection(option) }
                )
                .scaleEffect(0.8, anchor: .bottom)
                .frame(maxWidth: min((proxy.size.width - 24) * 0.88, 370))
                .padding(.bottom, 0)
            }
        }
    }
    
    private func landscapeContent(proxy: GeometryProxy) -> some View {
        let width = proxy.size.width
        let height = proxy.size.height
        let padding: CGFloat = 16
        
        let consoleWidth = width * 0.35
        let consoleHeight = height * 0.12
        let consoleY = padding + consoleHeight/2
        
        let neckWidth = width * 0.50
        let neckHeight = height * 0.55
        
        let thumbDiameter = min(width, height) * 0.13
        let thumbY = consoleY + consoleHeight/2 + thumbDiameter/2 + 10
        let leftThumbX = padding + thumbDiameter/2
        let rightThumbX = width - padding - thumbDiameter/2
        
        let noteWidth = thumbDiameter * 1.4
        let noteHeight = thumbDiameter * 0.35
        let noteY = thumbY + thumbDiameter * 0.6
        
        let transportY = consoleY + consoleHeight/2 + 25
        let panelWidth = (width - neckWidth) / 2 - padding * 2
        
        return ZStack {
            // Gold piping perimeter
            GoldHorizontalPipingLine(width: width)
                .position(x: width/2, y: padding)
            
            GoldHorizontalPipingLine(width: width)
                .position(x: width/2, y: height - padding)
            
            GoldVerticalPipingLine(height: height - padding * 2)
                .position(x: padding, y: height/2)
            
            GoldVerticalPipingLine(height: height - padding * 2)
                .position(x: width - padding, y: height/2)
            
            DeveloperConsoleFrame(
                text: "ROUND \(currentRound + 1) | $\(displayedBankDollars)",
                width: consoleWidth,
                height: consoleHeight
            )
            .position(x: width/2, y: consoleY)
            
            HStack(spacing: 12) {
                Button("START") { handleStart() }
                    .transportButtonStyle()
                Button(isRoundPaused ? "RESUME" : "PAUSE") { isRoundPaused.toggle() }
                    .transportButtonStyle()
                Button("RESET") { handleReset() }
                    .transportButtonStyle()
            }
            .position(x: width/2, y: transportY)
            
            landscapeFretboard(width: neckWidth, height: neckHeight)
                .position(x: width/2, y: height/2 + 10)
            
            controlPanel(width: panelWidth, height: neckHeight)
                .position(x: padding + panelWidth/2, y: height/2 + 10)
            
            controlPanel(width: panelWidth, height: neckHeight)
                .position(x: width - padding - panelWidth/2, y: height/2 + 10)
            
            Button(action: { submitAnswer(.left) }) {
                ThumbButtonView(diameter: thumbDiameter, label: "", state: leftThumbState)
            }
            .buttonStyle(.plain)
            .position(x: leftThumbX, y: thumbY)
            
            Button(action: { submitAnswer(.right) }) {
                ThumbButtonView(diameter: thumbDiameter, label: "", state: rightThumbState)
            }
            .buttonStyle(.plain)
            .position(x: rightThumbX, y: thumbY)
            
            NoteChoiceBox(text: leftChoiceNote, width: noteWidth, height: noteHeight, isDark: leftChoiceNote.contains("#"))
                .position(x: leftThumbX + thumbDiameter * 0.3, y: noteY)
            
            NoteChoiceBox(text: rightChoiceNote, width: noteWidth, height: noteHeight, isDark: rightChoiceNote.contains("#"))
                .position(x: rightThumbX - thumbDiameter * 0.3, y: noteY)
        }
        .onAppear {
            bankDollars = max(walletDollars, 0)
            displayedBankDollars = bankDollars
            currentRound = playStartingFret
            prepareNextQuestion()
        }
        .onDisappear {
            midiEngine.stop()
        }
    }
    
    private func controlPanel(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Toggle("AUTO", isOn: $autoPlayEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color.orange))
            Button("MENU") { handleMenuSelection(.home) }
        }
        .frame(width: width, height: height)
    }
    
    private func landscapeFretboard(width: CGFloat, height: CGFloat) -> some View {
        let fretRatios = FretMath.fretPositionRatios(totalFrets: 20, scaleLength: 25.5)
        return ZStack {
            RosewoodSegmentedBackground(fretRatios: fretRatios, cornerRadius: 12)
                .frame(width: width, height: height)
            StringLineOverlay(neckWidth: width, horizontalPadding: 0, stringTopY: height * 0.02)
        }
    }
    
    private func handleStart() { isRoundPaused = false; prepareNextQuestion() }
    private func handleReset() { currentRound = playStartingFret; bankDollars = max(walletDollars, 0); prepareNextQuestion() }
    private func handleMenuSelection(_ option: GameplayMenuOption) { onMenuSelection?(option) }

    private func handleMaestroStart() {
        isRoundPaused = false
        prepareNextQuestion()
    }

    private func handleMaestroStop() {
        isRoundPaused = true
    }

    private func handleMaestroReset() {
        isRoundPaused = false
        currentRound = playStartingFret
        bankDollars = max(walletDollars, 0)
        displayedBankDollars = bankDollars
        prepareNextQuestion()
    }
    
    private func submitAnswer(_ side: AnswerSide) {
        let isCorrect = side == correctAnswerSide
        if isCorrect {
            leftThumbState = .green; rightThumbState = .green; bankDollars += 1; prepareNextQuestion()
        } else {
            leftThumbState = side == .left ? .red : .neutral; rightThumbState = side == .right ? .red : .neutral
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { leftThumbState = .neutral; rightThumbState = .neutral }
    }
    
    private func prepareNextQuestion() {
        currentRound += 1
        let useFlats = false
        let targetString = Int.random(in: 1...6)
        let correctNote = noteName(forString: targetString, fret: currentRound, useFlats: useFlats)
        let incorrectNote = randomIncorrectNote(excluding: correctNote, useFlats: useFlats)
        let correctOnLeft = Bool.random()
        if correctOnLeft { leftChoiceNote = correctNote; rightChoiceNote = incorrectNote } else { leftChoiceNote = incorrectNote; rightChoiceNote = correctNote }
        correctAnswerSide = correctOnLeft ? .left : .right
    }
    
    private func noteName(forString string: Int, fret: Int, useFlats: Bool) -> String {
        let openNotes = ["E", "B", "G", "D", "A", "E"]
        let index = 6 - string
        guard index >= 0 && index < openNotes.count else { return "E" }
        let openNote = openNotes[index]
        let chromatic = useFlats ? chromaticFlats : chromaticSharps
        guard let noteIndex = chromatic.firstIndex(of: openNote) else { return "E" }
        return chromatic[(noteIndex + fret) % 12]
    }
    
    private func randomIncorrectNote(excluding correctNote: String, useFlats: Bool) -> String {
        let chromatic = useFlats ? chromaticFlats : chromaticSharps
        return chromatic.filter { $0 != correctNote }.randomElement() ?? "A"
    }
}

// MARK: - Startup Sequence View

private struct LandscapeMaestroStartupSequenceView: View {
    enum Phase { case armed }
    let elapsed: TimeInterval

    var body: some View {
        let state = LandscapeMaestroStartupSequenceView.state(for: elapsed)
        Text(state.text)
            .font(.system(size: 29.6, weight: .black, design: .monospaced))
            .foregroundStyle(state.color)
            .multilineTextAlignment(.center)
            .opacity(state.isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.08), value: state.isVisible)
    }

    static func state(for elapsed: TimeInterval) -> (text: String, color: Color, isVisible: Bool, phase: Phase) {
        let isVisible = Int(elapsed / 1.0).isMultiple(of: 2)
        return ("Memorization Sequence Armed", Color.green.opacity(0.98), isVisible, .armed)
    }
}

// MARK: - Developer Code Runner View

private struct LandscapeDevCodeRunnerView: View {
    @State private var startDate: Date = .now

    private struct RenderState {
        let renderedLines: [String]
        let lineHeight: CGFloat
        let offsetY: CGFloat
    }

    private static let sourceText: String = {
        if let text = try? String(contentsOfFile: #filePath, encoding: .utf8), !text.isEmpty {
            return text
        }
        return "import SwiftUI\nstruct LandscapeMaestroGameplayView: View {\n    var body: some View {\n        Text(\"Loading Source\")\n    }\n}"
    }()

    private static let lines: [String] = {
        let split = sourceText.components(separatedBy: .newlines)
        return split.isEmpty ? ["// source unavailable"] : split
    }()

    private static let charsPerSecond: Double = 42
    private static let postLineHold: Double = 0.12
    private static let lineHeight: CGFloat = 14
    private static let loopPause: Double = 0.9
    private static let lineDurations: [Double] = lines.map { max(Double($0.count) / charsPerSecond, 0.02) + postLineHold }
    private static let cumulativeDurations: [Double] = lineDurations.reduce(into: []) { partial, duration in
        partial.append((partial.last ?? 0) + duration)
    }
    private static let typingDuration: Double = lineDurations.reduce(0, +)
    private static let cycleDuration: Double = max(typingDuration + loopPause, 0.1)

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 0.03)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                let state = makeRenderState(elapsed: elapsed, viewportHeight: geo.size.height)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(state.renderedLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color(for: index))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: state.lineHeight, maxHeight: state.lineHeight, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: state.offsetY)
                .clipped()
            }
        }
    }

    private func makeRenderState(elapsed: TimeInterval, viewportHeight: CGFloat) -> RenderState {
        let cycleElapsed = elapsed.truncatingRemainder(dividingBy: Self.cycleDuration)
        let activeLine: Int = {
            if cycleElapsed >= Self.typingDuration { return max(Self.lines.count - 1, 0) }
            return Self.cumulativeDurations.firstIndex(where: { cycleElapsed <= $0 }) ?? max(Self.lines.count - 1, 0)
        }()
        let elapsedIntoLine: Double = {
            if cycleElapsed >= Self.typingDuration { return Self.lineDurations.last ?? 0 }
            let previousTotal = activeLine > 0 ? Self.cumulativeDurations[activeLine - 1] : 0
            return max(cycleElapsed - previousTotal, 0)
        }()
        let currentLineDuration = Self.lineDurations.isEmpty ? 1 : Self.lineDurations[activeLine]
        let typingWindow = max(currentLineDuration - Self.postLineHold, 0.02)
        let typedChars = min(Int(max(elapsedIntoLine, 0) * Self.charsPerSecond), Self.lines[activeLine].count)
        var renderedLines: [String] = []
        if activeLine > 0 { renderedLines.append(contentsOf: Self.lines.prefix(activeLine)) }
        let activeText = String(Self.lines[activeLine].prefix(max(typedChars, 0)))
        let showCursor = cycleElapsed < Self.typingDuration && elapsedIntoLine <= typingWindow
        renderedLines.append(activeText + (showCursor ? "▋" : ""))
        let typedProgress = min(max((elapsedIntoLine / currentLineDuration), 0), 1)
        let contentOffset = (CGFloat(activeLine) + CGFloat(typedProgress)) * Self.lineHeight
        let baselineY = viewportHeight - Self.lineHeight
        return RenderState(renderedLines: renderedLines, lineHeight: Self.lineHeight, offsetY: baselineY - contentOffset)
    }

    private func color(for index: Int) -> Color {
        let palette: [Color] = [.orange, .cyan, .mint, .pink, .yellow, .green]
        return palette[index % palette.count].opacity(0.95)
    }
}

// MARK: - Developer Console Frame

private struct LandscapeDevConsoleFrame: View {
    let width: CGFloat
    let height: CGFloat
    let isScreensaverMode: Bool
    let scaleRepetitionText: String
    let currentRoundInPhase: Int
    let bankText: String
    let repetitionCountColor: Color
    let startupElapsed: TimeInterval
    let showStartupSequence: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.18, green: 0.18, blue: 0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.65), lineWidth: 3)
                .padding(3)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.82, blue: 0.47), Color(red: 0.78, green: 0.6, blue: 0.22), Color(red: 0.97, green: 0.85, blue: 0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .padding(1.5)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.96), Color(red: 0.07, green: 0.07, blue: 0.08), Color.black.opacity(0.96)],
                    startPoint: .top, endPoint: .bottom
                ))
                .padding(4)
                .overlay {
                    Group {
                        if isScreensaverMode {
                            ZStack {
                                if !showStartupSequence {
                                    LandscapeDevCodeRunnerView()
                                        .padding(.horizontal, 12)
                                        .padding(.top, 24)
                                        .padding(.bottom, 10)
                                }
                                if showStartupSequence {
                                    LandscapeMaestroStartupSequenceView(elapsed: startupElapsed)
                                        .padding(.horizontal, 10)
                                        .padding(.top, 24)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                }
                            }
                        } else {
                            HStack {
                                Text(scaleRepetitionText)
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundStyle(repetitionCountColor)
                                Spacer()
                                Text("Round \(currentRoundInPhase)")
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Text(bankText)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.green.opacity(0.96))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                        }
                    }
                }
                .padding(4)
        }
        .frame(width: width, height: height)
    }
}

extension View {
    func transportButtonStyle() -> some View {
        self.font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(minWidth: 58, minHeight: 34, maxHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.black.opacity(0.34), lineWidth: 1.0)
            )
    }
    
    func controlButtonStyle() -> some View {
        self.font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.82, blue: 0.53))
                    .stroke(Color.black.opacity(0.26), lineWidth: 1.0)
            )
    }
}
