import SwiftUI
import Combine
import AVFoundation

// MARK: - BeginnerGameEngine Logic: Remaining Helpers (Step 5)

extension BeginnerGameEngine {

    func shiftFretSpan(by delta: Int) {
        guard delta != 0 else { return }
        withAnimation(.easeInOut(duration: 1.3)) {
            state.currentFretStart = min(max(state.currentFretStart + delta, minFretOffset), maxFretOffset)
        }
    }

    func shiftWindow(by delta: Int) {
        let proposed = state.currentWindowRow + delta
        let clamped = min(max(proposed, 0), 7)
        guard clamped != state.currentWindowRow else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            state.currentWindowRow = clamped
        }
    }

    func nextThumbState(after thumbState: ThumbGlowState) -> ThumbGlowState {
        switch thumbState {
        case .neutral: return .green
        case .orange: return .green
        case .green: return .red
        case .red: return .neutral
        }
    }
    // fretIndicatorOverlay — moved to BeginnerSubviews.swift
    // beatPulseOverlay — moved to BeginnerSubviews.swift

    // handleMainTimerTick, applyLivePlayRepetitionChangeIfNeeded,
    // beginnerTargetScaleRepetitionsRemaining, updateDirectionLockState,
    // handleContentOnAppear, initializeGameplaySession, startGameFromBeginning
    // — moved to BeginnerGameplayLogic.swift (Step 4d)
    // beginnerRewardPolicyForCurrentStage, beginnerRewardStringAssignments,
    // beginnerRewardChordPayloadForCurrentStage, beginnerRewardMIDINote,
    // scheduleBeginnerRewardChordThenAdvance, scheduleBeginnerAdvanceAfterFinalNoteHold,
    // handlePendingBeginnerRewardPlaybackIfNeeded, handlePendingSequentialRepeatResetIfNeeded,
    // handlePendingRoundShiftIfNeeded, handlePendingMidiStopIfNeeded, advanceBeginnerScaleStage,
    // transposedSharpNote, transposedNote, applyBeginnerBassTransposeForCurrentStage,
    // ensureBeginnerRoundOneRevealSequenceStarted, updateBeginnerRoundOneRevealSequence,
    // updateNoteRevealProgressionIfNeeded, handleBeginnerAutoPlayIfNeeded,
    // beginnerAutoPlayPreferredStringOrder
    // — moved to BeginnerGameplayLogic.swift (Step 4c)

    // submitAnswer, advanceGame, prepareCurrentQuestion, payoutForRound, randomIncorrectNote,
    // handleBeginnerConsoleButtonPress, handleBeginnerRoundOneProgressionIfNeeded,
    // handleBeginnerChordProgressionIfNeeded, playCurrentPromptedGuitarNotes, playGuitarNote
    // — moved to BeginnerGameplayLogic.swift (Step 4b)

    func textWidth(for text: String, font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return ceil(text.size(withAttributes: attributes).width)
    }

    // handleGameplayMenuSelection, handleHintButtonPress, handleAudioPageDismiss
    // — moved to BeginnerGameplayLogic.swift (Step 4a)

    // developerConsoleFrame — moved to BeginnerSubviews.swift

    func handleStartupSpeech(for phase: StartupSequenceView.Phase) {
        guard audioEngineEnabled else { return }
        switch phase {
        case .systemOnline:
            if startupSpeechPhase == .pendingSystem {
                audio.gameplayAudioEngine.speakStartupAlert("SYSTEM ONLINE", volume: stringVolume)
                startupSpeechPhase = .pendingPhase
            }
        case .phaseOne:
            if startupSpeechPhase == .pendingPhase {
                audio.gameplayAudioEngine.speakStartupAlert("PHASE ONE", volume: stringVolume)
                startupSpeechPhase = .pendingArmed
            }
        case .armed:
            if startupSpeechPhase == .pendingArmed {
                audio.gameplayAudioEngine.speakStartupAlert(layoutMode == .beginner ? beginnerStartupArmedText : "MEMORIZATION SEQUENCE ARMED", volume: stringVolume)
                startupSpeechPhase = .idle
            }
        }
    }

    // maestroThumbOverlay — moved to BeginnerSubviews.swift

    // transportButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonState — moved to BeginnerSubviews.swift

    func applyTempoForRound(_ round: Int) {
        let increase = audioSettings.tempoIncreasePerRound.rawValue
        let effective = max(audioSettings.startingBPM + round * increase, 40)
        SharedAudioEngine.shared.setTempo(bpm: Double(effective))
    }

    /// Returns the Date of the next beat-1 or beat-3 of a 4/4 measure,
    /// always waiting for the START of the next full measure before the
    /// first note, so playback enters cleanly on the downbeat.
    /// If the MIDI isn't playing, falls back to a 2-beat interval.
    func nextOnAndThreeBeatDate(after date: Date, waitForDownbeat: Bool = false) -> Date {
        let bpm = Double(max(audioSettings.startingBPM, 40))
        let secondsPerBeat = 60.0 / bpm
        guard audio.midiEngine.isPlaying else {
            return date.addingTimeInterval(secondsPerBeat * 2)
        }
        let currentBeat = audio.midiEngine.currentBeatPosition()
        let currentBeatFloor = floor(currentBeat)
        let beatInMeasure = Int(currentBeatFloor) % 4   // 0,1,2,3
        let fractionalRemaining = (currentBeatFloor + 1.0) - currentBeat
        let secondsToNextWholeBeat = fractionalRemaining * secondsPerBeat

        if waitForDownbeat {
            // Wait for the top of the next measure (beat 0), then fire on beat 0
            let beatsToNextMeasureStart = Double(4 - beatInMeasure)
            let seconds = secondsToNextWholeBeat + (beatsToNextMeasureStart - 1.0) * secondsPerBeat
            return date.addingTimeInterval(max(seconds, 0.05))
        }

        // Normal: target next beat 0 or 2 within the measure
        let beatsUntilNext: Double
        switch beatInMeasure {
        case 0: beatsUntilNext = 2   // next target is beat 2
        case 1: beatsUntilNext = 1   // next target is beat 2
        case 2: beatsUntilNext = 2   // next target is beat 0 of next measure
        case 3: beatsUntilNext = 1   // next target is beat 0 of next measure
        default: beatsUntilNext = 2
        }
        let secondsToTarget = secondsToNextWholeBeat + (beatsUntilNext - 1.0) * secondsPerBeat
        return date.addingTimeInterval(max(secondsToTarget, 0.05))
    }

    func syncBackingTrackPlayback(allowResumeFromPause: Bool = false) {
        guard !availableBackingTracks.isEmpty else {
            audio.midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
        guard backingTrackShouldPlayInGameplay else {
            audio.midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        guard !state.transportStoppedForResume else {
            isBackingTrackPlaying = false
            return
        }

        guard let selectedTrackID = audioSettings.selectedBackingTrackID,
              let selectedTrack = availableBackingTracks.first(where: { $0.id == selectedTrackID }),
              let trackURL = selectedTrack.resourceURL() else {
            audio.midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        applyBeginnerBassTransposeForCurrentStage()
        
        // If allowed and same track was paused, resume from that position
        if allowResumeFromPause {
            audio.midiEngine.resume()
            isBackingTrackPlaying = audio.midiEngine.isPlaying
            return
        }

        // Skip restart if the same URL is already playing — avoids mid-beat click
        if audio.midiEngine.isPlaying, audio.midiEngine.activeURL == trackURL {
            isBackingTrackPlaying = true
            return
        }

        audio.midiEngine.play(url: trackURL, title: selectedTrack.title, loop: true)
        isBackingTrackPlaying = audio.midiEngine.isPlaying
    }

    // handleFretboardButtonPress, handleRoundStartButton, handleStartButtonPress,
    // handleRoundStopButton, resumeRoundFromTransportStop, handleRoundResetButton
    // — moved to BeginnerGameplayLogic.swift (Step 4a)

    func postponeBeatDeadlineForAssist() {
        guard !isCodeScreensaverMode, modeVariant == .beat else { return }
        let bpm = Double(max(beatBPM, 60))
        beatQuestionDeadline = .now.addingTimeInterval(max(AnimationDurations.armedFlashPeriod, 120.0 / bpm))
    }

    func showDeveloperPrompt(_ text: String) {
        developerPromptText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self else { return }
            if self.developerPromptText == text {
                self.developerPromptText = ""
            }
        }
    }

    // MARK: - Private Helper Methods
    
    func midiNoteValue(forNote note: String) -> Int? {
        let noteToMIDI: [String: Int] = [
            "C": 60, "C♯": 61, "D♭": 61,
            "D": 62, "D♯": 63, "E♭": 63,
            "E": 64,
            "F": 65, "F♯": 66, "G♭": 66,
            "G": 67, "G♯": 68, "A♭": 68,
            "A": 69, "A♯": 70, "B♭": 70,
            "B": 71
        ]
        return noteToMIDI[note]
    }
}

// MARK: - BeginnerGameEngine Computed Properties (Step 5)

extension BeginnerGameEngine {

    func beginnerChordSuffixDisplay(_ rawSuffix: String) -> String {
        switch rawSuffix {
        case "m Pentatonic": return "m Pentatonic"
        case "MINOR": return "m"
        case "MINOR 7": return "m7"
        case "MINOR ADD 9": return "madd9"
        case "MINOR ADD 11": return "madd11"
        case "7 SUS 4": return "7sus4"
        case "MINOR 11": return "m11"
        case "MAJOR": return "Maj"
        case "6": return "6"
        case "ADD 9": return "add9"
        case "6/9": return "6/9"
        case "SUS 2": return "sus2"
        case "SUS 4": return "sus4"
        default: return rawSuffix
        }
    }

    var beginnerScaleStages: [BeginnerScaleStage] {
        beginnerScaleTemplates.map { template in
            let root = transposedNote(template.root, by: state.scaleCycleSemitoneOffset, useFlats: beginnerUsesFlats)
            let notes = template.intervals.map { interval in
                transposedNote(template.root, by: state.scaleCycleSemitoneOffset + interval, useFlats: beginnerUsesFlats)
            }
            let stageTitle = "\(root)\(beginnerChordSuffixDisplay(template.titleSuffix))"

            return BeginnerScaleStage(
                title: stageTitle,
                notes: notes,
                bassSemitoneTarget: template.bassSemitoneTarget + state.scaleCycleSemitoneOffset,
                endsCycle: template.endsCycle
            )
        }
    }

    var beginnerCurrentScaleStage: BeginnerScaleStage {
        let clampedIndex = min(max(state.scaleStageIndex, 0), max(beginnerScaleStages.count - 1, 0))
        return beginnerScaleStages[clampedIndex]
    }

    var beginnerCurrentScaleNotes: [String] {
        beginnerCurrentScaleStage.notes
    }

    var beginnerCurrentScaleTitle: String {
        beginnerCurrentScaleStage.title
    }

    var chordNoteStringMap: [Int] {
        let notes = beginnerCurrentScaleNotes
        let fret = max(state.currentRound, 0)
        var map: [Int] = []
        var usedStrings: Set<Int> = []

        for note in notes {
            var foundString: Int?
            // Search strings in low-to-high order (6,5,4,3,2,1), skipping already-used strings
            for stringNumber in stride(from: 6, through: 1, by: -1) {
                if !usedStrings.contains(stringNumber) && guitarNoteName(forString: stringNumber, fret: fret, useFlats: beginnerUsesFlats) == note {
                    foundString = stringNumber
                    usedStrings.insert(stringNumber)
                    break
                }
            }
            // If note not found on any unused string, skip it (shouldn't happen for valid scales)
            if let stringNum = foundString {
                map.append(stringNum)
            }
        }
        return map
    }

    var beginnerCurrentBassSemitoneTarget: Int {
        beginnerCurrentScaleStage.bassSemitoneTarget
    }

    var beginnerRewardPolicies: [BeginnerRewardPolicyKey: BeginnerRewardPolicy] {
        var table: [BeginnerRewardPolicyKey: BeginnerRewardPolicy] = [:]
        let defaultPolicy = BeginnerRewardPolicy(
            isRewardEnabled: true,
            delayBeats: 3.0,
            sustainMultiplier: 3.0,
            preferredStrings: nil
        )
        for stageIndex in 1..<max(beginnerScaleStages.count, 1) {
            table[BeginnerRewardPolicyKey(stageIndex: stageIndex, fret: nil)] = defaultPolicy
        }
        return table
    }

    var beginnerPentatonicProgressText: String {
        let notes = beginnerCurrentScaleNotes
        let count = min(max(state.pentatonicRevealCount, 0), notes.count)
        return notes.prefix(count).joined(separator: " ")
    }


    var shouldShowLegacyRoundZeroIntro: Bool {
        beginnerRoundOneStartingFret == 0
    }

    func getWalletColor() -> Color {
        .green
    }

    func getRepetitionCountColor() -> Color {
        .pink
    }

    var beginnerRoundStatusText: String? {
        guard layoutMode == .beginner else { return nil }

        // Sequential style: show revealed notes one by one
        if lessonStyle == .sequential {
            guard !isCodeScreensaverMode else { return nil }

            if let pendingSequentialRepeatDisplayText = state.pendingSequentialRepeatDisplayText {
                return pendingSequentialRepeatDisplayText
            }

            let revealCount = min(state.sequentialRevealCount, sequentialNoteGenerator.currentNoteSequence.count)
            let revealedNotes = sequentialNoteGenerator.currentNoteSequence
                .prefix(revealCount)
                .map(guitarNoteDisplayText)
                .joined(separator: " ")
            return revealedNotes
        }

        // Chord style: existing behavior
        if !state.answerBoxReady,
           !state.roundOneIntroActive {
            return nil
        }
        switch beginnerRoundZeroIntroDisplayPhase {
        case .centeredRoundZeroChordMode:
            return nil
        case .roundZeroHeader:
            return beginnerCurrentScaleTitle
        case .roundZeroScaleTitle:
            return beginnerCurrentScaleTitle
        case .noteReveal, .inactive:
            break
        }
        let progressLine = beginnerPentatonicProgressText
        if progressLine.isEmpty {
            return guitarNoteDisplayText(beginnerCurrentScaleTitle)
        }
        return "\(guitarNoteDisplayText(beginnerCurrentScaleTitle))\n\(guitarNoteDisplayText(progressLine))"
    }

    var beginnerCenteredStatusMessage: String? {
        guard layoutMode == .beginner else { return nil }

        // Sequential style: show intro message during startup
        if lessonStyle == .sequential {
            if isCodeScreensaverMode && startupSequenceActivated {
                let startupState = StartupSequenceView.state(
                    for: startupSequenceElapsed,
                    showFullSequence: false,
                    armedText: "SEQUENTIAL MODE ARMED"
                )
                if startupState.phase == .armed {
                    return "SEQUENTIAL MODE\nARMED"
                }
            }
            return nil
        }

        return nil
    }

    var beginnerCenteredStatusColor: Color {
        Color.green.opacity(0.98)
    }

    var beginnerRoundZeroIntroDisplayPhase: BeginnerRoundZeroIntroDisplayPhase {
        guard layoutMode == .beginner,
              state.roundOneIntroActive,
              state.showRoundZeroIntroSequence
        else {
            return .inactive
        }

        let currentBeatBucket = Int(floor(state.roundRevealElapsedBeats))
        let startBeatBucket = state.introStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - startBeatBucket, 0)

        if elapsedBeatBuckets < 2 {
            return .roundZeroHeader
        }
        if elapsedBeatBuckets < 4 {
            return .roundZeroScaleTitle
        }
        return .noteReveal
    }

    var beginnerAcceptsGameplayAnswers: Bool {
        return !state.roundOneIntroActive
    }

    var playDirection: LessonDirection {
        LessonDirection(rawValue: playDirectionRawValue) ?? .ascending
    }

    var isProgressionLowToHigh: Bool { playProgression == "lowToHigh" }

    var activeStringOrder: [Int] {
        let baseOrder: [Int] = {
            let base: [Int] = selectedMode == .oneHand ? [1, 2, 3, 4] : [1, 2, 3, 4, 5, 6]
            return (modeVariant == .freestyle && isProgressionLowToHigh) ? base.reversed() : base
        }()
        switch modeVariant {
        case .chord:
            return Array(baseOrder.enumerated().compactMap { index, value in
                index.isMultiple(of: 2) ? value : nil
            })
        case .freestyle, .beat:
            return baseOrder
        }
    }

    var effectivePlayRepetitions: Int {
        if playInfiniteRepetitions {
            return Int.max // Use very large number for infinite mode
        }
        return max(playRepetitions, 1)
    }

    var beginnerRoundTwoStartsDescending: Bool {
        playDirection == .descending
    }

    var beginnerLowerFretBoundary: Int {
        0
    }

    var beginnerUpperFretBoundary: Int {
        playEnableHighFrets ? 19 : 12
    }

    var clampedBeginnerStartingFret: Int {
        min(max(playStartingFret, beginnerLowerFretBoundary), beginnerUpperFretBoundary)
    }

    var beginnerRoundOneStartingFret: Int {
        clampedBeginnerStartingFret
    }

    var beginnerRoundTwoStartingFret: Int {
        clampedBeginnerStartingFret
    }

    var beginnerRoundOneStartsDescending: Bool {
        playDirection == .descending
    }

    var beginnerUsesFlats: Bool {
        guard layoutMode == .beginner else { return false }
        return state.isDescendingPhase
    }

    var backingTrackShouldPlayInGameplay: Bool {
        guard layoutMode == .beginner else { return false }
        guard !isCodeScreensaverMode else { return false }
        return true
    }

    var startupStartButtonAttentionActive: Bool {
        guard layoutMode == .beginner else { return false }
        guard isCodeScreensaverMode else { return false }
        guard !isLaunchTransitionAnimating else { return false }

        if !startupSequenceActivated {
            return true
        }

        let startupState = StartupSequenceView.state(
            for: startupSequenceElapsed,
            showFullSequence: layoutMode != .beginner,
            armedText: beginnerStartupArmedText
        )
        return startupState.phase == .armed
    }

    var canPressStopButton: Bool {
        !state.isRoundArmed && !isCodeScreensaverMode && !isRoundPaused
    }

    var shouldLockPlayDirection: Bool {
        guard layoutMode == .beginner else { return false }
        return !state.isRoundArmed
    }

    var beginnerStartupArmedText: String {
        if layoutMode == .beginner {
            if lessonStyle == .sequential { return "SEQUENTIAL MODE ARMED" }
            return "CHORD MODE ARMED"
        }
        return "Memorization Sequence Armed"
    }

}
