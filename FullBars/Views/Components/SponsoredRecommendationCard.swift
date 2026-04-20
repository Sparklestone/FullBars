import SwiftUI

/// Displays a partner recommendation (ad placement) inline with room recommendations.
/// Matches the app's dark theme and looks like a natural "recommended solution" rather than a banner ad.
struct SponsoredRecommendationCard: View {
    let placement: AdPlacementResponse
    let onTap: () -> Void
    let onImpression: () -> Void

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Badge + headline
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let badge = placement.badgeText {
                            Text(badge)
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(electricCyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(electricCyan.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Text(placement.headline)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    // Partner type icon
                    Image(systemName: iconForPartnerType(placement.partnerType))
                        .font(.title3)
                        .foregroundStyle(electricCyan.opacity(0.6))
                }

                // Body text
                Text(placement.bodyText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                // Discount code if present
                if let code = placement.discountCode {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Use code: \(code)")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }

                // CTA button
                HStack {
                    Text(placement.ctaText)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(electricCyan)
                .cornerRadius(8)

                // Sponsored label — must be clearly visible per App Store guidelines
                Text("Sponsored")
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(electricCyan.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear { onImpression() }
    }

    private func iconForPartnerType(_ type: String?) -> String {
        switch type {
        case "isp": return "antenna.radiowaves.left.and.right"
        case "mesh_hardware": return "wifi.router.fill"
        case "router": return "wifi.circle.fill"
        case "extender": return "wave.3.right"
        default: return "sparkles"
        }
    }
}
