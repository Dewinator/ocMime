import SwiftUI

enum Theme {

    // MARK: - Hintergruende

    static let backgroundPrimary   = Color(red: 0, green: 0, blue: 0)
    static let backgroundSecondary = Color(red: 0.035, green: 0.035, blue: 0.043)
    static let backgroundTertiary  = Color(red: 0.094, green: 0.094, blue: 0.106)

    // MARK: - Gruen-Palette (Phosphor)

    static let green400 = Color(red: 0.290, green: 0.871, blue: 0.498)
    static let green500 = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let green600 = Color(red: 0.086, green: 0.639, blue: 0.290)
    static let green700 = Color(red: 0.082, green: 0.502, blue: 0.239)
    static let green800 = Color(red: 0.086, green: 0.396, blue: 0.204)

    // MARK: - Text

    static let textPrimary   = green400
    static let textSecondary = green600
    static let textTertiary  = green700

    // MARK: - Semantisch

    static let success = green500
    static let warning = Color(red: 0.918, green: 0.702, blue: 0.031)
    static let danger  = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let info    = green400

    // MARK: - Status

    static let statusOnline  = green500
    static let statusActive  = warning
    static let statusReady   = Color(red: 0.294, green: 0.333, blue: 0.388)
    static let statusError   = danger

    // MARK: - Borders

    static let borderPrimary   = green500.opacity(0.3)
    static let borderSecondary = green500.opacity(0.2)
    static let borderTertiary  = green500.opacity(0.1)

    // MARK: - Accent

    static let accent      = green500
    static let accentLight = green500.opacity(0.2)

    // MARK: - OLED Display (Simulator-Farben)

    static let oledBackground = Color.black
    static let oledPixelOn    = Color.white
    static let oledPixelDim   = Color.white.opacity(0.3)

    // MARK: - Typografie (Monospace only)

    enum Font {
        static let title       = SwiftUI.Font.system(size: 20, weight: .regular, design: .monospaced)
        static let headline    = SwiftUI.Font.system(size: 14, weight: .regular, design: .monospaced)
        static let body        = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
        static let callout     = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        static let caption     = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        static let captionBold = SwiftUI.Font.system(size: 11, weight: .medium,  design: .monospaced)
        static let tiny        = SwiftUI.Font.system(size: 9,  weight: .regular, design: .monospaced)
    }

    // MARK: - Abstaende

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radien (Terminal = keine Rundungen)

    enum Radius {
        static let none: CGFloat = 0
        static let sm:   CGFloat = 0
        static let md:   CGFloat = 0
    }
}
