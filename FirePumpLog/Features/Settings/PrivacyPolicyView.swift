import SwiftUI

/// In-app privacy policy. Apple requires a policy that is reachable inside the app and from the
/// App Store listing. This text matches the template's default behaviour (local-only data, no analytics).
/// Edit it if an app adds any network call, and keep the hosted copy at AppConfig.privacyPolicyURL in sync.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy").font(.title2.bold())
                Text("Last updated \(Date.now.formatted(date: .long, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)

                policy("What we collect", "Nothing. \(AppConfig.appName) does not have accounts, analytics, advertising, or a server. Everything you record is stored on your device\(AppConfig.iCloudSyncEnabled ? " and, if you have iCloud enabled, in your private iCloud database that only you can access" : "").")
                policy("Purchases", "Purchases are handled by Apple. We receive no payment details. Apple's privacy policy applies to the transaction.")
                policy("Exports", "When you export a PDF or CSV, the file is created on your device and shared only where you choose to send it.")
                policy("Health and personal information", "If you use \(AppConfig.appName) to record health-related information, it stays on your device and is never transmitted to us. \(AppConfig.appName) is a record-keeping tool and does not provide medical advice.")
                policy("Deleting your data", "Use Settings → Delete All, or delete the app. Both remove everything.")
                policy("Contact", "Questions: \(AppConfig.supportEmail)")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policy(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading).font(.headline)
            Text(body).font(.body).foregroundStyle(.primary)
        }
    }
}
