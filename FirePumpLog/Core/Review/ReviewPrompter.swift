import Foundation
import StoreKit
import SwiftUI

/// Asks for a rating at a moment of success, not at launch. Rating velocity is a ranking input,
/// so every app calls `recordSuccess` after its core "it worked" action (a saved entry, an export).
/// Apple shows the prompt at most three times a year per app; this helper also limits it to once per version.
enum ReviewPrompter {
    private static let countKey = "review.successCount"
    private static let versionKey = "review.lastPromptedVersion"

    static func recordSuccess(request: RequestReviewAction) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard count >= AppConfig.reviewAfterSuccesses,
              defaults.string(forKey: versionKey) != version else { return }
        defaults.set(version, forKey: versionKey)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            request()
        }
    }
}
