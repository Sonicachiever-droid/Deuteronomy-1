//
//  Exodus_11App.swift
//  Exodus 11
//
//  Landscape Maestro Mode - Purchasable feature for Refret
//

import SwiftUI
import AVFoundation

@main
struct Exodus_11App: App {
    init() {
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LandscapeMaestroEntryView()
        }
    }
}
