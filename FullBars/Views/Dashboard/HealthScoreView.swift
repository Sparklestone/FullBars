import SwiftUI

struct HealthScoreView: View {
    let score: Int
    let quality: SignalQuality

    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle with subtle border
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 1, opacity: 0.08),
                                Color(white: 1, opacity: 0.04)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 12
                    )

                // Outer glow effect
                Circle()
                    .stroke(quality.color.opacity(0.3), lineWidth: 2)
                    .blur(radius: 8)
                    .padding(-12)

                // Animated gradient progress ring
                Circle()
                    .trim(from: 0, to: isAnimated ? Double(score) / 100.0 : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                quality.color,
                                quality.color.opacity(0.6)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.2, dampingFraction: 0.7), value: isAnimated)

                // Center content
                VStack(spacing: 8) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(quality.color)

                    // Quality pill badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(quality.color)
                            .frame(width: 6, height: 6)

                        Text(quality.label)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                quality.color.opacity(0.2),
                                quality.color.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                    .foregroundStyle(quality.color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .padding(24)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 1, opacity: 0.2),
                                Color(white: 1, opacity: 0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(16)
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.8)
            .onAppear {
                isAnimated = true
            }
        }
    }
}

#Preview {
    HealthScoreView(score: 78, quality: .good)
        .padding()
}
