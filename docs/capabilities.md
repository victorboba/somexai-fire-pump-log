# Capabilities

The template builds and runs with only one capability: an App Group, which the widget and the Shortcut use to share a small snapshot with the app. Everything else is opt-in.

## App Group (already on)

Both entitlements files declare `group.com.example.<slug>`. With automatic signing, Xcode registers the group on the App ID the first time you run on a device. If it complains, open the app target → Signing & Capabilities → App Groups and tick the group.

## iCloud sync (off by default)

SwiftData can mirror the store to the user's private CloudKit database. Turn it on only for apps where losing data on a phone upgrade would hurt (medical logs, licensure hours). Steps:

1. Xcode → app target → Signing & Capabilities → + iCloud → tick CloudKit → add container `iCloud.com.example.<slug>`.
2. Also add Background Modes → Remote notifications (CloudKit uses silent pushes to sync).
3. Xcode writes both into `<App>.entitlements`. Keep them there.
4. Set `AppConfig.iCloudSyncEnabled = true`.
5. Keep every `@Model` property defaulted and never use `@Attribute(.unique)`; CloudKit rejects both.
6. Test on two devices signed into the same Apple Account. The simulator can sync but is unreliable for it.

Update `PrivacyPolicyView` and the hosted policy: the template's copy already switches its wording on `AppConfig.iCloudSyncEnabled`.

## Things this template deliberately does not include

- Push notifications from a server (no server).
- Sign in with Apple or any account (Apple 5.1.1 lets you skip it when there are no account features).
- HealthKit. Reading HealthKit data adds review friction and a required privacy string; add it per app only when the core feature needs it.
- Camera or photo library. Add the usage strings to `project.yml` under `info.properties` the week an app needs them.
