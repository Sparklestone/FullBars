import SwiftUI

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let subtitle: String

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon with glow effect
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 12, x: 0, y: 0)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .foregroundStyle(.primary)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.2),
                    color.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

#Preview {
    QuickActionCard(
        title: "Signal Monitor",
        icon: "waveform.path.ecg",
        color: .blue,
        subtitle: "Real-time tracking"
    )
    .padding()
}
