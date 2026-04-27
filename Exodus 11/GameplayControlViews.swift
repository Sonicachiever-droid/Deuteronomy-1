import SwiftUI

// MARK: - Gameplay Control Plate Shell

struct GameplayControlPlateShell: View {
    let isMenuExpanded: Bool
    let isStartupInputLockActive: Bool
    let isAutoplayActive: Bool
    let onAutoplay: () -> Void
    let onFretboard: () -> Void
    let onToggleMenu: () -> Void
    let onSelectMenuOption: (GameplayMenuOption) -> Void

    private let menuOptions: [GameplayMenuOption] = [.home, .audio, .guide, .learn]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.95, green: 0.95, blue: 0.95), Color(red: 0.58, green: 0.58, blue: 0.58)],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: 1,
                                endRadius: 16
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.2))
                    Circle()
                        .fill(Color.black.opacity(0.9))
                        .frame(width: 14, height: 14)
                }

                HStack(spacing: 8) {
                    plateButton(title: "AUTOPLAY", action: onAutoplay, isActive: isAutoplayActive)
                        .disabled(isStartupInputLockActive)
                    plateButton(title: "FRETBOARD", action: onFretboard)
                        .disabled(isStartupInputLockActive)
                    plateButton(title: isMenuExpanded ? "CLOSE" : "MENU", action: onToggleMenu)
                }
            }

            if isMenuExpanded {
                HStack(spacing: 8) {
                    ForEach(menuOptions) { option in
                        plateButton(title: option.title) {
                            onSelectMenuOption(option)
                        }
                        .disabled(isStartupInputLockActive)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.9, blue: 0.66),
                            Color(red: 0.9, green: 0.74, blue: 0.4),
                            Color(red: 0.73, green: 0.55, blue: 0.26),
                            Color(red: 0.94, green: 0.82, blue: 0.53)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.26), lineWidth: 1.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
        )
    }

    private func plateButton(title: String, action: @escaping () -> Void, isActive: Bool = false) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.76, blue: 0.44),
                                Color(red: 0.72, green: 0.54, blue: 0.26),
                                Color(red: 0.87, green: 0.72, blue: 0.40)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                if isActive {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.green.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.black.opacity(0.34), lineWidth: 1.0)
            )
            .overlay(
                Text(title)
                    .font(.system(size: 10.35, weight: .regular, design: .monospaced))
                    .fontWidth(.compressed)
                    .kerning(0.8)
                    .foregroundStyle(Color.black.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}
