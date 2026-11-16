//
//  ReceiptScanUITests.swift
//  SpendLiteUITests
//

import XCTest

/// Scan a receipt → the form fills itself in → save. Uses the built-in sample receipt image
/// (UI tests only) because the simulator has no camera; the text recognition is real.
final class ReceiptScanUITests: XCTestCase {

    @MainActor
    func testScanningFillsTheFormAndSaves() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-ui-testing-pro"] // receipt scan is a Pro feature
        app.launch()

        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.add"].tap()

        let scan = app.buttons["addExpense.scanReceipt"]
        XCTAssertTrue(scan.waitForExistence(timeout: 3))
        scan.tap()
        app.buttons["Use Sample Receipt"].tap()

        // Filled in from the receipt.
        let amount = app.textFields["Enter amount"]
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '11.42'"), object: amount)
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 10), .completed, "Got: \(String(describing: amount.value))")
        XCTAssertEqual(app.textViews.firstMatch.value as? String, "Blue Bottle Coffee")
        XCTAssertTrue(app.staticTexts["addExpense.receiptMessage"].label.contains("Check the amount"))
        XCTAssertTrue(app.buttons["Food"].isSelected || app.buttons["Food"].exists)

        app.navigationBars.buttons["Save"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blue Bottle Coffee, Food,'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains("$11.42"))
    }

    @MainActor
    func testScanIsNotOfferedWhenEditing() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-ui-testing-pro"] // receipt scan is a Pro feature
        app.launch()
        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.add"].tap()
        let amount = app.textFields["Enter amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText("3")
        app.navigationBars.buttons["Save"].tap()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Other,'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Expense"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["addExpense.scanReceipt"].exists)
    }
}
