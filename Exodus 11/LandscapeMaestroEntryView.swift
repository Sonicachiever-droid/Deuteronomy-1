//
//  LandscapeMaestroEntryView.swift
//  Exodus 11
//
//  Entry point for Landscape Maestro Mode
//

import SwiftUI

struct LandscapeMaestroEntryView: View {
    @State private var showGameplay = false
    @State private var playStartingFret: Int = 0
    @State private var playRepetitions: Int = 1
    @State private var playInfiniteRepetitions: Bool = false
    @State private var playDirectionRawValue: String = LessonDirection.ascending.rawValue
    @State private var playEnableHighFrets: Bool = false
    @State private var playLessonStyle: String = "random"
    @State private var playProgression: String = "lowToHigh"
    @State private var walletDollars: Int = 0
    @State private var balanceDollars: Int = 0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Full screen elephant tolex background
                FullScreenElephantBackground()
                    .ignoresSafeArea()
                
                if showGameplay {
                    // Main landscape gameplay view
                    LandscapeMaestroGameplayView(
                        onMenuSelection: { option in
                            showGameplay = false
                        },
                        selectedMode: .freestyle,
                        selectedPhase: 1,
                        beatBPM: 100,
                        beatVolume: 0.5,
                        stringVolume: 0.8,
                        playStartingFret: $playStartingFret,
                        playRepetitions: $playRepetitions,
                        playInfiniteRepetitions: $playInfiniteRepetitions,
                        playDirectionRawValue: $playDirectionRawValue,
                        playEnableHighFrets: $playEnableHighFrets,
                        playLessonStyle: $playLessonStyle,
                        playProgression: $playProgression,
                        walletDollars: $walletDollars,
                        balanceDollars: $balanceDollars
                    )
                } else {
                    // Simple start menu
                    VStack(spacing: 30) {
                        Text("LANDSCAPE MAESTRO")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.9, blue: 0.66),
                                        Color(red: 0.90, green: 0.74, blue: 0.40),
                                        Color(red: 0.73, green: 0.55, blue: 0.26)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        
                        Text("Rotate device to landscape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button("START GAME") {
                            showGameplay = true
                        }
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.94, green: 0.82, blue: 0.53),
                                            Color(red: 0.78, green: 0.6, blue: 0.22)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    LandscapeMaestroEntryView()
}
