import SwiftUI

private struct VolumeSliderRow: View {
    let label: String
    @Binding var value: Float
    private let gold = Color.goldBorderMid

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 110, alignment: .leading)
            Slider(value: $value, in: 0.0...1.0)
                .tint(gold)
            Text("\(Int(value * 100))%")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(gold)
                .frame(width: 40, alignment: .trailing)
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

    private let gold = Color.goldBorderMid

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
                        MenuSection(title: "GUITAR TONE", gold: gold) {
                            GoldPickerRow(
                                label: "Preset",
                                options: GuitarTonePreset.allCases.map { (label: $0.rawValue, value: $0) },
                                selection: $audioSettings.guitarTonePreset
                            )
                        }

                        MenuSection(title: "VOLUME", gold: gold) {
                            VStack(spacing: 14) {
                                VolumeSliderRow(
                                    label: "Guitar",
                                    value: $audioSettings.guitarVolume
                                )
                                VolumeSliderRow(
                                    label: "Backing Track",
                                    value: $audioSettings.backingTrackVolume
                                )
                            }
                        }

                        MenuSection(title: "TEMPO", gold: gold) {
                            Stepper("Starting BPM: \(audioSettings.startingBPM)", value: $audioSettings.startingBPM, in: 40...200, step: 5)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .tint(gold)

                            GoldPickerRow(
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
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
            #else
            .navigationTitle("AUDIO")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { onDone() }
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
            #endif
        }
    }
}
