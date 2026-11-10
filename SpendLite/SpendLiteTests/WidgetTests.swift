//
//  WidgetTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct WidgetTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func item(_ title: String, _ amount: Double, on day: Date) -> ExpenseItem {
        ExpenseItem(id: UUID(), date: day, title: title, amount: amount, category: "Food")
    }

    private var now: Date { date(2026, 11, 10) }

    // MARK: - Building the snapshot

    @Test func snapshotHasThisMonthsTotalAndNewestThree() {
        let items = [
            item("Old", 500, on: date(2026, 10, 30)),     // last month: not in the total
            item("A", 10, on: date(2026, 11, 1)),
            item("B", 20, on: date(2026, 11, 5)),
            item("C", 30, on: date(2026, 11, 9)),
            item("D", 40, on: date(2026, 11, 10, 8)),
            item("Future rent", 900, on: date(2026, 11, 28)), // counts in the month, not in "recent"
        ]
        let snapshot = WidgetSync.makeSnapshot(expenses: items, monthlyBudget: 2000, currencyCode: "EUR",
                                               now: now, calendar: calendar)

        #expect(snapshot.spentThisMonth == 1000)            // 10+20+30+40+900, same as Home
        #expect(snapshot.monthlyBudget == 2000)
        #expect(snapshot.currencyCode == "EUR")
        #expect(snapshot.monthStart == date(2026, 11, 1, 0))
        #expect(snapshot.recent.map(\.title) == ["D", "C", "B"])
    }

    // MARK: - What the widget shows

    @Test func remainingProgressAndStatus() {
        var s = WidgetSync.makeSnapshot(expenses: [], monthlyBudget: 1000, currencyCode: "USD", now: now, calendar: calendar)
        s.spentThisMonth = 250
        #expect(s.remaining(asOf: now, calendar: calendar) == 750)
        #expect(s.progress(asOf: now, calendar: calendar) == 0.25)
        #expect(s.status(asOf: now, calendar: calendar) == .onTrack)

        s.spentThisMonth = 800
        #expect(s.status(asOf: now, calendar: calendar) == .nearLimit)

        s.spentThisMonth = 1200
        #expect(s.status(asOf: now, calendar: calendar) == .overBudget)
        #expect(s.remaining(asOf: now, calendar: calendar) == -200)
        #expect(s.progress(asOf: now, calendar: calendar) == 1) // ring capped
    }

    @Test func newMonthStartsFreshEvenIfTheAppWasntOpened() {
        var s = WidgetSync.makeSnapshot(expenses: [], monthlyBudget: 1000, currencyCode: "USD", now: now, calendar: calendar)
        s.spentThisMonth = 900
        let december = date(2026, 12, 1, 0)
        #expect(s.spent(asOf: december, calendar: calendar) == 0)
        #expect(s.remaining(asOf: december, calendar: calendar) == 1000)
        #expect(s.status(asOf: december, calendar: calendar) == .onTrack)
    }

    // MARK: - Storage

    @Test func snapshotRoundTripsThroughTheSharedStore() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        #expect(WidgetSnapshotStore.load(from: defaults) == nil)

        let snapshot = WidgetSync.makeSnapshot(expenses: [item("Coffee", 4.75, on: now)], monthlyBudget: 1500,
                                               currencyCode: "GBP", now: now, calendar: calendar)
        WidgetSnapshotStore.save(snapshot, to: defaults)
        #expect(WidgetSnapshotStore.load(from: defaults) == snapshot)
    }

    @Test func syncWritesAndReloadsWhenDataChanges() async throws {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let expenses = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let budget = UserDefaultsBudgetRepository(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        var reloads = 0
        let sync = WidgetSync(expenses: expenses, budget: budget, defaults: defaults,
                              now: { self.now }, calendar: calendar, debounce: .milliseconds(1),
                              reloadWidget: { reloads += 1 })

        await waitUntil { WidgetSnapshotStore.load(from: defaults) != nil }
        #expect(WidgetSnapshotStore.load(from: defaults)?.spentThisMonth == 0)

        var cancellable: AnyCancellable?
        await withCheckedContinuation { done in
            cancellable = expenses.addExpense(item("Lunch", 12.5, on: now))
                .sink(receiveCompletion: { _ in done.resume() }, receiveValue: { _ in })
        }
        await waitUntil { WidgetSnapshotStore.load(from: defaults)?.spentThisMonth == 12.5 }

        budget.setMonthlyBudget(800)
        await waitUntil { WidgetSnapshotStore.load(from: defaults)?.monthlyBudget == 800 }
        #expect(reloads >= 3)
        _ = (sync, cancellable)
    }

    // MARK: - Links from the widget

    @Test func widgetLinksOpenTheRightPlace() {
        let nav = NavCoordinator()
        nav.selectedTab = .settings
        nav.handle(URL(string: "spendlite://add")!)
        #expect(nav.selectedTab == .home)
        #expect(nav.addExpenseRequested)

        nav.addExpenseRequested = false
        nav.selectedTab = .insights
        nav.handle(URL(string: "spendlite://home")!)
        #expect(nav.selectedTab == .home)
        #expect(!nav.addExpenseRequested)

        nav.selectedTab = .insights
        nav.handle(URL(string: "https://example.com")!) // not ours: ignored
        #expect(nav.selectedTab == .insights)
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Timed out waiting for condition")
    }
}
