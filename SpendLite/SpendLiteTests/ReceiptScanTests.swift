//
//  ReceiptScanTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import CoreGraphics
@testable import SpendLite

@MainActor
struct ReceiptScanTests {

    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12))! }

    private func day(of date: Date?) -> DateComponents? {
        date.map { calendar.dateComponents([.year, .month, .day], from: $0) }
    }

    // MARK: - Total

    @Test func picksTheTotalNotSubtotalOrTax() {
        let lines = ["Subtotal 10.50", "Tax 0.92", "TOTAL 11.42", "Cash 20.00", "Change 8.58"]
        #expect(ReceiptParser.findTotal(in: lines) == Decimal(string: "11.42"))
    }

    @Test func preferredLabelsWin() {
        let lines = ["Total 40.00", "Tip 8.00", "Amount due 48.00"]
        #expect(ReceiptParser.findTotal(in: lines) == 48)
    }

    @Test func totalOnTheNextLine() {
        // Two-column receipts often come out as the label, then the number on its own line.
        let lines = ["Items 3", "TOTAL", "$27.80", "VISA ****1234"]
        #expect(ReceiptParser.findTotal(in: lines) == Decimal(string: "27.80"))
    }

    @Test func noLabelFallsBackToTheLargestAmount() {
        let lines = ["Bread 3.20", "Milk 1.99", "54.10", "Eggs 4.50"]
        #expect(ReceiptParser.findTotal(in: lines) == Decimal(string: "54.10"))
    }

    @Test(arguments: [
        ("TOTAL $1,250.00", "1250.00"),
        ("Total: 9,99 €", "9.99"),        // European decimal comma
        ("Grand Total 1.234,56", "1234.56"),
        ("TOTAL 45.00 USD", "45.00"),
    ])
    func amountFormats(line: String, expected: String) {
        #expect(ReceiptParser.findTotal(in: [line]) == Decimal(string: expected))
    }

    @Test func datesPhonesAndQuantitiesAreNotPrices() {
        #expect(ReceiptParser.amounts(in: "11.09.2026").isEmpty)
        #expect(ReceiptParser.amounts(in: "Tel 415-555-0199").isEmpty)
        #expect(ReceiptParser.amounts(in: "Qty 2").isEmpty)
        #expect(ReceiptParser.amounts(in: "2 x Latte 5.50") == [Decimal(string: "5.50")!])
    }

    @Test func nothingFound() {
        #expect(ReceiptParser.findTotal(in: ["Thank you", "Have a nice day"]) == nil)
    }

    // MARK: - Merchant

    @Test(arguments: [
        (["STARBUCKS COFFEE #1234", "123 Main St"], "Starbucks Coffee"),
        (["RECEIPT", "Joe's Pizza", "Tel 555 0101"], "Joe's Pizza"),
        (["4521 Market Street", "Corner Deli"], "Corner Deli"),   // address line skipped
    ])
    func merchant(lines: [String], expected: String) {
        #expect(ReceiptParser.findMerchant(in: lines) == expected)
    }

    // MARK: - Date

    @Test func readsTheReceiptDate() {
        let date = ReceiptParser.findDate(in: ["Date: 11/09/2026 08:42"], now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(day(of: date) == DateComponents(year: 2026, month: 11, day: 9))
    }

    @Test func ignoresFutureAndVeryOldDates() {
        #expect(ReceiptParser.findDate(in: ["Valid until 12/31/2027"], now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == nil)
        #expect(ReceiptParser.findDate(in: ["Since 03/02/2019"], now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == nil)
    }

    @Test(arguments: [
        ("2026-11-09 14:05", 2026, 11, 9),
        ("09.11.2026", 2026, 11, 9),          // dots: day first
        ("25/10/2026", 2026, 10, 25),         // first number > 12: must be the day
        ("11-09-26", 2026, 11, 9),            // two-digit year, US month first
        ("Nov 9, 2026", 2026, 11, 9),
        ("9 November 2026", 2026, 11, 9),
    ])
    func dateFormats(text: String, year: Int, month: Int, day: Int) {
        let date = ReceiptParser.findDate(in: [text], now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(self.day(of: date) == DateComponents(year: year, month: month, day: day))
    }

    @Test func regionDecidesAmbiguousDates() {
        // 03/11/2026: March 11 in the US, 3 November in the UK.
        let us = ReceiptParser.findDate(in: ["03/11/2026"], now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        let uk = ReceiptParser.findDate(in: ["03/11/2026"], now: now, calendar: calendar, locale: Locale(identifier: "en_GB"))
        #expect(day(of: us) == DateComponents(year: 2026, month: 3, day: 11))
        #expect(day(of: uk) == DateComponents(year: 2026, month: 11, day: 3))
    }

    @Test func invalidDatesAreIgnored() {
        #expect(ReceiptParser.findDate(in: ["13/13/2026", "02/30/2026"], now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == nil)
    }

    // MARK: - Category

    @Test(arguments: [
        ("Starbucks Coffee", ExpenseCategory.food),
        ("Shell Station", .transport),
        ("CVS Pharmacy", .health),
        ("IKEA", .shopping),
        ("AMC Cinema", .fun),
        ("Unknown Ltd", nil),
    ] as [(String, ExpenseCategory?)])
    func category(merchant: String, expected: ExpenseCategory?) {
        #expect(ReceiptParser.guessCategory(fromText: merchant) == expected)
    }

    // MARK: - Whole receipt

    @Test func parsesAFullReceipt() {
        let draft = ReceiptParser.parse(lines: SampleReceipt.lines, now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(draft.amount == Decimal(string: "11.42"))
        #expect(draft.merchant == "Blue Bottle Coffee")
        #expect(draft.category == .food)
        #expect(day(of: draft.date) == DateComponents(year: 2026, month: 11, day: 9))
    }

    // MARK: - Text recognition (real Vision, on a rendered receipt image)

    @Test func recognisesTextOnTheSampleReceiptImage() async throws {
        let lines = try await ReceiptTextRecognizer.lines(in: SampleReceipt.image())
        let draft = ReceiptParser.parse(lines: lines, now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(draft.amount == Decimal(string: "11.42"), "OCR lines: \(lines)")
        #expect(draft.merchant?.lowercased() == "blue bottle coffee", "OCR lines: \(lines)")
        #expect(draft.category == .food)
    }

    @Test func rowsAreJoinedLeftToRightTopToBottom() {
        // Vision's y axis starts at the bottom: higher midY = nearer the top.
        let pieces: [(text: String, box: CGRect)] = [
            ("11.42", CGRect(x: 0.7, y: 0.20, width: 0.2, height: 0.04)),
            ("TOTAL", CGRect(x: 0.1, y: 0.205, width: 0.2, height: 0.04)),
            ("SHOP", CGRect(x: 0.1, y: 0.90, width: 0.3, height: 0.05)),
        ]
        #expect(ReceiptTextRecognizer.joinRows(pieces) == ["SHOP", "TOTAL 11.42"])
    }
}
