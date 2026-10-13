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

/// Colours and symbols for clubs: every club has both, so it is never told apart by colour alone.
enum ClubPalette {
    static let colours: [Color] = [
        Color(red: 0.11, green: 0.42, blue: 0.29), Color(red: 0.78, green: 0.47, blue: 0.0), Color(red: 0.08, green: 0.40, blue: 0.75),
        Color(red: 0.68, green: 0.08, blue: 0.34), Color(red: 0.42, green: 0.11, blue: 0.60), Color(red: 0.0, green: 0.51, blue: 0.56),
        Color(red: 0.43, green: 0.30, blue: 0.25), Color(red: 0.33, green: 0.43, blue: 0.48),
    ]
    static let symbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill", "star.fill", "hexagon.fill"]

    static func colour(_ style: ClubStyle) -> Color {
        colours[style.colourSlot % colours.count]
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
