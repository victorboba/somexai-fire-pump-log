import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render without
/// touching SwiftData. The app rewrites it whenever a pump or a test changes.
///
/// What a building engineer wants on a home screen is not a count of records — it is whether
/// anything is late, and which pump it is.
struct WidgetSnapshot: Codable {
    var pumpCount: Int = 0
    var overdueCount: Int = 0
    /// The pump whose nearest clock is worst, and what that clock is.
    var nextPumpName: String?
    var nextTestName: String?
    var nextStatusText: String?
    var nextDueDate: Date?
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    /// The headline the widget shows: the number of pumps with something outstanding, or nothing.
    var headline: String {
        if pumpCount == 0 { return "No pumps yet" }
        if overdueCount == 0 { return "Nothing overdue" }
        return overdueCount == 1 ? "1 pump overdue" : "\(overdueCount) pumps overdue"
    }

    static let placeholder = WidgetSnapshot(pumpCount: 3, overdueCount: 1,
                                            nextPumpName: "Fire Pump 1",
                                            nextTestName: "No-flow",
                                            nextStatusText: "Overdue by 2 days",
                                            nextDueDate: .now)
}
