import XCTest

/// Rules from CLAUDE.md that are cheap to state and expensive to remember. These read the app's
/// own source rather than its behaviour, because the thing being checked is that a line of code
/// exists at all. A rule the build enforces is the only kind that survives a year of weekly apps.
final class TemplateRulesTests: XCTestCase {

    /// The directory holding the app target's Swift files, found from this test file's own path.
    private func appSourceDirectory() throws -> URL {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        let manager = FileManager.default
        let children = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
        for child in children {
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if manager.fileExists(atPath: child.appendingPathComponent("App/RootView.swift").path) {
                return child
            }
        }
        throw XCTSkip("Could not find the app source directory from \(root.path); skipping the source rules.")
    }

    private func swiftFiles(in directory: URL) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Rule 6: the review prompt fires on the app's core success action. Rating velocity feeds
    /// App Store search ranking, so an app that never asks is quietly giving up placement.
    func testTheAppAsksForAReviewSomewhere() throws {
        let directory = try appSourceDirectory()
        let callers = swiftFiles(in: directory).filter { url in
            url.lastPathComponent != "ReviewPrompter.swift"
                && ((try? String(contentsOf: url, encoding: .utf8))?.contains("ReviewPrompter.recordSuccess") ?? false)
        }
        XCTAssertFalse(callers.isEmpty, """
            No feature view calls ReviewPrompter.recordSuccess.
            Add it to the app's core success action, right after the record is saved:
                ReviewPrompter.recordSuccess(request: requestReview)
            with @Environment(\\.requestReview) private var requestReview on the view.
            """)
    }

    /// Rule 6 again: every app ships the How do I use this app guide, and it has to be reachable.
    func testTheHowToGuideIsReachable() throws {
        let directory = try appSourceDirectory()
        let references = swiftFiles(in: directory).filter { url in
            url.lastPathComponent != "HowToView.swift"
                && ((try? String(contentsOf: url, encoding: .utf8))?.contains("HowToView()") ?? false)
        }
        XCTAssertFalse(references.isEmpty, """
            Nothing presents HowToView, so the How do I use this app guide cannot be opened.
            Add it to the home toolbar and to Settings:
                NavigationLink { HowToView() } label: { Image(systemName: "questionmark.circle") }
            """)
    }

    /// Rule 2: the paywall is the only gate and it is not dismissible. A stray free-tier check in a
    /// feature view is the failure this catches.
    func testOnlyRootViewChecksEntitlement() throws {
        let directory = try appSourceDirectory()
        let offenders = swiftFiles(in: directory).filter { url in
            guard url.lastPathComponent != "RootView.swift",
                  url.lastPathComponent != "EntitlementStore.swift",
                  url.lastPathComponent != "PaywallView.swift",
                  url.lastPathComponent != "SettingsView.swift",
                  let source = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return source.contains(".isEntitled")
        }
        XCTAssertTrue(offenders.isEmpty, """
            Entitlement is checked outside RootView, in: \(offenders.map(\.lastPathComponent).joined(separator: ", ")).
            RootView is the single gate; feature views never ask whether the user has paid.
            """)
    }
}
