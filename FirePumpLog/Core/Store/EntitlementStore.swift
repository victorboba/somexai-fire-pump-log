import Foundation
import StoreKit

/// StoreKit 2 entitlement state for the two products every Somex app sells:
/// an annual subscription (with a store-managed free trial as its introductory offer)
/// and a lifetime non-consumable. Either one entitles the user.
@Observable
@MainActor
final class EntitlementStore {
    static let productIDs = [AppConfig.annualProductID, AppConfig.lifetimeProductID]

    private(set) var products: [Product] = []
    private(set) var isEntitled = false
    private(set) var hasLoadedEntitlements = false
    private(set) var activeProductID: String?
    private(set) var expiresAt: Date?
    private(set) var isPurchasing = false
    /// True after a product fetch returned nothing or threw, so the paywall can offer a retry.
    private(set) var productsFailedToLoad = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    var annual: Product? { products.first { $0.id == AppConfig.annualProductID } }
    var lifetime: Product? { products.first { $0.id == AppConfig.lifetimeProductID } }
    var isLifetime: Bool { activeProductID == AppConfig.lifetimeProductID }

    func loadProducts(force: Bool = false) async {
        guard products.isEmpty || force else { return }
        productsFailedToLoad = false
        do {
            products = try await Product.products(for: Self.productIDs)
            productsFailedToLoad = products.isEmpty
        } catch {
            productsFailedToLoad = true
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        var active: String?
        var expiry: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            entitled = true
            if transaction.productType == .nonConsumable {
                active = transaction.productID
                expiry = nil
            } else if active == nil {
                active = transaction.productID
                expiry = transaction.expirationDate
            }
        }

        #if DEBUG
        if DebugFlags.unlockAll {
            entitled = true
            active = active ?? "debug.unlock"
        }
        #endif

        isEntitled = entitled
        activeProductID = active
        expiresAt = expiry
        hasLoadedEntitlements = true
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isEntitled { lastError = "No purchase was found for this Apple Account." }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// "7 days free" for a subscription with a free introductory offer, otherwise nil.
    func trialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        let days: Int
        switch period.unit {
        case .day: days = period.value
        case .week: days = period.value * 7
        case .month: return "\(period.value) month\(period.value == 1 ? "" : "s") free"
        case .year: return "\(period.value) year\(period.value == 1 ? "" : "s") free"
        @unknown default: return nil
        }
        return "\(days) day\(days == 1 ? "" : "s") free"
    }
}
