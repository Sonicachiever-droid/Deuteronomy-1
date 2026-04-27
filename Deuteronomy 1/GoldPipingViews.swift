import SwiftUI

// MARK: - Gold Horizontal Piping Line

struct GoldHorizontalPipingLine: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.9, blue: 0.66),
                            Color(red: 0.90, green: 0.74, blue: 0.40),
                            Color(red: 0.73, green: 0.55, blue: 0.26),
                            Color(red: 0.94, green: 0.82, blue: 0.53)
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

// MARK: - Gold Piping Border

struct GoldPipingBorder: View {
    let bottomInset: CGFloat

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .inset(by: 1.75)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.82, blue: 0.47),
                            Color(red: 0.78, green: 0.6, blue: 0.22),
                            Color(red: 0.97, green: 0.85, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.5
                )
                .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 8)

            ContainerRelativeShape()
                .inset(by: 3.5)
                .stroke(Color.black.opacity(0.6), lineWidth: 1.5)
        }
        .padding(.bottom, bottomInset)
        .ignoresSafeArea()
    }
}
