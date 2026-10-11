import SwiftUI

/// Skeleton home screen. Real Home (mockup 03) is built under F05/F22.
struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("home.title", comment: "App name on the Home screen")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("home.title")
            Text("home.subtitle", comment: "Short product description under the app name")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("home.subtitle")
        }
        .padding()
    }
}

#Preview { HomeView() }
