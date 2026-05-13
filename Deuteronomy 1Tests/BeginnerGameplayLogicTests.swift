import XCTest
@testable import Deuteronomy_1

// MARK: - Beginner Gameplay Logic Tests

final class BeginnerGameplayLogicTests: XCTestCase {
    
    var logic: BeginnerGameplayLogic!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize the logic with test bindings
        let startingFret = Binding.constant(0)
        let repetitions = Binding.constant(10)
        let infiniteRepetitions = Binding.constant(false)
        let directionRawValue = Binding.constant("ascending")
        let enableHighFrets = Binding.constant(false)
        let lessonStyle = Binding.constant("chord")
        let progression = Binding.constant("lowToHigh")
        let walletDollars = Binding.constant(100)
        let balanceDollars = Binding.constant(50)
        
        logic = BeginnerGameplayLogic(
            selectedMode: .chord,
            beatBPM: 120,
            beatVolume: 0.8,
            stringVolume: 0.8,
            playStartingFret: startingFret,
            playRepetitions: repetitions,
            playInfiniteRepetitions: infiniteRepetitions,
            playDirectionRawValue: directionRawValue,
            playEnableHighFrets: enableHighFrets,
            playLessonStyle: lessonStyle,
            playProgression: progression,
            walletDollars: walletDollars,
            balanceDollars: balanceDollars
        )
    }
    
    override func tearDownWithError() throws {
        logic = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Game Initialization Tests
    
    func testGameInitialization() throws {
        XCTAssertFalse(logic.isGameActive, "Game should not be active initially")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused initially")
        XCTAssertEqual(logic.currentRound, 0, "Current round should start at 0")
        XCTAssertEqual(logic.score, 0, "Score should start at 0")
        XCTAssertEqual(logic.streak, 0, "Streak should start at 0")
    }
    
    func testStartGame() throws {
        logic.startGame()
        
        XCTAssertTrue(logic.isGameActive, "Game should be active after start")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused after start")
        XCTAssertEqual(logic.currentRound, 0, "Current round should be 0 after start")
        XCTAssertEqual(logic.score, 0, "Score should be 0 after start")
        XCTAssertEqual(logic.streak, 0, "Streak should be 0 after start")
    }
    
    func testResetRound() throws {
        // Start game first
        logic.startGame()
        
        // Modify some state
        logic.currentRound = 5
        logic.score = 100
        logic.streak = 3
        
        // Reset
        logic.resetRound()
        
        XCTAssertTrue(logic.isGameActive, "Game should remain active after reset")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused after reset")
        XCTAssertEqual(logic.currentRound, 0, "Current round should be 0 after reset")
        XCTAssertEqual(logic.score, 0, "Score should be 0 after reset")
        XCTAssertEqual(logic.streak, 0, "Streak should be 0 after reset")
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseRound() throws {
        logic.startGame()
        logic.pauseRound()
        
        XCTAssertTrue(logic.isGameActive, "Game should remain active when paused")
        XCTAssertTrue(logic.isRoundPaused, "Game should be paused")
    }
    
    func testResumeRound() throws {
        logic.startGame()
        logic.pauseRound()
        logic.resumeRound()
        
        XCTAssertTrue(logic.isGameActive, "Game should remain active when resumed")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused when resumed")
    }
    
    // MARK: - Answer Submission Tests
    
    func testSubmitAnswerWhenGameInactive() throws {
        logic.submitAnswer(.left)
        
        XCTAssertFalse(logic.isGameActive, "Game should remain inactive")
        XCTAssertEqual(logic.score, 0, "Score should not change")
        XCTAssertEqual(logic.streak, 0, "Streak should not change")
    }
    
    func testSubmitAnswerWhenPaused() throws {
        logic.startGame()
        logic.pauseRound()
        logic.submitAnswer(.left)
        
        XCTAssertTrue(logic.isRoundPaused, "Game should remain paused")
        XCTAssertEqual(logic.score, 0, "Score should not change")
        XCTAssertEqual(logic.streak, 0, "Streak should not change")
    }
    
    func testSubmitAnswerWhenActive() throws {
        logic.startGame()
        logic.submitAnswer(.left)
        
        XCTAssertTrue(logic.isGameActive, "Game should remain active")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused")
        XCTAssertEqual(logic.currentRound, 1, "Round should advance after answer")
        XCTAssertGreaterThan(logic.score, 0, "Score should increase after correct answer")
        XCTAssertEqual(logic.streak, 1, "Streak should increase after correct answer")
    }
    
    // MARK: - Round Advancement Tests
    
    func testAdvanceRound() throws {
        logic.startGame()
        let initialRound = logic.currentRound
        
        logic.advanceRound()
        
        XCTAssertEqual(logic.currentRound, initialRound + 1, "Round should advance by 1")
    }
    
    // MARK: - Computed Properties Tests
    
    func testLessonStyle() throws {
        XCTAssertEqual(logic.lessonStyle, .chord, "Lesson style should be chord")
    }
    
    func testIsPhaseDescending() throws {
        XCTAssertFalse(logic.isPhaseDescending, "Phase should not be descending for ascending direction")
    }
    
    func testIsProgressionLowToHigh() throws {
        XCTAssertTrue(logic.isProgressionLowToHigh, "Progression should be low to high")
    }
    
    func testActiveStringOrder() throws {
        let expectedOrder = [1, 2, 3, 4, 5, 6]
        XCTAssertEqual(logic.activeStringOrder, expectedOrder, "String order should be 1-6 for low to high progression")
    }
    
    func testUsesFlats() throws {
        XCTAssertFalse(logic.usesFlats, "Should not use flats for ascending direction")
    }
    
    // MARK: - Configuration Tests
    
    func testSelectedMode() throws {
        XCTAssertEqual(logic.selectedMode, .chord, "Selected mode should be chord")
    }
    
    func testBeatBPM() throws {
        XCTAssertEqual(logic.beatBPM, 120, "Beat BPM should be 120")
    }
    
    func testBeatVolume() throws {
        XCTAssertEqual(logic.beatVolume, 0.8, "Beat volume should be 0.8")
    }
    
    func testStringVolume() throws {
        XCTAssertEqual(logic.stringVolume, 0.8, "String volume should be 0.8")
    }
    
    // MARK: - Audio Tests
    
    func testPlayGuitarNote() throws {
        // This test ensures the method doesn't crash
        logic.playGuitarNote(forString: 1, fret: 0)
        
        // In a real test, you would verify the audio engine was called
        // For now, we just ensure no crash occurs
    }
    
    func testPlayCurrentPromptedGuitarNotes() throws {
        // This test ensures the method doesn't crash
        logic.playCurrentPromptedGuitarNotes()
        
        // In a real test, you would verify the audio engine was called
        // For now, we just ensure no crash occurs
    }
    
    func testSyncBackingTrackPlayback() throws {
        // This test ensures the method doesn't crash
        logic.syncBackingTrackPlayback()
        logic.syncBackingTrackPlayback(allowResumeFromPause: true)
        
        // In a real test, you would verify the audio engine was called
        // For now, we just ensure no crash occurs
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultiplePauseResume() throws {
        logic.startGame()
        
        // Multiple pause/resume cycles
        for _ in 0..<5 {
            logic.pauseRound()
            XCTAssertTrue(logic.isRoundPaused, "Game should be paused")
            
            logic.resumeRound()
            XCTAssertFalse(logic.isRoundPaused, "Game should be resumed")
        }
    }
    
    func testResetWhilePaused() throws {
        logic.startGame()
        logic.pauseRound()
        logic.resetRound()
        
        XCTAssertTrue(logic.isGameActive, "Game should remain active")
        XCTAssertFalse(logic.isRoundPaused, "Game should not be paused after reset")
    }
    
    func testAdvanceRoundMultipleTimes() throws {
        logic.startGame()
        
        for i in 1...10 {
            logic.advanceRound()
            XCTAssertEqual(logic.currentRound, i, "Round should be \(i) after \(i) advances")
        }
    }
    
    // MARK: - Performance Tests
    
    func testGameStartPerformance() throws {
        measure {
            for _ in 0..<100 {
                logic.resetRound()
                logic.startGame()
            }
        }
    }
    
    func testAnswerSubmissionPerformance() throws {
        logic.startGame()
        
        measure {
            for _ in 0..<1000 {
                logic.submitAnswer(.left)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryLeakPrevention() throws {
        weak var weakLogic: BeginnerGameplayLogic?
        
        autoreleasepool {
            let startingFret = Binding.constant(0)
            let repetitions = Binding.constant(10)
            let infiniteRepetitions = Binding.constant(false)
            let directionRawValue = Binding.constant("ascending")
            let enableHighFrets = Binding.constant(false)
            let lessonStyle = Binding.constant("chord")
            let progression = Binding.constant("lowToHigh")
            let walletDollars = Binding.constant(100)
            let balanceDollars = Binding.constant(50)
            
            let testLogic = BeginnerGameplayLogic(
                selectedMode: .chord,
                beatBPM: 120,
                beatVolume: 0.8,
                stringVolume: 0.8,
                playStartingFret: startingFret,
                playRepetitions: repetitions,
                playInfiniteRepetitions: infiniteRepetitions,
                playDirectionRawValue: directionRawValue,
                playEnableHighFrets: enableHighFrets,
                playLessonStyle: lessonStyle,
                playProgression: progression,
                walletDollars: walletDollars,
                balanceDollars: balanceDollars
            )
            
            testLogic.startGame()
            testLogic.submitAnswer(.left)
            testLogic.pauseRound()
            testLogic.resumeRound()
            
            weakLogic = testLogic
        }
        
        XCTAssertNil(weakLogic, "Logic should be deallocated")
    }
}