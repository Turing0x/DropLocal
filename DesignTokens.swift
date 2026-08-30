//
//  DesignTokens.swift
//  Generated from ThreeDotsDev Design System (colors_and_type.css)
//  Dynamic colors resolve automatically for light/dark — pass through Color(...) as-is.
//

import SwiftUI

// MARK: - Colors

enum TDDColor {
    // Semantic (shadcn-style) tokens — dynamic light/dark
    static let background         = dynamic(light: "#FFFFFF", dark: "#09090B")
    static let foreground          = dynamic(light: "#09090B", dark: "#FAFAFA")
    static let card                 = dynamic(light: "#FFFFFF", dark: "#09090B")
    static let cardForeground      = dynamic(light: "#09090B", dark: "#FAFAFA")
    static let popover              = dynamic(light: "#FFFFFF", dark: "#09090B")
    static let popoverForeground   = dynamic(light: "#09090B", dark: "#FAFAFA")

    static let primary              = dynamic(light: "#10B981", dark: "#34D399") // emerald-500 / emerald-400
    static let primaryForeground   = dynamic(light: "#000000", dark: "#000000")

    static let secondary            = dynamic(light: "#F4F4F5", dark: "#27272A")
    static let secondaryForeground = dynamic(light: "#18181B", dark: "#FAFAFA")

    static let muted                = dynamic(light: "#F4F4F5", dark: "#27272A")
    static let mutedForeground     = dynamic(light: "#71717A", dark: "#A1A1AA")

    static let accent               = dynamic(light: "#F4F4F5", dark: "#27272A")
    static let accentForeground    = dynamic(light: "#18181B", dark: "#FAFAFA")

    static let destructive          = dynamic(light: "#EF4444", dark: "#7F1D1D")
    static let destructiveForeground = dynamic(light: "#FAFAFA", dark: "#FAFAFA")

    static let border                = dynamic(light: "#E4E4E7", dark: "#27272A")
    static let input                 = dynamic(light: "#E4E4E7", dark: "#27272A")
    static let ring                  = primary

    // Raw brand palette (wordmark dots + CTAs) — fixed, not theme-dependent
    static let dotCyanFrom    = Color(hex: "#22D3EE")
    static let dotCyanTo      = Color(hex: "#2563EB")
    static let dotGreenFrom   = Color(hex: "#4ADE80")
    static let dotGreenTo     = Color(hex: "#059669")
    static let dotOrangeFrom  = Color(hex: "#FB923C")
    static let dotOrangeTo    = Color(hex: "#DC2626")

    static let wordmarkGradient = LinearGradient(
        colors: [Color(hex: "#4ADE80"), Color(hex: "#22D3EE"), Color(hex: "#10B981")],
        startPoint: .leading, endPoint: .trailing
    )

    static let ctaPrimaryBg        = Color(hex: "#10B981")
    static let ctaPrimaryBgHover   = Color(hex: "#34D399")
    static let ctaPrimaryFg        = Color(hex: "#000000")
    static let ctaSecondaryBg      = Color(hex: "#1E40AF")
    static let ctaSecondaryBgHover = Color(hex: "#2563EB")
    static let ctaSecondaryFg      = Color(hex: "#FFFFFF")

    static let badgeAvailableBg = Color(hex: "#10B981").opacity(0.15)
    static let badgeAvailableFg = Color(hex: "#6EE7B7")

    static let shadowEmeraldGlow = Color(hex: "#10B981").opacity(0.35)

    /// Builds a Color that resolves to `light` or `dark` hex depending on the active UI style.
    private static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

// MARK: - Typography

enum TDDFont {
    /// "Geist" in the source system; falls back to Inter, then system, on iOS.
    static let sansFamily = "Inter"

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(sansFamily, size: size).weight(weight)
    }

    // Tailwind-equivalent scale (pt, line-height pt)
    static let xs   = Scale(size: 12, lineHeight: 16)
    static let sm   = Scale(size: 14, lineHeight: 20)
    static let base = Scale(size: 16, lineHeight: 24)
    static let lg   = Scale(size: 18, lineHeight: 28)
    static let xl   = Scale(size: 20, lineHeight: 28)
    static let xl2  = Scale(size: 24, lineHeight: 32)
    static let xl3  = Scale(size: 30, lineHeight: 36)
    static let xl4  = Scale(size: 36, lineHeight: 40)
    static let xl5  = Scale(size: 48, lineHeight: 48)
    static let xl6  = Scale(size: 60, lineHeight: 60)

    // Tracking, expressed as em fraction of point size (multiply by size for a kerning value)
    static let trackingTighter: CGFloat = -0.05
    static let trackingTight: CGFloat   = -0.025
    static let trackingNormal: CGFloat  = 0
    static let trackingWide: CGFloat    = 0.025

    struct Scale {
        let size: CGFloat
        let lineHeight: CGFloat
    }
}

// MARK: - Radius

enum TDDRadius {
    static let base: CGFloat = 10   // --radius
    static let sm: CGFloat   = 6    // base - 4
    static let md: CGFloat   = 8    // base - 2
    static let lg: CGFloat   = 10   // == base
    static let xl: CGFloat   = 14   // base + 4
}

// MARK: - Spacing (4px base scale)

enum TDDSpacing {
    static let s4: CGFloat  = 4
    static let s8: CGFloat  = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s40: CGFloat = 40
    static let s48: CGFloat = 48
    static let s64: CGFloat = 64
    static let s80: CGFloat = 80
    static let s96: CGFloat = 96
}

// MARK: - Motion

enum TDDMotion {
    static let fast: Double = 0.15
    static let base: Double = 0.30
    static let slow: Double = 0.70

    static let easeOut = Animation.timingCurve(0, 0, 0.2, 1, duration: base)
    static let easeInOut = Animation.timingCurve(0.4, 0, 0.2, 1, duration: base)

    static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0, 0, 0.2, 1, duration: duration)
    }
    static func easeInOut(_ duration: Double) -> Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }
}

// MARK: - Hex helpers

extension Color {
    init(hex: String) {
        self = Color(UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
