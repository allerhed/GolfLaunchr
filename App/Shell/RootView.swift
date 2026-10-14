import SwiftUI

/// Adaptive shell: bottom tab bar in portrait, leading rail in landscape (F22). Content is never merely stretched.
struct RootView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(SettingsStore.self) private var settings
    @Environment(BagStore.self) private var bagStore
    @Environment(HistoryStore.self) private var historyStore
    @Environment(SetupLauncher.self) private var setup
    @Environment(PracticeLauncher.self) private var practice
    @Environment(CommerceStore.self) private var commerce
    @Environment(AllowanceStore.self) private var allowance
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var navigation = navigation
        GeometryReader { proxy in
            Group {
                if proxy.size.width > proxy.size.height {
                    HStack(spacing: 0) {
                        NavigationRail()
                        TabRoot(tab: navigation.selection, showsSettingsButton: false)
                    }
                } else {
                    TabView(selection: $navigation.selection) {
                        ForEach(AppTab.allCases) { tab in
                            TabRoot(tab: tab, showsSettingsButton: true)
                                .tabItem { Label(tab.titleKey, systemImage: tab.symbol) }
                                .tag(tab)
                                .accessibilityIdentifier("nav.\(tab.rawValue)")
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Tokens.background.color.ignoresSafeArea())
        .task {
            await practice.recoverInterrupted()
            await bagStore.load()
            await historyStore.load()
            await commerce.refreshEntitlement()
        }
        // A purchase, restore, expiry or refund changes what is free, so the balance is read again.
        .onChange(of: commerce.entitlement) { _, _ in Task { await allowance.refresh() } }
        // Renewals, expiries and refunds that happened while the app was away are picked up when it returns.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await commerce.refreshEntitlement() }
            }
        }
        .tint(Tokens.accent.color)
        .environment(\.locale, settings.language.locale ?? Locale.current)
        .fullScreenCover(isPresented: Binding(get: { !settings.onboardingCompleted }, set: { _ in })) {
            OnboardingView()
                .preferredColorScheme(settings.appearance.colorScheme)
                .environment(\.locale, settings.language.locale ?? Locale.current)
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .environment(\.locale, settings.language.locale ?? Locale.current)
        #if CAPTURE_HARNESS
            .fullScreenCover(isPresented: .constant(HarnessAutorunConfig.current != nil)) { HarnessView() }
        #endif
            .fullScreenCover(isPresented: Binding(get: { setup.model != nil }, set: {
                if !$0 {
                    setup.model = nil
                }
            })) {
                if let model = setup.model {
                    SetupView().environment(model).preferredColorScheme(settings.appearance.colorScheme)
                        .environment(\.locale, settings.language.locale ?? Locale.current)
                }
            }
            .fullScreenCover(isPresented: Binding(get: { practice.store != nil }, set: {
                if !$0 {
                    practice.store = nil
                }
            })) {
                if let store = practice.store, let model = practice.setupModel {
                    PracticeView(store: store, setup: model)
                        .preferredColorScheme(settings.appearance.colorScheme)
                        .environment(\.locale, settings.language.locale ?? Locale.current)
                }
            }
            .sheet(isPresented: $navigation.showingDrillSetup) {
                DrillSetupSheet()
                    .preferredColorScheme(settings.appearance.colorScheme)
                    .environment(\.locale, settings.language.locale ?? Locale.current)
            }
            .sheet(isPresented: $navigation.showingPlans) {
                PaywallView()
                    .preferredColorScheme(settings.appearance.colorScheme)
                    .environment(\.locale, settings.language.locale ?? Locale.current)
            }
            .sheet(isPresented: $navigation.showingSettings) {
                SettingsView()
                    .environment(settings)
                    .preferredColorScheme(settings.appearance.colorScheme)
                    .environment(\.locale, settings.language.locale ?? Locale.current)
            }
    }
}

/// One tab's root screen inside its own navigation stack.
struct TabRoot: View {
    @Environment(AppNavigation.self) private var navigation
    let tab: AppTab
    let showsSettingsButton: Bool

    var body: some View {
        NavigationStack(path: Binding(get: { navigation.paths[tab] ?? NavigationPath() }, set: { navigation.paths[tab] = $0 })) {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.background.color)
                .navigationDestination(for: SessionRoute.self) { SessionDetailView(sessionID: $0.id) }
                .navigationTitle(tab.screenTitleKey)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if showsSettingsButton {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { navigation.showingSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                            }
                            .accessibilityLabel(Text("nav.settings", comment: "Settings button, VoiceOver label"))
                            .accessibilityIdentifier("nav.settings")
                        }
                    }
                }
        }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .home: HomeView()
        case .bag: BagView()
        case .progress: ProgressScreen()
        }
    }
}

struct PlaceholderView: View {
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label { Text(message) } icon: { Image(systemName: symbol) }
        }
        .foregroundStyle(Tokens.textSecondary.color)
        .accessibilityIdentifier("placeholder")
    }
}
