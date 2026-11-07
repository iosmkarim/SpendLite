//
//  AppColors.swift
//  SpendLite
//

import SwiftUI
import UIKit

/// App colour palette. Every colour has a light and a dark version, so screens
/// stay readable in Dark Mode (a fixed cream background with white text was unreadable).
extension Color {
    /// Page background: soft cream in light mode, warm near-black in dark mode.
    static let appBackground = Color(light: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1),
                                     dark: UIColor(red: 0.07, green: 0.065, blue: 0.06, alpha: 1))

    /// Cards sitting on the page background: white / dark grey.
    static let cardBackground = Color(light: .white,
                                      dark: UIColor(red: 0.13, green: 0.125, blue: 0.12, alpha: 1))

    /// Inset areas inside a card (e.g. the "Total Spent" pill): light grey / lighter dark grey.
    static let insetBackground = Color(light: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1),
                                       dark: UIColor(red: 0.20, green: 0.19, blue: 0.18, alpha: 1))

    /// Card border: subtle in both modes.
    static let cardBorder = Color(light: UIColor.separator.withAlphaComponent(0.35),
                                  dark: UIColor.white.withAlphaComponent(0.08))

    /// Soft drop shadow in light mode; shadows don't read on dark backgrounds, so none there.
    static let cardShadow = Color(light: UIColor.black.withAlphaComponent(0.04),
                                  dark: .clear)

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    /// The standard card look used across Home and Insights.
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .shadow(color: .cardShadow, radius: 10, x: 0, y: 6)
    }
}
