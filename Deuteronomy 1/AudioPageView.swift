import SwiftUI

private struct AudioGoldPickerRow<T: Hashable>: View {
    let label: String
    let options: [(label: String, value: T)]
    @Binding var selection: T

    private let gold = Color(red: 0.95, green: 0.82, blue: 0.47)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(options, id: \.label) { option in
                    let isSelected = selection == option.value
                    Button(action: { selection = option.value }) {
                        Text(option.label)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? gold : Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? gold : gold.opacity(0.45), lineWidth: 1.5)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AudioMenuSection<Content: View>: View {
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

struct AudioPageView: View {
    @Bindable var audioSettings: AudioSettings
    let availableBackingTracks: [BackingTrack]
    let onDone: () -> Void

    private var hasBackingTracks: Bool {
        !availableBackingTracks.isEmpty
    }

    private let gold = Color(red: 0.95, green: 0.82, blue: 0.47)

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
                        AudioMenuSection(title: "GUITAR SOUND", gold: gold) {
                            AudioGoldPickerRow(
                                label: "Preset",
                                options: GuitarTonePreset.allCases.map { (label: $0.rawValue, value: $0) },
                                selection: $audioSettings.guitarTonePreset
                            )
                        }

                        AudioMenuSection(title: "TEMPO", gold: gold) {
                            AudioGoldPickerRow(
                                label: "Increase Per Round",
                                options: TempoIncreasePerRound.allCases.map { (label: $0.title, value: $0) },
                                selection: $audioSettings.tempoIncreasePerRound
                            )
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            #if os(iOS)
            .navigationTitle("AUDIO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
            #else
            .navigationTitle("AUDIO")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { onDone() }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
            #endif
        }
    }
}
