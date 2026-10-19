# Fire Pump Log

A log for the weekly no-flow test, the annual flow test against the nameplate, and the jockey pump and alarm check that NFPA 25 Chapter 8 runs on every fire pump, kept on the phone of whoever stands in the pump room.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the rest of the collection is in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- A due board per pump showing all three clocks at once (no-flow, annual flow, jockey and alarm), worst first. The no-flow cadence is set per pump and each test records the cadence in force.
- The annual flow test is multi-point entry: churn, 100% and 150% of rated flow. Each row computes net pressure (discharge minus suction) and the percentage of rated capacity and of the nameplate curve as you type.
- Driver-aware readings: a diesel no-flow test also asks for fuel level, both battery voltages, oil pressure and coolant temperature; an electric pump is never asked for them.
- The jockey pump and alarm check records cut-in and cut-out pressures against their setpoints and each alarm and supervisory signal.
- The annual flow test is signed with a finger and the signature prints on the PDF.
- A signed PDF per test, a whole pump history PDF, and every test across the fleet as one CSV.
- Home Screen widget, a Siri/Shortcuts action to start a no-flow test, and a How do I use guide.

## The boundary

The app records the readings entered and the arithmetic on them. It does not inspect, certify or approve any equipment, and it never says a pump passed or failed. That judgement is the technician's own entry under Your Finding, stated on screen and on every export.

## Privacy

Everything is stored on the device in SwiftData. There is no account, no analytics and no network access, and iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the phone only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), iOS 17+ (iPhone).

```bash
xcodegen generate
open FirePumpLog.xcodeproj
```

Pick the `FirePumpLog` scheme and an iPhone simulator, then Run.

- Tests: `xcodebuild -scheme FirePumpLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test`. The alternative is `scripts/ci.sh FirePumpLog`.
- Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.
- To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

The unit tests cover the net-pressure and nameplate-percentage arithmetic, zero versus not recorded, the three clocks and their boundaries, driver-aware item lists, test completeness, and CSV and PDF export. One UI test drives the core loop: add a pump, run both tests, and confirm they land in the pump's history.

## Project layout

- `FirePumpLog/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, then the app).
- `FirePumpLog/Core/`: StoreKit entitlement, CSV and PDF export, review prompt, and the App Shortcut.
- `FirePumpLog/Features/`: the screens.
- `FirePumpLog/Models/`: SwiftData models and the logic on them.
- `FirePumpLogWidget/`: the Home Screen widget.
- `FirePumpLogTests/`, `FirePumpLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, how-to guide).

## License

MIT. See [LICENSE](LICENSE).
