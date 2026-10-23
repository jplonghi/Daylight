import AppKit

// Read-only runtime check for the app under test; does not activate or operate UI.
let bundleID = CommandLine.arguments.dropFirst().first ?? "com.local.daylight.countdown.qa-fixed"
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
if apps.isEmpty {
    print("No matching process visible from this execution context.")
    exit(1)
}
for app in apps {
    let policy: String
    switch app.activationPolicy {
    case .regular: policy = "regular (Dock and application menu)"
    case .accessory: policy = "accessory (menu-bar app, no Dock icon)"
    default: policy = "prohibited"
    }
    print("\(bundleID): \(policy)")
}
