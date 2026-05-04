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

    /// Centralized signal/WiFi thresholds — single source of truth across
    /// GradingService, CoveragePlanningService, RoomDetailView, and FloorMapView.
    struct Signal {
        /// dBm thresholds for signal quality buckets
        static let excellent: Int = -50   // -50 dBm and above
        static let good: Int = -65        // -65 to -50 dBm
        static let fair: Int = -75        // -75 to -65 dBm
        static let weak: Int = -85        // below -75 dBm is weak; below -85 is dead

        /// Weak spot threshold adapts based on room download speed.
        /// Rooms with fast WiFi tolerate slightly weaker signal before flagging.
        static func weakSpotThreshold(downloadMbps: Double) -> Int {
            if downloadMbps >= 50 { return -90 }
            if downloadMbps >= 25 { return -85 }
            return -80
        }

        /// Download speed thresholds (Mbps) for scoring
        static let speedExcellent: Double = 100
        static let speedGood: Double = 50
        static let speedFair: Double = 25
        static let speedPoor: Double = 10

        /// Latency thresholds (ms)
        static let latencyExcellent: Double = 20
        static let latencyGood: Double = 50
        static let latencyFair: Double = 100
        static let latencyPoor: Double = 200
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

            /// Small pill / badge corners (8pt)
            static let cornerRadiusSmall: CGFloat = 8
            /// Default card and button corners (12pt)
            static let cornerRadius: CGFloat = 12
            /// Large card / modal corners (14pt)
            static let cornerRadiusMedium: CGFloat = 14
            /// Full-width sheet / report card corners (16pt)
            static let cornerRadiusLarge: CGFloat = 16
            /// Top-level container corners (20pt)
            static let cornerRadiusXL: CGFloat = 20

            /// Minimum touch target size per Apple HIG (44pt)
            static let minTouchTarget: CGFloat = 44
        }

        // MARK: Opacity Scale
        struct Opacity {
            /// Disabled / decorative (0.08)
            static let faint: Double = 0.08
            /// Borders and dividers (0.12)
            static let border: Double = 0.12
            /// Tertiary labels (0.5)
            static let tertiary: Double = 0.5
            /// Secondary labels (0.6)
            static let secondary: Double = 0.6
            /// Primary muted (0.7)
            static let muted: Double = 0.7
            /// Near-full (0.85)
            static let strong: Double = 0.85
        }

        // MARK: Shadows & Effects
        struct Effects {
            static let shadowRadius: CGFloat = 12
            static let glassOpacity: Double = 0.95
            static let glassBlur: Double = 20
        }
    }
}
