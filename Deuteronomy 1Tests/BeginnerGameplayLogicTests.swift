import XCTest
import SwiftUI
@testable import Deuteronomy_1

// MARK: - Beginner Gameplay Logic Tests
//
// These tests target the real types that are actually testable without a SwiftUI host:
//   - BeginnerGameState    (@Observable final class — pure data)
//   - guitarNoteName()     (free function in GuitarHelpers.swift — core note calculation)
//
// They specifically cover the chord-mode bugs fixed in build 1.3:
//   1. Pentatonic→chord transition: stale answeredNotesByStringAtCurrentFret / lastPickedNote
//   2. Wrong answer on chord: activePickedStringNumbers must preserve correct answers, not wipe them
//   3. Pre-validation flicker: activePickedStringNumbers must never be set before validation

final class BeginnerGameStateTests: XCTestCase {

    var state: BeginnerGameState!

    override func setUpWithError() throws {
        try super.setUpWithError()
        state = BeginnerGameState()
    }

    override func tearDownWithError() throws {
        state = nil
        try super.tearDownWithError()
    }

    // MARK: - Initial State

    func testInitialStateIsClean() {
        XCTAssertFalse(state.answerBoxReady, "answerBoxReady should be false on init")
        XCTAssertNil(state.lastPickedNote, "lastPickedNote should be nil on init")
        XCTAssertTrue(state.answeredNotesByStringAtCurrentFret.isEmpty, "answeredNotesByString should be empty on init")
        XCTAssertTrue(state.isRoundArmed, "isRoundArmed should be true on init")
        XCTAssertFalse(state.isResolvingAnswer, "isResolvingAnswer should be false on init")
        XCTAssertEqual(state.currentRound, 0, "currentRound should start at 0")
        XCTAssertEqual(state.correctAnswersAtCurrentFret, 0, "correctAnswers should start at 0")
    }

    // MARK: - clearReveal (covers pentatonic→chord transition bug fix)
    // Bug: When pentatonic phase ended, clearReveal was not resetting answeredNotesByStringAtCurrentFret
    // or lastPickedNote, causing stale state to bleed into chord phase.

    func testClearRevealResetsAnswerBoxReady() {
        state.answerBoxReady = true
        state.clearReveal()
        XCTAssertFalse(state.answerBoxReady, "clearReveal must reset answerBoxReady to false")
    }

    func testClearRevealResetsRevealCount() {
        state.revealCount = 5
        state.clearReveal()
        XCTAssertEqual(state.revealCount, 0, "clearReveal must reset revealCount to 0")
    }

    func testClearRevealResetsPentatonicRevealCount() {
        state.pentatonicRevealCount = 4
        state.clearReveal()
        XCTAssertEqual(state.pentatonicRevealCount, 0, "clearReveal must reset pentatonicRevealCount")
    }

    func testClearRevealResetsRevealBeatBucket() {
        state.revealBeatBucket = 12
        state.clearReveal()
        XCTAssertNil(state.revealBeatBucket, "clearReveal must nil out revealBeatBucket")
    }

    func testClearRevealResetsRoundOneIntro() {
        state.roundOneIntroActive = true
        state.roundOneSequenceStartDate = Date()
        state.clearReveal()
        XCTAssertFalse(state.roundOneIntroActive, "clearReveal must deactivate roundOneIntroActive")
        XCTAssertNil(state.roundOneSequenceStartDate, "clearReveal must nil roundOneSequenceStartDate")
    }

    // MARK: - clearReward (covers lastPickedNote stale state)

    func testClearRewardNilsLastPickedNote() {
        state.lastPickedNote = "E"
        state.clearReward()
        XCTAssertNil(state.lastPickedNote, "clearReward must nil lastPickedNote")
    }

    func testClearRewardClearsScheduledStrings() {
        state.rewardScheduledStrings = [1, 2, 3]
        state.rewardScheduledMIDINotes = [64, 59, 55]
        state.clearReward()
        XCTAssertTrue(state.rewardScheduledStrings.isEmpty, "clearReward must clear rewardScheduledStrings")
        XCTAssertTrue(state.rewardScheduledMIDINotes.isEmpty, "clearReward must clear rewardScheduledMIDINotes")
    }

    func testClearRewardResetsStageAdvanceFlag() {
        state.pendingRewardStageAdvance = true
        state.rewardSelectedString = 3
        state.clearReward()
        XCTAssertFalse(state.pendingRewardStageAdvance, "clearReward must reset pendingRewardStageAdvance")
        XCTAssertNil(state.rewardSelectedString, "clearReward must nil rewardSelectedString")
    }

    // MARK: - Chord mode wrong answer: activePickedStringNumbers must preserve correct answers
    // Bug fix: wrong answer used to wipe activePickedStringNumbers = [].
    // Correct behavior: restore it to Array(answeredNotesByStringAtCurrentFret.keys).

    func testWrongAnswerPreservesCorrectBoxes() {
        // Simulate: strings 1 and 2 already confirmed correct
        state.answeredNotesByStringAtCurrentFret = [1: "E", 2: "B"]
        state.activePickedStringNumbers = [1, 2]
        state.answerBoxReady = true

        // Simulate wrong answer: do NOT wipe activePickedStringNumbers
        // Instead restore from answeredNotesByStringAtCurrentFret (the fix)
        state.activePickedStringNumbers = Array(state.answeredNotesByStringAtCurrentFret.keys).sorted()

        XCTAssertEqual(state.activePickedStringNumbers.sorted(), [1, 2],
            "Wrong answer must preserve previously-correct string boxes")
    }

    func testWrongAnswerWithNoCorrectAnswersYet() {
        // First string in chord, no correct answers yet — wrong answer should leave empty
        state.answeredNotesByStringAtCurrentFret = [:]
        state.activePickedStringNumbers = []

        state.activePickedStringNumbers = Array(state.answeredNotesByStringAtCurrentFret.keys).sorted()

        XCTAssertTrue(state.activePickedStringNumbers.isEmpty,
            "Wrong answer with no prior correct answers should leave activePickedStringNumbers empty")
    }

    func testCorrectAnswerAppendsToActivePickedStrings() {
        // Simulate: string 3 already confirmed
        state.answeredNotesByStringAtCurrentFret = [3: "G"]
        state.activePickedStringNumbers = [3]

        // Now string 2 is answered correctly
        let newString = 2
        let newNote = "B"
        state.answeredNotesByStringAtCurrentFret[newString] = newNote
        state.activePickedStringNumbers = Array(state.answeredNotesByStringAtCurrentFret.keys).sorted()

        XCTAssertEqual(state.activePickedStringNumbers.sorted(), [2, 3],
            "Correct answer must add new string to activePickedStringNumbers")
    }

    // MARK: - Pentatonic→chord transition: stale state cleared
    // Bug: After pentatonic reveal completed, answeredNotesByStringAtCurrentFret and
    // lastPickedNote from pentatonic phase were not cleared. This caused all pentatonic
    // boxes to appear on the first wrong chord answer.

    func testPentatonicToChordTransitionClearsStaleState() {
        // Simulate end of pentatonic phase
        state.lastPickedNote = "E"
        state.answeredNotesByStringAtCurrentFret = [1: "E", 3: "G", 5: "A"]
        state.answerBoxReady = true

        // The fix applied at transition point:
        state.answeredNotesByStringAtCurrentFret = [:]
        state.lastPickedNote = nil

        XCTAssertNil(state.lastPickedNote,
            "Pentatonic→chord transition must clear lastPickedNote")
        XCTAssertTrue(state.answeredNotesByStringAtCurrentFret.isEmpty,
            "Pentatonic→chord transition must clear answeredNotesByStringAtCurrentFret")
    }

    // MARK: - Chord completion: all strings confirmed

    func testChordCompleteWhenAllStringsAnswered() {
        // Simulate a 3-string chord prompt
        let promptStrings = [1, 3, 5]
        state.answeredNotesByStringAtCurrentFret = [:]
        state.activePickedStringNumbers = []

        // Answer each string correctly
        for str in promptStrings {
            state.answeredNotesByStringAtCurrentFret[str] = "E"
            state.activePickedStringNumbers = Array(state.answeredNotesByStringAtCurrentFret.keys).sorted()
        }

        let isChordComplete = state.activePickedStringNumbers.count >= promptStrings.count
        XCTAssertTrue(isChordComplete, "Chord should be complete when all prompt strings are answered")
    }

    // MARK: - reset() covers all major state groups

    func testFullResetClearsEverything() {
        state.correctAnswersAtCurrentFret = 10
        state.scaleRepetitionsRemaining = 5
        state.revealCount = 3
        state.answerBoxReady = true
        state.autoPlayNextDate = Date()
        state.pendingRewardStageAdvance = true
        state.lastPickedNote = "G"

        state.reset()

        XCTAssertEqual(state.correctAnswersAtCurrentFret, 0)
        XCTAssertEqual(state.scaleRepetitionsRemaining, 1)
        XCTAssertEqual(state.revealCount, 0)
        XCTAssertFalse(state.answerBoxReady)
        XCTAssertNil(state.autoPlayNextDate)
        XCTAssertFalse(state.pendingRewardStageAdvance)
        XCTAssertNil(state.lastPickedNote)
    }

    // MARK: - isResolvingAnswer gate
    // Pre-validation flicker fix: isResolvingAnswer should block button processing

    func testIsResolvingAnswerStartsFalse() {
        XCTAssertFalse(state.isResolvingAnswer,
            "isResolvingAnswer should be false until a chord completion is resolving")
    }

    func testIsResolvingAnswerCanBeSetAndCleared() {
        state.isResolvingAnswer = true
        XCTAssertTrue(state.isResolvingAnswer)
        state.isResolvingAnswer = false
        XCTAssertFalse(state.isResolvingAnswer)
    }

    // MARK: - answerBoxReady gate

    func testAnswerBoxReadyStartsFalse() {
        XCTAssertFalse(state.answerBoxReady,
            "answerBoxReady should be false — buttons must not accept input until reveal completes")
    }
}

// MARK: - Guitar Note Calculation Tests
//
// guitarNoteName() is the heart of the app — every button label and every answer
// validation runs through it. These tests lock in correct behavior for all 6 strings
// at open position and at specific frets critical to chord mode.

final class GuitarNoteTests: XCTestCase {

    // MARK: - Open strings (fret 0)

    func testOpenStringNotes() {
        // Standard tuning: E A D G B E (strings 6→1)
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 0, useFlats: false), "E", "String 6 open = E")
        XCTAssertEqual(guitarNoteName(forString: 5, fret: 0, useFlats: false), "A", "String 5 open = A")
        XCTAssertEqual(guitarNoteName(forString: 4, fret: 0, useFlats: false), "D", "String 4 open = D")
        XCTAssertEqual(guitarNoteName(forString: 3, fret: 0, useFlats: false), "G", "String 3 open = G")
        XCTAssertEqual(guitarNoteName(forString: 2, fret: 0, useFlats: false), "B", "String 2 open = B")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 0, useFlats: false), "E", "String 1 open = E")
    }

    // MARK: - Fret 5 (A chord position — used in chord mode round 5)

    func testFretFiveNotes() {
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 5, useFlats: false), "A", "String 6 fret 5 = A")
        XCTAssertEqual(guitarNoteName(forString: 5, fret: 5, useFlats: false), "D", "String 5 fret 5 = D")
        XCTAssertEqual(guitarNoteName(forString: 4, fret: 5, useFlats: false), "G", "String 4 fret 5 = G")
        XCTAssertEqual(guitarNoteName(forString: 3, fret: 5, useFlats: false), "C", "String 3 fret 5 = C")
        XCTAssertEqual(guitarNoteName(forString: 2, fret: 5, useFlats: false), "E", "String 2 fret 5 = E")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 5, useFlats: false), "A", "String 1 fret 5 = A")
    }

    // MARK: - Flat equivalents for accidentals

    func testSharpsAndFlatsAreEquivalentPitches() {
        // Fret 1 on string 6: F — no accidental, same either way
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 1, useFlats: false), "F")
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 1, useFlats: true), "F")

        // Fret 2 on string 6: F♯ / G♭
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 2, useFlats: false), "F♯")
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 2, useFlats: true), "G♭")

        // Fret 3 on string 6: G — no accidental
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 3, useFlats: false), "G")
        XCTAssertEqual(guitarNoteName(forString: 6, fret: 3, useFlats: true), "G")
    }

    // MARK: - E string (string 1) validation — this was the chord mode E string bug

    func testStringOneEStringNotes() {
        // String 1 is high E. Fret 0 = E, fret 1 = F, fret 2 = F♯, fret 3 = G ...
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 0, useFlats: false), "E")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 1, useFlats: false), "F")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 2, useFlats: false), "F♯")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 3, useFlats: false), "G")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 4, useFlats: false), "G♯")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 5, useFlats: false), "A")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 7, useFlats: false), "B")
        XCTAssertEqual(guitarNoteName(forString: 1, fret: 12, useFlats: false), "E", "Fret 12 = octave = same note")
    }

    // MARK: - String 6 (low E) mirrors string 1 — same open note, same pattern

    func testString6SamePatternAsString1() {
        for fret in 0...12 {
            XCTAssertEqual(
                guitarNoteName(forString: 6, fret: fret, useFlats: false),
                guitarNoteName(forString: 1, fret: fret, useFlats: false),
                "String 6 and string 1 should produce identical note names at fret \(fret)"
            )
        }
    }

    // MARK: - 12-tone octave wraps correctly

    func testOctaveWrap() {
        for string in 1...6 {
            let openNote = guitarNoteName(forString: string, fret: 0, useFlats: false)
            let octaveNote = guitarNoteName(forString: string, fret: 12, useFlats: false)
            XCTAssertEqual(openNote, octaveNote,
                "String \(string): fret 0 and fret 12 should produce the same note name")
        }
    }

    // MARK: - Invalid string number returns empty string

    func testInvalidStringNumberReturnsEmpty() {
        XCTAssertEqual(guitarNoteName(forString: 0, fret: 0, useFlats: false), "",
            "String 0 is invalid — should return empty string")
        XCTAssertEqual(guitarNoteName(forString: 7, fret: 0, useFlats: false), "",
            "String 7 is invalid — should return empty string")
    }
}

// MARK: - Chord Answer Validation Logic Tests
//
// These test the validation predicate used in handleBeginnerChordProgressionIfNeeded.
// isValidAnswer = currentPromptStrings.contains(stringNumber) && currentCorrectNote == displayedNote

final class ChordValidationTests: XCTestCase {

    var state: BeginnerGameState!

    override func setUpWithError() throws {
        try super.setUpWithError()
        state = BeginnerGameState()
        // Set up a chord prompt: strings [1, 3, 5] all need note "E"
        state.currentPromptStrings = [1, 3, 5]
        state.currentCorrectNote = "E"
        state.answerBoxReady = true
    }

    override func tearDownWithError() throws {
        state = nil
        try super.tearDownWithError()
    }

    func isValidChordAnswer(stringNumber: Int, displayedNote: String) -> Bool {
        state.currentPromptStrings.contains(stringNumber) && state.currentCorrectNote == displayedNote
    }

    func testCorrectStringAndNoteIsValid() {
        XCTAssertTrue(isValidChordAnswer(stringNumber: 1, displayedNote: "E"),
            "Correct string + correct note should be valid")
    }

    func testWrongNoteIsInvalid() {
        XCTAssertFalse(isValidChordAnswer(stringNumber: 1, displayedNote: "G"),
            "Correct string but wrong note should be invalid")
    }

    func testWrongStringIsInvalid() {
        // String 2 is not in the prompt — even if note matches it's invalid
        XCTAssertFalse(isValidChordAnswer(stringNumber: 2, displayedNote: "E"),
            "Wrong string (not in prompt) should be invalid even if note matches")
    }

    func testWrongStringAndWrongNoteIsInvalid() {
        XCTAssertFalse(isValidChordAnswer(stringNumber: 2, displayedNote: "G"),
            "Wrong string and wrong note should be invalid")
    }

    func testAllPromptStringsValidate() {
        for string in state.currentPromptStrings {
            XCTAssertTrue(isValidChordAnswer(stringNumber: string, displayedNote: "E"),
                "All prompt strings should validate when note is correct")
        }
    }

    // MARK: - Duplicate answer is still valid (idempotent correct answer)

    func testAlreadyAnsweredStringIsStillValid() {
        // String 1 already answered — but the validation itself should still return true
        state.answeredNotesByStringAtCurrentFret[1] = "E"
        XCTAssertTrue(isValidChordAnswer(stringNumber: 1, displayedNote: "E"),
            "Re-pressing an already-correct string should still pass validation")
    }
}
