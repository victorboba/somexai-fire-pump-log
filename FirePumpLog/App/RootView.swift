import SwiftUI

/// The single access gate. Onboarding once, then a hard paywall until entitled, then the app.
/// Feature views never check entitlement themselves.
struct RootView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @Environment(EntitlementStore.self) private var entitlements

    var body: some View {
        Group {
            if !onboardingCompleted {
                OnboardingView { onboardingCompleted = true }
            } else if !entitlements.hasLoadedEntitlements {
                ProgressView()
            } else if !entitlements.isEntitled {
                PaywallView()
            } else {
                HomeView()
            }
        }
        .animation(.default, value: onboardingCompleted)
        .animation(.default, value: entitlements.isEntitled)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-skipOnboarding") { onboardingCompleted = true }
            #endif
        }
    }
}
