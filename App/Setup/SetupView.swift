import Capture
import Domain
import SwiftUI

/// Setup tutorial and live environment checks (F02). Shows exactly why capture is blocked and what to do about it.
struct SetupView: View {
    @SwiftUI.Environment(SetupModel.self) private var model
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("setup.subtitle", comment: "Setup instruction under the title").foregroundStyle(Tokens.textSecondary.color)
                    SetupDiagramView(handedness: model.state.handedness ?? .right)
                        .accessibilityIdentifier("setup.diagram")
                    handednessPicker
                    if model.mode == .test {
                        testBanner
                    }
                    blockers
                    checklist
                    actions
                }
                .frame(maxWidth: 600, alignment: .leading)
                .padding(Spacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(Tokens.background.color)
            .navigationTitle(Text("setup.title", comment: "Setup screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.done") { dismiss() }.accessibilityIdentifier("setup.close")
                }
            }
        }
        .task {
            model.startObserving()
        }
        .onDisappear { model.stopObserving() }
        .tint(Tokens.accent.color)
    }

    private var handednessPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("setup.handedness", comment: "Section label: swing handedness").font(.headline)
            HStack(spacing: Spacing.s) {
                option(.right, "onboarding.handedness.right")
                option(.left, "onboarding.handedness.left")
            }
        }
        .confirmationDialog(
            Text("setup.handedness.confirm.title"),
            isPresented: Binding(get: { model.needsHandednessConfirmation }, set: {
                if !$0 {
                    model.cancelHandednessChange()
                }
            }),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { model.confirmHandednessChange() } label: { Text("setup.handedness.confirm.change") }
            Button(role: .cancel) { model.cancelHandednessChange() } label: { Text("common.cancel") }
        } message: { Text("setup.handedness.confirm.message") }
    }

    private func option(_ value: SwingHandedness, _ key: LocalizedStringKey) -> some View {
        let selected = model.state.handedness == value
        return Button { model.choose(value) } label: {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                Text(key).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            .foregroundStyle(selected ? Tokens.onAccent.color : Tokens.textPrimary.color)
            .background(selected ? Tokens.accent.color : Tokens.surface.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("setup.handedness.\(value.rawValue)")
    }

    private var testBanner: some View {
        Label { Text("setup.test.banner") } icon: { Image(systemName: "testtube.2") }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            .accessibilityIdentifier("setup.testBanner")
    }

    private var checklist: some View {
        VStack(spacing: 0) {
            ForEach(model.rows, id: \.check.rawValue) { row in
                HStack {
                    Image(systemName: row.state.symbol).frame(width: 28).accessibilityHidden(true)
                    Text(row.check.titleKey)
                    Spacer()
                    Text(row.state.titleKey).foregroundStyle(Tokens.textSecondary.color)
                }
                .frame(minHeight: Spacing.minTarget)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("setup.check.\(row.check.rawValue).\(row.state.rawValue)")
                if row.check != SetupCheck.allCases.last {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Spacing.m)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }

    @ViewBuilder private var blockers: some View {
        let result = model.readiness
        if !result.blockers.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("setup.blocked.title", comment: "Heading above the reasons capture cannot start").font(.headline)
                ForEach(result.blockers, id: \.rawValue) { blocker in
                    VStack(alignment: .leading, spacing: 2) {
                        Label { Text(blocker.reason).bold() } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        Text(blocker.action).foregroundStyle(Tokens.textSecondary.color).padding(.leading, 32)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("setup.blocker.\(blocker.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        ForEach(result.warnings, id: \.rawValue) { warning in
            Label { Text(warning.reason) } icon: { Image(systemName: "info.circle") }
                .foregroundStyle(Tokens.textSecondary.color)
                .accessibilityIdentifier("setup.warning.\(warning.rawValue)")
        }
    }

    private var actions: some View {
        @Bindable var model = model
        return VStack(spacing: Spacing.s) {
            Button { dismiss() } label: { Text("setup.ready").frame(maxWidth: .infinity, minHeight: Spacing.minTarget) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.readiness.canArm)
                .accessibilityIdentifier("setup.ready")
            Button { model.mode = model.mode == .test ? .scored : .test } label: {
                Text(model.mode == .test ? "setup.test.exit" : "setup.test.button").frame(minHeight: Spacing.minTarget)
            }
            .accessibilityIdentifier("setup.test.toggle")
        }
    }
}

/// Top-down view: target line left to right, ball in the middle, golfer and phone on opposite sides. Drawn with shapes and text:
/// original artwork, mirrored for the other swing side.
struct SetupDiagramView: View {
    let handedness: SwingHandedness

    var body: some View {
        let golferTop = SetupDiagram.golferSide(for: handedness) == .top
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, mid = CGPoint(x: w * 0.4, y: h / 2)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 8, y: mid.y)); p.addLine(to: CGPoint(x: w - 70, y: mid.y))
                }
                .stroke(Tokens.accent.color, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                Image(systemName: "arrow.right").foregroundStyle(Tokens.accent.color).position(x: w - 56, y: mid.y)
                Text("setup.diagram.target").font(.footnote.bold()).position(x: w - 24, y: mid.y)
                Circle().fill(Color.white).overlay(Circle().stroke(Tokens.textPrimary.color, lineWidth: 2)).frame(width: 26, height: 26)
                    .position(mid)
                Text("setup.diagram.ball").font(.footnote.bold()).position(x: mid.x + 44, y: mid.y - 14)
                marker(symbol: "person.fill", label: "setup.diagram.golfer").position(x: mid.x, y: golferTop ? 28 : h - 28)
                marker(symbol: "iphone", label: "setup.diagram.phone").position(x: mid.x, y: golferTop ? h - 28 : 28)
                Path { p in
                    p.move(to: CGPoint(x: mid.x, y: 54)); p.addLine(to: CGPoint(x: mid.x, y: h - 54))
                }
                .stroke(Tokens.textSecondary.color, style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
            }
        }
        .frame(height: 180)
        .foregroundStyle(Tokens.textPrimary.color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(golferTop ? "setup.diagram.a11y.golferFar" : "setup.diagram.a11y.golferNear"))
    }

    private func marker(symbol: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: symbol).font(.title2)
            Text(label).font(.footnote.bold())
        }
    }
}
