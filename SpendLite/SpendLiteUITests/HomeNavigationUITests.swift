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
        // Fresh in-memory data each run; never touches the real app data.
        app.launchArguments += ["-ui-testing"]
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
    func testSeeAllOpensTransactionsTab() {
        app.buttons["See All"].tap()

        let transactionsTab = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 3), "Tab bar should still be visible")
        XCTAssertTrue(transactionsTab.isSelected)
    }

    @MainActor
    func testTabBarHasNoSeparateAddTab() {
        let labels = app.tabBars.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(labels, ["Home", "Transactions", "Insights", "Settings"])
    }
}
