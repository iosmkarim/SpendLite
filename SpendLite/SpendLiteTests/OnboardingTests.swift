//
//  OnboardingTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct OnboardingTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    private func makeViewModel(defaults: UserDefaults) -> (OnboardingViewModel, UserDefaultsBudgetRepository, CoreDataExpenseRepository) {
        let budget = UserDefaultsBudgetRepository(defaults: defaults)
        let expenses = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        return (OnboardingViewModel(budget: budget, expenses: expenses, defaults: defaults), budget, expenses)
    }

    // MARK: - Who sees it

    @Test func newUsersSeeOnboarding() {
        let defaults = freshDefaults()
        Onboarding.skipForExistingUsers(defaults: defaults, hasExpenses: false)
        #expect(!Onboarding.hasCompleted(defaults: defaults))
    }

    @Test func existingUsersWithExpensesSkipIt() {
        let defaults = freshDefaults()
        Onboarding.skipForExistingUsers(defaults: defaults, hasExpenses: true)
        #expect(Onboarding.hasCompleted(defaults: defaults))
    }

    @Test func existingUsersWithABudgetSkipIt() {
        let defaults = freshDefaults()
        defaults.set(1500.0, forKey: UserDefaultsBudgetRepository.key)
        Onboarding.skipForExistingUsers(defaults: defaults, hasExpenses: false)
        #expect(Onboarding.hasCompleted(defaults: defaults))
    }

    @Test func showAgainFromSettingsIsRespected() {
        // "Show welcome screens" sets the flag to false explicitly; data must not override that.
        let defaults = freshDefaults()
        defaults.set(false, forKey: Onboarding.key)
        Onboarding.skipForExistingUsers(defaults: defaults, hasExpenses: true)
        #expect(!Onboarding.hasCompleted(defaults: defaults))
    }

    // MARK: - Steps and budget

    @Test func stepsMoveForwardAndBack() {
        let (vm, _, _) = makeViewModel(defaults: freshDefaults())
        #expect(vm.step == .welcome)
        vm.next(); #expect(vm.step == .budget)
        vm.next(); #expect(vm.step == .ready)
        vm.next(); #expect(vm.step == .ready) // stays on the last step
        vm.back(); #expect(vm.step == .budget)
    }

    @Test func cantContinueWithoutAValidBudget() {
        let (vm, _, _) = makeViewModel(defaults: freshDefaults())
        vm.next()
        #expect(vm.budgetValue == 2000) // pre-filled with the default
        for bad in ["", "0", "abc"] {
            vm.budgetText = bad
            #expect(!vm.canContinue)
        }
        vm.pick(3000)
        #expect(vm.budgetValue == 3000)
        #expect(vm.canContinue)
    }

    // MARK: - Finishing

    @Test func startSavesTheBudgetAndCompletes() async {
        let defaults = freshDefaults()
        let (vm, budget, expenses) = makeViewModel(defaults: defaults)
        vm.pick(3500)

        await withCheckedContinuation { done in vm.finish(withSampleData: false) { done.resume() } }

        #expect(Onboarding.hasCompleted(defaults: defaults))
        #expect(await budget.monthlyBudgetPublisher.firstValue() == 3500)
        #expect(await expenses.expensesPublisher.firstValue().isEmpty)
    }

    @Test func exploreAddsSampleExpenses() async {
        let defaults = freshDefaults()
        let (vm, _, expenses) = makeViewModel(defaults: defaults)

        await withCheckedContinuation { done in vm.finish(withSampleData: true) { done.resume() } }

        #expect(Onboarding.hasCompleted(defaults: defaults))
        let added = await expenses.expensesPublisher.firstValue()
        #expect(added.count == SampleExpenses.make().count)
        #expect(Set(added.map(\.title)).contains("Morning coffee"))
    }

    @Test func sampleExpensesAreRecentAndPositive() {
        let now = Date()
        let samples = SampleExpenses.make(now: now)
        #expect(samples.allSatisfy { $0.amount > 0 && $0.date <= now && $0.date > now.addingTimeInterval(-7 * 86_400) })
    }
}
