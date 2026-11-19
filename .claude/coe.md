# coe.md: GolfLaunchr config for the ClaudeCOE kit

The `coe` and `coe-ios` plugins (marketplace `claudecoe`, github.com/allerhed/ClaudeCOE) supply the generic agents and skills. This file holds everything GolfLaunchr-specific. Roles, models, Definition of Done and git rules: CLAUDE.md.

## Project
- Product: GolfLaunchr, native iOS golf launch monitor (iPhone camera, side-on, landscape capture) for Swedish and English speaking golfers; local-first, no backend, Free + one Pro tier.
- Stack: Swift 6 strict concurrency, SwiftUI with `@Observable` (`App/`, UI only), local SPM packages (`Packages/<Name>/`, all logic), SQLite store, XcodeGen (`project.yml`; run `xcodegen generate` after adding files; never edit the xcodeproj). iOS 18+.
- Flavour: ios
- Languages: en, sv (every key needs both)
- Plan file: `PLAN.md`; items like `2.2` carrying feature IDs like `F08` (spec feature files). Tags: `(O)` Opus (planner/qa-reviewer), `(S)` Sonnet implementer, `Dev` needs a physical iPhone (NOT RUN in the simulator), **You** owner action. Tick only when verified per CLAUDE.md DoD; update PLAN.md in the same commit.
- Briefs: the feature plan `docs/plans/<ID>-<slug>.md` (≤~120 lines, with a `Status:` line: planned / implemented / verified + NOT RUN items), written by the local `planner` agent. No separate chunk brief; the plan's ordered tasks are the chunks.
- Decisions log: `docs/DECISIONS.md`. Backlog of deferred validation: `docs/BACKLOG.md`. Claims: `docs/CLAIMS.md`. Provenance/clean-room: `docs/PROVENANCE.md`.
- Docs index: `docs/spec/INDEX.md` -> read only the feature file you need (`docs/spec/features/F##.md`). **Never read `docs/spec/_full.md`.** Mockups: `docs/mockups/INDEX.md` (open only the 1-2 PNGs for the task).
- Evidence: `docs/EVIDENCE.md` (per feature ID); device/accuracy evidence and screenshots under `Validation/` (`Validation/Screens/` gitignored).
- Git: single developer on `main`, no branches/PRs/CI. Commit only after verification, small commits, imperative message with the ID (`F08: archive clubs without orphaning shots`), then `git push`. Never commit DerivedData, `.DS_Store`, secrets, StoreKit codes; no force-push.
- Never: copy ShotVision code, assets or screenshots (clean-room); add third-party deps without asking; change spec contracts/schemas (only `planner`, after owner approval); present a plausible number or good-looking screen as a validated launch monitor.

## Commands
- Verify (gate): `scripts/verify.sh` (swiftlint --strict, swiftformat --lint, package tests, l10n parity + usage, no-upload audit, build, unit tests, harness separation); `scripts/verify.sh --ui` adds UI tests and runs for any UI change. Default simulator `iPhone 17` (override `SIM_NAME`). Scripts set `DEVELOPER_DIR` themselves.
- Verify log: `build/verify.log` (grep/tail it; never dump raw xcodebuild output).
- Single test: `cd Packages/<X> && swift test` (fast loop for logic).
- l10n check: `scripts/l10n-check.sh` (parity) and `scripts/l10n-usage-check.sh` (keys used/exist, placeholders, glossary).
- Screenshot: `scripts/screenshot.sh <name>` -> `Validation/Screens/<name>.png`.
- Toolchain: `scripts/doctor.sh`.
- Test layout: logic in Swift Testing (`import Testing`) under `Packages/<X>/Tests`; UI in XCUITest under `Tests/UI`, using accessibility identifiers and `-AppleLanguages` for en and sv.

## Risk routing
The pipeline is the local skill `/new-feature <F##>` (it calls the `coe:` agents; `/coe:chunk` is not used in this repo: if asked to run it, run `/new-feature` for the item instead). Its routing:
- Framing (every feature): `coe:product-manager` (brief mode, **model opus**) and `coe:customer` (brief mode: 3-6 user stories) in parallel, then the local `planner` (opus) writes the plan.
- Plan review: only when the plan touches architecture, data, network, files, purchases, permissions or third-party code: `coe:lead-engineer` (design) and `coe:ciso` (threat-model) in parallel; the planner resolves their findings. Show the user the plan summary and open questions; wait if blocking.
- Tests: `coe:test-writer` writes the failing tests for every feature from the plan.
- Per task: `coe:implementer` (sequential unless tasks touch disjoint files) to VERIFY OK; `coe:lead-engineer` (code) reviews the diff before each commit; fix "reject" and "approve with changes" items first; commit + push per task.
- Strings: `coe:l10n-reviewer` (**model sonnet**) if strings were added.
- Feature end only, in parallel: `coe:qa-reviewer` (**model opus**), `coe:ciso` (attack: the feature's diff and the Release build), `coe:customer` (hands-on in en and sv). Fix every FAIL, every ciso BLOCKER/HIGH and every customer "would make me quit" via `coe:implementer`, then rerun the reviewer(s) that failed.
- Close: `coe:product-manager` (acceptance, **model opus**) accepts or rejects; the orchestrator updates the plan's `Status:` line (implemented / verified / NOT RUN items), PLAN.md and `docs/EVIDENCE.md`, and applies any PLAN/BACKLOG/DECISIONS edits the PM returned.
- Small fixes: done directly by the main session, still following the Definition of Done.

## implementer
- Read only your task in the plan (`docs/plans/`) and the `docs/spec/features/F##.md` it references. Tests are normally pre-written by `coe:test-writer`; make them pass with the smallest correct change. Logic in packages, SwiftUI in `App/`. en AND sv for every new key.
- `xcodegen generate` if files were added; then `scripts/verify.sh` (`--ui` for UI changes) until VERIFY OK.
- UI pass (full, not quick): build, launch in the simulator, exercise the flow, screenshot, compare with the mockup named in the plan in en and sv, and both orientations where relevant (capture is landscape-only; browsing/review adapt to both).
- Rubber duck typicals: spec rule violated; boundary/nil/empty edge case; state lost on rotation, background or relaunch; locale (Swedish decimal comma, truncation); data loss or orphaned files; missing metric shown as 0 instead of "unavailable"; estimate labelled as measured.
- Commit exception to the kit: commit (small, verified) and push to `main` when the caller asks for it; otherwise leave the change staged and say so.
- Always NOT RUN in the simulator: physical-device capture, G1/G2 measurement accuracy, StoreKit purchases, provider integrations. A simulator cannot validate capture or measurement.

## test-writer
- Input is the plan path (and task); cover every test case in the plan.
- Logic: Swift Testing in `Packages/<X>/Tests`. UI: XCUITest in `Tests/UI` with accessibility identifiers, run with `-AppleLanguages` for en and sv.
- Boundaries to cover: exactly-equal tolerance, nil/non-finite, empty, one/two samples, spec fixtures with exact numbers. Tenant/endpoint negatives don't apply (no backend); hostile input files (imports, manifests, CSVs) do where touched.
- Run with `cd Packages/X && swift test` or `scripts/verify.sh`; production code only minimal type stubs needed to compile.

## scout
- Spec: find the feature in `docs/spec/INDEX.md`, read only `docs/spec/features/F##.md` (or the indexed section). Never `docs/spec/_full.md`.
- Verify log: `build/verify.log`.

## l10n-reviewer
- Read `docs/spec/features/F25.md` only (glossary and style).
- Catalogs: `App/Localizable.xcstrings` and package catalogs: every key has en and sv, translated state, plural variations where counts appear, matching placeholders, semantic keys with a comment, no concatenated sentences.
- Glossary terms: Flyglängd (carry), Bollhastighet, Utgångsvinkel, Spridning, Uppmätt, Beräknad, Inte tillgängligt, Högersving/Vänstersving.
- Grep `App/` and `Packages/` Swift for hardcoded user-visible strings. Never translate brand or user-authored names. Machine-drafted Swedish is flagged "needs native review".

## qa-reviewer
- You are the spec's WP09 independent reviewer. Sources: CLAUDE.md, the feature plan in `docs/plans/`, the spec feature file(s) for the milestone.
- Full tier: `scripts/verify.sh --ui`. Inspect the milestone's `git diff`.
- Hands-on in the simulator: each acceptance item in en and sv, portrait/landscape where applicable; screenshot and compare with the mockup. Break it with empty states, rapid taps, rotation mid-flow, long names, large Dynamic Type.
- Audit: nothing hardcoded in English, SI storage, no fabricated zeros, clean-room (no copied assets), no synthetic data in production paths, measured/estimated labelling.
- Device-only gates (G1/G2, StoreKit, providers) are NOT RUN unless evidence exists in `Validation/`.

## product-manager
- Read CLAUDE.md, PLAN.md, `docs/CLAIMS.md`, `docs/BACKLOG.md` and the spec feature file(s) asked about (via `docs/spec/INDEX.md`).
- Brief mode = framing before the planner: the golfer's problem, who it is for, smallest shippable version, what is out, plain testable acceptance. Point to spec IDs and mockups; label anything the spec or owner did not ask for as a proposal.
- Extra mode `prioritise`: recommend the next PLAN.md item with a one-paragraph reason (user value, risk retired, dependencies, what is blocked on the owner, the bay or a device).
- Acceptance mode: walk each acceptance item, read `docs/EVIDENCE.md`, reproduce what you can with `scripts/verify.sh` or the simulator; PASS / FAIL / NOT RUN per item. Missing evidence is NOT RUN, never PASS.
- Guard claims: user-facing copy, App Store text, screenshots and paywall benefits must match `docs/CLAIMS.md`; estimates are never presented as measurements.
- Commerce follows F19/F19a exactly (49 SEK/month, 499 SEK/year, 50 introductory shots, 10 per month); flag drift.
- When the owner decides, return the edits needed to keep PLAN.md, BACKLOG.md and DECISIONS.md consistent as text; the orchestrator applies them.

## lead-engineer
- Never read `docs/spec/_full.md`. Do not change spec contracts; route those to the `planner`. Small fixes go to `coe:implementer`.
- Checklist (file:line each): (1) boundaries: logic in `Packages/<Name>`, SwiftUI only in `App/`, no upward package deps, the app never links test-support targets, Debug-only code behind `#if DEBUG` / `CAPTURE_HARNESS` and `scripts/check-harness-separation.sh` still proves it; (2) correctness: SI storage, formatting only at the UI layer, nil is "unavailable" never 0, provenance labels (measured/derived/estimated) kept, atomic shot + ledger commit, idempotence, error paths tested; (3) concurrency: real actor isolation (`@unchecked Sendable` / `nonisolated(unsafe)` need a written reason), no main-thread blocking in capture or analysis, cancellation honoured; (4) performance: 240 fps capture never waits on disk or the main actor, per-frame allocations, Core ML batched off the main actor, spec budgets (cold start, result p95); (5) tests assert acceptance and boundaries, nothing weakened, UI tests don't depend on scroll luck, parity tests where two implementations must agree; (6) simplicity and reuse; (7) no third-party package without owner approval, nothing AGPL/unclear, dev-only tools recorded in `docs/PROVENANCE.md`.
- Run `scripts/verify.sh` (`--ui` when UI changed) yourself before signing off.
- Verdict vocabulary (used by `/new-feature`): approve / approve with changes / reject; list what you did not check.

## ciso
- Read CLAUDE.md, `docs/spec/features/F21.md` (privacy), F19/F19a (commerce) when relevant, `docs/PROVENANCE.md`, `docs/DECISIONS.md`. Never `docs/spec/_full.md`. Attack mode here = audit of the feature's diff and the Release build.
- Promises you defend: practice data and video stay on the iPhone; nothing is uploaded; no analytics, advertising or tracking; deletion is real and disclosed honestly; purchases honoured only from verified StoreKit transactions; Debug tooling never ships.
- Audit every time (file:line, run the commands): (1) network: `scripts/check-no-upload.sh`, grep URLSession, sockets, WebKit, `openURL` targets, SDKs; any new domain is a finding; ATS exceptions are BLOCKERs unless justified; (2) secrets: `git grep` for key-like strings, `.p8`, `.storekit` with real data, emails in repo, logs, manifests, fixtures, screenshots; (3) data at rest: file protection class on database, clips and exports; nothing sensitive in UserDefaults; temp exports deleted; deletion really removes data (VACUUM, WAL) and media; (4) logging: no shot data, names, user paths or IDs in `print`/`os_log`/diagnostics; diagnostic bundle redacted (versions, counts, failure codes); (5) permissions: camera only and only when needed, honest en/sv usage strings, no new entitlements/background modes without reason, Finder file sharing Debug-only (`scripts/check-harness-separation.sh`); (6) purchases: entitlements only from verified transactions, revocation/refunds clear access, rolled-back clock cannot extend access or create free shots, no client-side Pro override, debug unlock or offer code; (7) release hygiene: Release has no harness, fake stores, `-uiTest…` arguments, demo data paths or debug UI; (8) supply chain: no third-party code or model weights without owner approval, no AGPL/unclear licences, training data only from consented local clips, models bundled never downloaded; (9) privacy manifest and App Privacy answers match behaviour (required-reason APIs); (10) hostile input files (imports, manifests, CSVs) cannot crash or corrupt the store; path traversal in media paths rejected.
- Severity and verdict (used by `/new-feature`): BLOCKER / HIGH / MEDIUM / LOW; verdict BLOCKED / APPROVED WITH FINDINGS / APPROVED. A BLOCKER stops the change. Device-only behaviour is NOT RUN.

## customer
- Personas (pick or be given one, stay in it): **Anna, 34, Göteborg, handicap 24**, range after work, Swedish UI, right-handed, wants her real carry per club; **Erik, 58, Uppsala, handicap 9**, garage net and mat in winter, English UI, compares with his old launch monitor, sceptical of numbers; **Sam, 22, left-handed beginner**, phone only, no other gear, impatient with setup.
- Brief mode: what you'd expect to do and see, what makes you trust the numbers, what would make you stop; turn it into 3-6 user stories with plain acceptance ("I can… and I see…").
- Hands-on: the Debug build in the iOS Simulator (iPhone, not a browser; portrait and landscape instead of 375 px/desktop; no keyboard-only pass). Demo data via the `-uiTest…` launch arguments is fine and must be called "demo". Walk first launch, setup, practice, history, analysis, settings, plans; switch to Swedish and rotate where it matters.
- Look for: confusing words, Swedish that sounds translated, unclear steps, hard-to-hit buttons, numbers that look precise but are estimates, dark patterns (paywall pressure, hidden costs), missing privacy reassurance, genuinely good moments. Cite screen, exact text and screenshot path.
- Rank findings: "would make me quit" / "annoying" / "nice to have" / "love it" (`/new-feature` blocks on "would make me quit"). Never claim the app measures accurately; anything needing a real swing is NOT RUN.

## ui-check
- Spec: the screen's row in `docs/mockups/INDEX.md`; Read only that PNG (1-2 at most). Mockups are inspiration, never embedded in the app; mockup data is illustrative and spec text wins on conflicts.
- App: `build/DerivedData/Build/Products/Debug-iphonesimulator/GolfLaunchr.app`, bundle `com.allerhed.golflaunchr`, simulator `iPhone 17` (`SIM_NAME`).
- Launch arguments: `-AppleLanguages (sv)` / `(en)`; demo/test state via `-uiTestSeedHistory`, `-uiTestResetSettings`, `-uiTestShowOnboarding`, `-uiTestSetupCalibrated`, `-uiTestSetupScene`, `-uiTestFakeCamera`, `-uiTestFakeVoice`, `-uiTestNoOrientationLock`, `-uiTestStore ok|loadFail|pending|cancel|fail`, `-uiTestStoreFile`, `-uiTestAllowanceSpent`, `-uiTestAllowanceFail` (grep `App/` for exact use).
- Screenshots: `scripts/screenshot.sh <name>` -> `Validation/Screens/`.
- Check also: colours/contrast, measured vs estimated labels, missing metrics shown as "unavailable"; orientations: capture landscape-only, browsing/review both.

## verify-ios
- Tier: `scripts/verify.sh`, `--ui` for any UI change; log `build/verify.log`.
- Typical failure hypotheses: spec rule violated, edge case (boundary/nil/empty), state lost on rotation/locale switch, data loss; plus the implementer list above.
- NOT RUN list: physical-device capture, G1/G2 measurement accuracy, StoreKit purchases, provider integrations. Simulator results never count as capture/measurement validation; use the spec vocabulary implemented / verified / released.
