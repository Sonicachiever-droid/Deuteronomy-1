import SwiftUI
import AVFoundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct Deuteronomy_1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var selectedMenuOption: GameplayMenuOption?
    @State private var layoutMode: LayoutMode? = nil
    @AppStorage("numbers3.progress.walletPoints") private var walletPoints: Int = 0
    @AppStorage("numbers3.progress.balancePoints") private var balancePoints: Int = 0
    @AppStorage("numbers3.setup.startingFret") private var startingFret: Int = 0
    @AppStorage("numbers3.setup.repetitions") private var repetitions: Int = 5
    @AppStorage("numbers3.setup.infiniteRepetitions") private var infiniteRepetitions: Bool = false
    @AppStorage("numbers3.setup.direction") private var directionRawValue: String = LessonDirection.ascending.rawValue
    @AppStorage("numbers3.setup.enableHighFrets") private var enableHighFrets: Bool = false
    @AppStorage("numbers3.setup.lessonStyle") private var lessonStyleRawValue: String = "chord"
    @AppStorage("numbers3.setup.selectedMode") private var selectedModeRawValue: String = "beginner"
    @AppStorage("numbers3.setup.progression") private var progressionRawValue: String = "highToLow"
    @AppStorage("numbers3.setup.orientation") private var orientationRawValue: String = Orientation.portrait.rawValue

    private var orientation: Orientation {
        Orientation(rawValue: orientationRawValue) ?? .portrait
    }

    init() {
        let savedMode = UserDefaults.standard.string(forKey: "numbers3.setup.selectedMode") ?? "beginner"
        let savedOrientation = UserDefaults.standard.string(forKey: "numbers3.setup.orientation") ?? Orientation.portrait.rawValue
        // Always portrait on launch — welcome screen is always shown first
        AppDelegate.orientationLock = .portrait
        _ = savedMode
        _ = savedOrientation
        // FIX A5: Single audio session configuration — no per-engine conflicts
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Deuteronomy 1] Audio session configuration failed: \(error)")
        }
        #endif

        if LessonDirection(rawValue: directionRawValue) == nil {
            directionRawValue = LessonDirection.ascending.rawValue
        }
        // Always show welcome screen on cold launch
        layoutMode = nil
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let mode = layoutMode {
                    switch mode {
                    case .beginner:
                        BeginnerGameplayView(
                            onMenuSelection: { option in
                                selectedMenuOption = option
                            },
                            playStartingFret: $startingFret,
                            playRepetitions: $repetitions,
                            playInfiniteRepetitions: $infiniteRepetitions,
                            playDirectionRawValue: $directionRawValue,
                            playEnableHighFrets: $enableHighFrets,
                            playLessonStyle: $lessonStyleRawValue,
                            playProgression: $progressionRawValue,
                            walletDollars: $walletPoints,
                            balanceDollars: $balancePoints
                        )
                    case .maestro:
                        MaestroGameplayView(
                            onMenuSelection: { option in
                                selectedMenuOption = option
                            },
                            playStartingFret: $startingFret,
                            playRepetitions: $repetitions,
                            playInfiniteRepetitions: $infiniteRepetitions,
                            playDirectionRawValue: $directionRawValue,
                            playEnableHighFrets: $enableHighFrets,
                            playLessonStyle: $lessonStyleRawValue,
                            playProgression: $progressionRawValue,
                            walletDollars: $walletPoints,
                            balanceDollars: $balancePoints,
                            orientation: orientation
                        )
                    }
                } else {
                    WelcomeScreenView(
                        onSelectBeginner: { layoutMode = .beginner },
                        onSelectMaestro: { layoutMode = .maestro }
                    )
                }
            }
            .onChange(of: layoutMode) { _, newMode in
                if newMode == .beginner {
                    selectedModeRawValue = "beginner"
                    // Beginner has no landscape — always lock portrait
                    AppDelegate.orientationLock = .portrait
                    #if os(iOS)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
                    }
                    #endif
                } else if newMode == .maestro {
                    selectedModeRawValue = "maestro"
                    // Always lock portrait when switching to maestro (user must explicitly choose landscape)
                    orientationRawValue = Orientation.portrait.rawValue
                    AppDelegate.orientationLock = .portrait
                    #if os(iOS)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
                    }
                    #endif
                }
                SharedAudioEngine.shared.stopAll()
            }
            .sheet(item: $selectedMenuOption) { option in
                Deuteronomy1MenuSheet(
                    option: option,
                    walletPoints: $walletPoints,
                    balancePoints: $balancePoints,
                    startingFret: $startingFret,
                    repetitions: $repetitions,
                    infiniteRepetitions: $infiniteRepetitions,
                    directionRawValue: $directionRawValue,
                    enableHighFrets: $enableHighFrets,
                    lessonStyleRawValue: $lessonStyleRawValue,
                    progressionRawValue: $progressionRawValue,
                    layoutMode: $layoutMode,
                    orientationRawValue: $orientationRawValue
                )
            }
            .onChange(of: orientationRawValue) { _, newValue in
                // Only allow landscape if in maestro mode
                guard layoutMode == .maestro else {
                    AppDelegate.orientationLock = .portrait
                    return
                }
                if newValue == Orientation.landscape.rawValue {
                    AppDelegate.orientationLock = .landscape
                } else {
                    AppDelegate.orientationLock = .portrait
                }
                #if os(iOS)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    let geometryPreferences: UIWindowScene.GeometryPreferences.iOS
                    if newValue == Orientation.landscape.rawValue {
                        geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                    } else {
                        geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                    }
                    windowScene.requestGeometryUpdate(geometryPreferences) { error in
                        print("[Deuteronomy 1] Orientation change error: \(error)")
                    }
                }
                #endif
            }
        }
    }
}

private struct GoldPickerRow<T: Hashable>: View {
    let label: String
    let options: [(label: String, value: T)]
    @Binding var selection: T
    var disabled: Bool = false

    private let gold = Color(red: 0.95, green: 0.82, blue: 0.47)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    let isSelected = selection == option.value
                    Button(action: {
                        guard !disabled else { return }
                        selection = option.value
                    }) {
                        Text(option.label)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .black : (disabled ? .white.opacity(0.3) : .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? gold : Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? gold : gold.opacity(disabled ? 0.2 : 0.45), lineWidth: 1.5)
                            )
                    }
                    .disabled(disabled)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MenuSection<Content: View>: View {
    let title: String
    let gold: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(gold)
                .tracking(2)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Divider()
                .background(gold.opacity(0.35))
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

private struct MenuRow: View {
    let label: String
    let value: String
    let gold: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(gold)
        }
    }
}

private struct MenuTextRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .lineSpacing(4)
    }
}

private struct Deuteronomy1MenuSheet: View {
    let option: GameplayMenuOption
    @Binding var walletPoints: Int
    @Binding var balancePoints: Int
    @Binding var startingFret: Int
    @Binding var repetitions: Int
    @Binding var infiniteRepetitions: Bool
    @Binding var directionRawValue: String
    @Binding var enableHighFrets: Bool
    @Binding var lessonStyleRawValue: String
    @Binding var progressionRawValue: String
    @Binding var layoutMode: LayoutMode?
    @Binding var orientationRawValue: String
    @AppStorage("numbers3.runtime.directionLockActive") private var directionLockActive: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isButtonPressed: Bool = false

    private var repetitionDisplay: String {
        infiniteRepetitions ? "∞" : "\(repetitions)"
    }

    private let gold = Color(red: 0.95, green: 0.82, blue: 0.47)
    private let goldDim = Color(red: 0.95, green: 0.82, blue: 0.47).opacity(0.55)

    var body: some View {
        NavigationStack {
            ZStack {
                FullScreenElephantBackground()
                    .ignoresSafeArea()
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                GoldPipingBorder(bottomInset: 0)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch option {
                        case .home:
                            MenuSection(title: "PROGRESS", gold: gold) {
                                MenuRow(label: "Wallet", value: "$\(walletPoints)", gold: gold)
                                MenuRow(label: "Balance", value: "$\(balancePoints)", gold: gold)
                            }
                            if layoutMode == .maestro {
                                MenuSection(title: "ORIENTATION", gold: gold) {
                                    GoldPickerRow(
                                        label: "Layout",
                                        options: [
                                            (label: "Portrait", value: Orientation.portrait.rawValue),
                                            (label: "Landscape", value: Orientation.landscape.rawValue)
                                        ],
                                        selection: $orientationRawValue
                                    )
                                }
                            }

                        case .learn:
                            MenuSection(title: "LESSON SETUP", gold: gold) {
                                if layoutMode == .beginner {
                                    GoldPickerRow(
                                        label: "Style",
                                        options: [
                                            (label: "Sequential", value: "sequential"),
                                            (label: "Chord", value: "chord")
                                        ],
                                        selection: $lessonStyleRawValue
                                    )
                                }

                                Stepper("Repetitions: \(repetitionDisplay)", value: $repetitions, in: 1...8)
                                    .disabled(infiniteRepetitions)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .tint(gold)

                                Toggle("Infinite Repetitions", isOn: $infiniteRepetitions)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .tint(gold)

                                Stepper("Starting Fret: \(startingFret)", value: $startingFret, in: 0...(enableHighFrets ? 19 : 12))
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .tint(gold)
                                    .onChange(of: startingFret) { _, newValue in
                                        if newValue == 0 {
                                            directionRawValue = LessonDirection.ascending.rawValue
                                        } else if newValue >= (enableHighFrets ? 19 : 12) {
                                            directionRawValue = LessonDirection.descending.rawValue
                                        }
                                    }

                                let upperBound = enableHighFrets ? 19 : 12
                                let descendingLocked = startingFret == 0
                                let ascendingLocked = startingFret >= upperBound
                                GoldPickerRow(
                                    label: "Direction",
                                    options: [
                                        (label: "Ascending", value: LessonDirection.ascending.rawValue),
                                        (label: "Descending", value: LessonDirection.descending.rawValue)
                                    ],
                                    selection: Binding(
                                        get: { directionRawValue },
                                        set: { newValue in
                                            let isDescending = newValue == LessonDirection.descending.rawValue
                                            if isDescending && descendingLocked { return }
                                            if !isDescending && ascendingLocked { return }
                                            directionRawValue = newValue
                                        }
                                    )
                                )

                                let progressionLocked = layoutMode == .beginner && lessonStyleRawValue == "chord"
                                GoldPickerRow(
                                    label: "Progression",
                                    options: [
                                        (label: "High → Low", value: "highToLow"),
                                        (label: "Low → High", value: "lowToHigh")
                                    ],
                                    selection: $progressionRawValue,
                                    disabled: progressionLocked
                                )

                                Toggle("Enable High Frets (12+)", isOn: $enableHighFrets)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .tint(gold)
                                    .onChange(of: enableHighFrets) { _, isEnabled in
                                        if !isEnabled {
                                            startingFret = min(startingFret, 12)
                                        }
                                    }
                            }

                            MenuSection(title: "CONSOLE", gold: gold) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        isButtonPressed = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        if layoutMode == .beginner {
                                            layoutMode = .maestro
                                        } else {
                                            layoutMode = .beginner
                                        }
                                        dismiss()
                                    }
                                } label: {
                                    Text(layoutMode == .beginner ? "SWITCH TO MAESTRO" : "SWITCH TO BEGINNER")
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
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
                                                    lineWidth: 1.5
                                                )
                                        )
                                }
                                .scaleEffect(isButtonPressed ? 1.04 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.4), value: isButtonPressed)
                            }

                        case .guide:
                            MenuSection(title: "THE GAME", gold: gold) {
                                MenuTextRow("ReFret drills you on note names across the guitar neck. Each round covers one fret — from open strings (round 0) through fret 19. Complete all strings on a fret to advance.")
                            }
                            MenuSection(title: "CONSOLES", gold: gold) {
                                MenuTextRow("BEGINNER — Six buttons appear, one per string, each showing a note name. Tap the correct note for the highlighted string. Notes are shown before each round.")
                                MenuTextRow("MAESTRO — No labels. Recall the correct note name from memory and tap it.")
                            }
                            MenuSection(title: "LESSON STYLES", gold: gold) {
                                MenuTextRow("SEQUENTIAL — Notes are revealed string by string before each round. Answer each in order.")
                                MenuTextRow("CHORD — All string positions are active at once. Answer the highlighted string.")
                            }
                            MenuSection(title: "TOOLBAR BUTTONS", gold: gold) {
                                MenuTextRow("FRETBOARD — Shows all note names at the current fret position for reference.")
                                MenuTextRow("AUTO — Plays correct answers automatically. Use to listen and learn. Tap again to stop.")
                                MenuTextRow("REV — Reverses the play direction between ascending and descending frets mid-round.")
                            }
                            MenuSection(title: "SCORING", gold: gold) {
                                MenuTextRow("Each correct answer earns $1 (Beginner) or $2 (Maestro). Wrong answers score nothing. Wallet total carries forward between rounds.")
                            }

                        case .audio:
                            MenuSection(title: "AUDIO", gold: gold) {
                                MenuTextRow("Use the AUDIO tab to select guitar sound preset and tempo settings.")
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .onAppear { directionLockActive = false }
            .navigationTitle(option.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
        }
    }
}
