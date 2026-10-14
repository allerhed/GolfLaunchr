import Modes
import SwiftUI

/// Home (mockup 03): start practice, QuickShot, the other modes (not available yet), and the latest session.
struct HomeView: View {
    @SwiftUI.Environment(SetupLauncher.self) private var setup
    @SwiftUI.Environment(PracticeLauncher.self) private var practice
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(BagStore.self) private var bag
    @SwiftUI.Environment(AllowanceStore.self) private var allowance
    @SwiftUI.Environment(AppNavigation.self) private var navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("home.title", comment: "App name on the Home screen")
                        .font(.title3.weight(.semibold)).foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("home.title")
                    Text("home.headline", comment: "Home headline").font(.largeTitle.bold())
                    Text("home.subtitle", comment: "Short product description under the app name")
                        .foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("home.subtitle")
                }
                startCard
                allowanceRow
                quickShotRow
                if practice.failed {
                    failureNote
                }
                setupRow
                modes
                latest
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .task { await allowance.refresh() }
    }

    private var failureNote: some View {
        Label {
            Text(bag.bag.active.isEmpty ? "home.start.noClubs" : "home.start.failed")
        } icon: { Image(systemName: "exclamationmark.triangle.fill") }
            .accessibilityIdentifier("home.start.error")
    }

    private var startCard: some View {
        Button { Task { await practice.start(.standard) } } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("home.start.title").font(.title2.bold())
                    Text("home.start.subtitle").multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 44)).accessibilityHidden(true)
            }
            .foregroundStyle(Tokens.onAccent.color)
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(Tokens.accent.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!practice.isAvailable)
        .accessibilityIdentifier("home.start")
    }

    /// What is left for free before practising (F19): introductory shots, then the monthly grant with the next reset date.
    @ViewBuilder
    private var allowanceRow: some View {
        if let snap = allowance.snapshot {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if snap.isPro {
                        Text("allowance.pro.active")
                    } else {
                        if snap.introRemaining > 0 {
                            Text("allowance.intro.left \(snap.introRemaining)")
                        } else if snap.monthlyRemaining > 0 {
                            Text("allowance.monthly.left \(snap.monthlyRemaining)")
                        } else {
                            Text("allowance.none.left")
                        }
                        if snap.introRemaining == 0, let reset = snap.nextReset {
                            HStack(spacing: Spacing.xs) {
                                Text("allowance.next.reset")
                                Text(reset, format: .dateTime.day().month(.wide))
                            }
                            .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.allowance")
                Button { navigation.showingPlans = true } label: {
                    Text("allowance.see.plans").frame(minHeight: Spacing.minTarget, alignment: .leading)
                }
                .accessibilityIdentifier("home.plans")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Tokens.textPrimary.color)
        }
    }

    private var quickShotRow: some View {
        Button { Task { await practice.start(.quickShot) } } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "bolt.fill").font(.title2).frame(width: 44, height: 44)
                    .background(Tokens.accent.color.opacity(0.15), in: Circle()).accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("home.quickshot.title").font(.headline)
                    Text("home.quickshot.subtitle").font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Tokens.textSecondary.color).accessibilityHidden(true)
            }
            .foregroundStyle(Tokens.textPrimary.color)
            .frame(minHeight: Spacing.minTarget)
            .card()
        }
        .buttonStyle(.plain)
        .disabled(!practice.isAvailable)
        .accessibilityIdentifier("home.quickshot")
    }

    private var setupRow: some View {
        Button { setup.open() } label: {
            Label { Text("setup.title") } icon: { Image(systemName: "iphone.gen3.radiowaves.left.and.right") }
                .frame(maxWidth: .infinity, minHeight: Spacing.minTarget, alignment: .leading)
                .card()
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.textPrimary.color)
        .accessibilityIdentifier("home.setup")
    }

    private var modes: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("home.modes").font(.headline)
            HStack(alignment: .top, spacing: Spacing.s) {
                modeTile("scope", "home.mode.target", "home.mode.target.text", id: "target")
                modeTile("chart.bar.fill", "home.mode.ladder", "home.mode.ladder.text", id: "ladder")
                modeTile("flag.fill", "home.mode.virtual", "home.mode.virtual.text", id: "virtual")
            }
        }
    }

    /// Not available yet: shown, labelled, and not tappable (no dead ends, no pretending).
    private func modeTile(_ symbol: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey, id: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol).font(.title).accessibilityHidden(true)
            Text(title).font(.subheadline.bold())
            Text(text).font(.caption).multilineTextAlignment(.center)
            Text("home.mode.soon").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(Capsule().stroke(Tokens.textSecondary.color))
        }
        .foregroundStyle(Tokens.textSecondary.color)
        .frame(maxWidth: .infinity)
        .padding(Spacing.s)
        .background(Tokens.surface.color.opacity(0.6), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.mode.\(id)")
    }

    @ViewBuilder private var latest: some View {
        if let session = history.visible.first {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("home.last").font(.headline)
                HStack {
                    Image(systemName: "chart.bar.xaxis").frame(width: 44, height: 44).accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                            .font(.headline)
                        Text("history.shotCount \(session.shotCount)").foregroundStyle(Tokens.textSecondary.color)
                    }
                    Spacer()
                }
                .card()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.latest")
            }
        }
    }
}
