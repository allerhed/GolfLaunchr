# Decisions

Product defaults live in [spec/03-decisions.md](spec/03-decisions.md). This file records engineering/tooling decisions.

| Date | Decision | Why |
|---|---|---|
| 2026-10-11 | Opus plans and reviews; Sonnet implements. Default session model is Sonnet. | Cost: planning/review is the high-judgement, low-volume work. |
| 2026-10-11 | XcodeGen (`project.yml`) generates the gitignored `.xcodeproj`. | Clean diffs for agents, no merge conflicts in pbxproj. |
| 2026-10-11 | Local SPM packages hold logic (Domain, Analytics, ...); app target holds SwiftUI only. | Fast `swift test`, agents work in small contexts. |
| 2026-10-11 | Single developer: commit and push to `main`, no PRs, no CI. `scripts/verify.sh` is the gate. | macOS CI runners cost money and add nothing for one developer. |
| 2026-10-11 | Spec split into per-feature files under `docs/spec/`; `_full.md` kept unread. | ~38k tokens per full read vs 1-3k per feature. |
| 2026-10-11 | Bundle id `com.allerhed.golflaunchr` (placeholder, brand-independent per spec section 1). | Spec requires a stable id independent of the final brand. |
| 2026-10-11 | Scripts set `DEVELOPER_DIR` to Xcode.app when `xcode-select` points at Command Line Tools. | Avoids needing sudo. |

| 2026-10-11 | The `planner` agent is the spec "coordinator" (sole owner of contract changes, with user approval). | Spec WP01 requires one contract owner. |
| 2026-10-11 | Club contract extended beyond spec section 6: `name` (= spec "label"), `brand?`, `model?`, `sortOrder`, `loftRevision`, plus `ClubSnapshot` (id, name, loftRad?, loftRevision). Resolves the F08 plan question Q1. **Pending owner confirmation** (planner role). | F08 needs brand/model/ordering; loftRevision lets future estimation know which loft a shot used. Additive, optional fields only. |
| 2026-10-11 | Shot JSON contract v1.0 is implemented exactly as the spec example (same keys, explicit nulls, UTC ISO-8601). Additive optional fields only: `Measurement.failure` (typed reason, omitted when nil) and `clubSnapshot.loftRevision`. Decoding is strict: unknown metric keys, units that do not match the metric, negative speeds/distances, value/provenance mismatches and bad schemaVersion are rejected. | Spec: "Consumers reject NaN/infinity, negative speeds/distances and invalid references." Strictness prevents silent zeros. |
| 2026-10-11 | `CalibrationRecord` field set (scale method, 3x3 transform, camera distance/height/heading, format) is provisional until the G1 capture spike; evolve via `calibrationVersion`. | Spec lists the categories but not the fields; real needs come from physical-device evidence. |
| 2026-10-11 | `Persistence` package: async repository protocols (Session, Calibration, Shot, Ledger) + `PersistenceTestSupport.InMemoryStore` fake in a separate library the app does not link. `commitAccepted(shot, ledger:)` is atomic and idempotent; production stores reject synthetic shots (T13); ledger rows survive shot/session deletion. Club/Bag repository is left to F08 (needs the Bag type). | Keeps the real store (2.1) swappable and the fake out of release builds. |
| 2026-10-11 | Shared formatting layer is the `Formatting` package (`DisplayUnits`, `UnitConversion`, `MetricFormatter`, `NumberInput`): SI in, locale-aware strings out; angles always degrees, spin always rpm; unavailable returns nil (never 0). Unit defaults follow region (US: yd/mph, else m/km/h), not language. | Spec F18/F25: one formatting layer, units separate from language, Swedish decimal comma. |
| 2026-10-11 | App shell: bottom tab bar in portrait, leading rail in landscape (chosen by view size, state in `AppNavigation` so rotation keeps selection); Home/Bag/Progress tabs, Settings via gear (sheet). Design tokens in `App/Theme` (light/dark, contrast unit-tested). Display settings (units, theme) interim in UserDefaults until `UserSettings` persistence (2.1). Language switching (F25) and handedness (F18) are not part of 0.5. | Spec 13/F22 pick one consistent navigation pattern. |
| 2026-10-11 | `Capture` package split: `Capture` (platform-free logic, tested with a fake frame source) and `CaptureAV` (iOS AVFoundation adapter, linked into the app so every verify compiles it). Timing is from presentation timestamps; a gap is an interval >= 1.5x nominal; pause/interrupt returns an incomplete window that is never promoted; frames while paused are ignored and counted. | G1 plan section 5, F04/F23. Keeps camera behaviour behind a protocol boundary until a device can exercise it. |

