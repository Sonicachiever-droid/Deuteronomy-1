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
        // Only allow landscape lock if maestro mode
        if savedMode == "maestro" && savedOrientation == Orientation.landscape.rawValue {
            AppDelegate.orientationLock = .landscape
        } else {
            AppDelegate.orientationLock = .portrait
        }
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
        if selectedModeRawValue == "beginner" {
            layoutMode = .beginner
        } else if selectedModeRawValue == "maestro" {
            layoutMode = .maestro
        }
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
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        VStack(spacing: 20) {
                            Text("Choose Console")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            VStack(spacing: 12) {
                                Button {
                                    layoutMode = .beginner
                                } label: {
                                    Text("Beginner Console")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.9))
                                        .cornerRadius(12)
                                }
                                Button {
                                    layoutMode = .maestro
                                } label: {
                                    Text("Maestro Console")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray.opacity(0.9))
                                        .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: 320)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
                    }
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
                    // Apply saved orientation for maestro
                    if orientationRawValue == Orientation.landscape.rawValue {
                        AppDelegate.orientationLock = .landscape
                        #if os(iOS)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)) { _ in }
                        }
                        #endif
                    } else {
                        AppDelegate.orientationLock = .portrait
                        #if os(iOS)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
                        }
                        #endif
                    }
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

    var body: some View {
        NavigationStack {
            Form {
                switch option {
                case .home:
                    Section("Progress") {
                        LabeledContent("Wallet", value: "\(walletPoints)")
                        LabeledContent("Balance", value: "\(balancePoints)")
                    }
                    if layoutMode == .maestro {
                        Section("Orientation") {
                            Picker("Layout", selection: $orientationRawValue) {
                                Text("Portrait").tag(Orientation.portrait.rawValue)
                                Text("Landscape").tag(Orientation.landscape.rawValue)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                case .learn:
                    Section("Lesson Setup") {
                        if layoutMode == .beginner {
                            Picker("Style", selection: $lessonStyleRawValue) {
                                Text("Sequential").tag("sequential")
                                Text("Chord").tag("chord")
                            }
                            .pickerStyle(.segmented)
                        }

                        Stepper("Repetitions: \(repetitionDisplay)", value: $repetitions, in: 1...8)
                            .disabled(infiniteRepetitions)

                        Toggle("Infinite Repetitions", isOn: $infiniteRepetitions)

                        Stepper("Starting Fret: \(startingFret)", value: $startingFret, in: 0...(enableHighFrets ? 19 : 12))
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
                        Picker("Direction", selection: Binding(
                            get: { directionRawValue },
                            set: { newValue in
                                let isDescending = newValue == LessonDirection.descending.rawValue
                                if isDescending && descendingLocked { return }
                                if !isDescending && ascendingLocked { return }
                                directionRawValue = newValue
                            }
                        )) {
                            Text("Ascending").tag(LessonDirection.ascending.rawValue)
                            Text("Descending").tag(LessonDirection.descending.rawValue)
                        }
                        .pickerStyle(.segmented)

                        let progressionLocked = layoutMode == .beginner && lessonStyleRawValue == "chord"
                        Picker("Progression", selection: $progressionRawValue) {
                            Text("High → Low").tag("highToLow")
                            Text("Low → High").tag("lowToHigh")
                        }
                        .pickerStyle(.segmented)
                        .disabled(progressionLocked)
                        .colorMultiply(progressionLocked ? .red : .white)

                        Toggle("Enable High Frets (12+)", isOn: $enableHighFrets)
                    }
                    .onChange(of: enableHighFrets) { _, isEnabled in
                        if !isEnabled {
                            startingFret = min(startingFret, 12)
                        }
                    }

                    Section {
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
                            HStack {
                                Spacer()
                                Text(layoutMode == .beginner ? "Switch to Maestro Mode" : "Switch to Beginner Mode")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .scaleEffect(isButtonPressed ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.4), value: isButtonPressed)
                    }
                case .guide:
                    Section("Controls") {
                        Text("FRETBOARD: Toggles a visual guide showing all notes at current fret position.")
                        Text("AUTO: Toggles autoplay mode (automatically plays correct notes).")
                    }
                    Section("Modes") {
                        Text("Choose Beginner Modes to familiarize yourself with fretboard.")
                        Text("Choose Maestro mode to test your knowledge.")
                        Text("Sequential teaches Fret Notes by repetition. Choose progression from high to low or low to high.")
                        Text("Chord teaches chords formed from Fret notes.")
                    }
                case .audio:
                    Section("Audio") {
                        Text("Use the in-game AUDIO page for backing track and instrument mix settings.")
                    }
                }
            }
            .onAppear { directionLockActive = false }
            .navigationTitle(option.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
