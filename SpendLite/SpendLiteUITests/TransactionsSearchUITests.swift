//
//  TransactionsSearchUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Transactions search bar and filter menu.
final class TransactionsSearchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] // fresh in-memory data each run
        app.launch()
        app.tabBars.buttons["Transactions"].tap()
        addExpense(amount: "12.50", description: "Lunch", category: "Food")
        addExpense(amount: "30", description: "Taxi home", category: "Transport")
        addExpense(amount: "8", description: "Coffee", category: "Food")
    }

    private func addExpense(amount: String, description: String, category: String) {
        app.buttons["transactions.add"].tap()
        let amountField = app.textFields["Enter amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText(amount)
        let descriptionField = app.textViews.firstMatch
        descriptionField.tap()
        descriptionField.typeText(description)
        app.navigationBars["Add Expense"].staticTexts["Add Expense"].tap()
        let categoryButton = app.buttons[category]
        if !categoryButton.isHittable { app.swipeUp() }
        categoryButton.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
    }

    private func row(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

    private var summary: XCUIElement { app.staticTexts["transactions.resultSummary"] }

    @MainActor
    func testSearchByDescriptionAndAmount() {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))

        search.tap()
        search.typeText("taxi")
        XCTAssertTrue(row("Taxi home").waitForExistence(timeout: 3))
        XCTAssertFalse(row("Lunch").exists)
        XCTAssertEqual(summary.label, "1 result · $30.00")

        // Search by amount.
        search.buttons["Clear text"].tap()
        search.typeText("12.5")
        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3))
        XCTAssertFalse(row("Coffee").exists)

        // Nothing matches → "No matches" with a way out.
        search.buttons["Clear text"].tap()
        search.typeText("zzz")
        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 3))
        app.buttons["transactions.noMatches.clear"].tap()
        XCTAssertTrue(row("Coffee").waitForExistence(timeout: 3))
    }

    @MainActor
    func testFilterByCategoryShowsChipAndTotals() {
        app.buttons["transactions.filterMenu"].tap()
        let food = app.buttons["Food"]
        XCTAssertTrue(food.waitForExistence(timeout: 3))
        food.tap()

        XCTAssertTrue(app.buttons["transactions.filter.category.Food"].waitForExistence(timeout: 3), "Food chip")
        XCTAssertEqual(summary.label, "2 results · $20.50")
        XCTAssertFalse(row("Taxi home").exists)

        // Removing the chip removes the filter.
        app.buttons["transactions.filter.category.Food"].tap()
        XCTAssertTrue(row("Taxi home").waitForExistence(timeout: 3))
        XCTAssertFalse(summary.exists)
    }

    @MainActor
    func testDateRangeFilter() {
        app.buttons["transactions.filterMenu"].tap()
        let lastMonth = app.buttons["Last month"]
        XCTAssertTrue(lastMonth.waitForExistence(timeout: 3))
        lastMonth.tap()

        // Everything was added today, so last month is empty.
        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 3))
        app.buttons["transactions.noMatches.clear"].tap()
        XCTAssertTrue(row("Lunch").waitForExistence(timeout: 3))
    }
}
