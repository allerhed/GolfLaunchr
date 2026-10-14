import Domain
import Formatting
import Modes
import SwiftUI

/// Words and symbols for drill results. Every outcome carries a symbol AND words, never colour alone (F22).
struct DrillText {
    let units: DisplayUnits
    let locale: Locale

    private var formatter: MetricFormatter {
        MetricFormatter(units: units, locale: locale)
    }

    func distance(_ si: Double) -> String {
        formatter.format(si, for: .carry)?.text ?? "–"
    }

    func attempt(_ a: DrillAttempt, in config: TargetDrillConfig) -> (text: LocalizedStringKey, symbol: String) {
        if a.isHit {
            return ("drill.hit", "checkmark.circle.fill")
        }
        let distanceOK = abs(a.longitudinalErrorM) <= config.longitudinalToleranceM + 1e-9
        if distanceOK, let side = a.lateralErrorM {
            let amount = distance(abs(side))
            return side < 0 ? ("drill.miss.left \(amount)", "arrow.left.circle.fill") : (
                "drill.miss.right \(amount)",
                "arrow.right.circle.fill"
            )
        }
        let amount = distance(abs(a.longitudinalErrorM))
        return a.longitudinalErrorM < 0 ? ("drill.miss.short \(amount)", "arrow.down.circle.fill") : (
            "drill.miss.long \(amount)",
            "arrow.up.circle.fill"
        )
    }

    /// "+3.2 m" / "−3.2 m" for tables.
    func signed(_ si: Double) -> String {
        let body = distance(abs(si))
        if si == 0 {
            return body
        }
        return (si < 0 ? "−" : "+") + body
    }
}
