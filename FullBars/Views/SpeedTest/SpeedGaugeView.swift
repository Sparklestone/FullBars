import SwiftUI

struct SpeedGaugeView: View {
    let speed: Double
    let maxSpeed: Double
    let label: String
    let color: Color

    let primaryColor = FullBars.Design.Colors.accentCyan

    var speedProgress: Double {
        min(speed / maxSpeed, 1.0)
    }

    var needleRotation: Double {
        90 + (speedProgress * 270)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Dark background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    // Gauge Arc Area
                    ZStack {
                        // Background arc
                        Circle()
                            .trim(from: 0.125, to: 0.875)
                            .stroke(Color(red: 0.15, green: 0.18, blue: 0.25), lineWidth: 14)
                            .rotationEffect(.degrees(90))

                        // Tick marks around the arc
                        ForEach(0..<13, id: \.self) { index in
                            VStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 2, height: index % 4 == 0 ? 12 : 8)
                                Spacer()
                            }
                            .frame(height: 140)
                            .rotationEffect(.degrees(Double(index) * 22.5 - 90))
                        }

                        // Gradient progress arc
                        Circle()
                            .trim(from: 0.125, to: 0.125 + (0.75 * speedProgress))
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.red, .orange, .yellow, .green]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(90))
                            .animation(.easeInOut(duration: 0.8), value: speedProgress)
                            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)

                        // Needle
                        VStack {
                            Rectangle()
                                .fill(primaryColor)
                                .frame(width: 2.5, height: 80)
                                .shadow(color: primaryColor.opacity(0.6), radius: 4, x: 0, y: 2)
                            Spacer()
                        }
                        .frame(height: 100)
                        .rotationEffect(.degrees(needleRotation))
                        .animation(.easeInOut(duration: 0.8), value: speedProgress)

                        // Center cap
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 12, height: 12)
                            .shadow(color: primaryColor.opacity(0.5), radius: 4, x: 0, y: 2)

                        // Center content
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", speed))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Mbps")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))

                            Text(label)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: 20)
                    }
                    .frame(height: 240)
                    .padding(24)

                    // Scale labels
                    HStack {
                        Text("Slow")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        Text("Fast")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(0)
        }
    }
}

#Preview {
    SpeedGaugeView(speed: 85.5, maxSpeed: 100, label: "Download", color: .green)
        .padding()
        .background(FullBars.Design.Colors.primaryBackground)
}
