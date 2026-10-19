import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Fire Pump Log"
    static let bundleID = "com.example.fire-pump-log"
    static let appGroupID = "group.com.example.fire-pump-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy.
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/fire-pump-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls one record.
    static let entryNoun = "Test"
    static let entryNounPlural = "Tests"
    /// File name stem for exports: "fire-pump-log-2026-09-14.csv".
    static let exportFileStem = "fire-pump-log"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "gauge.with.dots.needle.33percent", title: "Three clocks on every pump",
                       body: "NFPA 25 runs a no-flow test, an annual flow test and an alarm check on the same pump at once. The board shows all three clocks together and puts the worst one first."),
        OnboardingPage(symbol: "chart.xyaxis.line", title: "The flow test, point by point",
                       body: "Churn, 100% and 150% of rated flow. Enter flow, suction, discharge and speed at each point and the table shows the net pressure and what percentage of the nameplate the pump made."),
        OnboardingPage(symbol: "signature", title: "Arithmetic, not a verdict",
                       body: "The app subtracts and divides the numbers you entered, and stops. Whether the pump is acceptable is your judgement, and every record says so. Your data stays on your phone."),
    ]

    static let paywallSymbol = "gauge.with.dots.needle.67percent"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited pumps and tests",
        "The annual flow test against the nameplate",
        "Signed PDF test records and pump histories",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the board)
    static let howToIntro = "Five steps. Adding the pump takes the longest, and you only do it once."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "text.badge.plus", title: "Add the pump",
                  body: "Tap Add a pump and fill in the nameplate: rated flow in gpm, rated pressure in psi and rated speed in rpm. Then choose Electric motor or Diesel engine, because that decides which readings every test asks you for.",
                  tip: "Photograph the nameplate while you are standing at the pump. Rated flow and rated pressure are what the annual test is measured against, and they are the two numbers people misremember."),
        HowToStep(symbol: "calendar.badge.clock", title: "Set the no-flow cadence",
                  body: "On the same screen set No-flow test to Weekly or Monthly. NFPA 25 sets the frequency and your authority having jurisdiction or your insurer may ask for it more often, so the app records the cadence you chose on every test rather than assuming one."),
        HowToStep(symbol: "gauge.with.dots.needle.33percent", title: "Run the no-flow test",
                  body: "On the pump's card tap Start no-flow test. Enter suction and discharge pressure, how long the pump took to start and how long it ran, then tap Mark remaining observations OK and change only what is wrong. Two minutes, standing in the pump room.",
                  tip: "A diesel is asked for fuel level, both battery voltages, oil pressure and coolant temperature. An electric pump is never asked for any of them."),
        HowToStep(symbol: "chart.xyaxis.line", title: "Run the annual flow test",
                  body: "Tap Annual flow test. The table already has the churn, 100% and 150% rows with their target flows worked out from the nameplate. Fill in flow, suction, discharge and rpm on each row and the row shows its net pressure, its percentage of rated capacity and its percentage of the nameplate.",
                  tip: "The 150% row is what the annual test exists for. The app shows what the pump made; whether that is acceptable is your call, and you record it under Your finding."),
        HowToStep(symbol: "doc.richtext", title: "Sign it and produce the record",
                  body: "Put your name in, sign the annual test with a finger, then tap Test record (PDF). For a pump's whole file use Pump history (PDF) on the pump screen, or Every test as CSV from the board."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$12.99", lifetime: "$29.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3

    /// The sentence that has to appear in the app and on every export. The app reports arithmetic
    /// on the technician's own readings; it does not decide whether a pump is acceptable.
    static let judgementDisclaimer =
        "\(appName) records the readings entered and the arithmetic on them. It does not inspect, "
        + "certify or approve any equipment, and it does not decide whether a pump passed — that "
        + "judgement belongs to the person who ran the test."
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
