import SwiftUI

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
