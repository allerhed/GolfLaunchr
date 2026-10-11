import Observation
import SwiftUI

/// Primary navigation (spec 13): Home, Bag, Progress. Settings is a gear, not a tab.
enum AppTab: String, CaseIterable, Identifiable {
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
}
