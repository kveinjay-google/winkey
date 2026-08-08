import AppKit
import Foundation
import ServiceManagement

/// Per-user launchd agent that keeps WinKey alive. The agent is the single
/// launch mechanism (replacing the old SMAppService login item):
/// - RunAtLoad: starts WinKey at login and when (re)bootstraped.
/// - KeepAlive SuccessfulExit=false: launchd relaunches the app whenever it
///   exits abnormally (crash, SIGKILL, unexpected termination), but leaves it
///   stopped after a clean user quit.
/// A single-instance guard in main.swift prevents duplicate instances when
/// the agent is bootstrapped while the app is already running.
final class LaunchAgentManager {
    static let label = "dev.codex.winkey.keepalive"

    static var agentDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    static var agentFileURL: URL {
        agentDirectoryURL.appendingPathComponent("\(label).plist")
    }

    static func agentPlist(executablePath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive"
        ]
    }

    var isInstalled: Bool {
        guard FileManager.default.fileExists(atPath: Self.agentFileURL.path) else {
            return false
        }
        return launchctl(["print", "gui/\(getuid())/\(Self.label)"]) == 0
    }

    /// Keeps the agent in sync with the user's launch-at-login preference.
    /// Never kills the running app: turning the setting off disables the job
    /// and removes the plist, but the current instance keeps running.
    func sync(withEnabled enabled: Bool) {
        if enabled {
            try? install()
        } else {
            try? uninstall()
        }
    }

    func install() throws {
        guard let executablePath = Bundle.main.executablePath else {
            throw LaunchAgentError.missingExecutable
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: Self.agentDirectoryURL, withIntermediateDirectories: true)

        let plist = Self.agentPlist(executablePath: executablePath)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: Self.agentFileURL, options: .atomic)

        // Migrate away from the old SMAppService login item so the agent is the
        // single launch mechanism and the app cannot start twice at login.
        if #available(macOS 13, *) {
            try? SMAppService.mainApp.unregister()
        }

        // Clear any previously-set disabled bit, then load the job. Loading a
        // job that is already loaded is harmless (launchctl reports an error
        // which we ignore); RunAtLoad starting a duplicate is handled by the
        // single-instance guard in main.swift.
        _ = launchctl(["enable", "gui/\(getuid())/\(Self.label)"])
        _ = launchctl(["bootstrap", "gui/\(getuid())", Self.agentFileURL.path])
    }

    func uninstall() throws {
        // Disable first: this stops future launches (including at login) and
        // any KeepAlive relaunch, without terminating the running app.
        _ = launchctl(["disable", "gui/\(getuid())/\(Self.label)"])
        try? FileManager.default.removeItem(at: Self.agentFileURL)
    }

    @discardableResult
    private func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    enum LaunchAgentError: Error {
        case missingExecutable
    }
}
