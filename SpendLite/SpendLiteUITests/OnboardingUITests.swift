//
//  OnboardingUITests.swift
//  SpendLiteUITests
//

import XCTest

/// First launch: welcome → budget → start.
final class OnboardingUITests: XCTestCase {

    private func launch(_ extra: [String] = ["-ui-testing-onboarding"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testSetBudgetAndStart() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to SpendLite"].waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()

        XCTAssertTrue(app.staticTexts["What's your monthly budget?"].waitForExistence(timeout: 3))
        app.buttons["$3,000"].tap()
        app.buttons["onboarding.continue"].tap()

        XCTAssertTrue(app.staticTexts["You're all set"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your monthly budget is $3,000.00."].exists)
        app.buttons["onboarding.start"].tap()

        // Home, empty, with the chosen budget.
        XCTAssertTrue(app.buttons["Add sample data"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["onboarding"].exists)
    }

    @MainActor
    func testExploreWithSampleData() {
        let app = launch()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.sample"].tap()

        XCTAssertTrue(app.buttons["home.quickAction.insights"].waitForExistence(timeout: 5))
        // Home's recent rows aren't buttons, so match any element.
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Morning coffee,'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCantContinueWithEmptyBudget() {
        let app = launch()
        app.buttons["onboarding.continue"].tap()
        let field = app.textFields["onboarding.budget"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)
    }

    @MainActor
    func testShowAgainFromSettings() {
        let app = launch([]) // starts already onboarded
        app.tabBars.buttons["Settings"].tap()
        let row = app.buttons["settings.showOnboarding"]
        for _ in 0..<3 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.staticTexts["Welcome to SpendLite"].waitForExistence(timeout: 5))
    }
}
