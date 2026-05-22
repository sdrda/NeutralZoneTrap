//
//  Neutral_Zone_TrapUITests.swift
//  Neutral Zone Trap
//

import XCTest

#if os(iOS)
final class Neutral_Zone_TrapUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Live UDP → Rink Accessibility (iPhone & iPad)

    /// Drives the live pipeline end-to-end from a UI-test process: opens a UDP
    /// socket to 127.0.0.1:12345 (where `UDPReceiver` is bound) and fires N
    /// packets with distinct sensor IDs. Verifies that `RealityRinkView`'s
    /// accessibility value reflects the active-player count.
    @MainActor
    func testUDPPacketsUpdateActivePlayerCount() throws {
        // Default tab is Rink; nothing to navigate.
        let rink = app.descendants(matching: .any)
            .matching(identifier: "rink.realityview")
            .firstMatch
        XCTAssertTrue(rink.waitForExistence(timeout: 5),
                      "Rink accessibility element should be present")

        // Initial state — no sensors yet.
        XCTAssertEqual(rink.value as? String, "0 active players on the ice",
                       "Active player count should start at zero")

        // Pick three IDs in the puck/player range used by the production mocker.
        let ids: [Double] = [11, 12, 13]
        let sender = UDPMockSender()
        defer { sender.close() }

        // Resend a few times — UDP is unreliable and `UDPReceiver` may still
        // be coming up at the moment the test fires.
        for _ in 0..<5 {
            for id in ids {
                sender.send(id: id)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Poll the accessibility value until it reflects all three sensors.
        let expected = "\(ids.count) active players on the ice"
        let deadline = Date().addingTimeInterval(5)
        var lastSeen: String?
        while Date() < deadline {
            lastSeen = rink.value as? String
            if lastSeen == expected { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Rink accessibility value did not become '\(expected)' (last saw '\(lastSeen ?? "nil")')")
    }
}
#endif
