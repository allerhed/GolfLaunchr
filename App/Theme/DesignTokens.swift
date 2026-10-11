import SwiftUI
import UIKit

/// Original GolfLaunchr palette (spec 13): forest green, warm ivory, mint/lime accent. Raw hex so contrast can be unit tested.
enum Palette {
    static let forest: UInt32 = 0x103A2D
    static let forestDeep: UInt32 = 0x0B2A20
    static let ivory: UInt32 = 0xF6F5EE
    static let lime: UInt32 = 0xBFE77B
    static let ink: UInt32 = 0x12201A
    static let inkSoft: UInt32 = 0x46564E
    static let mist: UInt32 = 0xB9C8BE
    static let white: UInt32 = 0xFFFFFF
}

/// One semantic colour with its light and dark value.
struct ColorToken {
    let light: UInt32
    let dark: UInt32

    func hex(dark isDark: Bool) -> UInt32 {
        isDark ? dark : light
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

struct ContrastPair {
    let name: String
    let foreground: ColorToken
    let background: ColorToken
}

/// Semantic tokens. Views use these, never raw colours.
enum Tokens {
    static let background = ColorToken(light: Palette.ivory, dark: Palette.forestDeep)
    static let surface = ColorToken(light: Palette.white, dark: Palette.forest)
    static let textPrimary = ColorToken(light: Palette.ink, dark: Palette.ivory)
    static let textSecondary = ColorToken(light: Palette.inkSoft, dark: Palette.mist)
    /// Fill for primary actions and selected navigation.
    static let accent = ColorToken(light: Palette.forest, dark: Palette.lime)
    static let onAccent = ColorToken(light: Palette.ivory, dark: Palette.forest)

    /// Pairs that carry text and must meet WCAG AA (4.5:1). Checked in unit tests for both schemes.
    static let textPairs: [ContrastPair] = [
        ContrastPair(name: "textPrimary/background", foreground: textPrimary, background: background),
        ContrastPair(name: "textPrimary/surface", foreground: textPrimary, background: surface),
        ContrastPair(name: "textSecondary/background", foreground: textSecondary, background: background),
        ContrastPair(name: "textSecondary/surface", foreground: textSecondary, background: surface),
        ContrastPair(name: "onAccent/accent", foreground: onAccent, background: accent),
        ContrastPair(name: "accent/background", foreground: accent, background: background),
    ]
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let cornerRadius: CGFloat = 20
    /// Minimum touch target (F22).
    static let minTarget: CGFloat = 44
}

enum Typography {
    /// Large numerals for metrics. Text styles keep it Dynamic Type aware.
    static let metricNumeral = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
    static let title = Font.title2.weight(.semibold)
    static let body = Font.body
    static let caption = Font.footnote
}

/// WCAG 2.x contrast ratio between two sRGB hex colours.
enum Contrast {
    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Rounded card used for grouped content.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.m)
            .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}
