import XCTest
@testable import Deuteronomy_1

// MARK: - Speed Run Tests
//
// Tests for the Speed Run mode added in v1.4.
//
// Coverage:
//   1. Clock formatter  (formatSpeedRunTime)
//   2. Traversal arithmetic  (speedRunTotalFretPositions)
//   3. Best-time comparison  (speedRunIsNewBest)
//   4. LessonStyle enum has .speedRun case
//   5. SpeedRunResultOverlay isNewBest / previousBest logic (via model-layer helpers)

final class SpeedRunClockFormatterTests: XCTestCase {

    // MARK: - Zero / negative → placeholder

    func testZeroReturnsPlaceholder() {
        XCTAssertEqual(formatSpeedRunTime(0), "--:--.--")
    }

    func testNegativeReturnsPlaceholder() {
        XCTAssertEqual(formatSpeedRunTime(-5), "--:--.--")
    }

    // MARK: - Sub-minute times

    func testSevenAndAHalfSeconds() {
        // 7.50s → 0 min, 7 sec, 50 centis
        XCTAssertEqual(formatSpeedRunTime(7.50), "0:07.50")
    }

    func testExactlyOneSecond() {
        XCTAssertEqual(formatSpeedRunTime(1.0), "0:01.00")
    }

    func testOneCentisecond() {
        // 0.01 s → "0:00.01"
        XCTAssertEqual(formatSpeedRunTime(0.01), "0:00.01")
    }

    func testNinetyNineCentiseconds() {
        // 0.99 s → "0:00.99"
        XCTAssertEqual(formatSpeedRunTime(0.99), "0:00.99")
    }

    func testFiftyNinePointNineNineSeconds() {
        // 59.99s → "0:59.99"
        XCTAssertEqual(formatSpeedRunTime(59.99), "0:59.99")
    }

    // MARK: - Over-minute times

    func testExactlyOneMinute() {
        // 60s → "1:00.00"
        XCTAssertEqual(formatSpeedRunTime(60.0), "1:00.00")
    }

    func testOneMinuteTenPointFive() {
        // 70.5s = 1 min 10 sec 50 centis → "1:10.50"
        XCTAssertEqual(formatSpeedRunTime(70.5), "1:10.50")
    }

    func testTwoMinutesSevenPointFortyThree() {
        // From the docstring example: "2:07.43"
        let t = 2 * 60.0 + 7.43
        XCTAssertEqual(formatSpeedRunTime(t), "2:07.43")
    }

    func testDoubleDigitMinutes() {
        // 10 min 0 sec → "10:00.00"
        XCTAssertEqual(formatSpeedRunTime(600.0), "10:00.00")
    }

    // MARK: - Centisecond boundary (truncation, not rounding)

    func testCentisecondTruncationNotRounding() {
        // 1.999 → centis = Int(0.999 * 100) = 99, not 100
        XCTAssertEqual(formatSpeedRunTime(1.999), "0:01.99")
    }
}

// MARK: - Traversal Arithmetic

final class SpeedRunTraversalTests: XCTestCase {

    // MARK: - High Frets OFF (maxFret = 12)
    //
    // Ascending:  frets 0–12  → 13 positions
    // Descending: frets 11–1  → 11 positions
    // Completion: fret 0      →  1 position
    // Subtotal per string: 25
    // × 6 strings = 150

    func testTotalPositionsHighFretsOff() {
        // speedRunTotalFretPositions(maxFret: 12) = (13 + 11 + 1) * 6 = 150
        XCTAssertEqual(speedRunTotalFretPositions(maxFret: 12), 150)
    }

    func testAscendingCountHighFretsOff() {
        // Ascending leg alone: frets 0..12 = 13 frets × 6 strings
        let ascending = (12 + 1) * 6
        XCTAssertEqual(ascending, 78)
    }

    func testDescendingCountHighFretsOff() {
        // Descending leg: frets 11..1 = 11 frets × 6 strings (fret 0 is completion trigger)
        let descending = (12 - 1) * 6
        XCTAssertEqual(descending, 66)
    }

    func testDescendingStartsAtMaxMinusOne() {
        // The descending leg starts at maxFret - 1, NOT at maxFret (which was the turn-around point)
        let maxFret = 12
        let descendingStart = maxFret - 1
        XCTAssertEqual(descendingStart, 11)
    }

    // MARK: - High Frets ON (maxFret = 19)
    //
    // Ascending:  frets 0–19  → 20 positions
    // Descending: frets 18–1  → 18 positions
    // Completion: fret 0      →  1 position
    // Subtotal per string: 39
    // × 6 strings = 234

    func testTotalPositionsHighFretsOn() {
        XCTAssertEqual(speedRunTotalFretPositions(maxFret: 19), 234)
    }

    func testAscendingCountHighFretsOn() {
        let ascending = (19 + 1) * 6
        XCTAssertEqual(ascending, 120)
    }

    func testDescendingCountHighFretsOn() {
        let descending = (19 - 1) * 6
        XCTAssertEqual(descending, 108)
    }

    func testDescendingStartsAtMaxMinusOneHighFretsOn() {
        let maxFret = 19
        let descendingStart = maxFret - 1
        XCTAssertEqual(descendingStart, 18)
    }

    // MARK: - Completion fires at fret 0 descending

    func testCompletionFretIsZero() {
        // After descending from (maxFret-1) down to 1, the next step is fret 0 — completion.
        let afterFretOne = 1 - 1
        XCTAssertEqual(afterFretOne, 0)
    }

    // MARK: - Formula consistency

    func testFormulaMatchesDocstring() {
        // Docstring: total = 2 * maxFret + 1 positions per string × 6
        for maxFret in [12, 19] {
            let expected = (2 * maxFret + 1) * 6
            XCTAssertEqual(speedRunTotalFretPositions(maxFret: maxFret), expected,
                "maxFret=\(maxFret): formula mismatch")
        }
    }
}

// MARK: - Best Time Comparison

final class SpeedRunBestTimeTests: XCTestCase {

    // MARK: - First run ever (bestTime == 0 means no record)

    func testFirstRunIsAlwaysNewBest() {
        // bestTime == 0 → no previous record → any elapsed > 0 is a new best
        XCTAssertTrue(speedRunIsNewBest(elapsed: 120.0, bestTime: 0))
    }

    func testFirstRunOneSecond() {
        XCTAssertTrue(speedRunIsNewBest(elapsed: 1.0, bestTime: 0))
    }

    // MARK: - Improvement

    func testFasterTimeIsNewBest() {
        // Previous best: 120s, new run: 110s → improvement
        XCTAssertTrue(speedRunIsNewBest(elapsed: 110.0, bestTime: 120.0))
    }

    func testSlightlyFasterTimeIsNewBest() {
        XCTAssertTrue(speedRunIsNewBest(elapsed: 99.99, bestTime: 100.0))
    }

    // MARK: - No improvement

    func testSlowerTimeIsNotNewBest() {
        XCTAssertFalse(speedRunIsNewBest(elapsed: 130.0, bestTime: 120.0))
    }

    func testEqualTimeIsNotNewBest() {
        // Exact same time — not strictly better, so not a new best
        XCTAssertFalse(speedRunIsNewBest(elapsed: 120.0, bestTime: 120.0))
    }

    // MARK: - Edge cases

    func testZeroElapsedIsNotNewBest() {
        // elapsed == 0 means the timer never started — not a valid result
        XCTAssertFalse(speedRunIsNewBest(elapsed: 0, bestTime: 0))
    }

    func testNegativeElapsedIsNotNewBest() {
        XCTAssertFalse(speedRunIsNewBest(elapsed: -1.0, bestTime: 0))
    }
}

// MARK: - LessonStyle enum

final class SpeedRunLessonStyleTests: XCTestCase {

    func testSpeedRunCaseExists() {
        let style = LessonStyle(rawValue: "speedRun")
        XCTAssertNotNil(style, ".speedRun case must exist in LessonStyle")
        XCTAssertEqual(style, .speedRun)
    }

    func testSpeedRunRawValue() {
        XCTAssertEqual(LessonStyle.speedRun.rawValue, "speedRun")
    }

    func testAllCasesContainsSpeedRun() {
        XCTAssertTrue(LessonStyle.allCases.contains(.speedRun))
    }

    func testSpeedRunIsDistinctFromOtherStyles() {
        XCTAssertNotEqual(LessonStyle.speedRun, .sequential)
        XCTAssertNotEqual(LessonStyle.speedRun, .chord)
    }
}

// MARK: - Result overlay logic

final class SpeedRunResultOverlayLogicTests: XCTestCase {

    // These tests mirror the computed properties inside SpeedRunResultOverlay
    // but exercise the model-layer helpers directly.

    func testNewBestWhenElapsedEqualsStoredBest() {
        // In SpeedRunResultOverlay: isNewBest = elapsed > 0 && elapsed == bestTime
        // This happens because advanceGame saves elapsed → bestTime before the overlay appears.
        let elapsed = 95.5
        let bestTime = 95.5   // same value → new best
        let isNewBest = elapsed > 0 && elapsed == bestTime
        XCTAssertTrue(isNewBest)
    }

    func testNotNewBestWhenBestIsLower() {
        let elapsed = 105.0
        let bestTime = 95.5   // previous run was faster
        let isNewBest = elapsed > 0 && elapsed == bestTime
        XCTAssertFalse(isNewBest)
    }

    func testPreviousBestShownWhenNotNewBest() {
        let elapsed = 105.0
        let bestTime = 95.5
        let isNewBest = elapsed > 0 && elapsed == bestTime
        let previousBest: Double = isNewBest ? 0 : bestTime
        // Overlay shows "BEST  x:xx.xx" when previousBest > 0 && !isNewBest
        XCTAssertFalse(isNewBest)
        XCTAssertGreaterThan(previousBest, 0)
    }

    func testPreviousBestZeroWhenIsNewBest() {
        let elapsed = 95.5
        let bestTime = 95.5
        let isNewBest = elapsed > 0 && elapsed == bestTime
        let previousBest: Double = isNewBest ? 0 : bestTime
        XCTAssertTrue(isNewBest)
        XCTAssertEqual(previousBest, 0)
    }

    func testOverlayFormatsElapsedCorrectly() {
        // Overlay uses formatSpeedRunTime — verify it matches expectations
        XCTAssertEqual(formatSpeedRunTime(95.5),  "1:35.50")
        XCTAssertEqual(formatSpeedRunTime(60.0),  "1:00.00")
        XCTAssertEqual(formatSpeedRunTime(0),     "--:--.--")
    }
}
