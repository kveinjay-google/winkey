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

        // Remove the old SMAppService login item so the agent is the single
        // launch mechanism. Never do this from an instance that IS that login
        // item: unregistering would make macOS terminate the running app
        // (observed as a clean self-exit with no relaunch).
        if #available(macOS 13, *), !Self.isLegacyServiceInstance() {
            try? SMAppService.mainApp.unregister()
        }

        // Clear any previously-set disabled bit, then load the job. Loading a
        // job that is already loaded is harmless (launchctl reports an error
        // which we ignore); RunAtLoad starting a duplicate is handled by the
        // single-instance guard in main.swift.
        _ = launchctl(["enable", "gui/\(getuid())/\(Self.label)"])
        _ = launchctl(["bootstrap", "gui/\(getuid())", Self.agentFileURL.path])

        // If the agent is loaded but not running (e.g. this instance was
        // launched by the legacy login item), start it so it takes over via
        // the single-instance guard and becomes the process owner.
        ensureAgentRunning()

        // Make sure the keep-alive agent is the only launcher going forward.
        removeLegacyLoginItemServices()
    }

    func uninstall() throws {
        // Disable first: this stops future launches (including at login) and
        // any KeepAlive relaunch, without terminating the running app.
        _ = launchctl(["disable", "gui/\(getuid())/\(Self.label)"])
        try? FileManager.default.removeItem(at: Self.agentFileURL)
        if #available(macOS 13, *), !Self.isLegacyServiceInstance() {
            try? SMAppService.mainApp.unregister()
        }
        removeLegacyLoginItemServices()
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


    static func isLegacyServiceLabel(_ label: String) -> Bool {
        label.hasPrefix("application.dev.codex.winkey")
    }

    static func legacyServiceLabels(from output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let eq = trimmed.firstIndex(of: "=") else { return nil }
            let label = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            return isLegacyServiceLabel(label) ? label : nil
        }
    }

    static func parseAgentPID(from output: String) -> pid_t? {
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 3, parts[0] == "pid", parts[1] == "=", let pid = pid_t(parts[2]) {
                return pid
            }
        }
        return nil
    }

    /// PID of a currently-running launchd job with the given label, if any.
    static func jobPID(label: String) -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())/\(label)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            return parseAgentPID(from: output)
        } catch {
            return nil
        }
    }

    /// PID of the currently-running keep-alive job, if launchd has it running.
    static func agentPID() -> pid_t? {
        jobPID(label: label)
    }

    /// True when the current process is itself running as a legacy
    /// SMAppService login item (application.dev.codex.winkey.*).
    static func isLegacyServiceInstance() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return false }
            let ourPID = getpid()
            for label in legacyServiceLabels(from: output) {
                if let pid = jobPID(label: label), pid == ourPID {
                    return true
                }
            }
        } catch {
        }
        return false
    }

    /// Starts the keep-alive job now (if it is loaded but not running) so the
    /// agent can take ownership of the process via the single-instance guard.
    func ensureAgentRunning() {
        if Self.jobPID(label: Self.label) == nil {
            _ = launchctl(["kickstart", "gui/\(getuid())/\(Self.label)"])
        }
    }

    /// Removes leftover SMAppService login-item jobs (label prefix
    /// application.dev.codex.winkey) so the keep-alive agent is the only
    /// launcher. Never boots out a job whose process is our own.
    func removeLegacyLoginItemServices() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return }
            let ourPID = getpid()
            for label in Self.legacyServiceLabels(from: output) {
                if let jobPID = Self.jobPID(label: label), jobPID == ourPID { continue }
                _ = launchctl(["bootout", "gui/\(getuid())/\(label)"])
            }
        } catch {
        }
    }
}

enum LaunchAgentError: Error {
    case missingExecutable
}

