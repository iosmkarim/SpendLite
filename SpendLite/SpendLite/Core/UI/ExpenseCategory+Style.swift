//
//  ExpenseCategory+Style.swift
//  SpendLite
//

import SwiftUI

/// Icon and colour for each category, shared by the Add form, Home, Transactions and (later) Insights.
extension ExpenseCategory {
    var systemImage: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .fun: return "gamecontroller.fill"
        case .shopping: return "bag.fill"
        case .home: return "house.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .green
        case .transport: return .blue
        case .fun: return .pink
        case .shopping: return .orange
        case .home: return .purple
        case .health: return .red
        case .education: return .indigo
        case .other: return .gray
        }
    }
}
