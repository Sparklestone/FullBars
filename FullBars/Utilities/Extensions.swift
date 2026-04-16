import Foundation
import SwiftUI

// MARK: - Double Extensions
extension Double {
    var formattedSpeed: String {
        return String(format: "%.1f Mbps", self)
    }

    var formattedLatency: String {
        return String(format: "%.1f ms", self)
    }

    var formattedPercentage: String {
        return String(format: "%.1f%%", self)
    }
}

// MARK: - Int Extensions
extension Int {
    var signalBars: Int {
        switch self {
        case -50...0:
            return 4
        case -60..<(-50):
            return 3
        case -70..<(-60):
            return 2
        case -80..<(-70):
            return 1
        default:
            return 0
        }
    }

    var formattedRSSI: String {
        return "\(self) dBm"
    }
}

// MARK: - Color Extensions (Design System)
extension Color {
    /// Amber color for warning/fair indicators (not built into SwiftUI)
    static var amber: Color {
        Color(red: 1.0, green: 0.70, blue: 0.0)
    }

    static func forSignalStrength(_ dBm: Int) -> Color {
        switch dBm {
        case -50...0:
            return FullBars.Design.Colors.signalExcellent
        case -60..<(-50):
            return FullBars.Design.Colors.signalGood
        case -70..<(-60):
            return FullBars.Design.Colors.signalFair
        case -80..<(-70):
            return FullBars.Design.Colors.signalPoor
        default:
            return FullBars.Design.Colors.signalNoSignal
        }
    }

    // MARK: FullBars Color System
    static var fullBarsPrimaryBackground: Color {
        FullBars.Design.Colors.primaryBackground
    }

    static var fullBarsCardSurface: Color {
        FullBars.Design.Colors.cardSurface
    }

    static var fullBarsAccent: Color {
        FullBars.Design.Colors.accentCyan
    }

    static var fullBarsExcellent: Color {
        FullBars.Design.Colors.signalExcellent
    }

    static var fullBarsGood: Color {
        FullBars.Design.Colors.signalGood
    }

    static var fullBarsFair: Color {
        FullBars.Design.Colors.signalFair
    }

    static var fullBarsPoor: Color {
        FullBars.Design.Colors.signalPoor
    }

    static var fullBarsNoSignal: Color {
        FullBars.Design.Colors.signalNoSignal
    }

    static var fullBarsTextPrimary: Color {
        FullBars.Design.Colors.textPrimary
    }

    static var fullBarsTextSecondary: Color {
        FullBars.Design.Colors.textSecondary
    }
}

// MARK: - Date Extensions
extension Date {
    var timeAgoString: String {
        let interval = Date.now.timeIntervalSince(self)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hr ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - DisplayMode Environment Key

private struct DisplayModeKey: EnvironmentKey {
    static let defaultValue: DisplayMode = .basic
}

extension EnvironmentValues {
    var displayMode: DisplayMode {
        get { self[DisplayModeKey.self] }
        set { self[DisplayModeKey.self] = newValue }
    }
}

// MARK: - View Extensions (Custom Modifiers)
extension View {
    /// Glassmorphism card effect with frosted glass appearance
    func glassCard() -> some View {
        self
            .background(
                FullBars.Design.Colors.cardSurface
                    .opacity(FullBars.Design.Effects.glassOpacity)
            )
            .cornerRadius(FullBars.Design.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                    .stroke(
                        Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
    }

    /// Glow effect with customizable color and radius
    func glowEffect(color: Color, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
    }

    /// Staggered entrance animation for list items
    func staggeredEntrance(index: Int) -> some View {
        self
            .modifier(StaggeredEntranceModifier(index: index))
    }

    /// Pulsing animation for active states
    func pulsingAnimation(isActive: Bool) -> some View {
        self
            .modifier(PulsingAnimationModifier(isActive: isActive))
    }
}

// MARK: - Staggered Entrance Modifier
struct StaggeredEntranceModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(
                    .easeOut(duration: FullBars.Design.Animation.standard)
                        .delay(Double(index) * 0.05)
                ) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Pulsing Animation Modifier
struct PulsingAnimationModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                }
            }
            .onChange(of: isActive) { oldValue, newValue in
                if newValue {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.1
                    }
                } else {
                    scale = 1.0
                }
            }
    }
}
