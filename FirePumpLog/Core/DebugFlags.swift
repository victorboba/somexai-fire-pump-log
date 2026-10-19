import Foundation

#if DEBUG
/// Debug-only switches. Never compiled into Release builds.
enum DebugFlags {
    static let unlockKey = "debug.unlockAll"

    /// Bypass the paywall: toggle in Settings (Debug section) or launch with `-unlock`.
    static var unlockAll: Bool {
        get {
            UserDefaults.standard.bool(forKey: unlockKey)
                || ProcessInfo.processInfo.arguments.contains("-unlock")
        }
        set { UserDefaults.standard.set(newValue, forKey: unlockKey) }
    }
}
#endif
