import SwiftUI

struct SignalStrengthIndicator: View {
    let strength: Int
    var isMonitoring: Bool = false

    @State private var isPulsing = false

    var barColor: Color {
        switch strength {
        case -50...(-1):
            return FullBars.Design.Colors.accentCyan // cyan - excellent
        case -60...(-51):
            return .green // green - good
        case -70...(-61):
            return .amber // amber - fair
        case -80...(-71):
            return .orange // orange - poor
        default:
            return .red // red - no signal
        }
    }

    var signalQuality: String {
        switch strength {
        case -50...(-1):
            return "Excellent"
        case -60...(-51):
            return "Good"
        case -70...(-61):
            return "Fair"
        case -80...(-71):
            return "Poor"
        default:
            return "No Signal"
        }
    }

    var bars: Int {
        switch strength {
        case -50...(-1):
            return 4
        case -60...(-51):
            return 3
        case -70...(-61):
            return 2
        case -80...(-71):
            return 1
        default:
            return 0
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { index in
                if index <= bars {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: 2, height: CGFloat(index * 3))
                        .shadow(color: barColor.opacity(isPulsing && isMonitoring ? 0.8 : 0.4), radius: 4, x: 0, y: 0)
                        .opacity(isPulsing && isMonitoring ? 0.7 : 1.0)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 1, opacity: 0.1))
                        .frame(width: 2, height: CGFloat(index * 3))
                }
            }

            if bars == 0 {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: strength)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            if isMonitoring {
                isPulsing = true
            }
        }
        .accessibilityLabel("Signal strength: \(signalQuality)")
    }
}

#Preview {
    VStack(spacing: 12) {
        SignalStrengthIndicator(strength: -45, isMonitoring: true)
        SignalStrengthIndicator(strength: -65)
        SignalStrengthIndicator(strength: -75)
        SignalStrengthIndicator(strength: -85)
        SignalStrengthIndicator(strength: -95)
    }
    .padding()
}
