import Capture
import Domain
import SwiftUI

/// First-run flow: welcome, safe placement, swing handedness (required), device check. History is reachable at every step
/// through "Use history only", so nothing here needs the camera.
struct OnboardingView: View {
    @SwiftUI.Environment(OnboardingStore.self) private var store
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        progress
                        switch store.step {
                        case .welcome: welcome
                        case .placement: placement
                        case .handedness: handedness
                        case .device: device
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity)
                }
                // The result appears below the button; in landscape it would otherwise be off screen.
                .onChange(of: store.report) { _, new in
                    if new != nil {
                        withAnimation { proxy.scrollTo("onboarding.report", anchor: .bottom) }
                    }
                }
            }
            controls
        }
        .background(Tokens.background.color.ignoresSafeArea())
        .tint(Tokens.accent.color)
    }

    private var progress: some View {
        HStack(spacing: Spacing.s) {
            ForEach(OnboardingStore.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= store.step.rawValue ? Tokens.accent.color : Tokens.textSecondary.color.opacity(0.3))
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.progress \(store.step.rawValue + 1) \(OnboardingStore.Step.allCases.count)"))
    }

    private func heading(_ key: LocalizedStringKey, id: String) -> some View {
        Text(key).font(.largeTitle.bold()).foregroundStyle(Tokens.textPrimary.color)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier(id)
    }

    private func body(_ key: LocalizedStringKey, symbol: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(Tokens.accent.color).frame(width: 28).accessibilityHidden(true)
            }
            Text(key).foregroundStyle(Tokens.textPrimary.color)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Image(systemName: "figure.golf").font(.system(size: 64)).foregroundStyle(Tokens.accent.color).accessibilityHidden(true)
            heading("onboarding.welcome.title", id: "onboarding.title")
            Text("onboarding.welcome.body", comment: "Onboarding welcome text").foregroundStyle(Tokens.textSecondary.color)
        }
    }

    private var placement: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            heading("onboarding.placement.title", id: "onboarding.title")
            body("onboarding.placement.tripod", symbol: "camera.metering.unknown")
            body("onboarding.placement.clearance", symbol: "figure.walk.motion")
            body("onboarding.placement.landscape", symbol: "iphone.landscape")
        }
        .card()
    }

    private var handedness: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            heading("onboarding.handedness.title", id: "onboarding.title")
            Text("onboarding.handedness.body", comment: "Explains handedness means the golf swing")
                .foregroundStyle(Tokens.textSecondary.color)
            HStack(spacing: Spacing.m) {
                choice(.right, label: "onboarding.handedness.right")
                choice(.left, label: "onboarding.handedness.left")
            }
            if settings.swingHandedness == nil {
                Text("onboarding.handedness.required", comment: "Shown until a handedness is chosen")
                    .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                    .accessibilityIdentifier("onboarding.handedness.required")
            }
        }
    }

    private func choice(_ value: SwingHandedness, label: LocalizedStringKey) -> some View {
        let selected = settings.swingHandedness == value
        return Button { store.choose(value) } label: {
            VStack(spacing: Spacing.s) {
                // Stance illustration: the golfer mirrored for a left-handed swing.
                Image(systemName: "figure.golf").font(.system(size: 48))
                    .scaleEffect(x: value == .left ? -1 : 1, y: 1)
                Text(label).font(.headline)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(Spacing.m)
            .foregroundStyle(Tokens.textPrimary.color)
            .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous)
                .stroke(selected ? Tokens.accent.color : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.handedness.\(value.rawValue)")
    }

    private var device: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            heading("onboarding.device.title", id: "onboarding.title")
            Text("onboarding.device.body", comment: "Explains the camera check and that permission is asked now")
                .foregroundStyle(Tokens.textSecondary.color)
            Button { Task { await store.checkDevice() } } label: {
                Text("onboarding.device.check").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isChecking)
            .accessibilityIdentifier("onboarding.device.check")
            if store.permission == .denied {
                deniedBanner
            }
            if let report = store.report {
                reportCard(report)
            }
        }
    }

    private var deniedBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label { Text("onboarding.device.denied") } icon: { Image(systemName: "camera.fill").foregroundStyle(Tokens.accent.color) }
                .accessibilityIdentifier("onboarding.device.denied")
            Button {
                if let url = URL(string: "app-settings:") {
                    openURL(url)
                }
            } label: {
                Text("onboarding.device.openSettings").frame(minHeight: Spacing.minTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("onboarding.device.openSettings")
        }
        .card()
    }

    private func reportCard(_ report: CapabilityReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label { Text(report.status.titleKey).font(.title3.bold()) } icon: { Image(systemName: report.status.symbol) }
                .accessibilityIdentifier("onboarding.device.status.\(report.status.rawValue)")
            Text(report.status.explanationKey).foregroundStyle(Tokens.textSecondary.color)
            ForEach(report.reasons, id: \.rawValue) { reason in
                Label { Text(reason.titleKey) } icon: {
                    Image(systemName: reason.isBlocking ? "exclamationmark.triangle.fill" : "info.circle")
                }
                .accessibilityIdentifier("onboarding.device.reason.\(reason.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .id("onboarding.report")
    }

    private var controls: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                if store.step != .welcome {
                    Button { store.back() } label: { Text("onboarding.back").frame(minHeight: Spacing.minTarget) }
                        .accessibilityIdentifier("onboarding.back")
                }
                Spacer()
                if store.isLastStep {
                    Button { store.finish() } label: { Text("onboarding.finish").frame(minWidth: 140, minHeight: Spacing.minTarget) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("onboarding.finish")
                } else {
                    Button { store.next() } label: { Text("onboarding.next").frame(minWidth: 140, minHeight: Spacing.minTarget) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canContinue)
                        .accessibilityIdentifier("onboarding.next")
                }
            }
            Button { store.finish() } label: { Text("onboarding.skip").frame(minHeight: Spacing.minTarget) }
                .font(.footnote)
                .accessibilityIdentifier("onboarding.skip")
        }
        .padding(Spacing.m)
        .background(Tokens.background.color)
    }
}
