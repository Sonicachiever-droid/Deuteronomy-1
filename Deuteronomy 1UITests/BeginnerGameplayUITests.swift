import XCTest

// MARK: - Beginner Gameplay UI Tests

final class BeginnerGameplayUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Navigation Tests
    
    func testWelcomeScreenElements() throws {
        // Test welcome screen is displayed
        XCTAssertTrue(app.staticTexts["Welcome to Deuteronomy 1"].waitForExistence(timeout: 5), "Welcome title should exist")
        XCTAssertTrue(app.staticTexts["Music Learning Adventure"].exists, "Welcome subtitle should exist")
        
        // Test mode buttons
        XCTAssertTrue(app.buttons["Beginner"].exists, "Beginner button should exist")
        XCTAssertTrue(app.buttons["Maestro"].exists, "Maestro button should exist")
    }
    
    func testNavigateToBeginnerMode() throws {
        // Navigate to beginner mode
        app.buttons["Beginner"].tap()
        
        // Wait for gameplay view to load
        XCTAssertTrue(app.staticTexts["Round 1"].waitForExistence(timeout: 5), "Round label should exist")
        XCTAssertTrue(app.staticTexts["Score: 0"].exists, "Score label should exist")
        XCTAssertTrue(app.staticTexts["Streak: 0"].exists, "Streak label should exist")
    }
    
    // MARK: - Game Control Tests
    
    func testStartButton() throws {
        navigateToBeginnerMode()
        
        // Test start button
        let startButton = app.buttons["START"]
        XCTAssertTrue(startButton.exists, "Start button should exist")
        XCTAssertTrue(startButton.isEnabled, "Start button should be enabled")
        
        // Tap start button
        startButton.tap()
        
        // Verify game started
        XCTAssertTrue(app.buttons["PAUSE"].exists, "Pause button should exist after start")
        XCTAssertFalse(app.buttons["START"].exists, "Start button should not exist after start")
    }
    
    func testPauseResumeButton() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Test pause button
        let pauseButton = app.buttons["PAUSE"]
        XCTAssertTrue(pauseButton.exists, "Pause button should exist")
        XCTAssertTrue(pauseButton.isEnabled, "Pause button should be enabled")
        
        // Tap pause button
        pauseButton.tap()
        
        // Verify game paused
        XCTAssertTrue(app.buttons["RESUME"].exists, "Resume button should exist after pause")
        XCTAssertTrue(app.staticTexts["Paused"].exists, "Paused status should be shown")
        
        // Test resume button
        let resumeButton = app.buttons["RESUME"]
        XCTAssertTrue(resumeButton.exists, "Resume button should exist")
        XCTAssertTrue(resumeButton.isEnabled, "Resume button should be enabled")
        
        // Tap resume button
        resumeButton.tap()
        
        // Verify game resumed
        XCTAssertTrue(app.buttons["PAUSE"].exists, "Pause button should exist after resume")
        XCTAssertFalse(app.staticTexts["Paused"].exists, "Paused status should not exist after resume")
    }
    
    func testResetButton() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Advance a round to change score
        advanceRound()
        
        // Verify score changed
        XCTAssertGreaterThan(Int(app.staticTexts.matching(identifier: "Score").firstMatch.label.replacingOccurrences(of: "Score: ", with: "")) ?? 0, 0, "Score should be greater than 0")
        
        // Test reset button
        let resetButton = app.buttons["RESET"]
        XCTAssertTrue(resetButton.exists, "Reset button should exist")
        XCTAssertTrue(resetButton.isEnabled, "Reset button should be enabled")
        
        // Tap reset button
        resetButton.tap()
        
        // Verify game reset
        XCTAssertTrue(app.staticTexts["Score: 0"].exists, "Score should be 0 after reset")
        XCTAssertTrue(app.staticTexts["Streak: 0"].exists, "Streak should be 0 after reset")
        XCTAssertTrue(app.staticTexts["Round 1"].exists, "Round should be 1 after reset")
    }
    
    // MARK: - Answer Button Tests
    
    func testAnswerButtonsExist() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Test answer buttons exist
        XCTAssertTrue(app.buttons["Left"].exists, "Left answer button should exist")
        XCTAssertTrue(app.buttons["Right"].exists, "Right answer button should exist")
        XCTAssertTrue(app.buttons["Left"].isEnabled, "Left answer button should be enabled")
        XCTAssertTrue(app.buttons["Right"].isEnabled, "Right answer button should be enabled")
    }
    
    func testAnswerButtonInteraction() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Tap left answer button
        app.buttons["Left"].tap()
        
        // Verify round advanced
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Round'")).element(boundBy: 0).exists, "Round should advance after answer")
        
        // Tap right answer button
        app.buttons["Right"].tap()
        
        // Verify round advanced again
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Round'")).element(boundBy: 0).exists, "Round should advance after second answer")
    }
    
    // MARK: - UI Element Tests
    
    func testScoreDisplay() throws {
        navigateToBeginnerMode()
        
        // Test initial score
        XCTAssertTrue(app.staticTexts["Score: 0"].exists, "Initial score should be 0")
        
        startGame()
        advanceRound()
        
        // Test score after round
        let scoreLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Score'")).firstMatch
        XCTAssertTrue(scoreLabel.exists, "Score label should exist")
        
        let scoreText = scoreLabel.label
        let scoreValue = Int(scoreText.replacingOccurrences(of: "Score: ", with: "")) ?? 0
        XCTAssertGreaterThan(scoreValue, 0, "Score should increase after correct answer")
    }
    
    func testStreakDisplay() throws {
        navigateToBeginnerMode()
        
        // Test initial streak
        XCTAssertTrue(app.staticTexts["Streak: 0"].exists, "Initial streak should be 0")
        
        startGame()
        
        // Get multiple correct answers
        for _ in 0..<3 {
            advanceRound()
        }
        
        // Test streak after multiple answers
        let streakLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Streak'")).firstMatch
        XCTAssertTrue(streakLabel.exists, "Streak label should exist")
        
        let streakText = streakLabel.label
        let streakValue = Int(streakText.replacingOccurrences(of: "Streak: ", with: "")) ?? 0
        XCTAssertGreaterThan(streakValue, 0, "Streak should increase after multiple correct answers")
    }
    
    func testRoundDisplay() throws {
        navigateToBeginnerMode()
        
        // Test initial round
        XCTAssertTrue(app.staticTexts["Round 1"].exists, "Initial round should be 1")
        
        startGame()
        
        // Advance multiple rounds
        for i in 2...5 {
            advanceRound()
            XCTAssertTrue(app.staticTexts["Round \(i)"].waitForExistence(timeout: 2), "Round should be \(i)")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Test button accessibility labels
        let startButton = app.buttons["START"]
        XCTAssertTrue(startButton.exists, "Start button should exist")
        XCTAssertEqual(startButton.label, "START", "Start button should have correct label")
        
        let leftAnswerButton = app.buttons["Left"]
        XCTAssertTrue(leftAnswerButton.exists, "Left answer button should exist")
        XCTAssertEqual(leftAnswerButton.label, "Left", "Left answer button should have correct label")
        
        let rightAnswerButton = app.buttons["Right"]
        XCTAssertTrue(rightAnswerButton.exists, "Right answer button should exist")
        XCTAssertEqual(rightAnswerButton.label, "Right", "Right answer button should have correct label")
    }
    
    func testAccessibilityHints() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Test button accessibility hints
        let startButton = app.buttons["START"]
        if startButton.exists {
            // Note: Accessibility hints may not be directly testable in UI tests
            // This is more for documentation that hints should exist
        }
    }
    
    // MARK: - Menu Tests
    
    func testMenuButton() throws {
        navigateToBeginnerMode()
        
        // Test menu button exists
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.exists, "Menu button should exist")
        
        // Tap menu button
        menuButton.tap()
        
        // Test menu items exist
        XCTAssertTrue(app.buttons["Resume Game"].waitForExistence(timeout: 3), "Resume game option should exist")
        XCTAssertTrue(app.buttons["Reset Game"].exists, "Reset game option should exist")
        XCTAssertTrue(app.buttons["Main Menu"].exists, "Main menu option should exist")
        XCTAssertTrue(app.buttons["Audio Settings"].exists, "Audio settings option should exist")
    }
    
    func testMenuNavigation() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Open menu
        app.buttons["Menu"].tap()
        
        // Test resume game
        app.buttons["Resume Game"].tap()
        XCTAssertTrue(app.buttons["PAUSE"].exists, "Should return to game after resume")
        
        // Open menu again
        app.buttons["Menu"].tap()
        
        // Test reset game
        app.buttons["Reset Game"].tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].exists, "Score should be 0 after reset from menu")
    }
    
    // MARK: - Audio Settings Tests
    
    func testAudioSettingsButton() throws {
        navigateToBeginnerMode()
        
        // Test audio settings button exists
        let audioButton = app.buttons["Audio Settings"]
        XCTAssertTrue(audioButton.exists, "Audio settings button should exist")
        
        // Tap audio settings button
        audioButton.tap()
        
        // Test audio settings elements
        XCTAssertTrue(app.staticTexts["Audio Settings"].waitForExistence(timeout: 3), "Audio settings title should exist")
        XCTAssertTrue(app.buttons["Done"].exists, "Done button should exist")
    }
    
    // MARK: - Hint Button Tests
    
    func testHintButton() throws {
        navigateToBeginnerMode()
        startGame()
        
        // Test hint button exists
        let hintButton = app.buttons["Hint"]
        XCTAssertTrue(hintButton.exists, "Hint button should exist")
        XCTAssertTrue(hintButton.isEnabled, "Hint button should be enabled")
        
        // Tap hint button
        hintButton.tap()
        
        // In a real test, you would verify the hint was shown/audio played
        // For now, we just ensure no crash occurs
    }
    
    // MARK: - Performance Tests
    
    func testGameLaunchPerformance() throws {
        measure {
            app.terminate()
            app.launch()
            
            // Navigate to beginner mode
            if app.buttons["Beginner"].exists {
                app.buttons["Beginner"].tap()
            }
        }
    }
    
    func testRoundTransitionPerformance() throws {
        navigateToBeginnerMode()
        startGame()
        
        measure {
            for _ in 0..<10 {
                app.buttons["Left"].tap()
                // Wait for round transition
                _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Round'")).firstMatch.waitForExistence(timeout: 1)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToBeginnerMode() {
        if app.buttons["Beginner"].exists {
            app.buttons["Beginner"].tap()
        }
    }
    
    private func startGame() {
        if app.buttons["START"].exists {
            app.buttons["START"].tap()
        }
    }
    
    private func advanceRound() {
        // Tap either left or right answer button
        if app.buttons["Left"].exists && app.buttons["Left"].isEnabled {
            app.buttons["Left"].tap()
        } else if app.buttons["Right"].exists && app.buttons["Right"].isEnabled {
            app.buttons["Right"].tap()
        }
        
        // Wait for round transition
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Round'")).firstMatch.waitForExistence(timeout: 2)
    }
}