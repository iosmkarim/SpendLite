//
//  NotificationsUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Settings → Notifications, with a fake notification center (set by launch arguments).
final class NotificationsUITests: XCTestCase {

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] + extra
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        return app
    }

    private func waitFor(_ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func testTurnOnAlertsAndReminderWithTime() {
        let app = launch()
        let alerts = app.switches["settings.budgetAlerts"]
        XCTAssertTrue(alerts.waitForExistence(timeout: 3))
        alerts.switches.firstMatch.tap()
        XCTAssertTrue(waitFor(alerts, "value == '1'"))

        let reminder = app.switches["settings.dailyReminder"]
        reminder.switches.firstMatch.tap()
        XCTAssertTrue(waitFor(reminder, "value == '1'"))
        XCTAssertTrue(app.datePickers["settings.reminderTime"].waitForExistence(timeout: 3), "Time picker appears")

        reminder.switches.firstMatch.tap()
        XCTAssertTrue(waitFor(reminder, "value == '0'"))
        XCTAssertFalse(app.datePickers["settings.reminderTime"].exists)
    }

    @MainActor
    func testDeniedPermissionExplainsHowToFixIt() {
        let app = launch(["-ui-testing-notifications-denied"])
        let alerts = app.switches["settings.budgetAlerts"]
        XCTAssertTrue(alerts.waitForExistence(timeout: 3))
        alerts.switches.firstMatch.tap()

        XCTAssertTrue(app.alerts["Notifications are off"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.buttons["Open Settings"].exists)
        app.alerts.buttons["Not Now"].tap()
        XCTAssertEqual(alerts.value as? String, "0", "Stays off when permission is denied")
    }
}
