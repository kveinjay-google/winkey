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
}
