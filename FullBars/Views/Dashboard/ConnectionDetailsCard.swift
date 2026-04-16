import SwiftUI

struct ConnectionDetailsCard: View {
    let ssid: String
    let connectionType: String
    let signalStrength: Int
    let signalQuality: SignalQuality

    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // WiFi icon with glow
                Image(systemName: "wifi")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .shadow(color: FullBars.Design.Colors.accentCyan.opacity(0.5), radius: 8, x: 0, y: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ssid)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(connectionType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    SignalStrengthIndicator(strength: signalStrength)

                    Text("\(signalStrength) dBm (est.)")
                        .font(.caption2)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .opacity(0.3)

            HStack(spacing: 12) {
                // Quality badge with glow
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(signalQuality.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(signalQuality.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            signalQuality.color.opacity(0.2),
                            signalQuality.color.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    signalQuality.color.opacity(0.3),
                                    signalQuality.color.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .cornerRadius(6)
                .shadow(color: signalQuality.color.opacity(0.3), radius: 6, x: 0, y: 0)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Optimized")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 1, opacity: 0.15),
                            Color(white: 1, opacity: 0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(12)
        .padding(.horizontal)
        .opacity(isAnimated ? 1.0 : 0.8)
        .offset(y: isAnimated ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimated = true
            }
        }
    }
}

#Preview {
    ConnectionDetailsCard(
        ssid: "HomeNetwork",
        connectionType: "WiFi 6",
        signalStrength: -45,
        signalQuality: .excellent
    )
}
