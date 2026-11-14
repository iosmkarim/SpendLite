//
//  AppLockUITests.swift
//  SpendLiteUITests
//

import XCTest

/// The Face ID lock, with a fake Face ID (set by launch arguments) so no real face is needed.
final class AppLockUITests: XCTestCase {

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testLockedAppUnlocksWithFaceID() {
        let app = launch(["-ui-testing-lock-enabled"])
        // The fake Face ID succeeds straight away, so the lock screen goes and Home shows.
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForDisappearance(app.otherElements["lock.screen"]))
    }

    @MainActor
    func testFailedFaceIDStaysLocked() {
        let app = launch(["-ui-testing-lock-enabled", "-ui-testing-auth-fails"])
        let unlock = app.buttons["lock.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SpendLite is locked"].exists)

        unlock.tap() // try again: still fails
        XCTAssertTrue(app.staticTexts["SpendLite is locked"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.tabBars.buttons["Home"].isHittable, "App content must stay covered")
    }

    @MainActor
    func testTurnOnInSettingsThenLocksAfterBackground() {
        let app = launch([])
        app.tabBars.buttons["Settings"].tap()

        let toggle = app.switches["settings.appLock"]
        for _ in 0..<3 where !toggle.isHittable { app.swipeUp() }
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(waitFor(toggle, "value == '1'"), "Lock should turn on after Face ID")

        // Leave and come back: the lock screen appears, then unlocks (fake Face ID succeeds).
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForDisappearance(app.otherElements["lock.screen"]))
    }

    // MARK: - Helpers

    private func waitFor(_ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        waitFor(element, "exists == false", timeout: timeout)
    }
}
