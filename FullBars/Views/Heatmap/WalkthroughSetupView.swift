import SwiftUI

/// Shown before starting an AR walkthrough to set expectations.
struct WalkthroughSetupView: View {
    let onStart: () -> Void

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(electricCyan.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(electricCyan)
                    .shadow(color: electricCyan.opacity(0.5), radius: 8)
            }

            Text("Ready to Scan")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                tipRow(icon: "iphone", text: "Hold your phone upright at chest height")
                tipRow(icon: "figure.walk", text: "Walk slowly through each room")
                tipRow(icon: "clock", text: "30-60 seconds is usually enough")
                tipRow(icon: "hand.raised", text: "Tap Stop when you've covered your space")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                    Text("Start Walkthrough")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(electricCyan)
                .foregroundStyle(.black)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(electricCyan)
                .frame(width: 28)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview {
    WalkthroughSetupView(onStart: {})
        .preferredColorScheme(.dark)
}
