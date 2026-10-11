import SwiftUI

/// Leading rail for landscape browsing. Selection is shown by symbol fill, weight and an indicator, never colour alone.
struct NavigationRail: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(AppTab.allCases) { tab in
                railButton(tab)
            }
            Spacer(minLength: Spacing.s)
            Button { navigation.showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
            }
            .foregroundStyle(Tokens.textSecondary.color)
            .accessibilityLabel(Text("nav.settings", comment: "Settings button, VoiceOver label"))
            .accessibilityIdentifier("nav.settings")
        }
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.s)
        .frame(width: typeSize.isAccessibilitySize ? 76 : 92)
        .frame(maxHeight: .infinity)
        .background(Tokens.surface.color)
        .accessibilityElement(children: .contain)
    }

    private func railButton(_ tab: AppTab) -> some View {
        let selected = navigation.selection == tab
        return Button { navigation.selection = tab } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: selected ? tab.selectedSymbol : tab.symbol).font(.title3)
                if !typeSize.isAccessibilitySize {
                    Text(tab.titleKey).font(.caption.weight(selected ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Spacing.minTarget + Spacing.m)
            .foregroundStyle(selected ? Tokens.onAccent.color : Tokens.textPrimary.color)
            .background(selected ? Tokens.accent.color : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel(Text(tab.titleKey))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("nav.\(tab.rawValue)")
    }
}
