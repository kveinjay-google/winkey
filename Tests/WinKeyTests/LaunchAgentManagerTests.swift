import Foundation
import XCTest
@testable import WinKey

final class LaunchAgentManagerTests: XCTestCase {
    func testAgentPlistHasKeepAliveOnAbnormalExitSemantics() {
        let plist = LaunchAgentManager.agentPlist(executablePath: "/tmp/WinKey.app/Contents/MacOS/WinKey")

        XCTAssertEqual(plist["Label"] as? String, LaunchAgentManager.label)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            ["/tmp/WinKey.app/Contents/MacOS/WinKey"]
        )
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(
            plist["KeepAlive"] as? [String: Bool],
            ["SuccessfulExit": false]
        )
        XCTAssertEqual(plist["ProcessType"] as? String, "Interactive")
    }

    func testAgentFileURLPointsIntoLaunchAgents() {
        let url = LaunchAgentManager.agentFileURL

        XCTAssertTrue(url.path.contains("/Library/LaunchAgents"))
        XCTAssertEqual(url.lastPathComponent, "\(LaunchAgentManager.label).plist")
    }

    func testAgentPlistSerializesAndRoundTrips() throws {
        let plist = LaunchAgentManager.agentPlist(executablePath: "/tmp/WinKey.app/Contents/MacOS/WinKey")
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        let decoded = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            as? [String: Any]

        XCTAssertEqual(decoded?["Label"] as? String, LaunchAgentManager.label)
        XCTAssertEqual(decoded?["KeepAlive"] as? [String: Bool], ["SuccessfulExit": false])
        XCTAssertEqual(decoded?["RunAtLoad"] as? Bool, true)
    }
    func testLegacyServiceLabelDetection() {
        XCTAssertTrue(LaunchAgentManager.isLegacyServiceLabel("application.dev.codex.winkey.26205707.26205737"))
        XCTAssertFalse(LaunchAgentManager.isLegacyServiceLabel("dev.codex.winkey.keepalive"))
        XCTAssertFalse(LaunchAgentManager.isLegacyServiceLabel("application.com.example.app"))
    }

    func testLegacyServiceLabelsParsing() {
        let output = """
        gui/501 = {
            active count = 2
            application.dev.codex.winkey.26205707.26205737 = {
                program = /Users/kevin/Documents/winkey/dist/WinKey.app/Contents/MacOS/WinKey
            }
            dev.codex.winkey.keepalive = {
                program = /Users/kevin/Documents/winkey/dist/WinKey.app/Contents/MacOS/WinKey
            }
            com.apple.Safari = {
            }
        }
        """

        XCTAssertEqual(
            LaunchAgentManager.legacyServiceLabels(from: output),
            ["application.dev.codex.winkey.26205707.26205737"]
        )
    }

    func testParseAgentPID() {
        XCTAssertEqual(
            LaunchAgentManager.parseAgentPID(from: "\t\tpid = 88865\n\t\tstate = running"),
            88865
        )
        XCTAssertNil(LaunchAgentManager.parseAgentPID(from: "state = not running"))
        XCTAssertNil(LaunchAgentManager.parseAgentPID(from: ""))
    }
}

