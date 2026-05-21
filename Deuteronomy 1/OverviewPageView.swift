import SwiftUI

struct OverviewPageView: View {
    @Environment(\.dismiss) private var dismiss

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

                    // Section: What Is This?
                    OverviewSection(title: "WHAT IS THIS?") {
                        Text("ReFret is a fretboard training app for guitar players. It teaches you to identify notes by string and fret position across the entire neck — from open strings to fret 19.")
                    }

                    // Section: Two Consoles
                    OverviewSection(title: "TWO CONSOLES") {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BEGINNER CONSOLE")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
                                Text("Six answer buttons, one per string, each labelled with a note name. Tap the correct string for each note as it is called. Notes are revealed one by one before each round so you can study them first.\n\nTwo lesson styles: Sequential works through each string individually. Chord works through all strings of a chord shape together, building the full chord note by note.")
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.88))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MAESTRO CONSOLE")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.47))
                                Text("No hints. Two answer buttons show note names — identify the correct one from memory. Wrong answers restart the current fret. A more demanding test of recall.\n\nSpeed Run mode (select in PLAY menu) races you through every fret from 0 to the top and back down to 0 against the clock. Scoring, streaks, and multipliers all apply. Your best time for each category is saved to the HOME tab.")
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.88))
                            }
                        }
                    }

                    // Section: Scoring
                    OverviewSection(title: "SCORING") {
                        Text("Correct answers earn dollars. Beginner earns $1 per correct note. Maestro earns $2. Wrong answers do not cost you — the fret simply restarts. Your wallet accumulates across the session. Build a streak of consecutive correct answers to unlock multipliers and earn more per note.")
                    }

                    // Section: Rounds & Frets
                    OverviewSection(title: "ROUNDS & FRETS") {
                        Text("One round covers all six strings on one fret. Complete a round to advance to the next fret. Fret 0 is open strings. The game moves up to fret 12 by default, then reverses back down — or up to fret 19 if you have purchased High Frets. Direction and starting fret can be changed in the PLAY tab.")
                    }

                    // Section: Settings
                    OverviewSection(title: "SETTINGS") {
                        Text("Open MENU during play to access four tabs.\n\nHOME — wallet, balance, purchasable upgrades (High Frets, Landscape Mode), and console skins.\n\nPLAY — starting fret, repetitions per fret, direction, progression (High → Low or Low → High), and Maestro style (Standard or Speed Run).\n\nGUIDE — quick note reference.\n\nAUDIO — guitar tone, tempo, and volume.")
                    }

                    // Footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            // Close button
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
