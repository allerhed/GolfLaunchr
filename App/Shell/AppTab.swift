import Observation
import SwiftUI

/// Primary navigation (spec 13): Home, Bag, Progress. Settings is a gear, not a tab.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, bag, progress

    var id: String {
        rawValue
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: "nav.home"
        case .bag: "nav.bag"
        case .progress: "nav.progress"
        }
    }

    /// Screen title; the Bag tab's screen is called "My Bag" (spec 13) while its tab label stays short.
    var screenTitleKey: LocalizedStringKey {
        switch self {
        case .home: "nav.home"
        case .bag: "bag.title"
        case .progress: "nav.progress"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .bag: "bag"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: "house.fill"
        case .bag: "bag.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }
}

/// Shell state lives here, not in the views, so rotation (which swaps tab bar and rail) keeps the selection.
@MainActor @Observable
final class AppNavigation {
    var selection: AppTab = .home
    var showingSettings = false
    /// Kept here, not in a screen, so rotation (which rebuilds the shell) does not close the plans sheet.
    var showingPlans = false
    /// The Progress tab's segment, kept here so rotation and "Analyse this session" can change it.
    var progressSection = ProgressSection.sessions
    /// Per-tab navigation, kept here so rotating the phone (which rebuilds the shell) keeps the open session.
    /// Created up front so reading a path never fabricates a new one (an unstable path binding can make the stack rebuild its screens).
    var paths: [AppTab: NavigationPath] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) })
}

enum ProgressSection: String, Hashable {
    case sessions, analysis, trends
}
