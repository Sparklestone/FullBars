import SwiftUI

struct AnimatedRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let size: CGFloat
    var isPulsing: Bool = false

    @State private var isPulsingNow = false

    var body: some View {
        ZStack {
            // Background circle with subtle gradient
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
                    lineWidth: lineWidth
                )

            // Glow effect
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .blur(radius: 8)
                .padding(-lineWidth / 2)

            // Animated gradient progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.5)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
                .opacity(isPulsing && isPulsingNow ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(), value: isPulsingNow)
        }
        .frame(width: size, height: size)
        .onAppear {
            if isPulsing {
                isPulsingNow = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        AnimatedRingView(
            progress: 0.75,
            lineWidth: 12,
            color: .blue,
            size: 150
        )

        AnimatedRingView(
            progress: 0.5,
            lineWidth: 12,
            color: FullBars.Design.Colors.accentCyan,
            size: 150,
            isPulsing: true
        )
    }
    .padding()
}
