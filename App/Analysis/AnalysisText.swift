import Analytics
import Domain
import SwiftUI

extension AnalysisStore.Tab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .averages: "analysis.tab.averages"
        case .gapping: "analysis.tab.gapping"
        case .dispersion: "analysis.tab.dispersion"
        }
    }

    var screenTitleKey: LocalizedStringKey {
        switch self {
        case .averages: "analysis.title.averages"
        case .gapping: "analysis.title.gapping"
        case .dispersion: "analysis.title.dispersion"
        }
    }
}

extension DistanceKind {
    var titleKey: LocalizedStringKey {
        self == .carry ? MetricKey.carry.titleKey : "analysis.distance.total"
    }

    var meanTitleKey: LocalizedStringKey {
        self == .carry ? "analysis.card.meanCarry" : "analysis.card.meanTotal"
    }
}

extension ConditionsView {
    var titleKey: LocalizedStringKey {
        self == .asRecorded ? "analysis.conditions.recorded" : "analysis.conditions.standardised"
    }
}

extension InclusionState {
    var titleKey: LocalizedStringKey {
        switch self {
        case .included: "analysis.incl.included"
        case .excluded: "analysis.incl.excluded"
        case .all: "analysis.incl.all"
        }
    }
}

/// Colours and symbols for clubs: every club has both, so it is never told apart by colour alone. Each colour has a light and a dark
/// value, each at least 3:1 against the surface and background of its scheme (non-text contrast, WCAG 1.4.11; checked in unit tests).
enum ClubPalette {
    static let tokens: [ColorToken] = [
        ColorToken(light: 0x1B6B4A, dark: 0x7ED9A4), ColorToken(light: 0xB35F00, dark: 0xFFB74D),
        ColorToken(light: 0x1565C0, dark: 0x64B5F6), ColorToken(light: 0xAD1457, dark: 0xF48FB1),
        ColorToken(light: 0x6A1B9A, dark: 0xCE93D8), ColorToken(light: 0x00796B, dark: 0x4DD0E1),
        ColorToken(light: 0x6D4C41, dark: 0xBCAAA4), ColorToken(light: 0x546E7A, dark: 0xB0BEC5),
    ]
    static let symbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill", "star.fill", "hexagon.fill"]

    static func colour(_ style: ClubStyle) -> Color {
        tokens[style.colourSlot % tokens.count].color
    }

    static func symbol(_ style: ClubStyle) -> String {
        symbols[style.symbolIndex % symbols.count]
    }
}

/// Round badge with the club's two-letter code, ringed in its colour and carrying its symbol.
struct ClubAvatar: View {
    let name: String
    let style: ClubStyle

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle().stroke(ClubPalette.colour(style), lineWidth: 4)
                .overlay(Text(verbatim: ClubBadge.text(for: name)).font(.footnote.weight(.bold)).foregroundStyle(Tokens.textPrimary.color))
                .frame(width: 44, height: 44)
            Image(systemName: ClubPalette.symbol(style)).font(.system(size: 11)).foregroundStyle(ClubPalette.colour(style))
                .padding(3).background(Tokens.surface.color, in: Circle())
        }
        .accessibilityHidden(true)
    }
}
