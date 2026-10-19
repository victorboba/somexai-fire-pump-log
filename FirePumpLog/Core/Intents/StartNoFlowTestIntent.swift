import AppIntents
import Foundation

/// "Start a no-flow test in Fire Pump Log" from Siri, Spotlight or the Shortcuts app.
///
/// The no-flow test is the one that happens every week with wet hands and a phone in a pocket,
/// so it is the one worth a spoken shortcut. It opens the app on the pump whose clocks are
/// worst and starts the test there.
struct StartNoFlowTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a No-Flow Test"
    static var description = IntentDescription("Opens the app on the pump that needs it most, ready to record a no-flow test.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.startNoFlowTest"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct FirePumpLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartNoFlowTestIntent(),
            phrases: ["Start a no-flow test in \(.applicationName)",
                      "Log a pump test in \(.applicationName)"],
            shortTitle: "No-Flow Test",
            systemImageName: "gauge.with.dots.needle.33percent"
        )
    }
}
