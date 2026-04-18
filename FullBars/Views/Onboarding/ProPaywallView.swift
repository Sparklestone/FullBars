import SwiftUI
import StoreKit

/// Full-screen paywall with three pricing tiers, trial timeline, and feature list.
/// Matches the FullBars dark design language.
struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscription = SubscriptionManager.shared
    @State private var selectedProductID: String = ProProduct.annual.rawValue

    /// When true the paywall was shown inline (not as sheet) — hide the X button.
    var inline: Bool = false
    /// Optional callback when user upgrades or dismisses (for walkthrough continuation).
    var onDismiss: (() -> Void)?

    private let primary = FullBars.Design.Colors.accentCyan

    var body: some View {
        ZStack {
            FullBars.Design.Colors.primaryBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Close button (sheets only)
                    if !inline {
                        HStack {
                            Spacer()
                            Button { dismiss(); onDismiss?() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    heroSection
                    featureList
                    pricingCards
                    trialTimeline
                    ctaButton
                    restoreButton
                    legalLinks

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }

            if subscription.purchaseInProgress {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView("Processing…")
                    .tint(primary)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primary.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(primary)
            }
            Text("Unlock FullBars Pro")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Get the complete WiFi assessment toolkit")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "figure.walk.motion", text: "Unlimited Home Scans — map every room (30% of grade)")
            featureRow(icon: "speedometer", text: "Unlimited speed tests & history (25% of grade)")
            featureRow(icon: "stethoscope", text: "Full diagnostics — interference fixes & channel tips")
            featureRow(icon: "camera.viewfinder", text: "AR Floor Plan with LiDAR scan")
            featureRow(icon: "map.fill", text: "Coverage Planner — find dead zones & optimal mesh placement")
            featureRow(icon: "building.2.fill", text: "Multi-floor dead zone diagnosis across your whole building")
            featureRow(icon: "chart.line.uptrend.xyaxis", text: "Signal trends — track your grade improving over time")
            featureRow(icon: "arrow.left.arrow.right", text: "Before/After — prove your fixes worked")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium).stroke(Color.white.opacity(0.08)))
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(primary)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        VStack(spacing: 10) {
            ForEach(subscription.products, id: \.id) { product in
                pricingCard(product)
            }

            // Fallback if products haven't loaded from App Store yet
            if subscription.products.isEmpty {
                fallbackPricingCard(title: "Weekly", price: "$1.99 / week", id: ProProduct.weekly.rawValue)
                fallbackPricingCard(title: "Annual", price: "$29.99 / year", id: ProProduct.annual.rawValue, badge: "7-Day Free Trial", highlight: true)
                fallbackPricingCard(title: "Lifetime", price: "$49.99 one-time", id: ProProduct.lifetime.rawValue)
            }
        }
    }

    private func pricingCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isAnnual = product.id == ProProduct.annual.rawValue
        return Button { selectedProductID = product.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        if isAnnual {
                            Text("7-Day Free Trial")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(primary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice + (product.type == .autoRenewable ? " / \(periodLabel(product))" : " one-time"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? primary : .white.opacity(0.3))
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                    .fill(isSelected ? primary.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius).stroke(isSelected ? primary : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1))
            )
        }
    }

    private func fallbackPricingCard(title: String, price: String, id: String, badge: String? = nil, highlight: Bool = false) -> some View {
        let isSelected = selectedProductID == id
        return Button { selectedProductID = id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(primary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(price)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? primary : .white.opacity(0.3))
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                    .fill(isSelected ? primary.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius).stroke(isSelected ? primary : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1))
            )
        }
    }

    private func periodLabel(_ product: Product) -> String {
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .day:   return "day"
        case .week:  return "week"
        case .month: return "month"
        case .year:  return "year"
        @unknown default: return ""
        }
    }

    // MARK: - Trial Timeline

    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How the free trial works")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.bottom, 14)

            timelineStep(day: "Today", label: "Full access to every Pro feature", icon: "lock.open.fill", color: .green, isLast: false)
            timelineStep(day: "Day 5", label: "We'll remind you before the trial ends", icon: "bell.fill", color: .yellow, isLast: false)
            timelineStep(day: "Day 7", label: "Trial ends — $29.99/yr, cancel anytime", icon: "creditcard.fill", color: primary, isLast: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium).stroke(Color.white.opacity(0.08)))
        )
    }

    private func timelineStep(day: String, label: String, icon: String, color: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 30, height: 30)
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                }
                if !isLast {
                    Rectangle().fill(Color.white.opacity(0.15)).frame(width: 2, height: 36)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(day)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        VStack(spacing: 6) {
            Button {
                guard let product = subscription.products.first(where: { $0.id == selectedProductID }) else { return }
                Task { await subscription.purchase(product) }
            } label: {
                Text(selectedProductID == ProProduct.annual.rawValue ? "Start Free Trial" : "Subscribe Now")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium).fill(primary))
            }
            .disabled(subscription.purchaseInProgress)

            // Auto-renewal disclosure (App Store Guideline 3.1.2)
            if selectedProductID == ProProduct.annual.rawValue {
                Text("7-day free trial, then $29.99/year. Auto-renews. Cancel anytime in Settings > Subscriptions.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else if selectedProductID == ProProduct.weekly.rawValue {
                Text("$1.99/week. Auto-renews. Cancel anytime in Settings > Subscriptions.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            // Show error if any
            if let err = subscription.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Restore & Legal

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await subscription.restore() }
        }
        .font(.system(.caption, design: .rounded))
        .foregroundStyle(.white.opacity(0.5))
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: URL(string: "https://fullbars.app/terms")!)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
            Link("Privacy Policy", destination: URL(string: "https://fullbars.app/privacy")!)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

#Preview {
    ProPaywallView()
}
