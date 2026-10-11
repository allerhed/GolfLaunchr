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

