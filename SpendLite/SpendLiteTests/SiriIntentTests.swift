//
//  SiriIntentTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

/// The logic behind "Add an expense in SpendLite" and "How much is left in SpendLite".
@MainActor
struct SiriIntentTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// In-memory container with a $1,000 budget, at Nov 14 2026.
    private func makeHandler(budget: Double = 1000) -> ExpenseIntentHandler {
        let container = AppContainer(inMemory: true)
        container.budget.setMonthlyBudget(budget)
        return ExpenseIntentHandler(container: container, now: { self.date(2026, 11, 14) }, calendar: calendar)
    }

    // MARK: - Add expense

    @Test func addsTheExpenseWithDescriptionAndCategory() async throws {
        let handler = makeHandler()
        let item = try await handler.addExpense(amount: 5.4, description: "  Coffee  ", category: .food)

        let saved = await handler.container.expenses.expensesPublisher.firstValue()
        #expect(saved == [item])
        #expect(item.title == "Coffee")
        #expect(item.category == "Food")
        #expect(item.date == date(2026, 11, 14))
    }

    @Test func noDescriptionOrCategoryUsesOther() async throws {
        let item = try await makeHandler().addExpense(amount: 12, description: nil, category: nil)
        #expect(item.title == "Other")
        #expect(item.categoryKind == .other)
    }

    @Test(arguments: [0.0, -5.0, Double.infinity, Double.nan])
    func rejectsInvalidAmounts(amount: Double) async {
        let handler = makeHandler()
        await #expect(throws: ExpenseIntentHandler.IntentError.invalidAmount) {
            try await handler.addExpense(amount: amount, description: "x", category: .food)
        }
        #expect(await handler.container.expenses.expensesPublisher.firstValue().isEmpty)
    }

    @Test func confirmationSaysWhatWasAddedAndWhatsLeft() async throws {
        let handler = makeHandler()
        let coffee = try await handler.addExpense(amount: 5.4, description: "Coffee", category: .food)
        let message = await handler.confirmation(for: coffee)
        #expect(message == "Added \(5.4.asCurrency()) for Coffee to Food. \(994.6.asCurrency()) left this month.")

        // No description: don't repeat the category ("for Other to Other").
        let plain = try await handler.addExpense(amount: 10, description: nil, category: nil)
        #expect(await handler.confirmation(for: plain).hasPrefix("Added \(10.0.asCurrency()) to Other."))
    }

    @Test func confirmationWhenOverBudget() async throws {
        let handler = makeHandler(budget: 50)
        let item = try await handler.addExpense(amount: 80, description: "Shoes", category: .shopping)
        #expect(await handler.confirmation(for: item).hasSuffix("You're \(30.0.asCurrency()) over budget this month."))
    }

    // MARK: - Budget left

    @Test func budgetReplyOnTrack() async throws {
        let handler = makeHandler()
        try await handler.addExpense(amount: 200, description: "Groceries", category: .food)

        let reply = await handler.budgetReply()
        #expect(reply.remaining == 800)
        #expect(reply.spent == 200)
        #expect(reply.status == .onTrack)
        #expect(reply.sentence == "You have \(800.0.asCurrency()) left of your \(1000.0.asCurrency()) November budget.")
    }

    @Test func budgetReplyNearLimitAndOver() async throws {
        let handler = makeHandler()
        try await handler.addExpense(amount: 850, description: "Rent", category: .home)
        let near = await handler.budgetReply()
        #expect(near.status == .nearLimit)
        #expect(near.sentence.contains("85% spent"))

        try await handler.addExpense(amount: 300, description: "Flight", category: .transport)
        let over = await handler.budgetReply()
        #expect(over.status == .overBudget)
        #expect(over.sentence == "You're \(150.0.asCurrency()) over your \(1000.0.asCurrency()) November budget.")
    }

    @Test func budgetReplyIgnoresLastMonth() async throws {
        let handler = makeHandler()
        let old = ExpenseItem(id: UUID(), date: date(2026, 10, 20), title: "Old", amount: 400, category: "Food")
        try await handler.container.expenses.addExpense(old).firstValue()
        #expect(await handler.budgetReply().remaining == 1000)
    }

    @Test func budgetReplyIncludesRecurringThatCameDue() async throws {
        let handler = makeHandler()
        let rent = RecurringExpense(title: "Rent", amount: 600, category: "Home", frequency: .monthly,
                                    // 6am, so a daylight-saving change can't push "a month later" past noon.
                                    startDate: date(2026, 10, 14, 6), occurrencesGenerated: 1)
        // Saved as if the app last ran in October; November's rent is due but not added yet.
        try await handler.container.recurring.add(rent, now: date(2026, 10, 14)).firstValue()

        let reply = await handler.budgetReply()
        #expect(reply.spent == 600) // November's rent was added before answering
    }
}
