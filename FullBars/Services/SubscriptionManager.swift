import Foundation
import StoreKit

// MARK: - Product Identifiers

enum ProProduct: String, CaseIterable {
    case weekly  = "com.fullbars.pro.weekly"
    case annual  = "com.fullbars.pro.annual"
    case lifetime = "com.fullbars.pro.lifetime"

    var displayName: String {
        switch self {
        case .weekly:   return "Weekly"
        case .annual:   return "Annual"
        case .lifetime: return "Lifetime"
        }
    }
}

// MARK: - Subscription Manager (StoreKit 2)

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // ⚠️ DEBUG: Set to true to test all Pro features without a real subscription.
    // Set back to false before submitting to the App Store.
    #if DEBUG
    static let forceProForTesting = true
    #else
    static let forceProForTesting = false
    #endif

    // Published state
    var isPro: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var errorMessage: String?

    private var updateTask: Task<Void, Never>?

    private init() {
        if Self.forceProForTesting {
            isPro = true
        } else {
            // Restore from receipt cache on launch
            isPro = UserDefaults.standard.bool(forKey: "fullbars_pro_cached")
        }
        updateTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlement() }
    }

    deinit { updateTask?.cancel() }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let ids = ProProduct.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            await MainActor.run { products = fetched.sorted { $0.price < $1.price } }
        } catch {
            await MainActor.run { errorMessage = "Could not load products." }
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
            case .userCancelled:
                break
            case .pending:
                await MainActor.run { errorMessage = "Purchase pending approval." }
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { errorMessage = "Purchase failed. Please try again." }
        }
        await MainActor.run { purchaseInProgress = false }
    }

    // MARK: - Restore Purchases

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: - Entitlement Check

    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let tx = try? checkVerified(result) {
                let ids = ProProduct.allCases.map(\.rawValue)
                if ids.contains(tx.productID) { entitled = true }
            }
        }
        await MainActor.run {
            isPro = Self.forceProForTesting || entitled
            UserDefaults.standard.set(entitled, forKey: "fullbars_pro_cached")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let tx = try? self.checkVerified(result) {
                    await tx.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.unverified
        case .verified(let safe): return safe
        }
    }

    enum StoreError: Error { case unverified }

    // MARK: - Free-Tier Limits

    /// Number of walkthrough rooms allowed before paywall
    static let freeRoomLimit = 1

    /// Number of free speed tests per day
    static let freeSpeedTestsPerDay = 1

    var freeSpeedTestsUsedToday: Int {
        get {
            let key = "freeSpeedTests_\(dateKey)"
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            let key = "freeSpeedTests_\(dateKey)"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    var canRunFreeSpeedTest: Bool {
        isPro || freeSpeedTestsUsedToday < Self.freeSpeedTestsPerDay
    }

    func recordFreeSpeedTest() {
        if !isPro { freeSpeedTestsUsedToday += 1 }
    }

    private var dateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
