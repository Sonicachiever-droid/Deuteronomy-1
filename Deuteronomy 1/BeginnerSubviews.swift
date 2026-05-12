import SwiftUI

// MARK: - White Note Box Overlay
// Answer boxes shown above each guitar string at the active fret.

struct WhiteNoteBoxOverlay: View {
    let centerY: CGFloat
    let availableSize: CGSize
    let boxHeight: CGFloat
    let neckWidth: CGFloat
    let activeStringNumbers: [Int]
    let answerFeedback: ThumbGlowState?
    let revealedNoteText: String?
    let revealedNoteTextByString: [Int: String]?
    let revealedNoteTextColor: Color

    var body: some View {
        let totalStrings = GuitarStringLayout.totalStrings
        let stratNutWidthInches: CGFloat = GuitarConstants.stratNutWidth
        let stratStringSpanInches: CGFloat = GuitarConstants.stratStringSpan
        let clampedBoxHeight = min(boxHeight, availableSize.height)
        let nutWidth = neckWidth * GuitarConstants.nutWidthRatio
        let overallWidth = availableSize.width
        let overallPadding = (overallWidth - nutWidth) / 2
        let widthPerInch = nutWidth / stratNutWidthInches
        let interStringSpacing = (stratStringSpanInches / CGFloat(totalStrings - 1)) * widthPerInch
        let edgeMargin = ((stratNutWidthInches - stratStringSpanInches) / 2) * widthPerInch
        let grooveCenters = (0..<totalStrings).map { index in
            overallPadding + edgeMargin + CGFloat(index) * interStringSpacing
        }
        let minCenterSpacing = grooveCenters.enumerated().dropFirst().map { idx, center in
            center - grooveCenters[idx - 1]
        }.min() ?? interStringSpacing
        let spacingGap = max(minCenterSpacing * GuitarConstants.stringGapMultiplier, 6)
        let maxBoxWidthFromSpacing = max(minCenterSpacing - spacingGap, 0)
        let boxWidth = min(clampedBoxHeight * 1.8, maxBoxWidthFromSpacing)
        let activeSet = Set(activeStringNumbers)
        return ZStack {
            // Six individual translucent backgrounds for each answer box
            ForEach(0..<totalStrings, id: \.self) { index in
                let stringNumber = totalStrings - index
                let isActive = activeSet.contains(stringNumber)
                RoundedRectangle(cornerRadius: UIConstants.answerBoxRadius, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                    .frame(width: boxWidth, height: clampedBoxHeight)
                    .opacity(isActive ? 1 : 0.0001)
                    .position(x: grooveCenters[index], y: centerY)
            }

            ForEach(0..<totalStrings, id: \.self) { index in
                let stringNumber = totalStrings - index
                let isActive = activeSet.contains(stringNumber)
                let displayedNoteText = revealedNoteTextByString?[stringNumber] ?? revealedNoteText
                let displayText = displayedNoteText.map(guitarNoteDisplayText)
                let noteIsAccidental = displayedNoteText.map(guitarNoteContainsAccidental) ?? false
                let shouldUseAccidentalStyle = noteIsAccidental
                let fillColor: Color = {
                    guard isActive else { return Color.clear }
                    switch answerFeedback {
                    case .green:
                        return Color.feedbackGreenFill.opacity(0.95)
                    case .red:
                        return Color.feedbackRedFill.opacity(0.95)
                    default:
                        return shouldUseAccidentalStyle ? Color.black.opacity(0.95) : Color.white.opacity(0.92)
                    }
                }()
                let strokeColor: Color = {
                    guard isActive else { return .clear }
                    switch answerFeedback {
                    case .green:
                        return Color.feedbackGreenStroke.opacity(0.9)
                    case .red:
                        return Color.feedbackRedStroke.opacity(0.9)
                    default:
                        return shouldUseAccidentalStyle ? Color.white.opacity(0.86) : Color.black.opacity(0.72)
                    }
                }()

                RoundedRectangle(cornerRadius: UIConstants.answerBoxRadius, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.answerBoxRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: 2)
                    )
                    .frame(width: boxWidth, height: clampedBoxHeight)
                    .overlay {
                        if isActive, let displayText, !displayText.isEmpty {
                            Text(displayText)
                                .font(.system(size: min(clampedBoxHeight * 0.72, 26), weight: .black, design: .monospaced))
                                .minimumScaleFactor(0.32)
                                .lineLimit(1)
                                .foregroundStyle(shouldUseAccidentalStyle ? Color.white.opacity(0.96) : revealedNoteTextColor)
                                .padding(.horizontal, 1)
                        }
                    }
                    .opacity(isActive ? 1 : 0.0001)
                    .position(x: grooveCenters[index], y: centerY)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: activeStringNumbers)
        .animation(.easeInOut(duration: 0.18), value: answerFeedback)
    }
}

// MARK: - Startup Sequence View
// Flashing CRT startup text shown in the dev console during the arm sequence.

struct StartupSequenceView: View {
    enum Phase {
        case systemOnline
        case phaseOne
        case armed
    }

    let elapsed: TimeInterval
    let showFullSequence: Bool
    let armedText: String

    init(elapsed: TimeInterval, showFullSequence: Bool = true, armedText: String = "Memorization Sequence Armed") {
        self.elapsed = elapsed
        self.showFullSequence = showFullSequence
        self.armedText = armedText
    }

    var body: some View {
        let state = Self.state(for: elapsed, showFullSequence: showFullSequence, armedText: armedText)
        let fontSize: CGFloat = state.phase == .armed ? 29.6 : 34
        let fontWeight: Font.Weight = .black

        Text(state.text)
            .font(.system(size: fontSize, weight: fontWeight, design: .monospaced))
            .foregroundStyle(state.color)
            .minimumScaleFactor(0.3)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: state.color.opacity(0.95), radius: 14, x: 0, y: 0)
            .shadow(color: state.color.opacity(0.6), radius: 26, x: 0, y: 0)
            .opacity(state.isVisible ? 1 : 0)
    }

    static func state(for elapsed: TimeInterval, showFullSequence: Bool = true, armedText: String = "Memorization Sequence Armed") -> (text: String, color: Color, isVisible: Bool, phase: Phase) {
        let firstFlashPeriod: TimeInterval = 1.0
        let secondFlashPeriod: TimeInterval = 1.0
        let armedFlashPeriod: TimeInterval = 1.0
        let firstBlockDuration = firstFlashPeriod * 4
        let secondBlockDuration = firstBlockDuration + (secondFlashPeriod * 4)

        if !showFullSequence {
            let isVisible = Int(elapsed / armedFlashPeriod).isMultiple(of: 2)
            return (armedText, Color.green.opacity(0.98), isVisible, .armed)
        }

        if elapsed < firstBlockDuration {
            let isVisible = Int(elapsed / firstFlashPeriod).isMultiple(of: 2)
            return ("SYSTEM ONLINE", Color.orange.opacity(0.98), isVisible, .systemOnline)
        }

        if elapsed < secondBlockDuration {
            let localElapsed = elapsed - firstBlockDuration
            let isVisible = Int(localElapsed / secondFlashPeriod).isMultiple(of: 2)
            return ("PHASE 1", Color.red.opacity(0.98), isVisible, .phaseOne)
        }

        let localElapsed = elapsed - secondBlockDuration
        let isVisible = Int(localElapsed / armedFlashPeriod).isMultiple(of: 2)
        return (armedText, Color.green.opacity(0.98), isVisible, .armed)
    }
}
