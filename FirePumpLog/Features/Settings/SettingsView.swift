import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var confirmingDeleteAll = false
    #if DEBUG
    @State private var sampleDataImported = false
    @AppStorage(DebugFlags.unlockKey) private var debugUnlock = false
    @AppStorage("onboarding.completed") private var onboardingCompleted = true
    #endif

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your plan") {
                    LabeledContent("Status", value: planDescription)
                    if store.isEntitled && !store.isLifetime {
                        Button("Manage Subscription") {
                            openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                        }
                    }
                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    if let error = store.lastError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }

                Section("Your data") {
                    Text("Everything you record stays on this device\(AppConfig.iCloudSyncEnabled ? " and in your private iCloud" : ""). Nothing is sent to us.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Delete All Pumps", role: .destructive) {
                        confirmingDeleteAll = true
                    }
                }

                Section("Help") {
                    NavigationLink { HowToView() } label: { Label("How do I use \(AppConfig.appName)?", systemImage: "questionmark.circle") }
                }

                Section("About") {
                    if !AppConfig.appStoreID.isEmpty {
                        Button("Rate \(AppConfig.appName)") {
                            openURL(URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")!)
                        }
                    }
                    Button("Contact Support") {
                        let subject = "\(AppConfig.appName) \(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        openURL(URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(subject)")!)
                    }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    Link("Terms of Use", destination: AppConfig.termsURL)
                    LabeledContent("Version", value: version)
                }

                #if DEBUG
                Section("Debug (not in release builds)") {
                    Toggle("Unlock without purchase", isOn: $debugUnlock)
                        .onChange(of: debugUnlock) { Task { await store.refreshEntitlements() } }
                    Button("Show onboarding again") {
                        onboardingCompleted = false
                        dismiss()
                    }
                    Button(sampleDataImported ? "Imported ✓" : "Insert sample data") {
                        SampleData.insert(into: context)
                        sampleDataImported = true
                        Task { try? await Task.sleep(for: .seconds(2)); sampleDataImported = false }
                    }
                    .disabled(sampleDataImported)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete every pump and every test on this device?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    try? context.delete(model: PumpTest.self)
                    try? context.delete(model: Pump.self)
                    WidgetSync.update(with: [])
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. Export first if you want a copy.")
            }
        }
    }

    private var planDescription: String {
        guard store.isEntitled else { return "Not active" }
        if store.isLifetime { return "Lifetime" }
        if let expiry = store.expiresAt {
            return "Annual, renews \(expiry.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Active"
    }
}
