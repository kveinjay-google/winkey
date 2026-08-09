import AppKit
import Darwin

// Single-instance guard: if another WinKey is already running (e.g. the launchd
// agent bootstraps a duplicate while the app is open), exit cleanly so the
// existing instance keeps owning the event taps. The one exception: when the
// keep-alive agent starts us while an older, unprotected instance (launched by
// the legacy login item or manually) is still alive, we take over by
// terminating it, so the watchdog always owns the surviving process.
let bundleID = Bundle.main.bundleIdentifier ?? "dev.codex.winkey"
let currentPID = getpid()
let otherInstances = NSRunningApplication
    .runningApplications(withBundleIdentifier: bundleID)
    .filter { $0.processIdentifier != currentPID }

if let otherPID = otherInstances.first?.processIdentifier {
    let agentPID = LaunchAgentManager.agentPID()
    if agentPID == currentPID, agentPID != otherPID {
        kill(otherPID, SIGTERM)
        Thread.sleep(forTimeInterval: 0.3)
    } else {
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
