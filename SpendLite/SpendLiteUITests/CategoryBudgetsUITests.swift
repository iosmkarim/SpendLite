//
//  CategoryBudgetsUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Settings → Category budgets, and the limit showing up in Insights.
final class CategoryBudgetsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        // Home's sample data: one $5.40 coffee (Food).
        let addSample = app.buttons["Add sample data"]
        if addSample.waitForExistence(timeout: 3) { addSample.tap() }
        XCTAssertTrue(app.buttons["home.quickAction.insights"].waitForExistence(timeout: 5))
    }

    private func waitFor(_ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func setLimit(_ category: String, _ amount: String) {
        app.buttons["categoryBudget.\(category)"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + amount)
        app.alerts.buttons["Save"].tap()
    }

    @MainActor
    func testSetALimitAndSeeItInInsights() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.categoryBudgets"].tap()
        XCTAssertTrue(app.navigationBars["Category budgets"].waitForExistence(timeout: 3))

        let food = app.buttons["categoryBudget.Food"]
        XCTAssertTrue(food.label.contains("No limit"))

        setLimit("Food", "5")  // $5.40 spent → 40¢ over
        XCTAssertTrue(waitFor(food, "label CONTAINS 'of $5.00' AND label CONTAINS '$0.40 over'"), "Got: \(food.label)")

        let summary = app.descendants(matching: .any)["categoryBudgets.summary"]
        XCTAssertTrue(waitFor(summary, "label CONTAINS '$5.00'"))

        // Insights (This month) compares Food with its limit.
        app.tabBars.buttons["Insights"].tap()
        let insightsFood = app.buttons["insights.category.Food"]
        for _ in 0..<3 where !insightsFood.isHittable { app.swipeUp() }
        XCTAssertTrue(waitFor(insightsFood, "label CONTAINS 'of $5' AND label CONTAINS '108% of its limit'"), "Got: \(insightsFood.label)")
    }

    @MainActor
    func testRemoveALimit() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.categoryBudgets"].tap()
        setLimit("Fun", "100")
        let fun = app.buttons["categoryBudget.Fun"]
        XCTAssertTrue(waitFor(fun, "label CONTAINS 'left'"))

        fun.tap()
        app.alerts.buttons["Remove Limit"].tap()
        XCTAssertTrue(waitFor(fun, "label CONTAINS 'No limit'"))
    }
}
