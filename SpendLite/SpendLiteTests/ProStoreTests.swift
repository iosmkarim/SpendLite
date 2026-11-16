//
//  ProStoreTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import StoreKitTest
@testable import SpendLite

/// SpendLite Pro with the real StoreKit 2 code, against a local test App Store
/// (SpendLite.storekit). Serialized: the test store is shared.
@MainActor
@Suite(.serialized)
struct ProStoreStoreKitTests {

    private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "test.\(UUID().uuidString)")! }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "SpendLite")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        return session
    }

    /// StoreKit applies refunds and approvals asynchronously; re-check until it settles.
    private func waitForPro(_ store: ProStore, toBe expected: Bool, timeout: Duration = .seconds(5)) async {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            await store.refresh()
            if store.isPro == expected { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(store.isPro == expected, "Pro should become \(expected)")
    }

    @Test func loadsThePriceAndStartsLocked() async throws {
        _ = try makeSession()
        let store = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())
        await store.refresh()
        #expect(store.price == "$4.99")
        #expect(!store.isPro)
    }

    @Test func buyingUnlocksPro() async throws {
        let session = try makeSession()
        let store = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())
        await store.buy()
        #expect(store.isPro)
        #expect(store.message == nil)
        #expect(session.allTransactions().count == 1)
    }

    @Test func refundLocksItAgain() async throws {
        let session = try makeSession()
        let store = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())
        await store.buy()
        #expect(store.isPro)

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        await waitForPro(store, toBe: false)
    }

    @Test func askToBuyWaitsForApproval() async throws {
        let session = try makeSession()
        session.askToBuyEnabled = true
        let store = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())

        await store.buy()
        #expect(!store.isPro)
        #expect(store.message?.contains("waiting for approval") == true)

        let pending = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: UInt(pending.identifier))
        await waitForPro(store, toBe: true)
    }

    @Test func restoreFindsAnEarlierPurchase() async throws {
        _ = try makeSession()
        let first = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())
        await first.buy()

        // A fresh install (nothing cached) restores it.
        let reinstalled = ProStore(service: StoreKitPurchaseService(), defaults: freshDefaults())
        #expect(!reinstalled.isPro)
        await reinstalled.restore()
        #expect(reinstalled.isPro)
    }
}

/// Pro rules that don't need the App Store.
@MainActor
struct ProStoreTests {

    private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "test.\(UUID().uuidString)")! }

    @Test func freeUsersGetThreeRecurringExpenses() {
        let free = ProStore(service: FakePurchaseService(), defaults: freshDefaults())
        #expect(!free.recurringLimitReached(currentCount: 2))
        #expect(free.recurringLimitReached(currentCount: 3))

        let defaults = freshDefaults()
        defaults.set(true, forKey: ProStore.cachedKey)
        let pro = ProStore(service: FakePurchaseService(owns: true), defaults: defaults)
        #expect(!pro.recurringLimitReached(currentCount: 50))
    }

    @Test func rememberedSoProDoesntFlashLockedAtLaunch() async {
        let defaults = freshDefaults()
        let first = ProStore(service: FakePurchaseService(), defaults: defaults)
        await first.buy()
        #expect(defaults.bool(forKey: ProStore.cachedKey))

        let nextLaunch = ProStore(service: FakePurchaseService(owns: true), defaults: defaults)
        #expect(nextLaunch.isPro) // before any App Store check
    }

    @Test func cancelledPurchaseChangesNothing() async {
        let store = ProStore(service: FakePurchaseService(outcome: .cancelled), defaults: freshDefaults())
        await store.buy()
        #expect(!store.isPro)
        #expect(store.message == nil)
    }

    @Test func restoreWithNothingToRestoreSaysSo() async {
        let store = ProStore(service: FakePurchaseService(owns: false), defaults: freshDefaults())
        await store.restore()
        #expect(!store.isPro)
        #expect(store.message == "No SpendLite Pro purchase was found for this Apple Account.")
    }

    @Test func buyingUpdatesTheWidget() async {
        let defaults = freshDefaults()
        let sync = WidgetSync(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)),
                              budget: UserDefaultsBudgetRepository(defaults: defaults),
                              defaults: defaults, debounce: .milliseconds(1), reloadWidget: {})
        let store = ProStore(service: FakePurchaseService(), defaults: defaults)
        store.onChange = { sync.isPro = $0 }

        let deadline = ContinuousClock.now + .seconds(2)
        while WidgetSnapshotStore.load(from: defaults) == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(WidgetSnapshotStore.load(from: defaults)?.hasPro == false)

        await store.buy()
        #expect(WidgetSnapshotStore.load(from: defaults)?.hasPro == true)
    }

    @Test func snapshotsFromBeforeProStillLoad() throws {
        // Written by an older version: no "isPro" key.
        let old = #"{"monthStart":0,"monthlyBudget":2000,"spentThisMonth":10,"currencyCode":"USD","recent":[],"updatedAt":0}"#
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(old.utf8))
        #expect(!snapshot.hasPro)
        #expect(snapshot.monthlyBudget == 2000)
    }

    @Test func proLinkOpensThePaywall() {
        let nav = NavCoordinator()
        nav.handle(URL(string: "spendlite://pro")!)
        #expect(nav.showPaywall)
    }
}
