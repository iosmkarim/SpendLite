//
//  TransactionsUITests.swift
//  SpendLiteUITests
//

import XCTest

/// The Transactions tab: empty state, add, edit (tap), delete (swipe) and Undo.
final class TransactionsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] // fresh in-memory data each run
        app.launch()
        app.tabBars.buttons["Transactions"].tap()
    }

    /// The row's button, found by the start of its VoiceOver label ("Lunch, Other, Today…").
    private func row(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

    private func addExpense(amount: String, description: String) {
        app.buttons["transactions.add"].tap()
        let amountField = app.textFields["Enter amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText(amount)
        let descriptionField = app.textViews.firstMatch
        descriptionField.tap()
        descriptionField.typeText(description)
        app.navigationBars.buttons["Save"].tap()
    }

    @MainActor
    func testEmptyStateThenAddShowsTheExpense() {
        XCTAssertTrue(app.staticTexts["No transactions yet"].waitForExistence(timeout: 3))

        addExpense(amount: "7.25", description: "Lunch")

        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3))
        XCTAssertTrue(row("Lunch").label.contains("$7.25"))
        XCTAssertFalse(app.staticTexts["No transactions yet"].exists)
    }

    @MainActor
    func testTapRowEditsTheExpense() {
        addExpense(amount: "7.25", description: "Lunch")
        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3))

        row("Lunch").tap()
        XCTAssertTrue(app.navigationBars["Edit Expense"].waitForExistence(timeout: 3))
        let amountField = app.textFields["Enter amount"]
        XCTAssertEqual(amountField.value as? String, "7.25", "The form should start filled in")

        // Replace the amount.
        amountField.tap()
        amountField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "9")
        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
        XCTAssertTrue(row("Lunch").label.contains("$9.00"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lunch,'")).count, 1,
                       "Editing must not create a second copy")
    }

    @MainActor
    func testSwipeToDeleteThenUndo() {
        addExpense(amount: "7.25", description: "Lunch")
        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3))

        row("Lunch").swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No transactions yet"].waitForExistence(timeout: 3))
        let undo = app.buttons["transactions.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))

        undo.tap()
        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3), "Undo should bring the expense back")
    }
}
