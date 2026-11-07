//
//  HomeNavigationUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Checks Home's shortcuts switch to the real tabs (F3) and the tab bar stays visible (F4).
final class HomeNavigationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Quick actions only show when there's data; add a sample if Home is empty.
        let addSample = app.buttons["Add sample data"]
        if addSample.waitForExistence(timeout: 2) {
            addSample.tap()
        }
        XCTAssertTrue(app.buttons["home.quickAction.insights"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testViewInsightsOpensInsightsTab() {
        app.buttons["home.quickAction.insights"].tap()

        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 3), "Tab bar should still be visible")
        XCTAssertTrue(insightsTab.isSelected)
    }

    @MainActor
    func testSeeAllOpensHistoryTab() {
        app.buttons["See All"].tap()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 3), "Tab bar should still be visible")
        XCTAssertTrue(historyTab.isSelected)
    }

    @MainActor
    func testAddTabSaveReturnsHomeWithoutCancelButton() {
        app.tabBars.buttons["Add"].tap()
        XCTAssertFalse(app.navigationBars.buttons["Cancel"].exists, "Cancel makes no sense inside a tab")

        let amount = app.textFields["Enter amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText("7.25")
        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
    }
}
