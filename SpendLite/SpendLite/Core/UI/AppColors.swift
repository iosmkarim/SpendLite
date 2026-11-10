//
//  AppColors.swift
//  SpendLite
//

import SwiftUI
import UIKit

/// "Indigo Dusk" palette: a clean white page, white tiles lifted by soft grey
/// shadows, and an indigo accent.
/// Every colour has a light and a dark version.
extension Color {
    // MARK: Brand

    /// Main accent (buttons, links, selected tab). Also set as the app's AccentColor asset.
    static let brand = Color(light: UIColor(hex: 0x5B4FE9), dark: UIColor(hex: 0x8F87FF))
    /// Hero gradient: indigo → violet.
    static let brandStart = Color(light: UIColor(hex: 0x5B4FE9), dark: UIColor(hex: 0x4F46D8))
    static let brandEnd = Color(light: UIColor(hex: 0x9B5CF6), dark: UIColor(hex: 0x8B4FE6))

    // MARK: Surfaces

    /// Page background: clean white / deep indigo-black.
    /// On white, tiles stand out through their shadows rather than a colour difference.
    static let appBackground = Color(light: .white, dark: UIColor(hex: 0x0E0C1A))

    /// Tile surface, top and bottom of its subtle vertical gradient.
    static let cardTop = Color(light: .white, dark: UIColor(hex: 0x221E38))
    static let cardBottom = Color(light: .white, dark: UIColor(hex: 0x1A172C))
    /// Flat tile colour, for places that need a single colour.
    static let cardBackground = Color(light: .white, dark: UIColor(hex: 0x1E1B32))

    /// Form rows (Add/Edit Expense): a very light grey so fields are visible on the white page.
    static let formRowBackground = Color(light: UIColor(hex: 0xF4F4F7), dark: UIColor(hex: 0x1E1B32))

    /// Inset areas inside a tile (e.g. the Insights chart area).
    static let insetBackground = Color(light: UIColor(hex: 0xF6F4FF), dark: UIColor(hex: 0x2A2644))

    // MARK: Depth

    /// Bevel: a light top edge fading to a faint dark bottom edge, like light from above.
    static let rimHighlight = Color(light: UIColor.black.withAlphaComponent(0.04), dark: UIColor.white.withAlphaComponent(0.14))
    static let rimShade = Color(light: UIColor.black.withAlphaComponent(0.08),
                                dark: UIColor.white.withAlphaComponent(0.03))

    /// Tight shadow where the tile meets the page (light grey).
    static let shadowContact = Color(light: UIColor.black.withAlphaComponent(0.08),
                                     dark: UIColor.black.withAlphaComponent(0.5))
    /// Soft shadow that lifts the tile off the page (light grey).
    static let shadowAmbient = Color(light: UIColor.black.withAlphaComponent(0.12),
                                     dark: UIColor.black.withAlphaComponent(0.55))

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension LinearGradient {
    static let brand = LinearGradient(colors: [.brandStart, .brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// The standard raised tile used across the app.
    ///
    /// Three things make it look 3D:
    /// 1. a surface that's slightly lighter at the top than the bottom,
    /// 2. a bevelled edge (bright on top, shaded at the bottom),
    /// 3. two shadows: a tight contact shadow and a wide, soft one.
    func cardStyle(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(
                LinearGradient(colors: [.cardTop, .cardBottom], startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.rimHighlight, .rimShade], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: .shadowContact, radius: 1.5, x: 0, y: 1)
            .shadow(color: .shadowAmbient, radius: 10, x: 0, y: 5)
    }

    /// The hero tile: brand gradient, a glossy highlight across the top and a coloured glow below.
    func heroCardStyle(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(LinearGradient.brand, in: shape)
            .overlay(
                // Gloss: soft light falling on the upper part of the card.
                shape.fill(
                    LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
                )
                .allowsHitTesting(false)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.brandStart.opacity(0.25), radius: 3, x: 0, y: 2)
            .shadow(color: Color.brandEnd.opacity(0.35), radius: 22, x: 0, y: 14)
    }

    /// A small raised icon tile (category icons, quick-action icons).
    func iconTile(_ color: Color, size: CGFloat = 44, cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color.opacity(0.24), color.opacity(0.12)],
                               startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(shape.strokeBorder(color.opacity(0.18), lineWidth: 1))
            .shadow(color: color.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

/// For tappable tiles: the tile sinks into the page while touched
/// (shrinks slightly and its shadow tightens), so it feels like a physical button.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardButtonStyle {
    static var pressableCard: PressableCardButtonStyle { .init() }
}
