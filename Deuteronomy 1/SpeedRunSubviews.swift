import SwiftUI
import GameKit

// MARK: - GameCenterLeaderboardView
// Presents the native Game Center leaderboard UI for a given leaderboard ID.

struct GameCenterLeaderboardView: UIViewControllerRepresentable {
    let leaderboardID: String

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}

// MARK: - SpeedRunResultOverlay
// Shown full-screen when a Speed Run completes. Displays elapsed time, new-best
// indicator, previous best time, and a restart prompt. Dismissed automatically
// when the player presses Start/Reset (which calls startGameFromBeginning and
// sets speedRunFinished = false).

struct SpeedRunResultOverlay: View {
    let elapsed: TimeInterval
    let bestTime: Double          // the already-updated best (equals elapsed when a new best was just set)
    let consoleSkin: ConsoleSkin

    // bestTime is written by advanceGame before speedRunFinished is set to true,
    // so at render time bestTime == elapsed iff this run set a new record.
    private var isNewBest: Bool { elapsed > 0 && elapsed == bestTime }
    private var previousBest: Double { isNewBest ? 0 : bestTime }

    private var gold: Color { Color.goldBorderMid }
    private var screenBg: Color { Color.screenDark }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                Text("SPEED RUN COMPLETE")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(screenBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(gold.opacity(0.6), lineWidth: 1)
                            )
                    )

                Spacer().frame(height: 20)

                // New Best banner (only when record was beaten)
                if isNewBest {
                    Text("NEW BEST!")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.feedbackGreenFill)
                        .padding(.bottom, 8)
                }

                // Elapsed time
                Text(formatTime(elapsed))
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Spacer().frame(height: 14)

                // Previous best (shown when not a new best, or when there was a prior best)
                if !isNewBest && previousBest > 0 {
                    Text("BEST  \(formatTime(previousBest))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(gold.opacity(0.75))
                } else if isNewBest {
                    // New best — previous record not stored separately, nothing to show
                }

                Spacer().frame(height: 28)

                // Restart prompt
                Text("TAP TO RUN AGAIN")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(screenBg.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.goldBorderLight, Color.goldBorderDark],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 32)
        }
    }

    // Formats a TimeInterval as m:ss.xx  e.g. "2:07.43"
    private func formatTime(_ t: TimeInterval) -> String {
        formatSpeedRunTime(t)
    }
}

/// Package-internal formatter shared between `SpeedRunResultOverlay` and unit tests.
/// Returns `"--:--.--"` for zero/negative, otherwise `"m:ss.xx"`.
func formatSpeedRunTime(_ t: TimeInterval) -> String {
    guard t > 0 else { return "--:--.--" }
    let minutes = Int(t) / 60
    let seconds = Int(t) % 60
    let centis  = Int((t.truncatingRemainder(dividingBy: 1)) * 100)
    return String(format: "%d:%02d.%02d", minutes, seconds, centis)
}

/// Pure helper: computes the number of unique fret positions visited in one
/// complete Speed Run traversal for a given `maxFret`.
///
/// Ascending:  frets 0 … maxFret  → (maxFret + 1) positions
/// Descending: frets (maxFret-1) … 1  → (maxFret - 1) positions
/// (Fret 0 descending triggers completion, counted separately as 1)
/// Total unique fret positions = (maxFret + 1) + (maxFret - 1) + 1
///                              = 2 * maxFret + 1
///
/// Multiplied by 6 strings per fret.
func speedRunTotalFretPositions(maxFret: Int) -> Int {
    let ascending  = maxFret + 1          // frets 0 … maxFret
    let descending = maxFret - 1          // frets (maxFret-1) … 1
    let completion = 1                    // fret 0 descending (fires completion)
    return (ascending + descending + completion) * 6
}

/// Returns `true` if `elapsed` improves on (or sets) the stored `bestTime`.
/// `bestTime == 0` means no record has been set yet.
func speedRunIsNewBest(elapsed: TimeInterval, bestTime: Double) -> Bool {
    guard elapsed > 0 else { return false }
    return bestTime == 0 || elapsed < bestTime
}

// MARK: - SpeedRunEndView
// New end-of-speed-run screen with celebration, final time, Game Center
// reference, and explicit next actions. Wired into MaestroGameplayView.

struct SpeedRunEndView: View {
    let elapsed: TimeInterval
    let bestTime: Double
    let consoleSkin: ConsoleSkin
    let onRunAgain: () -> Void
    let onLeaderboard: () -> Void
    let onMenu: () -> Void

    private var isNewBest: Bool { elapsed > 0 && elapsed == bestTime }
    private var gold: Color { Color.goldBorderMid }
    private var screenBg: Color { Color.screenDark }

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("SPEED RUN ENDED!")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(screenBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(gold.opacity(0.6), lineWidth: 1)
                            )
                    )

                Spacer().frame(height: 20)

                if isNewBest {
                    Text("NEW BEST!")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.feedbackGreenFill)
                        .padding(.bottom, 8)
                        .scaleEffect(showContent ? 1.0 : 1.4)
                        .opacity(showContent ? 1.0 : 0.0)
                }

                Text(formatSpeedRunTime(elapsed))
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Spacer().frame(height: 14)

                Text("Submitted to Game Center")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(gold.opacity(0.75))

                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        actionButton(title: "RUN AGAIN", action: onRunAgain)
                        actionButton(title: "LEADERBOARD", action: onLeaderboard)
                    }
                    actionButton(title: "MAIN MENU", action: onMenu)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(screenBg.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.goldBorderLight, Color.goldBorderDark],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 32)
            .scaleEffect(showContent ? 1.0 : 0.85)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: showContent)

            StarBurst(active: showContent)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showContent = true
            }
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(minWidth: 100)
                .background(Color.goldBorderMid)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private struct StarBurst: View {
    let active: Bool

    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(0..<6) { i in
                    StarPiece(index: i, active: active)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct StarPiece: View {
    let index: Int
    let active: Bool

    @State private var scale: CGFloat = 0
    @State private var rotation: Double = 0

    private var color: Color {
        [Color.goldBorderMid, Color.feedbackGreenFill, Color.white, Color.goldBorderLight][index % 4]
    }

    private var angle: Angle {
        .degrees(Double(index) * 60)
    }

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: [12, 10, 14, 11, 13, 10][index % 6]))
            .foregroundStyle(color)
            .offset(x: cos(angle.radians) * 90, y: sin(angle.radians) * 90)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(scale)
            .onAppear {
                scale = 0
                rotation = Double.random(in: -45...45)
                withAnimation(
                    .spring(response: 0.6, dampingFraction: 0.5)
                    .delay(Double(index) * 0.08)
                ) {
                    scale = 1
                    rotation += Double.random(in: 45...90)
                }
            }
    }
}

#Preview("New Best") {
    SpeedRunEndView(
        elapsed: 127.43,
        bestTime: 127.43,
        consoleSkin: .classic,
        onRunAgain: {},
        onLeaderboard: {},
        onMenu: {}
    )
}

#Preview("Not New Best") {
    SpeedRunEndView(
        elapsed: 132.10,
        bestTime: 127.43,
        consoleSkin: .classic,
        onRunAgain: {},
        onLeaderboard: {},
        onMenu: {}
    )
    .background(Color.black)
}
