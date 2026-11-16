//
//  ExpensesCSV.swift
//  SpendLite
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Expenses as a CSV file for Settings → Export (opens in Numbers, Excel, Google Sheets).
struct ExpensesCSV: Transferable {
    let expenses: [ExpenseItem]
    let currencyCode: String
    var now: Date = .now

    /// "SpendLite-expenses-2026-11-09.csv"
    var fileName: String {
        "SpendLite-expenses-\(now.formatted(.iso8601.year().month().day())).csv"
    }

    /// Oldest first, one row per expense. Amounts use "." and no grouping so any
    /// spreadsheet reads them as numbers regardless of the user's region.
    var text: String {
        var lines = ["Date,Description,Category,Amount,Currency"]
        for item in expenses.sorted(by: { $0.date < $1.date }) {
            lines.append([
                Self.dateFormatter.string(from: item.date),
                Self.escape(item.title),
                Self.escape(item.categoryKind.name),
                item.amount.formatted(.number.grouping(.never).precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX"))),
                currencyCode,
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Makes a text field safe for a spreadsheet:
    /// - A field starting with `=`, `+`, `-`, `@`, tab or carriage return gets a leading `'`,
    ///   so Excel / Numbers show it as text instead of running it as a formula
    ///   (e.g. a description like `=HYPERLINK(...)` typed in or read from a receipt).
    /// - Quotes the field if it contains a comma, quote or line break, doubling any quotes inside.
    static func escape(_ field: String) -> String {
        var field = field
        if let first = field.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
            field = "'" + field
        }
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Exports are written here and removed before the next export and at launch,
    /// so copies of the user's spending don't pile up in temporary storage.
    static var exportFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    static func removeOldExports() {
        try? FileManager.default.removeItem(at: exportFolder)
    }

    /// "2026-11-09 14:05" in the user's time zone (what they'd expect to see).
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            removeOldExports()
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            let url = exportFolder.appendingPathComponent(csv.fileName)
            try csv.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
