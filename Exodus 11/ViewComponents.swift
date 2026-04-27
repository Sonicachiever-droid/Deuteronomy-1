import SwiftUI

// MARK: - String Line Overlay

private func safeCGFloat(_ value: CGFloat) -> CGFloat {
    value.isFinite ? max(0, value) : 0
}

struct StringLineOverlay: View {
    let neckWidth: CGFloat
    let horizontalPadding: CGFloat
    let stringTopY: CGFloat
    private let bottomClearance: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let clippedTopY = min(max(stringTopY, 0), geo.size.height)
            let clippedBottomY = max(clippedTopY, geo.size.height - bottomClearance)
            let clippedHeight = max(clippedBottomY - clippedTopY, 0)
            let grooveCenters = GuitarStringLayout.stringCenters(containerWidth: geo.size.width, neckWidth: neckWidth)

            ZStack {
                ForEach(0..<GuitarStringLayout.totalStrings, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.88, green: 0.88, blue: 0.84),
                                    Color(red: 0.62, green: 0.62, blue: 0.58),
                                    Color(red: 0.42, green: 0.42, blue: 0.38)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: index < 3 ? 2.8 - CGFloat(index) * 0.35 : 1.4)
                        .frame(height: clippedHeight)
                        .position(x: grooveCenters[index], y: clippedTopY + clippedHeight / 2)
                }
            }
            .frame(width: safeCGFloat(geo.size.width), height: safeCGFloat(geo.size.height))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Mini TV Frame

struct MiniTVFrame: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let fontScale: CGFloat
    var isDarkScreen: Bool = false
    var glowTint: Color? = nil
    var hitTestingEnabled: Bool = false

    init(text: String, width: CGFloat, height: CGFloat, fontScale: CGFloat, isDarkScreen: Bool = false, glowTint: Color? = nil, hitTestingEnabled: Bool = false) {
        self.text = text
        self.width = width
        self.height = height
        self.fontScale = fontScale
        self.isDarkScreen = isDarkScreen
        self.glowTint = glowTint
        self.hitTestingEnabled = hitTestingEnabled
    }

    var body: some View {
        let bezelWidth = width + 24
        let bezelHeight = height + 18

        return ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.18, green: 0.18, blue: 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.65), lineWidth: 3)
                .padding(3)

            Group {
                if isDarkScreen {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.95), Color(red: 0.07, green: 0.07, blue: 0.08), Color.black.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(8)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(white: 1.0, opacity: 0.85), location: 0.0),
                                    .init(color: Color(red: 1.0, green: 0.96, blue: 0.70), location: 0.08),
                                    .init(color: Color(red: 1.0, green: 0.78, blue: 0.12), location: 0.28),
                                    .init(color: Color(red: 1.0, green: 0.56, blue: 0.00), location: 0.40),
                                    .init(color: Color(red: 0.28, green: 0.12, blue: 0.00), location: 1.0)
                                ]),
                                center: .center,
                                startRadius: 2,
                                endRadius: 130
                            )
                        )
                        .padding(8)
                }
            }


            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.clear)
                .padding(12)

            Text(text.prefix(1).uppercased() + text.dropFirst())
                .font(.system(size: max(height * 0.78 * fontScale, 14), weight: .black, design: .default))
                .fontWidth(.condensed)
                .kerning(0.9)
                .allowsTightening(true)
                .foregroundColor(isDarkScreen ? .white : .black)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 12)
        }
        .frame(width: bezelWidth, height: bezelHeight)
        .overlay {
            if let glowTint {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(glowTint.opacity(0.78), lineWidth: 1.2)
                    .padding(3)
                    .shadow(color: glowTint.opacity(0.42), radius: 10)
            }
        }
        .allowsHitTesting(hitTestingEnabled)
    }
}

// MARK: - Screw Head View

struct ScrewHeadView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.72, green: 0.63, blue: 0.44),
                            Color(red: 0.38, green: 0.31, blue: 0.18)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: size * 0.05,
                        endRadius: size * 0.7
                    )
                )
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 0.6)
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: safeCGFloat(size * 0.55), height: 0.8)
                .rotationEffect(.degrees(-12))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Thumb Button View

struct ThumbButtonView: View {
    let diameter: CGFloat
    let label: String
    let state: ThumbGlowState

    private var glowStops: [Gradient.Stop] {
        switch state {
        case .neutral:
            return [
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.0),
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.12),
                .init(color: Color(red: 1.0, green: 0.96, blue: 0.70), location: 0.34),
                .init(color: Color(red: 1.0, green: 0.78, blue: 0.12), location: 0.54),
                .init(color: Color(red: 0.28, green: 0.12, blue: 0.00), location: 1.0)
            ]
        case .orange:
            return [
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.0),
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.12),
                .init(color: Color(red: 1.0, green: 0.84, blue: 0.38), location: 0.34),
                .init(color: Color(red: 1.0, green: 0.58, blue: 0.04), location: 0.54),
                .init(color: Color(red: 0.42, green: 0.17, blue: 0.00), location: 1.0)
            ]
        case .green:
            return [
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.0),
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.12),
                .init(color: Color(red: 0.66, green: 1.0, blue: 0.72), location: 0.34),
                .init(color: Color(red: 0.12, green: 0.84, blue: 0.22), location: 0.54),
                .init(color: Color(red: 0.0, green: 0.32, blue: 0.08), location: 1.0)
            ]
        case .red:
            return [
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.0),
                .init(color: Color(white: 1.0, opacity: 1.0), location: 0.12),
                .init(color: Color(red: 1.0, green: 0.58, blue: 0.46), location: 0.34),
                .init(color: Color(red: 0.82, green: 0.14, blue: 0.07), location: 0.54),
                .init(color: Color(red: 0.34, green: 0.01, blue: 0.01), location: 1.0)
            ]
        }
    }

    var body: some View {
        let bezel = diameter
        let ringOuter = diameter * 0.84
        let ringInner = diameter * 0.78
        let plunger = diameter * 0.50
        let screwOrbit = diameter * 0.39
        let screwSize = max(diameter * 0.085, 7)

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.9, blue: 0.66),
                                Color(red: 0.90, green: 0.74, blue: 0.40),
                                Color(red: 0.73, green: 0.55, blue: 0.26),
                                Color(red: 0.94, green: 0.82, blue: 0.53)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.black.opacity(0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                    .frame(width: bezel, height: bezel)

                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: ringMetalStops),
                            center: .center
                        ),
                        lineWidth: max(diameter * 0.085, 6)
                    )
                    .frame(width: ringOuter, height: ringOuter)

                Circle()
                    .stroke(
                        RadialGradient(
                            gradient: Gradient(stops: glowStops),
                            center: .center,
                            startRadius: ringInner * 0.02,
                            endRadius: ringInner * 0.65
                        )
                        .opacity(1.0),
                        lineWidth: max(diameter * 0.165, 12)
                    )
                    .frame(width: ringInner, height: ringInner)
                    .shadow(color: .white.opacity(0.62), radius: 6)
                    .shadow(color: ringShadowColor.opacity(0.95), radius: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.75), lineWidth: max(diameter * 0.02, 1.6))
                            .frame(width: ringInner * 0.88, height: ringInner * 0.88)
                            .blur(radius: 0.25)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.98, green: 0.9, blue: 0.66),
                                Color(red: 0.90, green: 0.74, blue: 0.40),
                                Color(red: 0.73, green: 0.55, blue: 0.26)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: plunger * 0.03,
                            endRadius: plunger * 0.55
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.40), Color.black.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: plunger * 0.23, height: plunger * 0.16)
                            .offset(x: -plunger * 0.16, y: -plunger * 0.14)
                            .blur(radius: 0.3)
                    )
                    .frame(width: plunger, height: plunger)

                ForEach(0..<4, id: \.self) { index in
                    let angle = Angle.degrees(Double(index) * 90 + 45)
                    ScrewHeadView(size: screwSize)
                        .offset(
                            x: cos(angle.radians) * screwOrbit,
                            y: sin(angle.radians) * screwOrbit
                        )
                }
            }

            Text(label.uppercased())
                .font(.system(size: max(diameter * 0.16, 10), weight: .semibold))
                .fontWidth(.condensed)
                .kerning(0.9)
                .foregroundColor(.white)
        }
    }

    private var ringShadowColor: Color {
        switch state {
        case .neutral: return Color(red: 1.0, green: 0.62, blue: 0.05)
        case .orange: return Color(red: 1.0, green: 0.52, blue: 0.02)
        case .green: return Color(red: 0.2, green: 0.9, blue: 0.3)
        case .red: return Color(red: 1.0, green: 0.2, blue: 0.1)
        }
    }

    private var ringMetalStops: [Color] {
        [
            Color(red: 0.98, green: 0.9, blue: 0.66),
            Color(red: 0.90, green: 0.74, blue: 0.40),
            Color(red: 0.73, green: 0.55, blue: 0.26),
            Color(red: 0.94, green: 0.82, blue: 0.53),
            Color(red: 0.98, green: 0.9, blue: 0.66)
        ]
    }
}

// MARK: - Debug Grid Overlay

func debugGridOverlay(size: CGSize, columns: Int, rows: Int) -> some View {
    let cellWidth = size.width / CGFloat(columns)
    let cellHeight = size.height / CGFloat(rows)

    return ZStack {
        Path { path in
            for column in 0...columns {
                let x = CGFloat(column) * cellWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 0...rows {
                let y = CGFloat(row) * cellHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.red.opacity(0.45), lineWidth: 1)

        ForEach(0..<rows, id: \.self) { row in
            ForEach(0..<columns, id: \.self) { column in
                let index = row * columns + column + 1
                Text("\(index)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.red.opacity(0.85))
                    .position(
                        x: CGFloat(column) * cellWidth + cellWidth / 2,
                        y: CGFloat(row) * cellHeight + cellHeight / 2
                    )
            }
        }
    }
}

// MARK: - Gold Piping Border (perimeter)

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

// MARK: - Gold Piping Lines

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

struct GoldVerticalPipingLine: View {
    let height: CGFloat
    
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
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.8, height: height)
            
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 0.45, height: height)
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 0.25, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 0.45, height: height)
            }
            .frame(width: 2.8, height: height)
            
            RoundedRectangle(cornerRadius: 0.4, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .frame(width: 0.7, height: max(height - 2, 0))
        }
    }
}

// MARK: - Rosewood Segmented Background

struct RosewoodSegmentedBackground: View {
    let fretRatios: [CGFloat]
    let cornerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let neckHeight = geometry.size.height
            let neckWidth = geometry.size.width
            let segments = segmentBounds(from: fretRatios)
            let bindingInset = max(neckWidth * 0.02, 6)
            let rosewoodTexture = Image("RosewoodOne")
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    let groupSize = 3
                    ForEach(Array(stride(from: 0, to: segments.count, by: groupSize)), id: \.self) { start in
                        let end = min(start + groupSize, segments.count)
                        let groupHeight = (start..<end).reduce(CGFloat(0)) { acc, idx in
                            acc + max((segments[idx].end - segments[idx].start) * neckHeight, 1)
                        }
                        rosewoodTexture
                            .resizable()
                            .scaledToFill()
                            .frame(width: neckWidth, height: groupHeight)
                            .clipped()
                    }
                }
                .padding(.horizontal, bindingInset)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.14),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.multiply)
                
                VStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, bounds in
                        Spacer()
                            .frame(height: max((bounds.end - bounds.start) * neckHeight, 1))
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(((index + 1) % 3 == 0) ? 0.08 : 0))
                                    .frame(height: 1.2)
                                    .opacity(bounds.end >= 1 ? 0 : 1)
                            )
                    }
                }
                .padding(.horizontal, bindingInset)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    
    private func segmentBounds(from ratios: [CGFloat]) -> [(start: CGFloat, end: CGFloat)] {
        guard ratios.count >= 2 else { return [(0, 1)] }
        var pairs: [(CGFloat, CGFloat)] = []
        for index in 0..<(ratios.count - 1) {
            let start = ratios[index]
            let end = ratios[index + 1]
            pairs.append((start, end))
        }
        if let last = ratios.last, last < 1 {
            pairs.append((last, 1))
        }
        return pairs
    }
}

// MARK: - Full Screen Elephant Background

struct FullScreenElephantBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("MARSHALL ELEPHANT")
                .resizable(resizingMode: .tile)
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Neck Components

struct BindingLayer: View {
    var body: some View {
        GeometryReader { geo in
            let stripWidth = max(geo.size.width * 0.02, 6)
            ZStack(alignment: .top) {
                HStack {
                    bindingStrip(width: stripWidth, height: geo.size.height)
                    Spacer()
                    bindingStrip(width: stripWidth, height: geo.size.height)
                }
                Rectangle()
                    .fill(Color(red: 0.65, green: 0.62, blue: 0.58))
                    .frame(width: geo.size.width - stripWidth * 2, height: 1)
                    .position(x: geo.size.width / 2, y: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func bindingStrip(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.88), Color(red: 0.91, green: 0.87, blue: 0.78)],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(VStack { Color.white.opacity(0.35).frame(height: 1); Spacer() })
            .frame(width: width, height: height)
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 1, y: 0)
    }
}

struct FretWireLayer: View {
    let fretRatios: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width * 1.04
            let wireThickness = max(geo.size.height * 0.0018, 2)
            ZStack(alignment: .topLeading) {
                ForEach(1..<fretRatios.count, id: \.self) { index in
                    let ratio = fretRatios[index]
                    RoundedRectangle(cornerRadius: wireThickness / 2, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.96, blue: 0.94),
                                Color(red: 0.7, green: 0.72, blue: 0.75),
                                Color(red: 0.45, green: 0.47, blue: 0.5),
                                Color(red: 0.98, green: 0.98, blue: 0.99)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .overlay(RoundedRectangle(cornerRadius: wireThickness / 2).stroke(Color.black.opacity(0.3), lineWidth: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: wireThickness / 2).stroke(LinearGradient(colors: [Color.white.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 0.7))
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .frame(width: width, height: wireThickness)
                        .offset(x: -(width - geo.size.width) / 2, y: ratio * height - wireThickness / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FretMarkerLayer: View {
    let fretRatios: [CGFloat]
    private let markedFrets: [Int] = [3, 5, 7, 9, 15, 17, 19, 21]
    private let stratNutWidthInches: CGFloat = 1.650
    private let stratStringSpanInches: CGFloat = 1.362
    private let totalStrings: Int = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let markerDiameter = max(min(width, height) * 0.135, 36)
            let widthPerInch = width / stratNutWidthInches
            let interStringSpacing = (stratStringSpanInches / CGFloat(totalStrings - 1)) * widthPerInch
            let edgeMargin = ((stratNutWidthInches - stratStringSpanInches) / 2) * widthPerInch
            let string2X = edgeMargin + 4 * interStringSpacing
            let string5X = edgeMargin + 1 * interStringSpacing
            let dotFill = RadialGradient(
                colors: [Color.white.opacity(0.98), Color(red: 0.93, green: 0.93, blue: 0.9), Color(red: 0.72, green: 0.72, blue: 0.7)],
                center: .center, startRadius: markerDiameter * 0.05, endRadius: markerDiameter * 0.6
            )
            ZStack {
                ForEach(markedFrets, id: \.self) { fret in
                    if fretRatios.indices.contains(fret), fretRatios.indices.contains(fret - 1) {
                        let start = fretRatios[fret - 1]
                        let end = fretRatios[fret]
                        let yPosition = ((start + end) / 2) * height
                        Circle()
                            .fill(dotFill)
                            .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1))
                            .frame(width: markerDiameter, height: markerDiameter)
                            .position(x: width / 2, y: yPosition)
                            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    }
                }
                if fretRatios.indices.contains(12), fretRatios.indices.contains(11) {
                    let y12 = ((fretRatios[11] + fretRatios[12]) / 2) * height
                    Circle().fill(dotFill).overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1)).frame(width: markerDiameter, height: markerDiameter).position(x: string2X, y: y12).shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    Circle().fill(dotFill).overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1)).frame(width: markerDiameter, height: markerDiameter).position(x: string5X, y: y12).shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct NutLayer: View {
    let width: CGFloat
    let height: CGFloat
    private let stratNutWidthInches: CGFloat = 1.650
    private let stratStringSpanInches: CGFloat = 1.362
    private let totalStrings: Int = 6

    var body: some View {
        GeometryReader { geo in
            let nutHeight = geo.size.height
            let bevelHeight = nutHeight * 0.25
            let widthPerInch = geo.size.width / stratNutWidthInches
            let interStringSpacing = (stratStringSpanInches / CGFloat(totalStrings - 1)) * widthPerInch
            let edgeMargin = ((stratNutWidthInches - stratStringSpanInches) / 2) * widthPerInch
            let grooveCenters = (0..<totalStrings).map { index in edgeMargin + CGFloat(index) * interStringSpacing }
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.94, blue: 0.88), Color(red: 0.90, green: 0.86, blue: 0.78)], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.1), lineWidth: 1))
                    .frame(height: nutHeight + bevelHeight)
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: geo.size.width * 0.98, height: bevelHeight)
                    .offset(y: nutHeight * 0.15)
                    .mask(LinearGradient(gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.4)]), startPoint: .top, endPoint: .bottom))
                let grooveWidth = max(1, geo.size.width * 0.01)
                let grooveHeight = bevelHeight * 1.4
                ForEach(0..<totalStrings, id: \.self) { index in
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: grooveWidth, height: grooveHeight)
                        .cornerRadius(grooveWidth / 2)
                        .offset(x: grooveCenters[index] - geo.size.width / 2, y: nutHeight * 0.1)
                }
                Rectangle().fill(Color.black.opacity(0.25)).frame(width: 1, height: nutHeight + bevelHeight * 0.6).offset(y: nutHeight * 0.2)
            }
        }
        .frame(width: width, height: height)
        .padding(.bottom, height * 0.05)
        .allowsHitTesting(false)
    }
}

// MARK: - Window Components

struct HighlightWindowGoldBorder: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        HighlightWindowShape(cornerRadius: cornerRadius)
            .strokeBorder(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.82, blue: 0.47), Color(red: 0.78, green: 0.6, blue: 0.22), Color(red: 0.97, green: 0.85, blue: 0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 4
            )
            .frame(width: width, height: height)
    }
}

struct MarshallElephantOverlay: View {
    let canvasSize: CGSize
    let highlightWidth: CGFloat
    let highlightHeight: CGFloat
    let highlightCenter: CGPoint
    let highlightCornerRadius: CGFloat

    var body: some View {
        let bleed: CGFloat = 36
        Image("MARSHALL ELEPHANT")
            .resizable(resizingMode: .tile)
            .frame(width: canvasSize.width + (bleed * 2), height: canvasSize.height + (bleed * 2))
            .scaleEffect(x: 1.15, y: 1.15, anchor: .center)
            .brightness(0.12)
            .saturation(1.05)
            .overlay(Color.black.opacity(0.2))
            .offset(x: -bleed, y: -bleed)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipped()
            .mask(maskShape)
            .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var maskShape: some View {
        Rectangle()
            .frame(width: canvasSize.width, height: canvasSize.height)
            .overlay {
                HighlightWindowShape(cornerRadius: highlightCornerRadius)
                    .frame(width: highlightWidth, height: highlightHeight)
                    .position(x: highlightCenter.x, y: highlightCenter.y)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}

struct ElephantWindowView: View {
    let canvasSize: CGSize
    let highlightWidth: CGFloat
    let highlightHeight: CGFloat
    let highlightCenter: CGPoint
    let highlightCornerRadius: CGFloat

    var body: some View {
        ZStack {
            MarshallElephantOverlay(
                canvasSize: canvasSize,
                highlightWidth: highlightWidth,
                highlightHeight: highlightHeight,
                highlightCenter: highlightCenter,
                highlightCornerRadius: highlightCornerRadius
            )
            HighlightWindowGoldBorder(width: highlightWidth, height: highlightHeight, cornerRadius: highlightCornerRadius)
                .position(x: highlightCenter.x, y: highlightCenter.y)
        }
    }
}

// MARK: - Developer Console Frame

struct DeveloperConsoleFrame: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(width: width, height: height)
            
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.82, blue: 0.53),
                            Color(red: 0.78, green: 0.6, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: width, height: height)
            
            Text(text)
                .font(.system(size: width * 0.08, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.0, green: 0.82, blue: 0.0))
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Note Choice Box

struct NoteChoiceBox: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let isDark: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isDark ? Color.black.opacity(0.7) : Color.white.opacity(0.9))
                .frame(width: width, height: height)
            
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.82, blue: 0.53),
                            Color(red: 0.78, green: 0.6, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width, height: height)
            
            Text(text)
                .font(.system(size: width * 0.25, weight: .bold, design: .monospaced))
                .foregroundColor(isDark ? .white : .black)
                .frame(width: width, height: height)
        }
    }
}
