//
//  ReceiptParser.swift
//  SpendLite
//

import Foundation

/// What we could read off a receipt. Every field is optional: the form keeps whatever
/// the user already typed for anything we couldn't find.
struct ReceiptDraft: Equatable {
    var amount: Decimal?
    var merchant: String?
    var date: Date?
    var category: ExpenseCategory?

    var isEmpty: Bool { amount == nil && merchant == nil && date == nil }
}

/// Turns the text lines of a receipt (top to bottom) into a `ReceiptDraft`.
/// Plain text in, plain values out, so it's fully unit tested without images.
enum ReceiptParser {

    static func parse(lines rawLines: [String], now: Date = .now, calendar: Calendar = .current,
                      locale: Locale = .current) -> ReceiptDraft {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let merchant = findMerchant(in: lines)
        return ReceiptDraft(
            amount: findTotal(in: lines),
            merchant: merchant,
            date: findDate(in: lines, now: now, calendar: calendar, locale: locale),
            // The store name is the best hint; otherwise look at everything printed.
            category: merchant.flatMap { guessCategory(fromText: $0) } ?? guessCategory(fromText: lines.joined(separator: " "))
        )
    }

    // MARK: - Total

    /// Labels for the amount actually paid, strongest first.
    private static let totalLabels = ["grand total", "amount due", "balance due", "total due",
                                      "amount paid", "to pay", "total amount", "total"]
    /// Lines that mention "total" but aren't the final amount.
    private static let notTheTotal = ["subtotal", "sub total", "sub-total", "total tax", "tax total",
                                      "total savings", "total items", "total qty", "total discount", "item count"]

    static func findTotal(in lines: [String]) -> Decimal? {
        // 1. A line labelled as the total (or the line right after the label, for two-column receipts).
        for label in totalLabels {
            for (index, line) in lines.enumerated() {
                let lower = line.lowercased()
                guard lower.contains(label), !notTheTotal.contains(where: lower.contains) else { continue }
                if let amount = amounts(in: line).last { return amount }
                if index + 1 < lines.count, let next = amounts(in: lines[index + 1]).first { return next }
            }
        }
        // 2. Otherwise the biggest money amount on the receipt (the total is usually the largest).
        return lines
            .filter { line in !notTheTotal.contains(where: line.lowercased().contains) }
            .flatMap(amounts(in:))
            .max()
    }

    /// Money amounts in a line: "12.50", "$1,250.00", "€ 9,99", "TOTAL 45.00 USD".
    /// Requires two decimal places so quantities, phone numbers and dates aren't mistaken for prices.
    static func amounts(in line: String) -> [Decimal] {
        // Not preceded by a digit/separator, and not followed by more digits ("11.09.2026" is a date).
        let pattern = #"(?<![\d.,])(\d{1,3}(?:[.,\s]\d{3})*|\d+)[.,](\d{2})(?![.,]?\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let whole = Range(match.range(at: 1), in: line),
                  let cents = Range(match.range(at: 2), in: line) else { return nil }
            let digits = line[whole].filter(\.isNumber)
            return Decimal(string: "\(digits).\(line[cents])", locale: Locale(identifier: "en_US_POSIX"))
        }
    }

    // MARK: - Merchant

    /// The store name is usually one of the first lines, in words rather than numbers.
    static func findMerchant(in lines: [String]) -> String? {
        let skip = ["receipt", "invoice", "welcome", "tax invoice", "order", "table", "tel", "phone", "www.", "http"]
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            let letters = line.filter(\.isLetter).count
            let digits = line.filter(\.isNumber).count
            guard letters >= 3, digits <= letters / 2,
                  line.first?.isNumber == false,           // "4521 Market Street" is an address
                  !skip.contains(where: lower.hasPrefix),
                  amounts(in: line).isEmpty else { continue }
            return prettify(line)
        }
        return nil
    }

    /// "STARBUCKS COFFEE #1234" → "Starbucks Coffee"
    private static func prettify(_ line: String) -> String {
        let cleaned = line
            .replacingOccurrences(of: #"#\s*\d+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let isShouting = cleaned == cleaned.uppercased()
        return isShouting ? cleaned.capitalized : cleaned
    }

    // MARK: - Date

    /// The first date on the receipt that isn't in the future (allowing a day for time zones)
    /// and isn't more than a year old. Without a date, the form keeps "today".
    ///
    /// Handles the formats receipts print: 11/09/2026, 11-09-26, 2026-11-09, 09.11.2026,
    /// "Nov 9, 2026" and "9 Nov 2026". For 11/09/2026 the region decides (US: month first);
    /// a first number above 12 must be the day.
    static func findDate(in lines: [String], now: Date, calendar: Calendar, locale: Locale = .current) -> Date? {
        let earliest = calendar.date(byAdding: .year, value: -1, to: now)!
        let latest = calendar.date(byAdding: .day, value: 1, to: now)!
        for line in lines {
            for date in dates(in: line, calendar: calendar, locale: locale) where date >= earliest && date <= latest {
                return date
            }
        }
        return nil
    }

    static func dates(in line: String, calendar: Calendar, locale: Locale) -> [Date] {
        var found: [(position: Int, date: Date)] = []

        func add(_ match: NSTextCheckingResult, year: Int, month: Int, day: Int) {
            let fullYear = year < 100 ? 2000 + year : year
            var parts = DateComponents(year: fullYear, month: month, day: day, hour: 12)
            parts.calendar = calendar
            guard parts.isValidDate(in: calendar), let date = calendar.date(from: parts) else { return }
            found.append((match.range.location, date))
        }

        func matches(_ pattern: String) -> [(NSTextCheckingResult, [String])] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
            let ns = line as NSString
            return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).map { match in
                (match, (1..<match.numberOfRanges).map { ns.substring(with: match.range(at: $0)) })
            }
        }

        // 2026-11-09
        for (match, g) in matches(#"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"#) {
            add(match, year: Int(g[0])!, month: Int(g[1])!, day: Int(g[2])!)
        }
        // 11/09/2026, 11-09-26, 09.11.2026
        let monthFirst = Self.prefersMonthFirst(locale)
        for (match, g) in matches(#"(?<!\d)(\d{1,2})([/.-])(\d{1,2})\2(\d{4}|\d{2})(?!\d)"#) {
            let a = Int(g[0])!, b = Int(g[2])!, year = Int(g[3])!
            let dayFirst = g[1] == "." || a > 12 || !monthFirst
            add(match, year: year, month: dayFirst ? b : a, day: dayFirst ? a : b)
        }
        // Nov 9, 2026  /  9 Nov 2026
        let months = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?"
        for (match, g) in matches("\\b\(months)\\s+(\\d{1,2}),?\\s+(\\d{4})") {
            if let month = Self.monthNumber(g[0]) { add(match, year: Int(g[2])!, month: month, day: Int(g[1])!) }
        }
        for (match, g) in matches("\\b(\\d{1,2})\\s+\(months),?\\s+(\\d{4})") {
            if let month = Self.monthNumber(g[1]) { add(match, year: Int(g[2])!, month: month, day: Int(g[0])!) }
        }
        return found.sorted { $0.position < $1.position }.map(\.date)
    }

    private static func monthNumber(_ name: String) -> Int? {
        let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return names.firstIndex(of: String(name.lowercased().prefix(3))).map { $0 + 1 }
    }

    /// True where dates are written month first (e.g. the US).
    private static func prefersMonthFirst(_ locale: Locale) -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "MMdd", options: 0, locale: locale) ?? "MM/dd"
        guard let month = format.range(of: "M"), let day = format.range(of: "d") else { return true }
        return month.lowerBound < day.lowerBound
    }

    // MARK: - Category

    private static let categoryKeywords: [(ExpenseCategory, [String])] = [
        (.food, ["starbucks", "coffee", "cafe", "café", "restaurant", "pizza", "burger", "bakery", "grocery",
                 "market", "supermarket", "deli", "kitchen", "mcdonald", "subway", "kfc", "chipotle",
                 "whole foods", "trader joe", "kroger", "safeway", "tesco", "aldi", "lidl"]),
        (.transport, ["uber", "lyft", "taxi", "shell", "chevron", "exxon", "bp ", "fuel", "gas station",
                      "parking", "metro", "transit", "airline", "airways"]),
        (.health, ["pharmacy", "cvs", "walgreens", "boots", "clinic", "dental", "hospital", "optical"]),
        (.shopping, ["target", "walmart", "amazon", "ikea", "zara", "h&m", "uniqlo", "best buy", "mall", "store"]),
        (.fun, ["cinema", "movie", "theatre", "theater", "netflix", "spotify", "steam", "concert", "bowling"]),
        (.education, ["bookstore", "books", "university", "college", "school", "course"]),
        (.home, ["hardware", "home depot", "lowe's", "electric", "utility", "water bill", "rent"]),
    ]

    static func guessCategory(fromText text: String) -> ExpenseCategory? {
        let lower = " " + text.lowercased() + " "
        return categoryKeywords.first { _, words in words.contains(where: lower.contains) }?.0
    }
}
