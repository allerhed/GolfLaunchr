import Capture
import Domain
import Formatting
import Modes
import SwiftUI

/// Practice capture screen (F05). Capture is landscape only: in portrait the screen shows a rotate prompt and nothing arms.
struct PracticeView: View {
    let store: PracticeStore
    let setup: SetupModel
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(AllowanceStore.self) private var allowance
    @State private var showingPlans = false
    @State private var showingDrillSummary = false
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false
    @State private var showingSetup = false

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    private var readiness: SetupReadinessResult {
        setup.readiness
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Tokens.background.color.ignoresSafeArea()
                if proxy.size.width > proxy.size.height {
                    capture
                } else {
                    rotateGate
                }
            }
        }
        .task {
            setup.startObserving()
            OrientationLock.requestLandscape()
            await allowance.refresh()
        }
        .onChange(of: store.state.shots.count) { _, _ in Task { await allowance.refresh() } }
        // The summary opens by itself when the last attempt is scored.
        .onChange(of: store.drillResult?.isComplete) { _, complete in
            if complete == true {
                showingDrillSummary = true
            }
        }
        .sheet(isPresented: $showingDrillSummary) {
            if let result = store.drillResult {
                DrillSummarySheet(result: result)
            }
        }
        .onDisappear {
            setup.stopObserving()
            OrientationLock.release()
        }
        .onChange(of: readiness.blockers.contains(.deviceMoving)) { _, moving in
            if moving, store.state.status == .active, !store.state.isArmed {
                store.voice?.prompt(.reposition)
            }
        }
        .sheet(isPresented: $showingSetup) {
            SetupView().environment(setup)
        }
        .confirmationDialog(Text("practice.end.title"), isPresented: $confirmEnd, titleVisibility: .visible) {
            Button(role: .destructive) { Task { await finish() } } label: { Text("practice.end.confirm") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: { Text("practice.end.message") }
        .tint(Tokens.accent.color)
    }

    private func finish() async {
        if await store.end() {
            await history.refresh()
            dismiss()
        }
    }

    // MARK: portrait gate

    private var rotateGate: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "rotate.right").font(.system(size: 56)).foregroundStyle(Tokens.accent.color).accessibilityHidden(true)
            Text("practice.rotate.title").font(.title2.bold()).multilineTextAlignment(.center)
            Text("practice.rotate.body").foregroundStyle(Tokens.textSecondary.color).multilineTextAlignment(.center)
            Button(role: .destructive) { confirmEnd = true } label: {
                Text("practice.end").frame(minWidth: 140, minHeight: Spacing.minTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("practice.end")
        }
        .padding(Spacing.l)
        .overlay(alignment: .topLeading) { Color.clear.frame(width: 1, height: 1).accessibilityIdentifier("practice.rotateGate") }
    }

    // MARK: landscape capture layout

    private var capture: some View {
        VStack(spacing: Spacing.m) {
            topBar
            HStack(alignment: .top, spacing: Spacing.m) {
                cards
                shotList
            }
            if !allowance.canArm {
                if allowance.snapshot != nil {
                    noAllowanceNote
                } else if allowance.loadFailed {
                    allowanceUnavailableNote
                }
            }
            controls
        }
        .padding(Spacing.m)
        // A marker, not an identifier on the container: a container identifier would replace every child identifier.
        .overlay(alignment: .topLeading) { Color.clear.frame(width: 1, height: 1).accessibilityIdentifier("practice.capture") }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.m) {
            Menu {
                ForEach(store.clubs) { club in
                    Button { store.selectClub(club) } label: {
                        if club.id == store.selectedClubID {
                            Label(club.name, systemImage: "checkmark")
                        } else {
                            Text(verbatim: club.name)
                        }
                    }
                }
            } label: {
                Label {
                    Text(verbatim: store.state.selectedClub?.name ?? "–").font(.headline)
                } icon: { Image(systemName: "figure.golf") }
                    .frame(minHeight: Spacing.minTarget)
            }
            .accessibilityIdentifier("practice.club")
            if store.state.isArmed, let armed = store.state.armedClub, armed != store.state.selectedClub {
                Text("practice.club.nextShot").font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                    .accessibilityIdentifier("practice.club.nextShot")
            }
            Spacer()
            statusPill
            Button { showingSetup = true } label: {
                Image(systemName: "slider.horizontal.3").frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
            }
            .accessibilityLabel(Text("setup.title"))
            .accessibilityIdentifier("practice.setup")
        }
    }

    private var statusPill: some View {
        let (key, symbol): (LocalizedStringKey, String) = switch store.state.status {
        case .paused: ("practice.status.paused", "pause.circle.fill")
        case .ended: ("practice.status.ended", "checkmark.circle.fill")
        case .active: store.state.isArmed ? ("practice.status.armed", "scope") : ("practice.status.idle", "circle.dashed")
        }
        return Label { Text(key) } icon: { Image(systemName: symbol) }
            .font(.subheadline.bold())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("practice.status")
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                metricCard(.carry, id: "practice.card.carry")
                metricCard(.ballSpeed, id: "practice.card.speed")
            }
            spokenCaption
            if !readiness.blockers.isEmpty, store.state.status == .active {
                blockedNote
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricCard(_ key: MetricKey, id: String) -> some View {
        let metric = store.latestShot?.metrics[key]
        let usable = metric.flatMap { $0.provenance == .unavailable ? nil : $0.value }
        let formatted = formatter.format(usable, for: key)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(key.titleKey).font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
            if let formatted, let metric {
                Text(verbatim: formatted.text).font(Typography.metricNumeral).minimumScaleFactor(0.6).lineLimit(1)
                Text(metric.provenance.titleKey).font(.caption).foregroundStyle(Tokens.textSecondary.color)
            } else {
                Text("history.noData").font(.title2).foregroundStyle(Tokens.textSecondary.color)
                Text("practice.card.waiting").font(.caption).foregroundStyle(Tokens.textSecondary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// The words of the last announcement, always visible: the audio is never the only channel.
    @ViewBuilder private var spokenCaption: some View {
        if let voice = store.voice, let text = voice.caption {
            Label {
                Text(verbatim: text)
            } icon: { Image(systemName: voice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").accessibilityHidden(true) }
                .font(.footnote)
                .foregroundStyle(Tokens.textSecondary.color)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("practice.spoken")
        }
    }

    private var blockedNote: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = readiness.blockers.first {
                Label { Text(first.reason).bold() } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                Text(first.action).foregroundStyle(Tokens.textSecondary.color).padding(.leading, 28)
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("practice.blocked")
    }

    /// The right column scrolls as a whole: the drill score sits above the shots and can never push Arm off the screen.
    private var shotList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if let drill = store.drillResult {
                    DrillPanel(result: drill, showingSummary: $showingDrillSummary)
                }
                Text("practice.shots \(store.state.shots.count)").font(.headline).accessibilityIdentifier("practice.shotCount")
                ForEach(store.state.shots.reversed().prefix(6), id: \.id) { shot in
                    ShotRow(shot: shot, formatter: formatter).card()
                }
            }
        }
        .frame(maxWidth: 320)
    }

    /// Shown instead of arming when nothing is left: history and settings stay reachable, never a swing that is not recorded.
    private var noAllowanceNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label { Text("practice.noAllowance") } icon: { Image(systemName: "lock.fill") }
                .font(.subheadline.weight(.semibold))
            if let reset = allowance.snapshot?.nextReset {
                HStack(spacing: Spacing.xs) {
                    Text("allowance.next.reset")
                    Text(reset, format: .dateTime.day().month(.wide))
                }
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("practice.noAllowance")
        .overlay(alignment: .trailing) {
            Button { showingPlans = true } label: {
                Text("allowance.see.plans").frame(minHeight: Spacing.minTarget)
            }
            .accessibilityIdentifier("practice.plans")
        }
        .sheet(isPresented: $showingPlans) { PaywallView() }
    }

    /// The balance could not be read, so nothing arms; say why and offer a retry instead of a silently dead button.
    private var allowanceUnavailableNote: some View {
        HStack(spacing: Spacing.m) {
            Label { Text("practice.allowanceUnavailable") } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("practice.allowanceUnavailable")
            Button { Task { await allowance.refresh() } } label: {
                Text("paywall.retry").frame(minHeight: Spacing.minTarget)
            }
            .accessibilityIdentifier("practice.allowance.retry")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(spacing: Spacing.m) {
            Button { store.arm(setupReady: readiness.canArm, allowanceAvailable: allowance.canArm) } label: {
                Text("practice.arm").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.state.isArmed || store.state.status != .active || !readiness.canArm || !allowance.canArm)
            .accessibilityIdentifier("practice.arm")
            Button { store.togglePause() } label: {
                Text(store.state.status == .paused ? "practice.resume" : "practice.pause")
                    .frame(minWidth: 100, minHeight: Spacing.minTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("practice.pause")
            #if DEBUG
                demoButton
            #endif
            Button(role: .destructive) { confirmEnd = true } label: {
                Text("practice.end").frame(minWidth: 100, minHeight: Spacing.minTarget)
            }
            .buttonStyle(.bordered)
            .disabled(store.isEnding)
            .accessibilityIdentifier("practice.end")
        }
    }
}

/// Asks iOS for landscape while capturing and releases the request afterwards.
enum OrientationLock {
    @MainActor static func requestLandscape() {
        update(.landscape)
    }

    @MainActor static func release() {
        update(.allButUpsideDown)
    }

    @MainActor private static func update(_ mask: UIInterfaceOrientationMask) {
        #if DEBUG
            if CommandLine.arguments.contains("-uiTestNoOrientationLock") {
                return
            } // lets UI tests see the portrait gate
        #endif
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}
