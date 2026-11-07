//
//  AppColors.swift
//  SpendLite
//

import SwiftUI
import UIKit

/// App colour palette, built on Apple's standard "grouped" system colours
/// (the look of Settings, Wallet, Health): a light grey page with white cards on top.
/// These adapt automatically to Dark Mode and Increase Contrast.
extension Color {
    /// Page background: light grey (#F2F2F7) / black.
    static let appBackground = Color(uiColor: .systemGroupedBackground)

    /// Cards sitting on the page: white / dark grey (#1C1C1E).
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// Inset areas inside a card (e.g. the "Total Spent" pill): light grey / lighter dark grey (#2C2C2E).
    static let insetBackground = Color(uiColor: .tertiarySystemGroupedBackground)

    /// Thin card edge. Light: a faint dark line. Dark: a faint light line, since
    /// shadows don't show on a black page and the edge is what separates the card.
    static let cardBorder = Color(light: UIColor.black.withAlphaComponent(0.05),
                                  dark: UIColor.white.withAlphaComponent(0.08))

    /// Shadows read in light mode only; in dark mode depth comes from the lighter card colour.
    static let cardShadowNear = Color(light: UIColor.black.withAlphaComponent(0.06), dark: .clear)
    static let cardShadowFar = Color(light: UIColor.black.withAlphaComponent(0.08), dark: .clear)

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    /// The standard raised card used across the app.
    ///
    /// Depth comes from two shadows, like a real object under soft light:
    /// a tight one where the card "touches" the page, and a wide, soft one below it.
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color.cardBackground, in: shape)
            .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
            .shadow(color: .cardShadowNear, radius: 2, x: 0, y: 1)
            .shadow(color: .cardShadowFar, radius: 14, x: 0, y: 8)
    }
}

/// For tappable cards: presses the card slightly into the page while touched,
/// so it feels like a physical button.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardButtonStyle {
    static var pressableCard: PressableCardButtonStyle { .init() }
}
