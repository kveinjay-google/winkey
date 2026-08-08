import AppKit

// Single-instance guard: if another WinKey is already running (e.g. the launchd
// agent bootstraps a duplicate while the app is open), exit cleanly so the
// existing instance keeps owning the event taps.
let bundleID = Bundle.main.bundleIdentifier ?? "dev.codex.winkey"
let currentPID = getpid()
let alreadyRunning = NSRunningApplication
    .runningApplications(withBundleIdentifier: bundleID)
    .contains { $0.processIdentifier != currentPID }
if alreadyRunning {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
