import SwiftUI
import StoreKit

/// Hard paywall: shown by RootView until the user is entitled, and it cannot be dismissed.
/// Two choices only: annual (with the store-managed free trial) or lifetime.
struct PaywallView: View {
    @Environment(EntitlementStore.self) private var store
    @State private var choice: Choice = .annual

    enum Choice { case annual, lifetime }

    private var selectedProduct: Product? {
        choice == .annual ? store.annual : store.lifetime
    }

    /// Screenshot mode: DEBUG builds launched with `-mockPrices` draw the plan rows from AppConfig.mockPrices
    /// because StoreKit configuration files are not applied to UI-test launches.
    private var mockPrices: (annual: String, lifetime: String)? {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-mockPrices") ? AppConfig.mockPrices : nil
        #else
        return nil
        #endif
    }

    private var callToAction: String {
        if let mockPrices {
            return choice == .annual ? "Start 7 days free" : "Buy once for \(mockPrices.lifetime)"
        }
        guard let product = selectedProduct else { return "Continue" }
        if choice == .annual, let trial = store.trialText(for: product) {
            return "Start \(trial)"
        }
        return choice == .annual ? "Subscribe for \(product.displayPrice) / year" : "Buy once for \(product.displayPrice)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: AppConfig.paywallSymbol)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text(AppConfig.paywallHeadline)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AppConfig.paywallBenefits, id: \.self) { benefit in
                        Label(benefit, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

                if let mockPrices {
                    VStack(spacing: 12) {
                        PlanRow(title: "Annual", price: "\(mockPrices.annual) / year", subtitle: "7 days free, then billed yearly. Cancel anytime.", isSelected: choice == .annual) { choice = .annual }
                        PlanRow(title: "Lifetime", price: "\(mockPrices.lifetime) once", subtitle: "Pay once. No subscription, ever.", isSelected: choice == .lifetime) { choice = .lifetime }
                    }
                } else if store.products.isEmpty {
                    if store.productsFailedToLoad {
                        VStack(spacing: 10) {
                            Text("Prices couldn't be loaded. Check your connection and try again.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Try Again") { Task { await store.loadProducts(force: true) } }
                                .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ProgressView("Loading prices…")
                            .padding(.vertical, 24)
                    }
                } else {
                    VStack(spacing: 12) {
                        if let annual = store.annual {
                            PlanRow(
                                title: "Annual",
                                price: "\(annual.displayPrice) / year",
                                subtitle: store.trialText(for: annual).map { "\($0), then billed yearly. Cancel anytime." } ?? "Billed yearly. Cancel anytime.",
                                isSelected: choice == .annual
                            ) { choice = .annual }
                        }
                        if let lifetime = store.lifetime {
                            PlanRow(
                                title: "Lifetime",
                                price: "\(lifetime.displayPrice) once",
                                subtitle: "Pay once. No subscription, ever.",
                                isSelected: choice == .lifetime
                            ) { choice = .lifetime }
                        }
                    }
                }

                Button {
                    guard let product = selectedProduct else { return }
                    Task { await store.purchase(product) }
                } label: {
                    Group {
                        if store.isPurchasing { ProgressView().tint(.white) } else { Text(callToAction).bold() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled((selectedProduct == nil && mockPrices == nil) || store.isPurchasing)

                if let error = store.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .font(.footnote)

                #if DEBUG
                Button("Debug: unlock without purchase") {
                    DebugFlags.unlockAll = true
                    Task { await store.refreshEntitlements() }
                }
                .font(.footnote)
                .foregroundStyle(.orange)
                #endif

                HStack(spacing: 12) {
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    Text("·")
                    Link("Terms of Use", destination: AppConfig.termsURL)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .interactiveDismissDisabled()
        .task { await store.loadProducts() }
    }
}

private struct PlanRow: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Text(price).font(.headline).monospacedDigit()
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
