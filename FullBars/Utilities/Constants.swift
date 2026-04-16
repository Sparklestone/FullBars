import Foundation
import SwiftUI

struct AppConstants {
    struct Network {
        static let pingTargets: [String] = ["1.1.1.1", "8.8.8.8", "apple.com"]
        static let speedTestURL: String = "https://speed.cloudflare.com/__down?bytes=10000000"
        static let sampleInterval: TimeInterval = 1.0
        static let historyDuration: TimeInterval = 60
    }

    struct BLE {
        static let scanDuration: TimeInterval = 10.0
        static let rssiThreshold: Int = -100
    }

    struct Heatmap {
        static let sampleInterval: TimeInterval = 1.5
        static let minPointDistance: Float = 0.3
    }
}

// MARK: - FullBars Design System
struct FullBars {
    struct Design {
        // MARK: Color Palette
        struct Colors {
            static let primaryBackground = Color(red: 0.08, green: 0.09, blue: 0.12) // #14171F
            static let cardSurface = Color(red: 0.09, green: 0.11, blue: 0.13) // #161B22
            static let accentCyan = Color(red: 0.0, green: 0.83, blue: 1.0) // #00D4FF
            static let signalExcellent = Color(red: 0.0, green: 0.83, blue: 1.0) // Cyan #00D4FF
            static let signalGood = Color(red: 0.0, green: 0.90, blue: 0.46) // Emerald #00E676
            static let signalFair = Color(red: 1.0, green: 0.70, blue: 0.0) // Amber #FFB300
            static let signalPoor = Color(red: 1.0, green: 0.43, blue: 0.0) // Coral #FF6D00
            static let signalNoSignal = Color(red: 1.0, green: 0.09, blue: 0.27) // Crimson #FF1744

            static let textPrimary = Color(white: 0.95) // White 95% opacity
            static let textSecondary = Color(white: 0.55) // White 55% opacity
        }

        // MARK: Animation Timing
        struct Animation {
            static let quick: TimeInterval = 0.15
            static let standard: TimeInterval = 0.3
            static let slow: TimeInterval = 0.5
            static let entrance: TimeInterval = 0.6
        }

        // MARK: Typography
        struct Typography {
            static let largeTitle: Font = .system(size: 32, weight: .bold, design: .rounded)
            static let title: Font = .system(size: 24, weight: .bold, design: .rounded)
            static let headline: Font = .system(size: 18, weight: .semibold, design: .rounded)
            static let body: Font = .system(size: 16, weight: .regular, design: .rounded)
            static let bodySmall: Font = .system(size: 14, weight: .regular, design: .rounded)
            static let caption: Font = .system(size: 12, weight: .regular, design: .rounded)
            static let captionSmall: Font = .system(size: 10, weight: .regular, design: .rounded)
        }

        // MARK: Spacing & Layout
        struct Layout {
            static let extraSmall: CGFloat = 4
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
            static let extraLarge: CGFloat = 32

            static let cornerRadius: CGFloat = 12
            static let cornerRadiusLarge: CGFloat = 20
        }

        // MARK: Shadows & Effects
        struct Effects {
            static let shadowRadius: CGFloat = 12
            static let glassOpacity: Double = 0.95
            static let glassBlur: Double = 20
        }
    }
}
