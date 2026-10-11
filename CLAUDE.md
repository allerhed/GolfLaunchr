# GolfLaunchr

Native iOS 18+ SwiftUI golf launch monitor (iPhone camera, side-on, landscape capture). English + Swedish. Local-first, no backend. Clean-room: original code/assets only; never copy ShotVision code, assets or screenshots.

## Where things are
- Spec (authoritative, split): `docs/spec/INDEX.md` -> read **only** the feature file you need (`docs/spec/features/F##.md`). **Never read `docs/spec/_full.md`** (38k+ tokens).
- Mockups: `docs/mockups/INDEX.md` -> open only the 1-2 PNGs for the task. They are inspiration, never embedded in the app.
- Decisions: `docs/DECISIONS.md`. Plans: `docs/plans/<ID>-<slug>.md`. Device/accuracy evidence: `Validation/`.
- Code: `App/` (SwiftUI only) + `Packages/<Name>/` (logic, local SPM, `swift test` fast). New logic goes in a package, not the app target. Spec layout in `docs/spec/10-work-packages.md`.
- `project.yml` (XcodeGen) generates the gitignored `GolfLaunchr.xcodeproj`. After adding files: `xcodegen generate`. Never edit the xcodeproj.

## Commands
```bash
scripts/doctor.sh          # toolchain check
scripts/verify.sh          # THE GATE: package tests, l10n parity, build, unit tests (quiet output)
scripts/verify.sh --ui     # + UI tests (run for any UI change)
scripts/screenshot.sh name # simulator screenshot -> Validation/Screens/ (gitignored)
cd Packages/X && swift test   # fast loop while developing logic
```
Scripts auto-set `DEVELOPER_DIR` to Xcode.app (xcode-select points at CLT). Default simulator `iPhone 17` (override `SIM_NAME`). Don't dump raw xcodebuild output; read `build/verify.log` with grep/tail.

## Code rules
- Swift 6 strict concurrency, `@Observable`, async/await, no force-unwraps/`try!`, no third-party deps without asking.
- All user-visible text via String Catalog keys (`App/Localizable.xcstrings`, semantic keys like `home.title`, with comment). en **and** sv for every key; no concatenated sentences. `scripts/l10n-check.sh` enforces.
- Store SI units/UTC; format only at the UI layer. Missing metric = nil/"unavailable", never 0. Label measured vs estimated (spec F06).
- Accessibility: Dynamic Type, VoiceOver labels, 44pt targets, `accessibilityIdentifier` on elements UI tests touch.
- Capture is landscape-only; browsing/review adapt to both orientations.
- Fixtures/demo data only in test or clearly labelled demo paths; no synthetic events in production code.

## Agents (model routing: Opus thinks, Sonnet types)
Session default is Sonnet. Delegate with the Agent tool:
| Agent | Model | Use for |
|---|---|---|
| `planner` | opus | Turn feature ID(s) into `docs/plans/*.md`: scope, files, contracts, test cases, mockup refs. Only role allowed to change spec contracts/schemas. |
| `swift-test-writer` | sonnet | Write failing tests from acceptance criteria first (TDD). |
| `ios-implementer` | sonnet | Implement one plan item until `scripts/verify.sh` passes. |
| `l10n-reviewer` | sonnet | en/sv completeness and Swedish terminology (spec F25 glossary). |
| `qa-reviewer` | opus | Independent milestone review: reproduces everything, never trusts implementer summaries. |
Flow: `planner` -> `swift-test-writer` -> `ios-implementer` -> (milestone) `qa-reviewer`. Skill `new-feature` runs it. Small fixes: do directly, still follow Definition of Done. Give agents the plan path and feature IDs, not pasted spec text.

## Definition of Done (mandatory)
Never report a UI change or function as complete because an edit succeeded or the build compiles. Verify it as a human reviewer would:
1. **Test cases first**: derive from the feature's Acceptance section (including edge cases, boundaries, null/empty); write them and see them fail.
2. Implement. 3. `scripts/verify.sh` (add `--ui` for UI).
4. **UI changes**: run in the simulator (iOS Simulator tool), exercise the flow by tapping/typing, screenshot, compare to the mockup in both en and sv and both orientations where applicable.
5. **Rubber duck**: write down 3+ ways it could still be wrong (spec rule violated, edge case, state/rotation/locale, data loss) and check each by running something, not by re-reading code.
6. **Any failure -> fix and rerun from step 1.** Do not hand back partially verified work.
7. Report with evidence (commands, test counts, screenshot paths). Use the spec vocabulary: *implemented / verified / released* are different; anything not executed, especially physical-device capture, G1/G2 measurement accuracy, StoreKit and provider integrations, is **NOT RUN** and said so. A simulator cannot validate capture or measurement.
Never call a plausible number or good-looking screen a validated launch monitor.

## Git (single developer)
Work on `main`; no branches/PRs/CI. Commit only after verification passes, small commits, imperative message (`F08: archive clubs without orphaning shots`), then `git push`. Never commit DerivedData, `.DS_Store`, secrets, StoreKit codes. No force-push or history rewrite. Commit trailers per session attribution.

## Token discipline
Read by feature ID, grep before reading, read line ranges, don't re-read files you just edited, view images sparingly, use Explore/search agents for broad sweeps, keep one feature per session and `/clear` between them, put durable context in `docs/plans/` not chat.
