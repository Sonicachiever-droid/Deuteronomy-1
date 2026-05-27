import SwiftUI

// MARK: - Overview / Guide Page (Learn to Play sheet)
// Layout for the welcome screen sheet. Text content lives in GuideContent.swift.
// The in-game GUIDE tab has its own layout in Deuteronomy_1App.swift (case .guide).

struct OverviewPageView: View {
    @Environment(\.dismiss) private var dismiss
    // When embedded inside the in-game menu NavigationView, no close button is needed.
    var showCloseButton: Bool = true

    var body: some View {
        ZStack {
            FullScreenElephantBackground()
                .ignoresSafeArea()

            Color.black.opacity(0.55)
                .ignoresSafeArea()

            GoldPipingBorder(bottomInset: 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    VStack(alignment: .center, spacing: 6) {
                        Text("ReFret")
                            .font(.system(size: 68, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
                            .tracking(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 15)

                    Divider()
                        .background(Color(red: 0.95, green: 0.82, blue: 0.47).opacity(0.5))

                    // WHAT IS THIS?
                    OverviewSection(title: "WHAT IS THIS?") {
                        Text(GuideContent.whatIsThis)
                    }

                    // TWO CONSOLES
                    OverviewSection(title: "TWO CONSOLES") {
                        VStack(alignment: .leading, spacing: 14) {
                            OverviewSubsection(title: "BEGINNER") {
                                Text(GuideContent.beginner)
                            }
                            OverviewSubsection(title: "MAESTRO") {
                                Text(GuideContent.maestro)
                            }
                        }
                    }

                    // LESSON STYLES
                    OverviewSection(title: "LESSON STYLES") {
                        VStack(alignment: .leading, spacing: 10) {
                            OverviewRow(label: "SEQUENTIAL", value: GuideContent.LessonStyles.sequential)
                            OverviewRow(label: "CHORD",      value: GuideContent.LessonStyles.chord)
                            OverviewRow(label: "SPEED RUN",  value: GuideContent.LessonStyles.speedRun)
                        }
                    }

                    // ROUNDS & FRETS
                    OverviewSection(title: "ROUNDS & FRETS") {
                        Text(GuideContent.roundsAndFrets)
                    }

                    // DIRECTION
                    OverviewSection(title: "DIRECTION") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(GuideContent.directionIntro)
                            OverviewRow(label: "ASCENDING",  value: GuideContent.ascending)
                            OverviewRow(label: "DESCENDING", value: GuideContent.descending)
                            Text(GuideContent.accidentals)
                        }
                    }

                    // PROGRESSION
                    OverviewSection(title: "PROGRESSION") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(GuideContent.progressionIntro)
                            OverviewRow(label: "HIGH → LOW", value: GuideContent.highToLow)
                            OverviewRow(label: "LOW → HIGH", value: GuideContent.lowToHigh)
                        }
                    }

                    // SCORING
                    OverviewSection(title: "SCORING") {
                        Text(GuideContent.scoring)
                    }

                    // CONTROL PANEL
                    OverviewSection(title: "CONTROL PANEL") {
                        VStack(alignment: .leading, spacing: 10) {
                            OverviewRow(label: "AUTOPLAY",  value: GuideContent.ControlPanel.autoplay)
                            OverviewRow(label: "FRETBOARD", value: GuideContent.ControlPanel.fretboard)
                            OverviewRow(label: "MENU",      value: GuideContent.ControlPanel.menu)
                        }
                    }

                    // MENU TABS
                    OverviewSection(title: "MENU TABS") {
                        VStack(alignment: .leading, spacing: 10) {
                            OverviewRow(label: "HOME",    value: GuideContent.MenuTabs.home)
                            OverviewRow(label: "OPTIONS", value: GuideContent.MenuTabs.options)
                            OverviewRow(label: "GUIDE",   value: GuideContent.MenuTabs.guide)
                            OverviewRow(label: "AUDIO",   value: GuideContent.MenuTabs.audio)
                        }
                    }

                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }

            // Close button — only shown when presented as a standalone sheet
            if showCloseButton {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Text("CLOSE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.95, green: 0.82, blue: 0.47).opacity(0.5), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Shared section components

private struct OverviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
                .tracking(2)

            content()
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(5)
        }
    }
}

private struct OverviewSubsection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
            content()
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(5)
        }
    }
}

private struct OverviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .padding(.leading, 8)
    }
}
