import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // Icon with glow
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 8, x: 0, y: 0)

            // Bold rounded value
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Title
            Text(title)
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.15),
                    color.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 1, opacity: 0.1),
                            Color(white: 1, opacity: 0.02)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .cornerRadius(10)
        .accessibilityLabel("\(title): \(value)\(subtitle.map { " \($0)" } ?? "")")
    }
}

#Preview {
    MetricCard(
        title: "Min",
        value: "-60",
        subtitle: "dBm",
        icon: "arrow.down",
        color: .red
    )
    .padding()
}
