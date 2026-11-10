//
//  RecurringUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Recurring expenses: create from the Add form, manage in Settings → Recurring expenses.
final class RecurringUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] // fresh in-memory data each run
        app.launch()
    }

    private func wait(for element: XCUIElement, _ predicate: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Adds "Rent" $1200 repeating monthly from the Transactions tab.
    private func addMonthlyRent() {
        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.add"].tap()
        let amount = app.textFields["Enter amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText("1200")
        let description = app.textViews.firstMatch
        description.tap()
        description.typeText("Rent")
        app.navigationBars["Add Expense"].staticTexts["Add Expense"].tap() // move focus off the keyboard

        let repeatPicker = app.buttons["addExpense.repeat"]
        for _ in 0..<3 where !repeatPicker.isHittable { app.swipeUp() }
        repeatPicker.tap()
        app.buttons["Monthly"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
    }

    private func openRecurringList() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.recurring"].tap()
        XCTAssertTrue(app.navigationBars["Recurring"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRepeatAddsTodaysExpenseAndShowsInRecurringList() {
        addMonthlyRent()

        // This month's rent is added straight away and marked as recurring.
        let rentRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rent,' AND label CONTAINS 'recurring'")).firstMatch
        XCTAssertTrue(rentRow.waitForExistence(timeout: 3))

        openRecurringList()
        XCTAssertTrue(app.buttons["recurring.row.Rent"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["recurring.row.Rent"].label.contains("Monthly · Next"))
        let summary = app.descendants(matching: .any)["recurring.summary"]
        XCTAssertTrue(wait(for: summary, "label CONTAINS '$1,200.00' AND label CONTAINS '1 active'"), "Got: \(summary.label)")
    }

    @MainActor
    func testPauseThenStopRepeating() {
        addMonthlyRent()
        openRecurringList()

        // Pause from the edit screen.
        app.buttons["recurring.row.Rent"].tap()
        let paused = app.switches["recurringEdit.paused"]
        XCTAssertTrue(paused.waitForExistence(timeout: 3))
        paused.switches.firstMatch.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(wait(for: app.buttons["recurring.row.Rent"], "label CONTAINS 'Paused'"))
        let summary = app.descendants(matching: .any)["recurring.summary"]
        XCTAssertTrue(wait(for: summary, "label CONTAINS '$0.00' AND label CONTAINS '1 paused'"),
                      "Paused expenses don't count towards the monthly total. Got: \(summary.label)")

        // Stop repeating: asks first, then the list is empty…
        app.buttons["recurring.row.Rent"].tap()
        app.buttons["recurringEdit.delete"].tap()
        let confirm = app.buttons["Stop Repeating"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["No recurring expenses"].waitForExistence(timeout: 3))

        // …but the rent already added stays in Transactions.
        app.tabBars.buttons["Transactions"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rent,'")).firstMatch.waitForExistence(timeout: 3))
    }
}
