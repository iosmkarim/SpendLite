//
//  WidgetLinkUITests.swift
//  SpendLiteUITests
//

import XCTest

/// The widget's links: spendlite://add opens the Add Expense form, spendlite://home opens Home.
final class WidgetLinkUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Settings"].tap() // start somewhere other than Home
    }

    /// Opens a link the way the system does; accepts iOS's "Open in SpendLite?" prompt if shown
    /// (it appears for links opened from outside, not for taps on the widget itself).
    private func open(_ link: String) {
        XCUIDevice.shared.system.open(URL(string: link)!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 3) { openButton.tap() }
    }

    @MainActor
    func testAddLinkOpensTheAddForm() {
        open("spendlite://add")
        XCTAssertTrue(app.navigationBars["Add Expense"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Enter amount"].exists)
    }

    @MainActor
    func testHomeLinkOpensHome() {
        open("spendlite://home")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        let homeSelected = NSPredicate(format: "isSelected == true")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: homeSelected, object: app.tabBars.buttons["Home"])], timeout: 5), .completed)
        XCTAssertFalse(app.navigationBars["Add Expense"].exists)
    }
}
