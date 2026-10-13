import SwiftUI

/// A row of filter chips that stays one row when it fits and becomes a stack at large text sizes, so nothing runs off the screen
/// and nothing needs sideways scrolling (F22). The chips are built twice, once for each arrangement.
struct WrappingChips<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = Spacing.s, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) { content() }
            // Stacked: each chip may use the full width, so its text wraps instead of running off the screen.
            VStack(alignment: .leading, spacing: spacing) { content().frame(maxWidth: .infinity, alignment: .leading) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Segmented pickers cannot shrink their segments, so at accessibility text sizes they run off the screen: use a menu instead.
struct AdaptiveSegmented: ViewModifier {
    @SwiftUI.Environment(\.dynamicTypeSize) private var size

    func body(content: Content) -> some View {
        if size.isAccessibilitySize {
            content.pickerStyle(.menu)
        } else {
            content.pickerStyle(.segmented)
        }
    }
}

extension View {
    func adaptiveSegmented() -> some View {
        modifier(AdaptiveSegmented())
    }
}
