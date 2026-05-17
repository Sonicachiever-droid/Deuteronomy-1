import SwiftUI
import UIKit

// MARK: - Gold Horizontal Piping Line

struct GoldHorizontalPipingLine: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.goldLight, .goldMid, .goldDark, .goldMidtone],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 2.8)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: width, height: 0.45)

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: width, height: 0.45)
            }
            .frame(width: width, height: 2.8)

            RoundedRectangle(cornerRadius: 0.4, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .frame(width: max(width - 2, 0), height: 0.7)
        }
    }

}

// MARK: - Device-specific helpers (local)
private func isProblematicRoundedCornerDevice() -> Bool {
    let bounds = UIScreen.main.nativeBounds
    let short = min(bounds.width, bounds.height)
    let long = max(bounds.width, bounds.height)
    // iPhone XR/11 native resolution: 828 x 1792
    if short == 828 && long == 1792 { return true }
    return false
}

// MARK: - Perimeter border helpers (composed views)
@ViewBuilder
private func perimeterOuterBorder() -> some View {
    if isProblematicRoundedCornerDevice() {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .inset(by: 1.75)
            .strokeBorder(
                LinearGradient(
                    colors: [.goldBorderMid, .goldBorderDark, .goldBorderLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3.5
            )
    } else {
        ContainerRelativeShape()
            .inset(by: 1.75)
            .strokeBorder(
                LinearGradient(
                    colors: [.goldBorderMid, .goldBorderDark, .goldBorderLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3.5
            )
    }
}

@ViewBuilder
private func perimeterInnerBorder() -> some View {
    if isProblematicRoundedCornerDevice() {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .inset(by: 3.5)
            .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
    } else {
        ContainerRelativeShape()
            .inset(by: 3.5)
            .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
    }
}

@ViewBuilder
private func perimeterWhiteBorder() -> some View {
    if isProblematicRoundedCornerDevice() {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .inset(by: 1.75)
            .strokeBorder(Color.white, lineWidth: 3.5)
    } else {
        ContainerRelativeShape()
            .inset(by: 1.75)
            .strokeBorder(Color.white, lineWidth: 3.5)
    }
}

// MARK: - Gold Piping Border

struct GoldPipingBorder: View {
    let bottomInset: CGFloat

    var body: some View {
        ZStack {
            perimeterOuterBorder()
                .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 8)

            perimeterInnerBorder()
        }
        .padding(Edge.Set.bottom, bottomInset)
        .ignoresSafeArea()
    }
}

// MARK: - White Horizontal Piping Line

struct WhiteHorizontalPipingLine: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.98, blue: 0.98),
                            Color(red: 0.90, green: 0.90, blue: 0.90),
                            Color(red: 0.73, green: 0.73, blue: 0.73),
                            Color(red: 0.94, green: 0.94, blue: 0.94)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 2.8)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: width, height: 0.45)

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: width, height: 0.45)
            }
            .frame(width: width, height: 2.8)

            RoundedRectangle(cornerRadius: 0.4, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .frame(width: max(width - 2, 0), height: 0.7)
        }
    }
}

// MARK: - White Piping Border

struct WhitePipingBorder: View {
    let bottomInset: CGFloat

    var body: some View {
        perimeterWhiteBorder()
            .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 8)
            .padding(Edge.Set.bottom, bottomInset)
            .ignoresSafeArea()
    }
}

