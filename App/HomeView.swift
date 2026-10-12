import SwiftUI

/// Skeleton home screen. Real Home (mockup 03) is built under F05/F22.
struct HomeView: View {
    @SwiftUI.Environment(SetupLauncher.self) private var setup

    var body: some View {
        VStack(spacing: Spacing.s) {
            Text("home.title", comment: "App name on the Home screen")
                .font(.largeTitle.bold())
                .foregroundStyle(Tokens.textPrimary.color)
                .accessibilityIdentifier("home.title")
            Text("home.subtitle", comment: "Short product description under the app name")
                .foregroundStyle(Tokens.textSecondary.color)
                .accessibilityIdentifier("home.subtitle")
            Button { setup.open() } label: {
                Text("setup.title").frame(minHeight: Spacing.minTarget)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.m)
            .accessibilityIdentifier("home.setup")
        }
        .multilineTextAlignment(.center)
        .card()
        .padding(Spacing.m)
    }
}

#Preview { HomeView() }
