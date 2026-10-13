import Analytics
import Domain
import Formatting
import SwiftUI

/// Carry (up) against lateral landing (sideways): one dot per eligible shot, a dashed ±1 SD shape per club with enough points, a
/// legend, a tap-to-select callout and a plain list of the same shots. Landing positions are estimates, not GPS positions.
struct DispersionView: View {
    let result: AnalysisStore.Result
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale
    @State private var candidates: [DispersionPoint] = []

    private var units: DisplayUnits {
        settings.units
    }

    private var formatter: MetricFormatter {
        MetricFormatter(units: units, locale: locale)
    }

    private var kind: DistanceKind {
        result.gap.distance
    }

    private var styleByClub: [UUID: ClubStyle] {
        Dictionary(uniqueKeysWithValues: result.profiles.map { ($0.clubID, store.style(for: $0.clubID)) })
    }

    private func distanceText(_ si: Double?) -> String {
        formatter.format(si, for: kind.key)?.text ?? "–"
    }

    private func spreadText(_ p: ClubProfile) -> String {
        p.spread.flatMap { formatter.format($0, for: kind.key) }.map { "±\($0.text)" } ?? "–"
    }

    private func lateralText(_ si: Double?) -> String {
        formatter.format(si, for: .lateralLanding)?.text ?? "–"
    }

    private func shown(_ si: Double, _ key: MetricKey) -> Double {
        UnitConversion.display(si, for: key, units: units)
    }

    private struct Axes {
        let xMax: Double
        let yMin: Double
        let yMax: Double
    }

    private var ellipses: [(clubID: UUID, ellipse: SpreadEllipse)] {
        result.profiles.compactMap { p in
            Dispersion.ellipse(result.points.filter { $0.clubID == p.clubID }).map { (p.clubID, $0) }
        }
    }

    private func axes() -> Axes {
        let ys = result.points.map { shown($0.longitudinalM, kind.key) }
        let xs = result.points.compactMap { $0.lateralM.map { abs(shown($0, .lateralLanding)) } }
        let yLo = (ys.min() ?? 0), yHi = (ys.max() ?? 100)
        let pad = max((yHi - yLo) * 0.25, 10)
        let step = 10.0
        let xm = max((xs.max() ?? 10) * 1.3, 10)
        return Axes(
            xMax: (xm / step).rounded(.up) * step, yMin: max(0, ((yLo - pad) / step).rounded(.down) * step),
            yMax: ((yHi + pad) / step).rounded(.up) * step
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("analysis.title.dispersion").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            plot.frame(height: 340)
                .padding(Spacing.s)
                .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            if !candidates.isEmpty {
                callout
            }
            legend
            if result.points.contains(where: { $0.lateralM == nil }) {
                Label { Text("analysis.disp.noLateral") } icon: { Image(systemName: "info.circle") }
                    .font(.footnote).accessibilityIdentifier("analysis.disp.noLateral")
            }
            Label { Text("analysis.disp.estimates") } icon: { Image(systemName: "info.circle") }
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
            Label { Text("analysis.disp.ellipse") } icon: { Image(systemName: "oval") }
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
            shotList
        }
    }

    // MARK: the plot

    private var plot: some View {
        let a = axes()
        return GeometryReader { geo in plotContent(size: geo.size, a: a) }
    }

    private func plotContent(size: CGSize, a: Axes) -> some View {
        let box = CGRect(x: 44, y: 12, width: size.width - 56, height: size.height - 48)
        func px(_ lateral: Double) -> CGFloat {
            box.minX + box.width * (lateral + a.xMax) / (2 * a.xMax)
        }
        func py(_ carry: Double) -> CGFloat {
            box.maxY - box.height * (carry - a.yMin) / (a.yMax - a.yMin)
        }
        return Canvas { ctx, _ in
            grid(ctx, box, a, px: px, py: py)
            for item in ellipses {
                guard let style = styleByClub[item.clubID] else { continue }
                ctx.stroke(
                    ellipsePath(item.ellipse, px: px, py: py),
                    with: .color(ClubPalette.colour(style).opacity(0.9)),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
            }
            for point in result.points {
                guard let style = styleByClub[point.clubID] else { continue }
                let at = CGPoint(
                    x: px(point.lateralM.map { shown($0, .lateralLanding) } ?? 0),
                    y: py(shown(point.longitudinalM, kind.key))
                )
                var symbol = ctx.resolve(Image(systemName: ClubPalette.symbol(style)))
                symbol.shading = .color(ClubPalette.colour(style).opacity(point.lateralM == nil ? 0.5 : 1))
                ctx.draw(symbol, at: at)
            }
        }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap in
            candidates = result.points.filter { point in
                let at = CGPoint(
                    x: px(point.lateralM.map { shown($0, .lateralLanding) } ?? 0),
                    y: py(shown(point.longitudinalM, kind.key))
                )
                return hypot(at.x - tap.location.x, at.y - tap.location.y) <= 22
            }
            .sorted { $0.longitudinalM < $1.longitudinalM }
        })
        .accessibilityElement()
        .accessibilityLabel(Text("analysis.disp.a11y \(result.points.count) \(result.profiles.count)"))
        .accessibilityIdentifier("analysis.disp.plot")
    }

    private func grid(_ ctx: GraphicsContext, _ box: CGRect, _ a: Axes, px: (Double) -> CGFloat, py: (Double) -> CGFloat) {
        var lines = Path()
        let yStep = max(10, ((a.yMax - a.yMin) / 5 / 10).rounded(.up) * 10)
        var y = a.yMin
        while y <= a.yMax + 0.001 {
            lines.move(to: CGPoint(x: box.minX, y: py(y))); lines.addLine(to: CGPoint(x: box.maxX, y: py(y)))
            ctx.draw(Text(verbatim: "\(Int(y))").font(.caption2), at: CGPoint(x: box.minX - 18, y: py(y)))
            y += yStep
        }
        let xStep = a.xMax <= 20 ? 10.0 : 20.0
        var x = -a.xMax
        while x <= a.xMax + 0.001 {
            lines.move(to: CGPoint(x: px(x), y: box.minY)); lines.addLine(to: CGPoint(x: px(x), y: box.maxY))
            ctx.draw(Text(verbatim: "\(Int(x))").font(.caption2), at: CGPoint(x: px(x), y: box.maxY + 10))
            x += xStep
        }
        ctx.stroke(lines, with: .color(Tokens.textSecondary.color.opacity(0.18)), lineWidth: 1)
        ctx.stroke(
            Path { $0.move(to: CGPoint(x: px(0), y: box.minY)); $0.addLine(to: CGPoint(x: px(0), y: box.maxY)) },
            with: .color(Tokens.textSecondary.color.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
        ctx.draw(Text("analysis.disp.axisLateral").font(.caption), at: CGPoint(x: box.midX, y: box.maxY + 28))
        ctx.draw(
            Text(verbatim: "\(UnitConversion.symbol(for: kind.key, units: units))").font(.caption),
            at: CGPoint(x: box.minX - 18, y: box.minY - 2)
        )
    }

    /// The 1-SD shape: sampled around the covariance ellipse (data axes have different scales, so it is drawn point by point).
    private func ellipsePath(_ e: SpreadEllipse, px: (Double) -> CGFloat, py: (Double) -> CGFloat) -> Path {
        var path = Path()
        for i in 0 ... 72 {
            let t = Double(i) / 72 * 2 * .pi
            let along = e.semiMajorM * cos(t), across = e.semiMinorM * sin(t)
            let long = e.centreLongitudinalM + along * cos(e.angleRad) - across * sin(e.angleRad)
            let lat = e.centreLateralM + along * sin(e.angleRad) + across * cos(e.angleRad)
            let p = CGPoint(x: px(shown(lat, .lateralLanding)), y: py(shown(long, kind.key)))
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        path.closeSubpath()
        return path
    }

    // MARK: callout, legend, list

    private var callout: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(candidates, id: \.shotID) { point in
                if let shot = history.shot(point.shotID) {
                    Button { history.selectedShotID = shot.id } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("shot.number \(shot.sequence)").font(.headline)
                                Text(
                                    verbatim: "\(shot.clubSnapshot.name) · \(distanceText(point.longitudinalM))"
                                )
                                Text("provenance.estimated").font(.caption).foregroundStyle(Tokens.textSecondary.color)
                            }
                            Spacer()
                            Text("analysis.disp.openShot").font(.subheadline.bold())
                        }
                        .frame(minHeight: Spacing.minTarget)
                    }
                    .accessibilityIdentifier("analysis.disp.callout.\(shot.id.uuidString)")
                }
            }
            if candidates
                .count > 1 {
                Text("analysis.disp.overlap \(candidates.count)").font(.caption).foregroundStyle(Tokens.textSecondary.color)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .accessibilityIdentifier("analysis.disp.callout")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(result.profiles.enumerated()), id: \.element.clubID) { index, p in
                HStack(spacing: Spacing.s) {
                    let style = store.style(for: p.clubID)
                    Image(systemName: ClubPalette.symbol(style)).foregroundStyle(ClubPalette.colour(style)).accessibilityHidden(true)
                    Text(verbatim: p.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(
                        verbatim: "\(distanceText(p.mean)) · \(spreadText(p))"
                    )
                    .font(.subheadline.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("analysis.disp.legend.\(index)")
            }
        }
        .padding(Spacing.m)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }

    /// The same shots as text, for VoiceOver and anyone who prefers a list to a plot.
    private var shotList: some View {
        DisclosureGroup {
            ForEach(result.points, id: \.shotID) { point in
                if let shot = history.shot(point.shotID) {
                    Button { history.selectedShotID = shot.id } label: {
                        HStack {
                            Text(verbatim: "\(shot.clubSnapshot.name) #\(shot.sequence)")
                            Spacer()
                            Text(
                                verbatim: "\(distanceText(point.longitudinalM)) · \(lateralText(point.lateralM))"
                            )
                            .font(.body.monospacedDigit())
                        }
                        .frame(minHeight: Spacing.minTarget)
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: { Text("analysis.disp.list").frame(maxWidth: .infinity, minHeight: Spacing.minTarget, alignment: .leading) }
            .accessibilityIdentifier("analysis.disp.list")
    }
}
