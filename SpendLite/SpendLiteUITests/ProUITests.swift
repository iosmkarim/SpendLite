//
//  ProUITests.swift
//  SpendLiteUITests
//

import XCTest

/// SpendLite Pro gating and the upgrade screen (with a fake App Store, set by launch arguments).
final class ProUITests: XCTestCase {

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] + extra
        app.launch()
        return app
    }

    private func openAddForm(_ app: XCUIApplication) {
        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.add"].tap()
        XCTAssertTrue(app.textFields["Enter amount"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testFreeUserUnlocksReceiptScan() {
        let app = launch()
        openAddForm(app)

        // Locked: tapping opens the Pro screen instead of the scanner.
        app.buttons["addExpense.scanReceipt"].tap()
        XCTAssertTrue(app.buttons["pro.buy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["pro.buy"].label.contains("$4.99"))
        XCTAssertTrue(app.buttons["pro.restore"].exists, "Restore Purchases is required by App Review")

        app.buttons["pro.buy"].tap()
        XCTAssertTrue(app.staticTexts["Pro unlocked"].waitForExistence(timeout: 3)
                      || app.descendants(matching: .any)["pro.unlocked"].waitForExistence(timeout: 1))
        app.buttons["pro.close"].tap()

        // Unlocked: the scan menu now works.
        app.buttons["addExpense.scanReceipt"].tap()
        XCTAssertTrue(app.buttons["Use Sample Receipt"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testFourthRecurringExpenseNeedsPro() {
        let app = launch()
        for name in ["Rent", "Phone", "Gym"] {
            openAddForm(app)
            let amount = app.textFields["Enter amount"]
            amount.tap()
            amount.typeText("10")
            let description = app.textViews.firstMatch
            description.tap()
            description.typeText(name)
            app.navigationBars["Add Expense"].staticTexts["Add Expense"].tap()
            let repeatPicker = app.buttons["addExpense.repeat"]
            for _ in 0..<3 where !repeatPicker.isHittable { app.swipeUp() }
            repeatPicker.tap()
            app.buttons["Monthly"].tap()
            app.navigationBars.buttons["Save"].tap()
            XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
        }

        // The form now offers Pro instead of Repeat…
        openAddForm(app)
        let locked = app.buttons["addExpense.repeatLocked"]
        for _ in 0..<3 where !locked.isHittable { app.swipeUp() }
        XCTAssertTrue(locked.exists)
        XCTAssertFalse(app.buttons["addExpense.repeat"].exists)
        app.navigationBars.buttons["Cancel"].tap()

        // …and so does + in Settings → Recurring expenses.
        app.tabBars.buttons["Settings"].tap()
        let recurring = app.buttons["settings.recurring"]
        for _ in 0..<3 where !recurring.isHittable { app.swipeUp() }
        recurring.tap()
        app.buttons["recurring.add"].tap()
        XCTAssertTrue(app.buttons["pro.buy"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsShowsUpgradeOrUnlocked() {
        let free = launch()
        free.tabBars.buttons["Settings"].tap()
        let row = free.buttons["settings.pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains("Upgrade"))
        XCTAssertTrue(free.buttons["settings.restore"].exists)
        row.tap()
        XCTAssertTrue(free.buttons["pro.buy"].waitForExistence(timeout: 3))
        free.terminate()

        let pro = launch(["-ui-testing-pro"])
        pro.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(pro.buttons["settings.pro"].waitForExistence(timeout: 3))
        XCTAssertTrue(pro.buttons["settings.pro"].label.contains("Unlocked"))
        XCTAssertFalse(pro.buttons["settings.restore"].exists)
    }

    @MainActor
    func testProWidgetLinkOpensThePaywall() {
        let app = launch()
        XCUIDevice.shared.system.open(URL(string: "spendlite://pro")!)
        let openButton = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if openButton.waitForExistence(timeout: 3) { openButton.tap() }
        XCTAssertTrue(app.buttons["pro.buy"].waitForExistence(timeout: 5))
    }
}
