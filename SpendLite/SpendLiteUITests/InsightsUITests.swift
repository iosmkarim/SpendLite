//
//  InsightsUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Insights shows real data, and tapping a category opens Transactions filtered to it.
final class InsightsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] // fresh in-memory data each run
        app.launch()
    }

    private func addExpense(amount: String, description: String, category: String) {
        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.add"].tap()
        let amountField = app.textFields["Enter amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText(amount)
        let descriptionField = app.textViews.firstMatch
        descriptionField.tap()
        descriptionField.typeText(description)
        app.navigationBars["Add Expense"].staticTexts["Add Expense"].tap() // move focus off the keyboard
        let categoryButton = app.buttons[category]
        if !categoryButton.isHittable { app.swipeUp() }
        categoryButton.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testEmptyStateWhenNothingSpent() {
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["No spending yet"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testShowsRealTotalAndCategoryOpensFilteredTransactions() {
        addExpense(amount: "12.50", description: "Lunch", category: "Food")
        addExpense(amount: "30", description: "Taxi", category: "Transport")

        app.tabBars.buttons["Insights"].tap()
        let total = app.staticTexts["insights.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertEqual(total.label, "$42.50", "Insights must show the real total, not placeholder numbers")

        // Tap Transport (the biggest category) → Transactions, filtered.
        let transport = app.buttons["insights.category.Transport"]
        if !transport.isHittable { app.swipeUp() }
        transport.tap()

        XCTAssertTrue(app.tabBars.buttons["Transactions"].isSelected)
        let clearFilter = app.buttons["transactions.filter.clear"]
        XCTAssertTrue(clearFilter.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Taxi,'")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lunch,'")).firstMatch.exists,
                       "Other categories should be hidden while filtered")

        // Clearing the filter shows everything again.
        clearFilter.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lunch,'")).firstMatch.waitForExistence(timeout: 3))
    }
}
