import XCTest
import CoreGraphics
@testable import Deuteronomy_1

// MARK: - UI Constants & Layout Tests
//
// Tests the real types that exist:
//   - UIConstants      (flat enum with static CGFloat constants)
//   - GameConstants    (enum with static game behavior values)
//   - AnimationDurations (enum with static TimeInterval values)
//   - UIMetrics        (enum with static CGFloat UI sizing values)
//   - GuitarStringLayout (fretboard geometry)
//   - FretMath         (fret position ratios)

final class UIConstantsTests: XCTestCase {

    // MARK: - Console Frame Radii (must be positive and in descending order outward→inward)

    func testConsoleFrameRadiiArePositive() {
        XCTAssertGreaterThan(UIConstants.consoleFrameRadius, 0)
        XCTAssertGreaterThan(UIConstants.consoleInnerBorderRadius, 0)
        XCTAssertGreaterThan(UIConstants.consoleContentRadius, 0)
        XCTAssertGreaterThan(UIConstants.consoleInnerFrameRadius, 0)
    }

    func testConsoleFrameRadiiDescendingOutwardToInward() {
        // Each layer is inset from the previous — radii should decrease
        XCTAssertGreaterThan(UIConstants.consoleFrameRadius, UIConstants.consoleInnerBorderRadius,
            "Outer frame radius must be greater than inner border radius")
        XCTAssertGreaterThan(UIConstants.consoleInnerBorderRadius, UIConstants.consoleContentRadius,
            "Inner border radius must be greater than content radius")
        XCTAssertGreaterThan(UIConstants.consoleContentRadius, UIConstants.consoleInnerFrameRadius,
            "Content radius must be greater than innermost frame radius")
    }

    // MARK: - Control Plate

    func testControlPlateConstantsArePositive() {
        XCTAssertGreaterThan(UIConstants.controlPlateRadius, 0)
        XCTAssertGreaterThan(UIConstants.controlPlateButtonRadius, 0)
        XCTAssertGreaterThan(UIConstants.controlPlateButtonHeight, 0)
        XCTAssertGreaterThan(UIConstants.controlPlatePaddingH, 0)
        XCTAssertGreaterThan(UIConstants.controlPlatePaddingV, 0)
    }

    func testControlPlateButtonHeightIsReasonable() {
        XCTAssertGreaterThan(UIConstants.controlPlateButtonHeight, 20,
            "Button height should be at least 20pt for tap targets")
        XCTAssertLessThan(UIConstants.controlPlateButtonHeight, 80,
            "Button height should not exceed 80pt")
    }

    // MARK: - Transport Buttons

    func testTransportButtonConstantsArePositive() {
        XCTAssertGreaterThan(UIConstants.transportButtonHeight, 0)
        XCTAssertGreaterThan(UIConstants.transportButtonMinWidth, 0)
    }

    func testTransportButtonMinWidthExceedsHeight() {
        // Transport buttons should be wider than tall (landscape-ish)
        XCTAssertGreaterThan(UIConstants.transportButtonMinWidth, UIConstants.transportButtonHeight,
            "Transport buttons should be wider than they are tall")
    }

    // MARK: - Answer Box

    func testAnswerBoxRadiusIsPositive() {
        XCTAssertGreaterThan(UIConstants.answerBoxRadius, 0)
        XCTAssertLessThan(UIConstants.answerBoxRadius, 20,
            "Answer box radius should be modest — not pill-shaped")
    }

    // MARK: - Power Indicator

    func testPowerIndicatorDotSmallerThanContainer() {
        XCTAssertGreaterThan(UIConstants.powerIndicatorDotDiameter, 0)
        XCTAssertLessThan(UIConstants.powerIndicatorDotDiameter, UIConstants.powerIndicatorDiameter,
            "Power indicator dot must be smaller than its container")
    }

    // MARK: - Indicator Dots

    func testIndicatorDotSizesOrdered() {
        XCTAssertGreaterThan(UIConstants.indicatorDotMedium, UIConstants.indicatorDotSmall,
            "Medium indicator dot must be larger than small")
    }

    // MARK: - MiniTV Bezel

    func testMiniTVBezelInsetsArePositive() {
        XCTAssertGreaterThan(UIConstants.miniTVBezelInsetW, 0)
        XCTAssertGreaterThan(UIConstants.miniTVBezelInsetH, 0)
    }

    // MARK: - Padding / Insets

    func testConsolePaddingIsPositive() {
        XCTAssertGreaterThan(UIConstants.consoleFramePadding, 0)
        XCTAssertGreaterThan(UIConstants.consoleContentPadding, 0)
    }

    // MARK: - Progress Bar

    func testProgressBarRadiusIsSubpixelScale() {
        // This is intentionally small (1.5pt) to be a thin bar
        XCTAssertGreaterThan(UIConstants.progressBarRadius, 0)
        XCTAssertLessThan(UIConstants.progressBarRadius, 5,
            "Progress bar radius should be very small for a thin line appearance")
    }
}

// MARK: - Game Constants Tests

final class GameConstantsTests: XCTestCase {

    func testStringCountIsSix() {
        XCTAssertEqual(GameConstants.stringCount, 6, "A guitar has 6 strings")
    }

    func testMaxRevealCountIsPositive() {
        XCTAssertGreaterThan(GameConstants.maxRevealCount, 0)
    }

    func testLeftAndRightColumnStringsCoverAllSix() {
        let allStrings = Set(GameConstants.leftColumnStrings + GameConstants.rightColumnStrings)
        XCTAssertEqual(allStrings, Set([1, 2, 3, 4, 5, 6]),
            "Left + right column strings must cover all 6 strings exactly once")
    }

    func testLeftColumnStringsAreCorrect() {
        // Left column: strings 4, 5, 6 (top→bottom)
        XCTAssertEqual(Set(GameConstants.leftColumnStrings), Set([4, 5, 6]))
    }

    func testRightColumnStringsAreCorrect() {
        // Right column: strings 3, 2, 1 (top→bottom)
        XCTAssertEqual(Set(GameConstants.rightColumnStrings), Set([1, 2, 3]))
    }

    func testMinBPMIsPlayable() {
        XCTAssertGreaterThanOrEqual(GameConstants.minBPM, 40,
            "Min BPM should be at least 40 to be musically playable")
        XCTAssertLessThanOrEqual(GameConstants.minBPM, 80,
            "Min BPM should not be too fast — it's the minimum")
    }

    func testRevealGateBeatsIsPositive() {
        XCTAssertGreaterThan(GameConstants.revealGateBeats, 0)
    }

    func testAutoPlayIntervalIsPositive() {
        XCTAssertGreaterThan(GameConstants.autoPlayInterval, 0)
        XCTAssertLessThan(GameConstants.autoPlayInterval, 1.0,
            "Auto-play interval should be under 1 second for fluid playback")
    }
}

// MARK: - Animation Duration Tests

final class AnimationDurationTests: XCTestCase {

    func testAllDurationsArePositive() {
        XCTAssertGreaterThan(AnimationDurations.launchTransition, 0)
        XCTAssertGreaterThan(AnimationDurations.beatFlash, 0)
        XCTAssertGreaterThan(AnimationDurations.resetDelay, 0)
        XCTAssertGreaterThan(AnimationDurations.armedFlashPeriod, 0)
    }

    func testBeatFlashIsShorterThanLaunchTransition() {
        // Beat flash should be imperceptibly quick; launch is a visible animation
        XCTAssertLessThan(AnimationDurations.beatFlash, AnimationDurations.launchTransition,
            "Beat flash should be much shorter than the launch transition")
    }

    func testLaunchTransitionIsUnderOneSecond() {
        XCTAssertLessThan(AnimationDurations.launchTransition, 1.0,
            "Launch transition should feel snappy — under 1 second")
    }

    func testResetDelayIsShort() {
        XCTAssertLessThan(AnimationDurations.resetDelay, 1.0,
            "Reset delay should be brief")
    }
}

// MARK: - UIMetrics Tests

final class UIMetricsTests: XCTestCase {

    func testBannerHeightBoundsAreConsistent() {
        XCTAssertGreaterThan(UIMetrics.bannerMaxHeight, UIMetrics.bannerMinHeight,
            "Max banner height must exceed min banner height")
        XCTAssertGreaterThan(UIMetrics.bannerMinHeight, 0)
    }

    func testBannerHeightFractionIsBetweenZeroAndOne() {
        XCTAssertGreaterThan(UIMetrics.bannerHeightFraction, 0)
        XCTAssertLessThan(UIMetrics.bannerHeightFraction, 1.0,
            "Banner height fraction should be less than 1.0 (less than full row height)")
    }

    func testBannerFontScaleIsReasonable() {
        XCTAssertGreaterThan(UIMetrics.bannerFontScale, 0.5,
            "Banner font scale should not be extremely small")
        XCTAssertLessThanOrEqual(UIMetrics.bannerFontScale, 1.0,
            "Banner font scale should be at most full size")
    }

    func testStartupFontSizeIsReadable() {
        XCTAssertGreaterThan(UIMetrics.startupFontSize, 16,
            "Startup font size should be at least 16pt for legibility")
        XCTAssertLessThan(UIMetrics.startupFontSize, 60,
            "Startup font size should not be excessively large")
    }
}

// MARK: - Guitar String Layout Tests

final class GuitarStringLayoutTests: XCTestCase {

    func testTotalStringsIsSix() {
        XCTAssertEqual(GuitarStringLayout.totalStrings, 6)
    }

    func testStringCentersCountMatchesTotalStrings() {
        let centers = GuitarStringLayout.stringCenters(containerWidth: 375, neckWidth: 300)
        XCTAssertEqual(centers.count, GuitarStringLayout.totalStrings,
            "stringCenters must return exactly \(GuitarStringLayout.totalStrings) values")
    }

    func testStringCentersAreWithinContainerWidth() {
        let containerWidth: CGFloat = 375
        let neckWidth: CGFloat = 300
        let centers = GuitarStringLayout.stringCenters(containerWidth: containerWidth, neckWidth: neckWidth)

        for (i, center) in centers.enumerated() {
            XCTAssertGreaterThanOrEqual(center, 0,
                "String \(i+1) center should be >= 0")
            XCTAssertLessThanOrEqual(center, containerWidth,
                "String \(i+1) center should be <= container width")
        }
    }

    func testStringCentersAreMonotonicallyIncreasing() {
        let centers = GuitarStringLayout.stringCenters(containerWidth: 375, neckWidth: 300)
        for i in 0..<(centers.count - 1) {
            XCTAssertLessThan(centers[i], centers[i + 1],
                "String centers should increase left-to-right (string \(i+1) < string \(i+2))")
        }
    }

    func testStringCentersWithZeroContainerReturnsDefaults() {
        // Edge case: zero container should not crash
        let centers = GuitarStringLayout.stringCenters(containerWidth: 0, neckWidth: 0)
        XCTAssertEqual(centers.count, GuitarStringLayout.totalStrings,
            "Should return correct count even with zero dimensions")
    }
}

// MARK: - FretMath Tests

final class FretMathTests: XCTestCase {

    func testFretPositionCountMatchesTotalFrets() {
        let totalFrets = 20
        let ratios = FretMath.fretPositionRatios(totalFrets: totalFrets, scaleLength: 25.5)
        // Returns frets 0...totalFrets = totalFrets + 1 values
        XCTAssertEqual(ratios.count, totalFrets + 1,
            "fretPositionRatios must return totalFrets + 1 values (including nut at fret 0)")
    }

    func testFretZeroRatioIsZero() {
        let ratios = FretMath.fretPositionRatios(totalFrets: 12, scaleLength: 25.5)
        XCTAssertEqual(ratios[0], 0.0, accuracy: 0.001,
            "Fret 0 (nut) should be at position 0")
    }

    func testFretRatiosAreStrictlyIncreasing() {
        let ratios = FretMath.fretPositionRatios(totalFrets: 12, scaleLength: 25.5)
        for i in 0..<(ratios.count - 1) {
            XCTAssertLessThan(ratios[i], ratios[i + 1],
                "Fret positions must increase from nut toward body (fret \(i) < fret \(i+1))")
        }
    }

    func testFretRatiosAreAllLessThanOne() {
        let ratios = FretMath.fretPositionRatios(totalFrets: 24, scaleLength: 25.5)
        for (i, ratio) in ratios.enumerated() {
            XCTAssertLessThan(ratio, 1.0,
                "No fret position should reach the bridge (ratio < 1.0) — fret \(i) = \(ratio)")
        }
    }

    func testFretMathWithZeroScaleLengthDoesNotCrash() {
        // Should not crash or produce NaN/inf
        let ratios = FretMath.fretPositionRatios(totalFrets: 5, scaleLength: 0)
        XCTAssertEqual(ratios.count, 6)
        for ratio in ratios {
            XCTAssertFalse(ratio.isNaN, "Ratios should not be NaN with zero scale length")
            XCTAssertFalse(ratio.isInfinite, "Ratios should not be infinite with zero scale length")
        }
    }
}
