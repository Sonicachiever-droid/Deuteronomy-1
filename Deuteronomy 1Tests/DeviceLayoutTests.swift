import XCTest
@testable import Deuteronomy_1

// MARK: - Device Layout Tests

final class DeviceLayoutTests: XCTestCase {
    
    var deviceLayout: DeviceLayout!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        deviceLayout = DeviceLayout()
    }
    
    override func tearDownWithError() throws {
        deviceLayout = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Device Detection Tests
    
    func testDeviceLayoutInitialization() throws {
        XCTAssertNotNil(deviceLayout, "Device layout should initialize successfully")
    }
    
    func testAdaptiveSpacing() throws {
        XCTAssertGreaterThan(deviceLayout.adaptiveSpacing, 0, "Adaptive spacing should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.adaptiveSpacing, 50, "Adaptive spacing should be reasonable")
    }
    
    func testAdaptivePadding() throws {
        XCTAssertGreaterThan(deviceLayout.adaptivePadding, 0, "Adaptive padding should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.adaptivePadding, 50, "Adaptive padding should be reasonable")
    }
    
    func testFontScale() throws {
        XCTAssertGreaterThan(deviceLayout.fontScale, 0, "Font scale should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.fontScale, 2, "Font scale should be reasonable")
    }
    
    func testAdaptiveButtonHeight() throws {
        XCTAssertGreaterThan(deviceLayout.adaptiveButtonHeight, 30, "Button height should be at least 30")
        XCTAssertLessThanOrEqual(deviceLayout.adaptiveButtonHeight, 80, "Button height should not exceed 80")
    }
    
    func testAdaptiveCornerRadius() throws {
        XCTAssertGreaterThan(deviceLayout.adaptiveCornerRadius, 0, "Corner radius should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.adaptiveCornerRadius, 25, "Corner radius should be reasonable")
    }
    
    // MARK: - Layout Helper Tests
    
    func testFretboardWidthMultiplier() throws {
        XCTAssertGreaterThan(deviceLayout.fretboardWidthMultiplier, 0, "Fretboard width multiplier should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.fretboardWidthMultiplier, 1, "Fretboard width multiplier should not exceed 1")
    }
    
    func testConsoleButtonColumns() throws {
        XCTAssertGreaterThan(deviceLayout.consoleButtonColumns, 0, "Console button columns should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.consoleButtonColumns, 10, "Console button columns should be reasonable")
    }
    
    func testTransportButtonSpacing() throws {
        XCTAssertGreaterThan(deviceLayout.transportButtonSpacing, 0, "Transport button spacing should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.transportButtonSpacing, 30, "Transport button spacing should be reasonable")
    }
    
    func testAnswerButtonWidth() throws {
        XCTAssertGreaterThan(deviceLayout.answerButtonWidth, 50, "Answer button width should be at least 50")
        XCTAssertLessThanOrEqual(deviceLayout.answerButtonWidth, 250, "Answer button width should not exceed 250")
    }
    
    func testTVFrameScale() throws {
        XCTAssertGreaterThan(deviceLayout.tvFrameScale, 0, "TV frame scale should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.tvFrameScale, 2, "TV frame scale should be reasonable")
    }
    
    func testScoreDisplayScale() throws {
        XCTAssertGreaterThan(deviceLayout.scoreDisplayScale, 0, "Score display scale should be positive")
        XCTAssertLessThanOrEqual(deviceLayout.scoreDisplayScale, 2, "Score display scale should be reasonable")
    }
    
    // MARK: - Constants Consistency Tests
    
    func testLayoutConstantsConsistency() throws {
        // Test that adaptive spacing is greater than or equal to standard spacing
        XCTAssertGreaterThanOrEqual(deviceLayout.adaptiveSpacing, LayoutConstants.Spacing.lg, "Adaptive spacing should be at least large spacing")
        
        // Test that adaptive padding is greater than or equal to standard padding
        XCTAssertGreaterThanOrEqual(deviceLayout.adaptivePadding, LayoutConstants.Padding.lg, "Adaptive padding should be at least large padding")
        
        // Test that adaptive button height is reasonable
        XCTAssertGreaterThanOrEqual(deviceLayout.adaptiveButtonHeight, LayoutConstants.Button.standardHeight, "Adaptive button height should be at least standard height")
    }
    
    // MARK: - UI Constants Integration Tests
    
    func testUIConstantsDeviceIntegration() throws {
        // Test device-specific constants
        let isIPad = deviceLayout.isIPad
        
        let consoleFrameRadius = UIConstants.Device.consoleFrameRadius(isIPad: isIPad)
        XCTAssertGreaterThan(consoleFrameRadius, 0, "Console frame radius should be positive")
        
        let transportButtonHeight = UIConstants.Device.transportButtonHeight(isIPad: isIPad)
        XCTAssertGreaterThan(transportButtonHeight, 0, "Transport button height should be positive")
        
        let answerButtonWidth = UIConstants.Device.answerButtonWidth(isIPad: isIPad)
        XCTAssertGreaterThan(answerButtonWidth, 0, "Answer button width should be positive")
        
        let consoleButtonSize = UIConstants.Device.consoleButtonSize(isIPad: isIPad)
        XCTAssertGreaterThan(consoleButtonSize, 0, "Console button size should be positive")
        
        let gridColumns = UIConstants.Device.gridColumns(isIPad: isIPad)
        XCTAssertGreaterThan(gridColumns, 0, "Grid columns should be positive")
    }
    
    // MARK: - Performance Tests
    
    func testDeviceLayoutPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let layout = DeviceLayout()
                _ = layout.adaptiveSpacing
                _ = layout.adaptivePadding
                _ = layout.fontScale
                _ = layout.adaptiveButtonHeight
                _ = layout.fretboardWidthMultiplier
                _ = layout.consoleButtonColumns
                _ = layout.transportButtonSpacing
                _ = layout.answerButtonWidth
            }
        }
    }
    
    func testUIConstantsPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let isIPad = false
                _ = UIConstants.Device.consoleFrameRadius(isIPad: isIPad)
                _ = UIConstants.Device.transportButtonHeight(isIPad: isIPad)
                _ = UIConstants.Device.answerButtonWidth(isIPad: isIPad)
                _ = UIConstants.Device.consoleButtonSize(isIPad: isIPad)
                _ = UIConstants.Device.gridColumns(isIPad: isIPad)
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultipleDeviceLayoutInstances() throws {
        let layout1 = DeviceLayout()
        let layout2 = DeviceLayout()
        let layout3 = DeviceLayout()
        
        // All instances should have consistent values
        XCTAssertEqual(layout1.adaptiveSpacing, layout2.adaptiveSpacing, "Multiple instances should have same adaptive spacing")
        XCTAssertEqual(layout2.adaptiveSpacing, layout3.adaptiveSpacing, "Multiple instances should have same adaptive spacing")
        
        XCTAssertEqual(layout1.adaptivePadding, layout2.adaptivePadding, "Multiple instances should have same adaptive padding")
        XCTAssertEqual(layout2.adaptivePadding, layout3.adaptivePadding, "Multiple instances should have same adaptive padding")
        
        XCTAssertEqual(layout1.fontScale, layout2.fontScale, "Multiple instances should have same font scale")
        XCTAssertEqual(layout2.fontScale, layout3.fontScale, "Multiple instances should have same font scale")
    }
    
    // MARK: - Memory Tests
    
    func testDeviceLayoutMemoryUsage() throws {
        weak var weakLayout: DeviceLayout?
        
        autoreleasepool {
            let layout = DeviceLayout()
            _ = layout.adaptiveSpacing
            _ = layout.adaptivePadding
            _ = layout.fontScale
            
            weakLayout = layout
        }
        
        XCTAssertNil(weakLayout, "DeviceLayout should be deallocated")
    }
    
    // MARK: - Validation Tests
    
    func testLayoutConstantsValidation() throws {
        // Validate spacing constants
        XCTAssertGreaterThan(LayoutConstants.Spacing.xs, 0, "XS spacing should be positive")
        XCTAssertLessThan(LayoutConstants.Spacing.xs, LayoutConstants.Spacing.sm, "XS spacing should be less than SM")
        XCTAssertLessThan(LayoutConstants.Spacing.sm, LayoutConstants.Spacing.md, "SM spacing should be less than MD")
        XCTAssertLessThan(LayoutConstants.Spacing.md, LayoutConstants.Spacing.lg, "MD spacing should be less than LG")
        XCTAssertLessThan(LayoutConstants.Spacing.lg, LayoutConstants.Spacing.xl, "LG spacing should be less than XL")
        XCTAssertLessThan(LayoutConstants.Spacing.xl, LayoutConstants.Spacing.xxl, "XL spacing should be less than XXL")
        XCTAssertLessThan(LayoutConstants.Spacing.xxl, LayoutConstants.Spacing.xxxl, "XXL spacing should be less than XXXL")
        
        // Validate button constants
        XCTAssertGreaterThan(LayoutConstants.Button.heightXS, 0, "XS button height should be positive")
        XCTAssertLessThan(LayoutConstants.Button.heightXS, LayoutConstants.Button.heightSM, "XS height should be less than SM")
        XCTAssertLessThan(LayoutConstants.Button.heightSM, LayoutConstants.Button.heightMD, "SM height should be less than MD")
        XCTAssertLessThan(LayoutConstants.Button.heightMD, LayoutConstants.Button.heightLG, "MD height should be less than LG")
        XCTAssertLessThan(LayoutConstants.Button.heightLG, LayoutConstants.Button.heightXL, "LG height should be less than XL")
        XCTAssertLessThan(LayoutConstants.Button.heightXL, LayoutConstants.Button.heightXXL, "XL height should be less than XXL")
        XCTAssertLessThan(LayoutConstants.Button.heightXXL, LayoutConstants.Button.heightXXXL, "XXL height should be less than XXXL")
        
        // Validate typography constants
        XCTAssertGreaterThan(LayoutConstants.Typography.fontSizeXS, 0, "XS font size should be positive")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeXS, LayoutConstants.Typography.fontSizeSM, "XS font size should be less than SM")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeSM, LayoutConstants.Typography.fontSizeMD, "SM font size should be less than MD")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeMD, LayoutConstants.Typography.fontSizeLG, "MD font size should be less than LG")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeLG, LayoutConstants.Typography.fontSizeXL, "LG font size should be less than XL")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeXL, LayoutConstants.Typography.fontSizeXXL, "XL font size should be less than XXL")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeXXL, LayoutConstants.Typography.fontSizeXXXL, "XXL font size should be less than XXXL")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeXXXL, LayoutConstants.Typography.fontSizeHuge, "XXXL font size should be less than Huge")
        XCTAssertLessThan(LayoutConstants.Typography.fontSizeHuge, LayoutConstants.Typography.fontSizeMassive, "Huge font size should be less than Massive")
        
        // Validate guitar constants
        XCTAssertEqual(LayoutConstants.Guitar.stringCount, 6, "Guitar should have 6 strings")
        XCTAssertGreaterThan(LayoutConstants.Guitar.fretCount, 0, "Guitar should have positive fret count")
        XCTAssertLessThanOrEqual(LayoutConstants.Guitar.visibleFrets, LayoutConstants.Guitar.fretCount, "Visible frets should not exceed total frets")
        XCTAssertGreaterThanOrEqual(LayoutConstants.Guitar.startingFret, 0, "Starting fret should be non-negative")
        XCTAssertGreaterThan(LayoutConstants.Guitar.maxFret, LayoutConstants.Guitar.fretCount, "Max fret should be greater than standard fret count")
        
        // Validate game constants
        XCTAssertGreaterThan(LayoutConstants.Game.maxRounds, 0, "Max rounds should be positive")
        XCTAssertGreaterThan(LayoutConstants.Game.maxScore, 0, "Max score should be positive")
        XCTAssertGreaterThan(LayoutConstants.Game.maxStreak, 0, "Max streak should be positive")
        XCTAssertEqual(LayoutConstants.Game.startingScore, 0, "Starting score should be 0")
        XCTAssertEqual(LayoutConstants.Game.startingStreak, 0, "Starting streak should be 0")
        
        // Validate audio constants
        XCTAssertGreaterThan(LayoutConstants.Audio.defaultTempo, 0, "Default tempo should be positive")
        XCTAssertGreaterThan(LayoutConstants.Audio.minTempo, 0, "Min tempo should be positive")
        XCTAssertGreaterThan(LayoutConstants.Audio.maxTempo, LayoutConstants.Audio.minTempo, "Max tempo should be greater than min tempo")
        XCTAssertGreaterThan(LayoutConstants.Audio.tempoStep, 0, "Tempo step should be positive")
        
        XCTAssertGreaterThanOrEqual(LayoutConstants.Audio.defaultVolume, 0, "Default volume should be non-negative")
        XCTAssertLessThanOrEqual(LayoutConstants.Audio.defaultVolume, 1, "Default volume should not exceed 1")
        XCTAssertGreaterThanOrEqual(LayoutConstants.Audio.minVolume, 0, "Min volume should be non-negative")
        XCTAssertLessThanOrEqual(LayoutConstants.Audio.maxVolume, 1, "Max volume should not exceed 1")
        XCTAssertGreaterThan(LayoutConstants.Audio.volumeStep, 0, "Volume step should be positive")
    }
}