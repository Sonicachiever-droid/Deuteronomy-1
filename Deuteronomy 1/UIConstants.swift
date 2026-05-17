import CoreGraphics
import UIKit

// MARK: - UI Constants

enum UIConstants {

    // MARK: - Console Frame Corner Radii
    static let consoleFrameRadius: CGFloat      = 26   // outer console frame
    static let consoleInnerBorderRadius: CGFloat = 22   // inner bevel ring
    static let consoleContentRadius: CGFloat    = 18   // screen content area
    static let consoleInnerFrameRadius: CGFloat = 14   // innermost frame layer

    // MARK: - Control Plate
    static let controlPlateRadius: CGFloat      = 20   // plate shell corner radius
    static let controlPlateButtonRadius: CGFloat = 7   // button corner radius
    static let controlPlateButtonHeight: CGFloat = 34  // button fixed height
    static let controlPlatePaddingH: CGFloat    = 14   // horizontal padding
    static let controlPlatePaddingV: CGFloat    = 11   // vertical padding

    // MARK: - Transport Buttons
    static let transportButtonHeight: CGFloat   = 27
    static let transportButtonMinWidth: CGFloat = 46

    // MARK: - Answer / Note Choice Box
    static let answerBoxRadius: CGFloat         = 8

    // MARK: - Power Indicator
    static let powerIndicatorDiameter: CGFloat  = 28
    static let powerIndicatorDotDiameter: CGFloat = 14

    // MARK: - Indicator Dots
    static let indicatorDotSmall: CGFloat       = 8
    static let indicatorDotMedium: CGFloat      = 12

    // MARK: - MiniTV Bezel Insets
    static let miniTVBezelInsetW: CGFloat       = 24   // bezel width added around screen
    static let miniTVBezelInsetH: CGFloat       = 18   // bezel height added around screen

    // MARK: - Console Frame Padding / Insets
    static let consoleFramePadding: CGFloat     = 3
    static let consoleContentPadding: CGFloat   = 12

    // MARK: - Fret Indicator Spacing
    static let fretIndicatorSpacing: CGFloat    = 28

    // MARK: - Progress Bar
    static let progressBarRadius: CGFloat       = 1.5

    // MARK: - Device Corner Radius
    /// Returns an estimated device screen corner radius in points.
    /// Uses known values for certain devices (e.g., iPhone XR ~44pt) and falls back to a reasonable default.
    static var deviceScreenCornerRadius: CGFloat {
        // Detect via screen native bounds to avoid model checks.
        let nativeBounds = UIScreen.main.nativeBounds
        let width = Int(nativeBounds.width)
        let height = Int(nativeBounds.height)
        let short = min(width, height)
        let long = max(width, height)
        // iPhone XR / iPhone 11 native resolution: 828 x 1792
        if (short == 828 && long == 1792) {
            return 44
        }
        // iPhone 12/13 non‑Pro (1170 x 2532) approx 47–50pt
        if (short == 1170 && long == 2532) {
            return 47
        }
        // Generic notch devices default
        return 40
    }
}
