//
//  SettingsUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Settings: budget, currency, delete all. Runs on throwaway data and preferences
/// (-ui-testing), so it never changes the real app's settings.
final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        let addSample = app.buttons["Add sample data"]
        if addSample.waitForExistence(timeout: 2) { addSample.tap() }
        XCTAssertTrue(app.buttons["home.quickAction.insights"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
    }

    /// Waits for an asynchronous update (saves and deletes land a moment after the tap).
    private func wait(for element: XCUIElement, _ predicate: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func testEditingBudgetUpdatesHome() {
        app.buttons["settings.budget"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "500")
        app.alerts.buttons["Save"].tap()

        XCTAssertTrue(wait(for: app.buttons["settings.budget"], "label CONTAINS '$500.00'"),
                      "Got: \(app.buttons["settings.budget"].label)")
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of $500.00'")).firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testChangingCurrencyUpdatesAmountsEverywhere() {
        app.buttons["settings.currency"].tap()
        let euro = app.buttons.matching(NSPredicate(format: "label CONTAINS 'EUR'")).firstMatch
        XCTAssertTrue(euro.waitForExistence(timeout: 3))
        euro.tap()

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '€'")).firstMatch.waitForExistence(timeout: 3),
                      "Home amounts should switch to euros")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).firstMatch.exists)
    }

    @MainActor
    func testDeleteAllAsksFirstThenEmptiesTheApp() {
        app.buttons["settings.deleteAll"].tap()
        let confirm = app.buttons["Delete All Expenses"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "Must ask before deleting")
        confirm.tap()

        XCTAssertTrue(wait(for: app.buttons["settings.deleteAll"], "isEnabled == false"))
        XCTAssertTrue(wait(for: app.buttons["settings.export"], "isEnabled == false"))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Add sample data"].waitForExistence(timeout: 3), "Home should show its empty state")
    }

    @MainActor
    func testExportIsAvailableWhenThereAreExpenses() {
        XCTAssertTrue(app.buttons["settings.export"].isEnabled)
    }
}
