//
//  TransactionFilter.swift
//  SpendLite
//

import Foundation

/// What the Transactions list is narrowed to: search text, categories and a date range.
/// Pure value + matching logic, so it's unit tested without any UI.
struct TransactionFilter: Equatable {

    enum DateRange: String, CaseIterable, Identifiable {
        case allTime, thisMonth, lastMonth, last3Months, thisYear

        var id: String { rawValue }

        var title: String {
            switch self {
            case .allTime: "All time"
            case .thisMonth: "This month"
            case .lastMonth: "Last month"
            case .last3Months: "Last 3 months"
            case .thisYear: "This year"
            }
        }

        /// The dates included (`start` inclusive, `end` exclusive), or nil for all time.
        func interval(now: Date, calendar: Calendar) -> DateInterval? {
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            switch self {
            case .allTime:
                return nil
            case .thisMonth:
                return DateInterval(start: startOfMonth, end: endOfMonth)
            case .lastMonth:
                return DateInterval(start: calendar.date(byAdding: .month, value: -1, to: startOfMonth)!, end: startOfMonth)
            case .last3Months:
                return DateInterval(start: calendar.date(byAdding: .month, value: -2, to: startOfMonth)!, end: endOfMonth)
            case .thisYear:
                let year = calendar.dateInterval(of: .year, for: now)!
                return year
            }
        }
    }

    var searchText = ""
    /// Empty means every category.
    var categories: Set<ExpenseCategory> = []
    var dateRange: DateRange = .allTime

    /// Categories or a date range are set (shown as chips; the filter button looks "on").
    var hasFilters: Bool { !categories.isEmpty || dateRange != .allTime }

    /// Anything at all narrows the list, including search.
    var isActive: Bool { hasFilters || !trimmedSearch.isEmpty }

    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    func matches(_ item: ExpenseItem, now: Date = .now, calendar: Calendar = .current) -> Bool {
        if !categories.isEmpty, !categories.contains(item.categoryKind) { return false }
        if let interval = dateRange.interval(now: now, calendar: calendar),
           !(item.date >= interval.start && item.date < interval.end) {
            return false
        }
        return matchesSearch(item)
    }

    /// Every word typed must appear in the description, the category name or the amount.
    /// Ignores case and accents ("cafe" finds "Café"); "5.40", "5,40" and "5.4" all find $5.40.
    private func matchesSearch(_ item: ExpenseItem) -> Bool {
        let words = trimmedSearch.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }

        let amount = item.amount.formatted(
            .number.grouping(.never).precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX"))
        )
        let haystack = [item.title, item.categoryKind.name]

        return words.allSatisfy { word in
            if haystack.contains(where: { $0.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil }) {
                return true
            }
            // Amount search: accept a comma as the decimal separator and ignore a currency symbol.
            let number = word.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
            guard number.contains(where: \.isNumber) else { return false }
            if number.contains(".") {
                return amount.hasPrefix(number)            // "5.4" / "5.40" → $5.40
            }
            return amount.split(separator: ".").first.map(String.init) == number // "12" → $12.xx, not $125
        }
    }
}
