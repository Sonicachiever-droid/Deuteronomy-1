import SwiftUI
import Combine
import AVFoundation

// MARK: - BeginnerGameplayView Logic: Transport Handlers (Step 4a)
// Extracted from BeginnerGameplayView.swift.
// These are methods on BeginnerGameplayView so they have full access to all
// view state and can call sibling functions without any architectural changes.

extension BeginnerGameplayView {

    // MARK: - Menu / Audio / Fretboard

    func handleGameplayMenuSelection(_ option: GameplayMenuOption) {
        gameplayMenuExpanded = false
        if !isCodeScreensaverMode && !beginnerRuntime.isRoundArmed && !isRoundPaused {
            handleRoundStopButton()
        }
        if option == .audio {
            availableBackingTracks = BackingTrack.discoverBundledTracks()
            audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
            showAudioPage = true
            showDeveloperPrompt("MENU: AUDIO")
            return
        }
        onMenuSelection?(option)
        showDeveloperPrompt("MENU: \(option.title)")
    }

    func handleAudioPageDismiss() {
        if beginnerRuntime.transportStoppedForResume {
            resumeRoundFromTransportStop()
        }
    }

    func handleFretboardButtonPress() {
        showFretboardGuide.toggle()
        postponeBeatDeadlineForAssist()
        showDeveloperPrompt(showFretboardGuide ? "Fretboard guide ON" : "Fretboard guide OFF")
    }

    func handleHintButtonPress() {
        postponeBeatDeadlineForAssist()
        if layoutMode == .beginner {
            showFretboardGuide.toggle()
        }
        showDeveloperPrompt("HINT: \(guitarNoteDisplayText(beginnerRuntime.currentCorrectNote))")
    }

    // MARK: - Round Start

    func handleRoundStartButton(animateNeckSlideFromStartup: Bool = false) {
        if isCodeScreensaverMode {
            guard !isLaunchTransitionAnimating else { return }
            isLaunchTransitionAnimating = true
            startupNeckVisualsHidden = true
            launchTileScale = 1
            launchTileOpacity = 1
            withAnimation(.easeIn(duration: 0.4725)) {
                launchTileScale = 0.1
                launchTileOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4725) {
                isCodeScreensaverMode = false
                startupSequenceActivated = false
                startupSequenceElapsed = 0
                startupSpeechPhase = .idle
                isLaunchTransitionAnimating = false
                launchTileScale = 1
                launchTileOpacity = 1
                beginnerRuntime.questionBoxIntroProgress = 1
                handleRoundStartButton(animateNeckSlideFromStartup: true)
            }
            return
        }

        if layoutMode == .beginner {
            beginnerRuntime.reset()
        }
        isCodeScreensaverMode = false
        startupSequenceActivated = false
        startupSequenceElapsed = 0
        startupSpeechPhase = .idle
        beginnerRuntime.questionBoxIntroProgress = 1
        isRoundPaused = false
        beginnerRuntime.transportStoppedForResume = false
        beginnerRuntime.isRoundArmed = false
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil

        // Ensure reveal beat-buckets are always fresh for the active style at START
        if lessonStyle == .sequential {
            beginnerRuntime.sequentialRevealCount = 0
            beginnerRuntime.sequentialRevealStartBeatBucket = nil
        }

        startGameFromBeginning(animateNeckSlideFromStartup: animateNeckSlideFromStartup)
        updateDirectionLockState()
        if !animateNeckSlideFromStartup {
            syncBackingTrackPlayback()
        }
    }

    func handleStartButtonPress() {
        if startupStartButtonAttentionActive,
           layoutMode == .beginner,
           isCodeScreensaverMode,
           !startupSequenceActivated {
            startupSequenceActivated = true
            startupSequenceStartDate = .now
            startupSequenceElapsed = 0
            startupSpeechPhase = .pendingArmed
            beginnerRuntime.questionBoxIntroProgress = 0
            return
        }

        if beginnerRuntime.transportStoppedForResume {
            resumeRoundFromTransportStop()
            return
        }

        if isRoundPaused {
            resumeRoundFromTransportStop(forceIfPaused: true)
            return
        }

        if !beginnerRuntime.isRoundArmed {
            handleRoundResetButton()
            return
        }

        handleRoundStartButton()
    }

    // MARK: - Round Stop / Pause / Resume

    func handleRoundStopButton() {
        guard canPressStopButton else { return }

        isRoundPaused = true
        beginnerRuntime.transportStoppedForResume = true
        beginnerRuntime.roundRevealLastTickDate = nil
        midiEngine.pause()
        isBackingTrackPlaying = midiEngine.isPlaying
        beginnerRuntime.beatLightFlashOn = false
        beginnerRuntime.beatLightLastProcessedBeat = nil
        beginnerRuntime.beatLightIntroMeasureSkipped = false
        updateDirectionLockState()
    }

    func resumeRoundFromTransportStop(forceIfPaused: Bool = false) {
        guard beginnerRuntime.transportStoppedForResume || (forceIfPaused && isRoundPaused) else { return }

        beginnerRuntime.transportStoppedForResume = false
        isRoundPaused = false
        beginnerRuntime.roundRevealLastTickDate = nil
        midiEngine.resume()
        beginnerRuntime.beatLightFlashOn = false
        beginnerRuntime.beatLightLastProcessedBeat = nil
        beginnerRuntime.beatLightIntroMeasureSkipped = false
        updateDirectionLockState()
    }

    // MARK: - Reset

    func handleRoundResetButton() {
        beginnerRuntime.resetButtonPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            beginnerRuntime.resetButtonPressed = false
        }

        if layoutMode == .beginner {
            beginnerRuntime.reset()
        }
        isCodeScreensaverMode = true
        startupSequenceActivated = true
        startupSequenceStartDate = .now
        startupSequenceElapsed = 0
        startupSpeechPhase = .pendingArmed
        beginnerRuntime.questionBoxIntroProgress = 0
        isLaunchTransitionAnimating = false
        launchTileScale = 1
        launchTileOpacity = 1
        isRoundPaused = false
        beginnerRuntime.transportStoppedForResume = false
        beginnerRuntime.isRoundArmed = true
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil
        syncBackingTrackPlayback()
        startGameFromBeginning()
        developerPromptText = ""
        beginnerRuntime.answerBoxReady = false
        updateDirectionLockState()
    }
}

// MARK: - BeginnerGameplayView Logic: Answer / Submission Handlers (Step 4b)

extension BeginnerGameplayView {

    // MARK: - Maestro answer submission (thumb buttons)

    func submitAnswer(_ side: AnswerSide, force: Bool = false) {
        if layoutMode == .beginner && beginnerRuntime.isRoundArmed {
            handleRoundStartButton()
            return
        }
        if layoutMode == .beginner && isRoundPaused {
            return
        }
        if isCodeScreensaverMode {
            if !startupSequenceActivated {
                startupSequenceActivated = true
                startupSequenceStartDate = .now
                startupSequenceElapsed = 0
                startupSpeechPhase = layoutMode == .beginner ? .pendingArmed : .pendingSystem
                beginnerRuntime.questionBoxIntroProgress = 0
                return
            }

            let startupState = StartupSequenceView.state(
                for: startupSequenceElapsed,
                showFullSequence: layoutMode != .beginner,
                armedText: beginnerStartupArmedText
            )
            guard startupState.phase == .armed else { return }
            guard !isLaunchTransitionAnimating else { return }

            isLaunchTransitionAnimating = true
            startupNeckVisualsHidden = true
            launchTileScale = 1
            launchTileOpacity = 1
            withAnimation(.easeIn(duration: 0.4725)) {
                launchTileScale = 0.1
                launchTileOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4725) {
                isCodeScreensaverMode = false
                startupSequenceActivated = false
                startupSequenceElapsed = 0
                startupSpeechPhase = .idle
                startGameFromBeginning(animateNeckSlideFromStartup: true)
                isLaunchTransitionAnimating = false
                launchTileScale = 1
                launchTileOpacity = 1
                withAnimation(.easeOut(duration: 0.6)) {
                    beginnerRuntime.questionBoxIntroProgress = 1
                }
            }
            return
        }

        if isRoundPaused {
            return
        }

        if layoutMode == .beginner {
            return
        }

        guard force || !beginnerRuntime.isResolvingAnswer else { return }
        beginnerRuntime.isResolvingAnswer = true
        beatQuestionDeadline = nil
        playCurrentPromptedGuitarNotes(velocity: force ? 0.82 : 0.94)

        let isCorrect = side == beginnerRuntime.correctAnswerSide
        if isCorrect {
            if side == .left {
                leftThumbState = .green
            } else {
                rightThumbState = .green
            }
            beginnerRuntime.activeAnswerFeedback = .green
            beginnerRuntime.lastResolvedCorrectNote = beginnerRuntime.currentCorrectNote
            beginnerRuntime.lastResolvedCorrectString = beginnerRuntime.currentPromptStrings.first
        } else {
            if side == .left {
                leftThumbState = .red
            } else {
                rightThumbState = .red
            }
            beginnerRuntime.activeAnswerFeedback = .red
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            leftThumbState = .neutral
            rightThumbState = .neutral
            questionBoxAssistActive = false
            if isCorrect {
                beginnerRuntime.isResolvingAnswer = false
                advanceGame(afterCorrectAnswer: true)
            } else {
                advanceGame(afterCorrectAnswer: false)
            }
        }
    }

    // MARK: - Game progression

    func advanceGame(afterCorrectAnswer isCorrect: Bool) {
        if !isCorrect {
            beginnerRuntime.isResolvingAnswer = false
            prepareCurrentQuestion()
            return
        }

        // Skip point earning for autoplay
        guard !beginnerRuntime.isAutoPlayTriggered else {
            prepareCurrentQuestion()
            return
        }

        beginnerRuntime.correctAnswersAtCurrentFret = min(beginnerRuntime.correctAnswersAtCurrentFret + 1, 20)
        let payout = payoutForRound(beginnerRuntime.currentRound)
        beginnerRuntime.bankDollars += payout
        beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
        walletDollars = beginnerRuntime.bankDollars
        balanceDollars += payout

        if layoutMode == .beginner {
            if beginnerRuntime.isDescendingPhase {
                let requiredCorrectAnswers = effectivePlayRepetitions
                let completedAtCurrentFret = beginnerRuntime.correctAnswersAtCurrentFret

                if completedAtCurrentFret >= requiredCorrectAnswers {
                    beginnerRuntime.correctAnswersAtCurrentFret = 0

                    if beginnerRoundTwoStartsDescending {
                        if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                            beginnerRuntime.currentRound -= 1
                            prepareCurrentQuestion()
                        } else {
                            startGameFromBeginning()
                            return
                        }
                    } else {
                        if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                            beginnerRuntime.currentRound += 1
                            beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                            prepareCurrentQuestion()
                        } else {
                            startGameFromBeginning()
                            return
                        }
                    }

                    // Reset repetitions for the new chord
                    beginnerRuntime.scaleRepetitionsRemaining = requiredCorrectAnswers
                } else {
                    beginnerRuntime.scaleRepetitionsRemaining = max(requiredCorrectAnswers - completedAtCurrentFret, 1)
                }
            }

            prepareCurrentQuestion()
            return
        }

        if roundStringIndex < activeStringOrder.count - 1 {
            roundStringIndex += 1
        } else {
            roundStringIndex = 0
            if !beginnerRuntime.isDescendingPhase {
                if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                    beginnerRuntime.currentRound += 1
                    beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                } else {
                    startGameFromBeginning()
                    return
                }
            } else {
                if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                    beginnerRuntime.currentRound -= 1
                    beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
                } else {
                    startGameFromBeginning()
                    return
                }
            }
        }
    }

    func prepareCurrentQuestion() {
        if lessonStyle == .sequential {
            // Sequential style: use SequentialNoteGenerator
            let idx = sequentialNoteGenerator.sequenceProgressIndex
            guard idx < sequentialNoteGenerator.currentNoteSequence.count,
                  let nextString = sequentialNoteGenerator.expectedString else { return }
            let correctNote = sequentialNoteGenerator.currentNoteSequence[idx]
            let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
            let incorrectNote = randomIncorrectNote(excluding: correctNote, useFlats: useFlats)
            let correctOnLeft = Bool.random()
            if correctOnLeft {
                beginnerRuntime.leftChoiceNote = correctNote
                beginnerRuntime.rightChoiceNote = incorrectNote
            } else {
                beginnerRuntime.leftChoiceNote = incorrectNote
                beginnerRuntime.rightChoiceNote = correctNote
            }
            beginnerRuntime.correctAnswerSide = correctOnLeft ? .left : .right
            beginnerRuntime.currentPromptStrings = [nextString]
            beginnerRuntime.lastPromptedCorrectNote = correctNote
            beginnerRuntime.lastPromptedStringHalf = .left
            beginnerRuntime.lastPromptedStringNumber = nextString
            withAnimation(.easeInOut(duration: 1.3)) {
                beginnerRuntime.currentFretStart = max(beginnerRuntime.currentRound, 0)
            }
        } else {
            // Chord style: existing behavior
            let fret = max(beginnerRuntime.currentRound, 0)
            let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
            let targetString = activeStringOrder.isEmpty ? 1 : activeStringOrder.randomElement() ?? 1
            let correctNote = guitarNoteName(forString: targetString, fret: fret, useFlats: useFlats)
            let incorrectNote = randomIncorrectNote(excluding: correctNote, useFlats: useFlats)
            let correctOnLeft = Bool.random()

            if correctOnLeft {
                beginnerRuntime.leftChoiceNote = correctNote
                beginnerRuntime.rightChoiceNote = incorrectNote
            } else {
                beginnerRuntime.leftChoiceNote = incorrectNote
                beginnerRuntime.rightChoiceNote = correctNote
            }

            beginnerRuntime.currentPromptStrings = [targetString]
            beginnerRuntime.lastPromptedCorrectNote = correctNote
            withAnimation(.easeInOut(duration: 1.3)) {
                beginnerRuntime.currentFretStart = fret
            }
        }
    }

    func payoutForRound(_ round: Int) -> Int {
        _ = round
        return 1
    }

    func randomIncorrectNote(excluding correct: String, useFlats: Bool) -> String {
        let source = useFlats ? chromaticFlats : chromaticSharps
        let pool = source.filter { $0 != correct }
        return pool.randomElement() ?? "C"
    }

    // MARK: - Beginner console button handling

    func handleBeginnerConsoleButtonPress(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard layoutMode == .beginner else { return }
        if beginnerRuntime.isRoundArmed {
            handleRoundStartButton()
            return
        }
        if isCodeScreensaverMode {
            submitAnswer(.left)
            return
        }

        let canAdvanceBeginnerProgression = !beginnerRuntime.isResolvingAnswer
            && !beginnerRuntime.pendingRewardStageAdvance
            && !beginnerRuntime.roundOneIntroActive

        if lessonStyle == .sequential {
            beginnerRuntime.activePickedStringNumbers = Array(beginnerRuntime.answeredNotesByStringAtCurrentFret.keys)
        } else {
            beginnerRuntime.activePickedStringNumbers = [selectedString]
        }
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.lastPickedNote = lessonStyle == .sequential ? nil : selectedNote
        if lessonStyle != .sequential {
            beginnerRuntime.answeredNotesByStringAtCurrentFret[selectedString] = selectedNote
        }
        beginnerRuntime.answerBoxReady = true
        beginnerRuntime.activeAnswerFeedback = nil
        questionBoxAssistActive = false

        guard canAdvanceBeginnerProgression else {
            playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
            return
        }

        if lessonStyle == .sequential {
            handleBeginnerRoundOneProgressionIfNeeded(selectedNote: selectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
        } else if lessonStyle == .chord {
            handleBeginnerChordProgressionIfNeeded(selectedNote: selectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
        }

        playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
    }

    func handleBeginnerRoundOneProgressionIfNeeded(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard lessonStyle == .sequential else { return }

        guard !sequentialNoteGenerator.currentNoteSequence.isEmpty else { return }
        guard !sequentialNoteGenerator.isSequenceComplete() else { return }

        guard sequentialNoteGenerator.isValidAnswer(note: selectedNote, string: selectedString) else {
            // Wrong answer — restart the sequence
            let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
            sequentialNoteGenerator.resetForNewFret()
            sequentialNoteGenerator.generateNoteSequence(
                for: max(beginnerRuntime.currentRound, 0),
                useFlats: useFlats,
                lowToHigh: isProgressionLowToHigh
            )
            beginnerRuntime.sequentialRevealCount = 0
            beginnerRuntime.sequentialRevealStartBeatBucket = nil
            beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            beginnerRuntime.activePickedStringNumbers = []
            beginnerRuntime.lastPickedNote = nil
            beginnerRuntime.answerBoxReady = false
            return
        }

        // Correct answer — commit to answered set
        beginnerRuntime.answeredNotesByStringAtCurrentFret[selectedString] = selectedNote
        beginnerRuntime.activePickedStringNumbers = Array(beginnerRuntime.answeredNotesByStringAtCurrentFret.keys)
        beginnerRuntime.lastPickedNote = selectedNote

        beginnerPressedButtonIndex = buttonIndex
        beginnerPressedButtonCorrect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            beginnerPressedButtonIndex = nil
            beginnerPressedButtonCorrect = false
        }
        if !beginnerRuntime.isAutoPlayTriggered {
            let payout = payoutForRound(beginnerRuntime.currentRound)
            beginnerRuntime.bankDollars += payout
            beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
            walletDollars = beginnerRuntime.bankDollars
            balanceDollars += payout
        }
        sequentialNoteGenerator.advanceSequence()

        if sequentialNoteGenerator.isSequenceComplete() {
            if beginnerRuntime.scaleRepetitionsRemaining <= 1 {
                if beginnerRuntime.pendingRoundShiftBeatPosition == nil {
                    beginnerRuntime.pendingRoundShiftBeatPosition = beginnerRuntime.roundRevealElapsedBeats + 2.0
                }
            } else {
                beginnerRuntime.scaleRepetitionsRemaining -= 1
                beginnerRuntime.pendingSequentialRepeatDisplayText = sequentialNoteGenerator.currentNoteSequence
                    .map(guitarNoteDisplayText)
                    .joined(separator: " ")
                beginnerRuntime.pendingSequentialRepeatResetBeatPosition = beginnerRuntime.roundRevealElapsedBeats + 2.0
            }
        }
    }

    func handleBeginnerChordProgressionIfNeeded(selectedNote: String, selectedString: Int, buttonIndex: Int) {
        guard lessonStyle == .chord,
              beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count
        else { return }

        let currentScaleNotes = beginnerCurrentScaleNotes
        guard !currentScaleNotes.isEmpty else { return }

        let safeSequenceIndex = min(max(beginnerRuntime.scaleSequenceIndex, 0), currentScaleNotes.count - 1)
        if safeSequenceIndex != beginnerRuntime.scaleSequenceIndex {
            beginnerRuntime.scaleSequenceIndex = safeSequenceIndex
        }

        let expectedNote = currentScaleNotes[safeSequenceIndex]
        if selectedNote == expectedNote {
            beginnerPressedButtonIndex = buttonIndex
            beginnerPressedButtonCorrect = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                beginnerPressedButtonIndex = nil
                beginnerPressedButtonCorrect = false
            }
            if !beginnerRuntime.isAutoPlayTriggered {
                let payout = payoutForRound(beginnerRuntime.currentRound)
                beginnerRuntime.bankDollars += payout
                beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
                walletDollars = beginnerRuntime.bankDollars
                balanceDollars += payout
            }
            if safeSequenceIndex == currentScaleNotes.count - 1 {
                if let rewardPolicy = beginnerRewardPolicyForCurrentStage() {
                    playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
                    scheduleBeginnerRewardChordThenAdvance(selectedString: selectedString, policy: rewardPolicy)
                } else {
                    playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
                    scheduleBeginnerAdvanceAfterFinalNoteHold(selectedString: selectedString)
                }
                return
            } else {
                beginnerRuntime.scaleSequenceIndex += 1
            }
        } else {
            beginnerPressedButtonIndex = buttonIndex
            beginnerPressedButtonCorrect = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                beginnerPressedButtonIndex = nil
                beginnerPressedButtonCorrect = false
            }
            beginnerRuntime.scaleSequenceIndex = (selectedNote == currentScaleNotes[0]) ? 1 : 0
        }
    }

    // MARK: - Audio playback helpers

    func playCurrentPromptedGuitarNotes(velocity: Float) {
        let fret = max(beginnerRuntime.currentRound, 0)
        let promptStrings = beginnerRuntime.currentPromptStrings.isEmpty ? [1] : beginnerRuntime.currentPromptStrings
        for (index, stringNumber) in promptStrings.enumerated() {
            let delay = Double(index) * 0.035
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playGuitarNote(forString: stringNumber, fret: fret, velocity: velocity)
            }
        }
    }

    func playGuitarNote(forString stringNumber: Int, fret: Int, velocity: Float) {
        guitarNoteEngine.play(string: stringNumber, fret: max(fret, 0), velocity: velocity)
    }
}

// MARK: - BeginnerGameplayView Logic: Reward / Progression Handlers (Step 4c)

extension BeginnerGameplayView {

    func beginnerRewardPolicyForCurrentStage() -> BeginnerRewardPolicy? {
        guard layoutMode == .beginner else { return nil }

        let currentFret = max(beginnerRuntime.currentRound, 0)
        let specificKey = BeginnerRewardPolicyKey(stageIndex: beginnerRuntime.scaleStageIndex, fret: currentFret)
        if let policy = beginnerRewardPolicies[specificKey], policy.isRewardEnabled {
            return policy
        }

        let fallbackKey = BeginnerRewardPolicyKey(stageIndex: beginnerRuntime.scaleStageIndex, fret: nil)
        if let policy = beginnerRewardPolicies[fallbackKey], policy.isRewardEnabled {
            return policy
        }

        return nil
    }

    func beginnerRewardStringAssignments(forChordNotes chordNotes: [String], preferredStrings: [Int]?) -> [(Int, String)] {
        let allStringsDescending = [6, 5, 4, 3, 2, 1]
        let preferredSequence = preferredStrings ?? []
        let fallbackSequence = allStringsDescending.filter { !preferredSequence.contains($0) }
        let candidateSequence = preferredSequence + fallbackSequence
        let rewardDisplayFret = max(beginnerRuntime.currentRound, 0)
        var unusedStrings = candidateSequence
        var assignments: [(Int, String)] = []
        let strictStringPriority = [1, 6, 5, 4, 3, 2]

        for chordNote in chordNotes {
            let matchingStrings = unusedStrings.filter {
                guitarNoteName(forString: $0, fret: rewardDisplayFret, useFlats: false) == chordNote
                    || guitarNoteName(forString: $0, fret: rewardDisplayFret, useFlats: beginnerUsesFlats) == chordNote
            }

            guard let matchedString = strictStringPriority.first(where: { matchingStrings.contains($0) }) else {
                continue
            }
            assignments.append((matchedString, chordNote))
            unusedStrings.removeAll { $0 == matchedString }
        }

        return assignments
    }

    func beginnerRewardChordPayloadForCurrentStage(
        policy: BeginnerRewardPolicy
    ) -> (strings: [Int], notesByString: [Int: String], midiNotes: [Int]) {
        let chordNotes = Array(beginnerCurrentScaleNotes.prefix(5))
        let rewardPairs = beginnerRewardStringAssignments(forChordNotes: chordNotes, preferredStrings: policy.preferredStrings)

        var strings: [Int] = []
        var notesByString: [Int: String] = [:]
        var midiNotes: [Int] = []

        let rewardDisplayFret = max(beginnerRuntime.currentRound, 0)

        for (stringNumber, _) in rewardPairs {
            let displayedNote = guitarNoteName(forString: stringNumber, fret: rewardDisplayFret, useFlats: beginnerUsesFlats)
            guard let midiNote = beginnerRewardMIDINote(for: displayedNote, stringNumber: stringNumber) else { continue }
            strings.append(stringNumber)
            notesByString[stringNumber] = displayedNote
            midiNotes.append(midiNote)
        }

        return (strings, notesByString, midiNotes)
    }

    func beginnerRewardMIDINote(for noteName: String, stringNumber: Int) -> Int? {
        let openMIDINoteByString: [Int: Int] = [6: 40, 5: 45, 4: 50, 3: 55, 2: 59, 1: 64]
        guard let openMIDINote = openMIDINoteByString[stringNumber] else { return nil }

        let targetPitchClass = chromaticSharps.firstIndex(of: noteName)
            ?? chromaticFlats.firstIndex(of: noteName)
        guard let targetPitchClass else { return nil }

        let openPitchClass = openMIDINote % 12
        let fretOffset = (targetPitchClass - openPitchClass + 12) % 12
        return openMIDINote + fretOffset
    }

    func scheduleBeginnerRewardChordThenAdvance(selectedString: Int, policy: BeginnerRewardPolicy) {
        let rewardPayload = beginnerRewardChordPayloadForCurrentStage(policy: policy)
        guard !rewardPayload.midiNotes.isEmpty else {
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
            return
        }

        beginnerRuntime.pendingRewardStageAdvance = true
        beginnerRuntime.rewardSelectedString = selectedString
        beginnerRuntime.rewardTargetBeatPosition = beginnerRuntime.roundRevealElapsedBeats + policy.delayBeats
        beginnerRuntime.rewardScheduledStrings = rewardPayload.strings
        beginnerRuntime.rewardScheduledMIDINotes = rewardPayload.midiNotes
        beginnerRuntime.rewardScheduledNoteTextByString = rewardPayload.notesByString
        beginnerRuntime.rewardSustainMultiplier = policy.sustainMultiplier
        beginnerRuntime.rewardNoteTextByString = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString,
                  beginnerRuntime.rewardTargetBeatPosition != nil else { return }
            beginnerRuntime.activePickedStringNumbers = []
            beginnerRuntime.lastPickedNote = nil
            beginnerRuntime.answerBoxReady = false
        }
    }

    func scheduleBeginnerAdvanceAfterFinalNoteHold(selectedString: Int, holdSeconds: Double = 0.65) {
        beginnerRuntime.pendingRewardStageAdvance = true
        beginnerRuntime.rewardSelectedString = selectedString
        beginnerRuntime.rewardTargetBeatPosition = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString,
                  beginnerRuntime.rewardTargetBeatPosition == nil else { return }
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
        }
    }

    func handlePendingBeginnerRewardPlaybackIfNeeded() {
        guard layoutMode == .beginner,
              beginnerRuntime.pendingRewardStageAdvance,
              let targetBeatPosition = beginnerRuntime.rewardTargetBeatPosition,
              let selectedString = beginnerRuntime.rewardSelectedString else { return }

        let currentBeatPosition = beginnerRuntime.roundRevealElapsedBeats
        guard currentBeatPosition >= targetBeatPosition else { return }

        beginnerRuntime.rewardTargetBeatPosition = nil

        guard !beginnerRuntime.rewardScheduledMIDINotes.isEmpty else {
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            beginnerRuntime.rewardScheduledStrings = []
            beginnerRuntime.rewardScheduledMIDINotes = []
            beginnerRuntime.rewardScheduledNoteTextByString = [:]
            beginnerRuntime.rewardSustainMultiplier = 3.0
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
            return
        }

        beginnerRuntime.activePickedStringNumbers = beginnerRuntime.rewardScheduledStrings
        beginnerRuntime.answerBoxReady = true
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = beginnerRuntime.rewardScheduledNoteTextByString
        let rewardChordRingDuration = guitarNoteEngine.playChord(
            midiNotes: beginnerRuntime.rewardScheduledMIDINotes,
            velocity: 0.98,
            sustainMultiplier: beginnerRuntime.rewardSustainMultiplier
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + rewardChordRingDuration) {
            guard beginnerRuntime.pendingRewardStageAdvance,
                  beginnerRuntime.rewardSelectedString == selectedString else { return }
            beginnerRuntime.pendingRewardStageAdvance = false
            beginnerRuntime.rewardSelectedString = nil
            beginnerRuntime.rewardScheduledStrings = []
            beginnerRuntime.rewardScheduledMIDINotes = []
            beginnerRuntime.rewardScheduledNoteTextByString = [:]
            beginnerRuntime.rewardSustainMultiplier = 3.0
            advanceBeginnerScaleStage(afterCompletionFromString: selectedString, playTransitionNote: false)
        }
    }

    func handlePendingSequentialRepeatResetIfNeeded() {
        guard lessonStyle == .sequential,
              let targetBeatPosition = beginnerRuntime.pendingSequentialRepeatResetBeatPosition else { return }

        guard beginnerRuntime.roundRevealElapsedBeats >= targetBeatPosition else { return }

        beginnerRuntime.pendingSequentialRepeatResetBeatPosition = nil
        sequentialNoteGenerator.resetForNewFret()
        beginnerRuntime.sequentialRevealCount = 0
        beginnerRuntime.sequentialRevealStartBeatBucket = nil
        beginnerRuntime.answerBoxReady = false
        // Clear all answer-display state so the new repetition starts blank.
        // Without this, beginnerRuntime.activePickedStringNumbers and lastPickedNote leak from
        // the just-completed repetition, causing every string to show the
        // previous final answer when beginnerRuntime.answeredNotesByStringAtCurrentFret is empty.
        beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
        beginnerRuntime.activePickedStringNumbers = []
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil

        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        sequentialNoteGenerator.generateNoteSequence(
            for: max(beginnerRuntime.currentRound, 0),
            useFlats: useFlats,
            lowToHigh: isProgressionLowToHigh
        )
        prepareCurrentQuestion()

        DispatchQueue.main.async {
            beginnerRuntime.pendingSequentialRepeatDisplayText = nil
        }
    }

    func handlePendingRoundShiftIfNeeded() {
        guard lessonStyle == .sequential,
              let targetBeatPosition = beginnerRuntime.pendingRoundShiftBeatPosition else { return }

        let currentBeatPosition = beginnerRuntime.roundRevealElapsedBeats
        guard currentBeatPosition >= targetBeatPosition else { return }

        // 2-beat delay has passed - clear the pending shift and execute
        beginnerRuntime.pendingRoundShiftBeatPosition = nil

        // Clear white note box immediately before shift
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.answerBoxReady = false

        // Reset mode state for new fret
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        sequentialNoteGenerator.resetForNewFret()
        beginnerRuntime.sequentialRevealCount = 0
        beginnerRuntime.sequentialRevealStartBeatBucket = nil

        // Advance to next fret (or reverse direction at boundary)
        if !beginnerRuntime.isDescendingPhase {
            if beginnerRuntime.currentRound < beginnerUpperFretBoundary {
                beginnerRuntime.currentRound += 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            } else {
                // At boundary - reverse direction
                beginnerRuntime.isDescendingPhase = true
                playDirectionRawValue = LessonDirection.descending.rawValue
                beginnerRuntime.currentRound = beginnerUpperFretBoundary - 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            }
        } else {
            if beginnerRuntime.currentRound > beginnerLowerFretBoundary {
                beginnerRuntime.currentRound -= 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            } else {
                beginnerRuntime.isDescendingPhase = false
                playDirectionRawValue = LessonDirection.ascending.rawValue
                beginnerRuntime.currentRound = 1
                beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
            }
        }

        // Generate new sequence for new fret and apply bass transpose
        let useFlats = layoutMode == .beginner ? beginnerUsesFlats : false
        sequentialNoteGenerator.generateNoteSequence(for: max(beginnerRuntime.currentRound, 0), useFlats: useFlats, lowToHigh: isProgressionLowToHigh)
        applyBeginnerBassTransposeForCurrentStage()
        prepareCurrentQuestion()
    }

    func handlePendingMidiStopIfNeeded() {
        guard layoutMode == .beginner,
              let stopDate = beginnerRuntime.pendingMidiStopDate else { return }
        guard Date() >= stopDate else { return }

        // 3-beat delay has passed - stop the MIDI playback
        beginnerRuntime.pendingMidiStopDate = nil
        midiEngine.stop()
        isBackingTrackPlaying = false
    }

    func advanceBeginnerScaleStage(afterCompletionFromString selectedString: Int, playTransitionNote: Bool = true) {
        beginnerRuntime.autoPlayLastStringByNote = [:]
        let completedStageWasCycleEnd = beginnerCurrentScaleStage.endsCycle
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.rewardScheduledStrings = []
        beginnerRuntime.rewardScheduledMIDINotes = []
        beginnerRuntime.rewardScheduledNoteTextByString = [:]
        beginnerRuntime.rewardSustainMultiplier = 3.0
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        if completedStageWasCycleEnd {
            beginnerRuntime.scaleRepetitionsRemaining -= 1
            if beginnerRuntime.scaleRepetitionsRemaining > 0 {
                beginnerRuntime.scaleStageIndex = 0
                beginnerRuntime.scaleSequenceIndex = 0
                beginnerRuntime.pentatonicRevealCount = 0
                beginnerRuntime.roundOneIntroActive = true
                beginnerRuntime.roundOneSequenceStartDate = Date()
                beginnerRuntime.roundRevealElapsedBeats = 0
                if lessonStyle == .chord {
                    beginnerRuntime.showRoundZeroIntroSequence = true
                    beginnerRuntime.introStartBeatBucket = 0
                }
                return
            }
        }
        if completedStageWasCycleEnd {
            let nextFret: Int?
            if beginnerRuntime.isDescendingPhase {
                nextFret = beginnerRuntime.currentRound > beginnerLowerFretBoundary ? beginnerRuntime.currentRound - 1 : nil
            } else {
                nextFret = beginnerRuntime.currentRound < beginnerUpperFretBoundary ? beginnerRuntime.currentRound + 1 : nil
            }

            if let nextFret {
                beginnerRuntime.currentRound = nextFret
                beginnerRuntime.scaleCycleSemitoneOffset = nextFret
                beginnerRuntime.scaleStageIndex = 0
                beginnerRuntime.scaleSequenceIndex = 0
                beginnerRuntime.pentatonicRevealCount = 0
                beginnerRuntime.roundOneIntroActive = false
                beginnerRuntime.roundOneSequenceStartDate = nil
                beginnerRuntime.revealStartBeatBucket = nil
                beginnerRuntime.introStartBeatBucket = nil
                beginnerRuntime.rewardSelectedString = nil
            } else {
                // At boundary - reverse direction and keep the shared binding aligned
                if beginnerRuntime.isDescendingPhase {
                    beginnerRuntime.isDescendingPhase = false
                    playDirectionRawValue = LessonDirection.ascending.rawValue
                    beginnerRuntime.currentRound = 1
                } else {
                    beginnerRuntime.isDescendingPhase = true
                    playDirectionRawValue = LessonDirection.descending.rawValue
                    beginnerRuntime.currentRound = beginnerUpperFretBoundary - 1
                }
            }
        } else {
            beginnerRuntime.scaleStageIndex = min(beginnerRuntime.scaleStageIndex + 1, beginnerScaleStages.count - 1)
        }
        beginnerRuntime.scaleSequenceIndex = 0
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.roundOneIntroActive = true
        beginnerRuntime.roundOneSequenceStartDate = Date()
        beginnerRuntime.roundRevealElapsedBeats = 0
        if lessonStyle == .chord {
            beginnerRuntime.showRoundZeroIntroSequence = true
            beginnerRuntime.introStartBeatBucket = 0
        }
        beginnerRuntime.roundRevealLastTickDate = nil
        beginnerRuntime.answerBoxReady = false
        beginnerRuntime.lastPickedNote = nil
        applyBeginnerBassTransposeForCurrentStage()
        if playTransitionNote {
            playGuitarNote(forString: selectedString, fret: max(beginnerRuntime.currentRound, 0), velocity: 0.98)
        }
    }

    func transposedSharpNote(_ note: String, by semitones: Int) -> String {
        transposedNote(note, by: semitones, useFlats: false)
    }

    func transposedNote(_ note: String, by semitones: Int, useFlats: Bool) -> String {
        guard let index = chromaticSharps.firstIndex(of: note) else { return note }
        let wrapped = (index + semitones % chromaticSharps.count + chromaticSharps.count) % chromaticSharps.count
        let scale = useFlats ? chromaticFlats : chromaticSharps
        return scale[wrapped]
    }

    func applyBeginnerBassTransposeForCurrentStage() {
        guard layoutMode == .beginner else {
            midiEngine.setBassTransposeSemitones(0)
            return
        }

        if !beginnerRuntime.isDescendingPhase {
            if lessonStyle == .sequential {
                let transposeSemitones = playEnableHighFrets ? max(beginnerRuntime.currentRound, 0) % 12 : max(beginnerRuntime.currentRound, 0)
                midiEngine.setBassTransposeSemitones(transposeSemitones)
            } else {
                midiEngine.setBassTransposeSemitones(beginnerCurrentBassSemitoneTarget)
            }
            return
        }

        if beginnerRuntime.isDescendingPhase {
            midiEngine.setBassTransposeSemitones(max(beginnerRuntime.currentRound, 0) % 12)
            return
        }

        midiEngine.setBassTransposeSemitones(0)
    }

    func ensureBeginnerRoundOneRevealSequenceStarted(currentDate: Date) {
        guard layoutMode == .beginner,
              !isCodeScreensaverMode,
              !startupSequenceActivated,
              lessonStyle == .chord,
              beginnerRuntime.questionBoxIntroProgress > 0,
              beginnerRuntime.roundOneSequenceStartDate == nil,
              beginnerRuntime.pentatonicRevealCount == 0,
              !beginnerRuntime.answerBoxReady,
              !beginnerRuntime.isRoundArmed
        else { return }

        beginnerRuntime.roundOneIntroActive = true
        beginnerRuntime.roundOneSequenceStartDate = currentDate
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.revealStartBeatBucket = nil
        beginnerRuntime.introStartBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        beginnerRuntime.showRoundZeroIntroSequence = lessonStyle == .chord ? true : shouldShowLegacyRoundZeroIntro
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.answerBoxReady = false
    }

    func updateBeginnerRoundOneRevealSequence(currentDate _: Date) {
        guard beginnerRuntime.roundOneIntroActive,
              beginnerRuntime.roundOneSequenceStartDate != nil,
              layoutMode == .beginner,
              lessonStyle == .chord,
              !isCodeScreensaverMode,
              !startupSequenceActivated
        else { return }

        guard beginnerRoundZeroIntroDisplayPhase == .noteReveal else { return }
        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        if beginnerRuntime.revealStartBeatBucket == nil {
            beginnerRuntime.revealStartBeatBucket = currentBeatBucket
        }
        let revealStartBeatBucket = beginnerRuntime.revealStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - revealStartBeatBucket, 0)
        let revealedCount: Int = {
            guard elapsedBeatBuckets >= 0 else { return 0 }
            return elapsedBeatBuckets + 1
        }()
        let clampedRevealCount = min(max(revealedCount, 0), beginnerCurrentScaleNotes.count)

        if clampedRevealCount != beginnerRuntime.pentatonicRevealCount {
            beginnerRuntime.pentatonicRevealCount = clampedRevealCount
        }

        if clampedRevealCount >= beginnerCurrentScaleNotes.count {
            beginnerRuntime.roundOneIntroActive = false
            beginnerRuntime.roundOneSequenceStartDate = nil
            beginnerRuntime.revealStartBeatBucket = nil
            beginnerRuntime.introStartBeatBucket = nil
            beginnerRuntime.showRoundZeroIntroSequence = false
            beginnerRuntime.answerBoxReady = true
        }
    }

    func updateNoteRevealProgressionIfNeeded() {
        guard layoutMode == .beginner,
              lessonStyle == .sequential,
              !isCodeScreensaverMode,
              !startupSequenceActivated
        else { return }

        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        if beginnerRuntime.revealStartBeatBucket == nil {
            beginnerRuntime.revealStartBeatBucket = currentBeatBucket
        }
        let startBucket = beginnerRuntime.revealStartBeatBucket ?? currentBeatBucket
        let elapsedBeatBuckets = max(currentBeatBucket - startBucket, 0)
        let clampedRevealCount = min(elapsedBeatBuckets + 1, GameConstants.maxRevealCount)

        if clampedRevealCount != beginnerRuntime.revealCount {
            beginnerRuntime.revealCount = clampedRevealCount
        }
        if clampedRevealCount >= GameConstants.maxRevealCount {
            beginnerRuntime.answerBoxReady = true
        }
        if elapsedBeatBuckets >= GameConstants.maxRevealCount {
            beginnerRuntime.roundOneIntroActive = false
            beginnerRuntime.roundOneSequenceStartDate = nil
        }
    }

    func handleBeginnerAutoPlayIfNeeded(currentDate: Date) {
        guard layoutMode == .beginner,
              beginnerRuntime.autoPlayEnabled,
              !isCodeScreensaverMode,
              !startupSequenceActivated,
              !beginnerRuntime.isResolvingAnswer,
              !beginnerRuntime.pendingRewardStageAdvance,
              beginnerRuntime.pendingRoundShiftBeatPosition == nil
        else {
            if layoutMode != .beginner || !beginnerRuntime.autoPlayEnabled {
                beginnerRuntime.autoPlayNextDate = nil
            }
            return
        }

        let fret = max(beginnerRuntime.currentRound, 0)

        if lessonStyle == .sequential {
            guard beginnerRuntime.revealCount >= GameConstants.maxRevealCount else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let revealElapsed = Int(floor(beginnerRuntime.roundRevealElapsedBeats)) - (beginnerRuntime.revealStartBeatBucket ?? Int(floor(beginnerRuntime.roundRevealElapsedBeats)))
            guard revealElapsed >= GameConstants.maxRevealCount + 1 else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            guard !currentGenerator.isSequenceComplete() else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let idx = currentGenerator.sequenceProgressIndex
            guard let nextString = currentGenerator.expectedString,
                  currentGenerator.currentNoteSequence.indices.contains(idx)
            else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let nextNote = currentGenerator.currentNoteSequence[idx]
            if beginnerRuntime.autoPlayNextDate == nil {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(GameConstants.autoPlayInterval)
                return
            }
            guard let nextDate = beginnerRuntime.autoPlayNextDate, currentDate >= nextDate else { return }
            let buttonIndex = nextString >= 4 ? (nextString - 4) : (6 - nextString)
            beginnerRuntime.isAutoPlayTriggered = true
            handleBeginnerConsoleButtonPress(selectedNote: nextNote, selectedString: nextString, buttonIndex: buttonIndex)
            beginnerRuntime.isAutoPlayTriggered = false
            beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(GameConstants.autoPlayInterval)
            return
        } else {
            // Chord style: existing behavior
            guard lessonStyle == .chord,
                  !beginnerRuntime.roundOneIntroActive,
                  beginnerRuntime.pentatonicRevealCount >= beginnerCurrentScaleNotes.count,
                  !beginnerCurrentScaleNotes.isEmpty
            else {
                beginnerRuntime.autoPlayNextDate = nil
                return
            }
            let safeSequenceIndex = min(max(beginnerRuntime.scaleSequenceIndex, 0), beginnerCurrentScaleNotes.count - 1)
            if safeSequenceIndex != beginnerRuntime.scaleSequenceIndex {
                beginnerRuntime.scaleSequenceIndex = safeSequenceIndex
            }
            let expectedNote = beginnerCurrentScaleNotes[safeSequenceIndex]

            if beginnerRuntime.autoPlayNextDate == nil {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
                return
            }
            guard let nextDate = beginnerRuntime.autoPlayNextDate, currentDate >= nextDate else { return }
            let preferredStringOrder = beginnerAutoPlayPreferredStringOrder(for: expectedNote)
            let matchedString = preferredStringOrder.first {
                guitarNoteName(forString: $0, fret: fret, useFlats: false) == expectedNote
            } ?? preferredStringOrder.first {
                guitarNoteName(forString: $0, fret: fret, useFlats: beginnerUsesFlats) == expectedNote
            }
            guard let selectedString = matchedString else {
                beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
                return
            }
            beginnerRuntime.autoPlayLastStringByNote[expectedNote] = selectedString
            let buttonIndex = selectedString <= 3 ? (6 - selectedString) : (selectedString - 4)
            beginnerRuntime.isAutoPlayTriggered = true
            handleBeginnerConsoleButtonPress(selectedNote: expectedNote, selectedString: selectedString, buttonIndex: buttonIndex)
            beginnerRuntime.isAutoPlayTriggered = false
            beginnerRuntime.autoPlayNextDate = currentDate.addingTimeInterval(0.38)
        }
    }

    func beginnerAutoPlayPreferredStringOrder(for expectedNote: String) -> [Int] {
        let lowToHigh = [6, 5, 4, 3, 2, 1]
        let highToLow = [1, 2, 3, 4, 5, 6]
        let stageTitle = beginnerCurrentScaleStage.title.uppercased()
        let stageTokens = stageTitle.split(separator: " ")
        let stageRoot = stageTokens.first.map(String.init) ?? ""

        if stageTitle.hasPrefix("G ") && expectedNote == "E" {
            return highToLow
        }

        let isFinalNoteInStage = beginnerRuntime.scaleSequenceIndex == max(beginnerCurrentScaleNotes.count - 1, 0)
        if stageTitle.contains("MINOR PENTATONIC")
            && !stageRoot.isEmpty
            && expectedNote == stageRoot
            && isFinalNoteInStage {
            return highToLow
        }

        // Force alternation between string 1 and 6 for notes that appear on both
        if let lastString = beginnerRuntime.autoPlayLastStringByNote[expectedNote] {
            if lastString == 6 { return highToLow }
            if lastString == 1 { return lowToHigh }
        }

        return lowToHigh
    }
}

// MARK: - BeginnerGameplayView Logic: Timer-Driven & Session Handlers (Step 4d)

extension BeginnerGameplayView {

    func handleMainTimerTick(_ date: Date) {
        let shouldBlinkStartupStartButton = startupStartButtonAttentionActive && !startupSequenceActivated

        if shouldBlinkStartupStartButton {
            if startupStartButtonNextBlinkDate == nil {
                startupStartButtonBlinkOn = true
                startupStartButtonNextBlinkDate = date.addingTimeInterval(0.45)
            } else if let nextBlinkDate = startupStartButtonNextBlinkDate, date >= nextBlinkDate {
                startupStartButtonBlinkOn.toggle()
                startupStartButtonNextBlinkDate = date.addingTimeInterval(0.45)
            }
        } else {
            startupStartButtonBlinkOn = false
            startupStartButtonNextBlinkDate = nil
        }

        if startupSequenceActivated {
            startupSequenceElapsed = max(date.timeIntervalSince(startupSequenceStartDate), 0)
            let startupState = StartupSequenceView.state(for: startupSequenceElapsed, showFullSequence: layoutMode != .beginner, armedText: beginnerStartupArmedText)
            handleStartupSpeech(for: startupState.phase)
        }

        handlePendingMidiStopIfNeeded()

        if beginnerRuntime.isRoundArmed || isRoundPaused {
            beginnerRuntime.beatLightFlashOn = false
            beginnerRuntime.roundRevealLastTickDate = nil
            return
        }

        if beginnerRuntime.roundRevealLastTickDate == nil {
            beginnerRuntime.roundRevealLastTickDate = date
        } else if let lastTick = beginnerRuntime.roundRevealLastTickDate {
            let delta = max(date.timeIntervalSince(lastTick), 0)
            let beatsPerSecond = Double(max(beatBPM, 60)) / 60.0
            beginnerRuntime.roundRevealElapsedBeats += delta * beatsPerSecond
            beginnerRuntime.roundRevealLastTickDate = date
        }

        handlePendingBeginnerRewardPlaybackIfNeeded()
        handlePendingSequentialRepeatResetIfNeeded()
        handlePendingRoundShiftIfNeeded()
        ensureBeginnerRoundOneRevealSequenceStarted(currentDate: date)
        updateBeginnerRoundOneRevealSequence(currentDate: date)
        updateNoteRevealProgressionIfNeeded()
        handleBeginnerAutoPlayIfNeeded(currentDate: date)

        let trackPlayingNow = midiEngine.isPlaying
        if isBackingTrackPlaying != trackPlayingNow {
            isBackingTrackPlaying = trackPlayingNow
        }

        let shouldRunBeatLight = layoutMode == .beginner && !isCodeScreensaverMode && trackPlayingNow
        if shouldRunBeatLight {
            let currentBeatBucket = Int(floor(midiEngine.currentBeatPosition()))

            if beginnerRuntime.beatLightLastProcessedBeat == nil {
                beginnerRuntime.beatLightLastProcessedBeat = currentBeatBucket
                beginnerRuntime.beatLightFlashOn = false
                return
            }

            if beginnerRuntime.beatLightLastProcessedBeat != currentBeatBucket {
                beginnerRuntime.beatLightLastProcessedBeat = currentBeatBucket

                if !beginnerRuntime.beatLightIntroMeasureSkipped {
                    if currentBeatBucket >= 4 {
                        beginnerRuntime.beatLightIntroMeasureSkipped = true
                    } else {
                        beginnerRuntime.beatLightFlashOn = false
                        return
                    }
                }

                beginnerRuntime.beatLightFlashOn = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    beginnerRuntime.beatLightFlashOn = false
                }
            }
        } else {
            beginnerRuntime.beatLightFlashOn = false
            beginnerRuntime.beatLightLastProcessedBeat = nil
            beginnerRuntime.beatLightIntroMeasureSkipped = false
        }
    }

    func applyLivePlayRepetitionChangeIfNeeded() {
        guard layoutMode == .beginner,
              !beginnerRuntime.isRoundArmed,
              !isRoundPaused
        else { return }

        beginnerRuntime.scaleRepetitionsRemaining = beginnerTargetScaleRepetitionsRemaining()
    }

    func beginnerTargetScaleRepetitionsRemaining() -> Int {
        if beginnerRuntime.isDescendingPhase {
            return max(effectivePlayRepetitions - beginnerRuntime.correctAnswersAtCurrentFret, 1)
        }
        return effectivePlayRepetitions
    }

    func updateDirectionLockState() {
        directionLockActive = shouldLockPlayDirection
    }

    func handleContentOnAppear() {
        initializeGameplaySession()
        updateDirectionLockState()
    }

    func initializeGameplaySession() {
        audioSettings = AudioSettings()
        availableBackingTracks = BackingTrack.discoverBundledTracks()
        audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
        guitarNoteEngine.configure(
            preset: audioSettings.guitarTonePreset,
            reverbLevel: audioSettings.reverbLevel,
            delayLevel: audioSettings.delayLevel
        )
        syncBackingTrackPlayback()
        if assetToNutBottomDelta == nil {
            assetToNutBottomDelta = 0
        }
        introDidRun = true
        startupSequenceStartDate = .now
        startupSequenceElapsed = 0
        startupSequenceActivated = false
        introWindowBlack = false
        beginnerRuntime.currentFretStart = 0
        beginnerRuntime.bankDollars = max(walletDollars, 0)
        beginnerRuntime.displayedBankDollars = beginnerRuntime.bankDollars
        showDeveloperPrompt("MODE: \(selectedMode.rawValue.uppercased())")
        beginnerRuntime.questionBoxIntroProgress = isCodeScreensaverMode ? 0 : 1
        beginnerRuntime.answerBoxReady = layoutMode == .beginner ? false : !isCodeScreensaverMode
        beginnerRuntime.isRoundArmed = layoutMode == .beginner
        isRoundPaused = false
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil
    }

    func startGameFromBeginning(animateNeckSlideFromStartup: Bool = false) {
        if layoutMode == .beginner {
            beginnerRuntime.currentRound = beginnerRoundOneStartingFret
            beginnerRuntime.isDescendingPhase = beginnerRoundOneStartsDescending
        } else {
            beginnerRuntime.currentRound = isPhaseDescending ? 12 : 0
            beginnerRuntime.isDescendingPhase = isPhaseDescending
        }
        if animateNeckSlideFromStartup {
            startupNeckVisualsHidden = true
            beginnerRuntime.currentFretStart = beginnerRuntime.isDescendingPhase ? maxFretOffset : minFretOffset
            DispatchQueue.main.async {
                startupNeckVisualsHidden = false
                withAnimation(.easeInOut(duration: 0.78)) {
                    beginnerRuntime.currentFretStart = beginnerRuntime.currentRound
                }
            }
        } else {
            startupNeckVisualsHidden = false
            beginnerRuntime.currentFretStart = beginnerRuntime.currentRound
        }
        roundStringIndex = 0
        beginnerRuntime.bankDollars = 0
        beginnerRuntime.displayedBankDollars = 0
        walletDollars = 0
        beatQuestionDeadline = nil
        beginnerRuntime.currentPromptStrings = [1]
        beginnerRuntime.activePickedStringNumbers = [1]
        beginnerRuntime.answeredNotesByStringAtCurrentFret = [:]
        beginnerRuntime.beatCountInRemaining = modeVariant == .beat ? 4 : 0
        beginnerRuntime.nextBeatTickDate = nil
        leftThumbState = .neutral
        rightThumbState = .neutral
        beginnerRuntime.activeAnswerFeedback = nil
        beginnerRuntime.isResolvingAnswer = false
        isRoundPaused = false
        beginnerRuntime.roundRevealElapsedBeats = 0
        beginnerRuntime.roundRevealLastTickDate = nil
        gameplayMenuExpanded = false
        developerPromptText = ""
        beginnerRuntime.currentCorrectNote = ""
        beginnerRuntime.lastResolvedCorrectNote = nil
        beginnerRuntime.streakMeterLitColumns = 0
        beginnerRuntime.streakMeterFailureActive = false
        beginnerRuntime.streakMeterFailureVisibleColumns = 0
        beginnerRuntime.correctAnswersAtCurrentFret = 0
        beginnerRuntime.lastPromptedCorrectNote = nil
        beginnerRuntime.lastPromptedStringHalf = nil
        beginnerRuntime.lastPromptedStringNumber = nil
        beginnerRuntime.recentPromptedCorrectNotes = []
        beginnerRuntime.lastPickedNote = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.answerBoxReady = layoutMode != .beginner
        beginnerRuntime.autoPlayNextDate = nil
        beginnerRuntime.beatLightFlashOn = false
        beginnerRuntime.beatLightLastProcessedBeat = nil
        beginnerRuntime.roundOneIntroActive = false
        beginnerRuntime.roundOneSequenceStartDate = nil
        beginnerRuntime.beatLightIntroMeasureSkipped = false
        beginnerRuntime.scaleRepetitionsRemaining = effectivePlayRepetitions
        beginnerRuntime.pendingRoundShiftBeatPosition = nil
        beginnerRuntime.scaleSequenceIndex = 0
        beginnerRuntime.scaleStageIndex = 0
        beginnerRuntime.scaleCycleSemitoneOffset = beginnerRuntime.currentRound
        beginnerRuntime.pentatonicRevealCount = 0
        beginnerRuntime.revealStartBeatBucket = nil
        beginnerRuntime.introStartBeatBucket = nil
        beginnerRuntime.showRoundZeroIntroSequence = false
        beginnerRuntime.pendingRewardStageAdvance = false
        beginnerRuntime.rewardTargetBeatPosition = nil
        beginnerRuntime.rewardSelectedString = nil
        beginnerRuntime.rewardNoteTextByString = nil
        beginnerRuntime.rewardScheduledStrings = []
        beginnerRuntime.rewardScheduledMIDINotes = []
        beginnerRuntime.rewardScheduledNoteTextByString = [:]
        beginnerRuntime.rewardSustainMultiplier = 3.0

        // Initialize Sequential style state if needed
        if lessonStyle == .sequential {
            sequentialNoteGenerator.generateNoteSequence(for: beginnerRuntime.currentRound, useFlats: beginnerUsesFlats, lowToHigh: isProgressionLowToHigh)
            beginnerRuntime.sequentialRevealCount = 0
            beginnerRuntime.sequentialRevealStartBeatBucket = nil
            beginnerRuntime.roundOneIntroActive = true
            beginnerRuntime.roundOneSequenceStartDate = Date()
        }

        applyBeginnerBassTransposeForCurrentStage()
        prepareCurrentQuestion()
    }

}

// MARK: - BeginnerGameplayView Logic: Remaining Helpers (Step 5)

extension BeginnerGameplayView {

    func shiftFretSpan(by delta: Int) {
        guard delta != 0 else { return }
        withAnimation(.easeInOut(duration: 1.3)) {
            beginnerRuntime.currentFretStart = min(max(beginnerRuntime.currentFretStart + delta, minFretOffset), maxFretOffset)
        }
    }

    func shiftWindow(by delta: Int) {
        let proposed = beginnerRuntime.currentWindowRow + delta
        let clamped = min(max(proposed, 0), 7)
        guard clamped != beginnerRuntime.currentWindowRow else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            beginnerRuntime.currentWindowRow = clamped
        }
    }

    func nextThumbState(after state: ThumbGlowState) -> ThumbGlowState {
        switch state {
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
                gameplayAudioEngine.speakStartupAlert("SYSTEM ONLINE", volume: stringVolume)
                startupSpeechPhase = .pendingPhase
            }
        case .phaseOne:
            if startupSpeechPhase == .pendingPhase {
                gameplayAudioEngine.speakStartupAlert("PHASE ONE", volume: stringVolume)
                startupSpeechPhase = .pendingArmed
            }
        case .armed:
            if startupSpeechPhase == .pendingArmed {
                gameplayAudioEngine.speakStartupAlert(layoutMode == .beginner ? beginnerStartupArmedText : "MEMORIZATION SEQUENCE ARMED", volume: stringVolume)
                startupSpeechPhase = .idle
            }
        }
    }

    // maestroThumbOverlay — moved to BeginnerSubviews.swift

    // transportButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonPanelOverlay — moved to BeginnerSubviews.swift

    // beginnerButtonState — moved to BeginnerSubviews.swift

    func syncBackingTrackPlayback(allowResumeFromPause: Bool = false) {
        guard !availableBackingTracks.isEmpty else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        audioSettings.selectInitialBackingTrackIfNeeded(from: availableBackingTracks)
        guard backingTrackShouldPlayInGameplay else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        guard !beginnerRuntime.transportStoppedForResume else {
            isBackingTrackPlaying = false
            return
        }

        guard let selectedTrackID = audioSettings.selectedBackingTrackID,
              let selectedTrack = availableBackingTracks.first(where: { $0.id == selectedTrackID }),
              let trackURL = selectedTrack.resourceURL() else {
            midiEngine.stop()
            isBackingTrackPlaying = false
            return
        }

        applyBeginnerBassTransposeForCurrentStage()
        
        // If allowed and same track was paused, resume from that position
        if allowResumeFromPause {
            midiEngine.resume()
            isBackingTrackPlaying = midiEngine.isPlaying
            return
        }

        // Skip restart if the same URL is already playing — avoids mid-beat click
        if midiEngine.isPlaying, midiEngine.activeURL == trackURL {
            isBackingTrackPlaying = true
            return
        }

        midiEngine.play(url: trackURL, title: selectedTrack.title, loop: true)
        isBackingTrackPlaying = midiEngine.isPlaying
    }

    // handleFretboardButtonPress, handleRoundStartButton, handleStartButtonPress,
    // handleRoundStopButton, resumeRoundFromTransportStop, handleRoundResetButton
    // — moved to BeginnerGameplayLogic.swift (Step 4a)

    func postponeBeatDeadlineForAssist() {
        guard !isCodeScreensaverMode, modeVariant == .beat else { return }
        let bpm = Double(max(beatBPM, 60))
        beatQuestionDeadline = .now.addingTimeInterval(max(1.0, 120.0 / bpm))
    }

    func showDeveloperPrompt(_ text: String) {
        developerPromptText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if developerPromptText == text {
                developerPromptText = ""
            }
        }
    }

    // MARK: - Private Helper Methods
    
    func midiNoteValue(forNote note: String) -> Int? {
        let noteToMIDI: [String: Int] = [
            "C": 60, "C#": 61, "Db": 61,
            "D": 62, "D#": 63, "Eb": 63,
            "E": 64,
            "F": 65, "F#": 66, "Gb": 66,
            "G": 67, "G#": 68, "Ab": 68,
            "A": 69, "A#": 70, "Bb": 70,
            "B": 71
        ]
        return noteToMIDI[note]
    }
}

// MARK: - BeginnerGameplayView Computed Properties (Step 5)

extension BeginnerGameplayView {

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
            let root = transposedNote(template.root, by: beginnerRuntime.scaleCycleSemitoneOffset, useFlats: beginnerUsesFlats)
            let notes = template.intervals.map { interval in
                transposedNote(template.root, by: beginnerRuntime.scaleCycleSemitoneOffset + interval, useFlats: beginnerUsesFlats)
            }
            let stageTitle = "\(root)\(beginnerChordSuffixDisplay(template.titleSuffix))"

            return BeginnerScaleStage(
                title: stageTitle,
                notes: notes,
                bassSemitoneTarget: template.bassSemitoneTarget + beginnerRuntime.scaleCycleSemitoneOffset,
                endsCycle: template.endsCycle
            )
        }
    }

    var beginnerCurrentScaleStage: BeginnerScaleStage {
        let clampedIndex = min(max(beginnerRuntime.scaleStageIndex, 0), max(beginnerScaleStages.count - 1, 0))
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
        let fret = max(beginnerRuntime.currentRound, 0)
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
        let count = min(max(beginnerRuntime.pentatonicRevealCount, 0), notes.count)
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

            if let pendingSequentialRepeatDisplayText = beginnerRuntime.pendingSequentialRepeatDisplayText {
                return pendingSequentialRepeatDisplayText
            }

            let revealCount = min(beginnerRuntime.sequentialRevealCount, sequentialNoteGenerator.currentNoteSequence.count)
            let revealedNotes = sequentialNoteGenerator.currentNoteSequence
                .prefix(revealCount)
                .map(guitarNoteDisplayText)
                .joined(separator: " ")
            return revealedNotes
        }

        // Chord style: existing behavior
        if !beginnerRuntime.answerBoxReady,
           !beginnerRuntime.roundOneIntroActive {
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
              beginnerRuntime.roundOneIntroActive,
              beginnerRuntime.showRoundZeroIntroSequence
        else {
            return .inactive
        }

        let currentBeatBucket = Int(floor(beginnerRuntime.roundRevealElapsedBeats))
        let startBeatBucket = beginnerRuntime.introStartBeatBucket ?? currentBeatBucket
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
        return !beginnerRuntime.roundOneIntroActive
    }

    var playDirection: LessonDirection {
        LessonDirection(rawValue: playDirectionRawValue) ?? .ascending
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
        return beginnerRuntime.isDescendingPhase
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
        !beginnerRuntime.isRoundArmed && !isCodeScreensaverMode && !isRoundPaused
    }

    var shouldLockPlayDirection: Bool {
        guard layoutMode == .beginner else { return false }
        return !beginnerRuntime.isRoundArmed
    }

    var beginnerStartupArmedText: String {
        if layoutMode == .beginner {
            if lessonStyle == .sequential { return "SEQUENTIAL MODE ARMED" }
            return "CHORD MODE ARMED"
        }
        return "Memorization Sequence Armed"
    }

}
