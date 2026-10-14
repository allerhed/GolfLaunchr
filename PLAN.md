# GolfLaunchr delivery plan

Deferred validation (device, bay, human reviews, owner decisions) is collected in `docs/BACKLOG.md`.

Tick `[x]` only when the item is **verified** per CLAUDE.md Definition of Done (tests + simulator/device evidence, committed, pushed). `NOT RUN` items stay unchecked. Update this file in the same commit that completes an item.

**Legend.** Model: **O** = Opus (planner/qa-reviewer), **S** = Sonnet (implementer). **Dev** = needs a physical iPhone. **You** = needs the owner (accounts, money, real-world action). Every feature slice runs the `new-feature` skill: planner -> swift-test-writer -> ios-implementer -> l10n-reviewer -> (milestone) qa-reviewer. Plan files: `docs/plans/<ID>-<slug>.md`.

**Critical path.** The real risk is measurement, not UI (spec section 0). Phase 1 (physical-device capture spike) starts immediately and runs in parallel with fixture-driven phases 2-4. Phases 5+ need real measurement. A release without gate G2 is a research prototype and cannot ship as a "launch monitor".

Gates (spec 08): G0 requirements, G1 capture feasibility, G2 measurement qualification, G3 core product, G4 mode breadth, G5 integrations, G6 release.

---

## Phase 0 - Foundation (done in setup)
- [x] Repo, split spec, CLAUDE.md, agents, skills, scripts, XcodeGen skeleton, Domain + Analytics packages, en/sv smoke tests, verify gate proven
- [x] Developer team + certificates configured in Xcode (team ID kept in `project.yml` so regeneration keeps it)
- [x] SwiftLint + SwiftFormat installed
- [x] 0.1 (S) Add `.swiftlint.yml` and `.swiftformat` (Swift 6, sensible limits); make `verify.sh` run `swiftlint --strict` and fail on warnings; fix findings
- [x] 0.2 (O) G0: `docs/CLAIMS.md` (capability/claim list: what we may and may not claim), `docs/EVIDENCE.md` (template for evidence per feature ID), provenance/clean-room statement (`docs/CLAIMS.md`, `docs/EVIDENCE.md`, `docs/PROVENANCE.md`; owner sign-off on the attestation still pending)
- [x] 0.3 (S) Data-model contracts from spec 06 as typed Swift in `Domain` (Shot, Measurement w/ provenance, Club, Session, CalibrationRecord, ledger entry, ids as UUID); JSON shot contract + round-trip tests. Planner resolves the Club contract question from F08 plan (brand/model, sortOrder, label vs name)
- [x] 0.4 (S) `Persistence` package: repository protocols + in-memory fake for tests (real store in 2.1)
- [x] 0.5 (S) App shell: navigation (portrait tab bar, landscape rail), design tokens, dark/light theme, Dynamic Type, shared formatting layer (units m/yd, m/s/km/h/mph; en/sv locale; Swedish decimal comma) - F22, F18 formatting part

## Phase 1 - Capture feasibility spike (G1) - start in parallel with Phase 0.3+
Research-grade; physical iPhone required. Opus plans each experiment; Sonnet builds harnesses; **You** run them and attach traces.
- [x] 1.1 (O) Plan spike: candidate formats (240/120 fps, lens, exposure), side-on geometry per spec 14, data to record, pass criteria (`docs/plans/G1-capture-spike.md`)
- [x] 1.2 (S, Dev) `Capture` package: AVFoundation session, format selection, PTS-timestamped ring buffer, dropped-frame accounting, thermal + exposure logging (F04, F23)
  - D1 passed 2026-10-11 on iPhone 17 Pro Max (see `docs/EVIDENCE.md`, `Validation/DeviceReports/D1-smoke-2026-10-11/`): ultra-wide 1080p240 held at 239.9 fps, clips decode with every PTS, manifests match the files. Known defects go to 1.3a.
- [x] 1.3 (S, Dev) Debug-only capture harness screen: record raw impact windows to files + manifest for offline analysis (compile-time separated from production)
  - Harness verified on device (D1). Defects found by D1 are tracked in 1.3a below.
- [x] 1.3a (S, Dev) Harness fixes from D1 (before 1.4): (1) ignore motion for ~1.5 s after Start (startup auto-exposure and stream start-up fired triggers that gave short windows with a 10-13 frame gap); (2) manifest drop counts per window, not per run, plus run totals; (3) record device orientation (CoreMotion) and lens/format in the manifest, and warn when not landscape; (4) manual exposure control (fixed duration 1/1000-1/4000, ISO limit, lock after ball lock) with the applied values logged; (5) cut per-frame callback cost (exposure property reads every Nth frame) and re-measure steady-state single-frame drops (currently about 0.2-0.5 per second); (6) log encoder queue depth and output frame sizes; (7) ship the analysis probe as part of 1.5
  - Done 2026-10-12. Biggest fix: the camera now queues late frames instead of discarding them (`discardLateFrames = false`): wide lens 1/2000 s run went from 61 missing frames to one 14-frame start-up gap, and windows from 0.05-0.7% loss to 0 of 3,848 frames in two runs. Still to do in the home rehearsal (not blocking the tick): 10-minute run, motion trigger on device, effect of touching the screen. Light is the open problem: see EVIDENCE.
- [ ] 1.4 **You**: record real shots on device across lighting/speeds/clubs (indoors + range); copy to `Validation/DeviceReports/`
- [x] 1.5 (S) Offline analysis tooling (Swift CLI/test target) to run detectors against recorded clips
  - Done 2026-10-12: `Packages/Analysis` (library `Analysis` + macOS tool `g1-analyze`). Run: `swift build -c release --package-path Packages/Analysis && Packages/Analysis/.build/release/g1-analyze <clip.mov> --manifest <clip.json> [--json out] [--annotation-template out.json --annotator id]`.
- [ ] 1.6 (O) G1 review: do recordings contain enough trajectory evidence? Declare initial speed/light envelope and supported device profiles, or stop/re-scope. **Decision point for the owner**

## Phase 2 - Data and domain core (fixtures, no camera) - WP04
- [x] 2.1 F20 Persistence, ledger, recovery: real store (SwiftData or SQLite), atomic accepted-shot + ledger write, migrations, orphan-file recovery
- [x] 2.2 F08 My Bag (plan exists: `docs/plans/F08-my-bag.md`)
- [x] 2.3 F10 Sessions and history: list, filters, exclusion/restore, confirmed delete, transactional recompute
- [x] 2.4 F09 + F10a analytics in `Analytics`: mean/median/SD/P10/P90, club averages, gapping, dispersion maths, multi-club filter contract (spec fixtures 224/160/130/110, 120/130/140)
  - Done 2026-10-12 (logic only; the Averages/Gapping/Dispersion screens and filter sheet are UI work, not yet in the plan as an item: see `docs/BACKLOG.md` E10). Evidence: `docs/EVIDENCE.md` 2.4.
- [x] 2.5 F17 Export: CSV (formula-escaped, SI) and JSON v1, round-trip tests
  - Done 2026-10-12 (data layer only; the Export screen and share sheet are UI work, see `docs/BACKLOG.md` E11). Evidence: `docs/EVIDENCE.md` 2.5.
- [x] 2.6 **Milestone QA** (O): data layer review incl. crash/kill atomicity tests
  - Done 2026-10-12 as a self-review (no separate Opus agent was spawned): see `docs/EVIDENCE.md` 2.6 for what was and was not independent.

## Phase 3 - Measurement and flight (G2) - WP03; depends on Phase 1 evidence
- [ ] 3.1 (O) Plan measurement method from G1 findings: geometry, calibration math, uncertainty approach (`docs/plans/G2-measurement.md`)
- [ ] 3.2 F03 Calibration + ball-lock state machine (`Capture`/`Measurement` packages), versioned calibration records, invalidation on movement/format change
- [ ] 3.3 F04 Strike detection, single accepted shot, rejection reasons, state machine from spec 07
- [ ] 3.4 Measurement pipeline: ball speed, launch angles with uncertainty, provenance labels; unavailable metrics stay unavailable (F06)
- [x] 3.5 `Flight` package: deterministic carry/total/apex model, standard + pressure-adjusted atmosphere, versioned (F06, F18 environment)
  - Done 2026-10-12 as unvalidated engineering (`flight-0.1-unvalidated`), done ahead of 3.1 because it needs no G1 data. Coefficients are generic; G2 must fit/validate them. Total distance deliberately not produced. Evidence: `docs/EVIDENCE.md` 3.5.
- [ ] 3.6 **You**: collect paired reference data (calibrated launch monitor) per spec 08 scientific validation design; store in `Validation/AccuracyReports/`
- [ ] 3.7 (O) G2 report: held-out evaluation, per-metric pass/fail. Failed metrics ship as unavailable or labelled Experimental. **Decision point**

## Phase 4 - Product UI (fixtures first, then real input) - WP05, WP10
- [x] 4.1 F01 Onboarding + device qualification (Supported/Experimental/Unsupported), handedness, permissions, units
  - Done 2026-10-12 on the simulator with test doubles; real-device camera/permission check NOT RUN. Evidence: `docs/EVIDENCE.md` 4.1.
- [x] 4.2 F02 Setup tutorial + environment checks (top-down diagrams, brightness/blur/flicker, test setup without credit)
  - Done 2026-10-12 on the simulator with fake scenes; the live camera observer and all thresholds are NOT RUN on a device. Calibration itself (3.2) does not exist yet, so the calibration blockers act on a placeholder state. Evidence: `docs/EVIDENCE.md` 4.2.
- [x] 4.3 F05 Home, mode chooser, Standard practice, QuickShot (mockups 03, 20), landscape capture layout and rotate-gate
  - Done 2026-10-12 as fixtures-first UI: no production shot source exists yet (5.3), so only Debug demo shots can be accepted; target carry and shot goal are in the state machine but have no UI. Evidence: `docs/EVIDENCE.md` 4.3.
- [x] 4.4 F07 Spoken feedback (AVSpeechSynthesizer, en/sv voices, bounded queue)
  - Done 2026-10-12 with a silent test double; the real system voice, audio routing and headphone unplug are NOT RUN on a device. Evidence: `docs/EVIDENCE.md` 4.4.
- [x] 4.5 F18 Settings: language, handedness, units, voice, atmosphere, privacy
  - Done 2026-10-12/13 for language, swing side, units, theme, voice, atmosphere and a privacy statement. Replay retention (needs Phase 5), delete/export privacy actions (6.5) and automatic barometer readings are NOT built. Evidence: `docs/EVIDENCE.md` 4.5.
- [x] 4.6 F10a screens: shot detail, club averages, club profile, gapping, dispersion, filter sheet (portrait + landscape)
  - Done 2026-10-13 on the simulator with demo data; zoom/reset and the Pro entitlement gate are NOT built. Evidence: `docs/EVIDENCE.md` 4.6.
- [x] 4.7 F25 Localisation pass: complete en/sv catalogs, glossary, pseudo-localisation + max Dynamic Type layout tests; **You**: native Swedish review
  - Done 2026-10-13 except the native Swedish review (yours, backlog H1) which stays open. Evidence: `docs/EVIDENCE.md` 4.7.
- [x] 4.8 F22 Accessibility audit: VoiceOver, Reduce Motion, 44pt targets, colour-independence
  - Done 2026-10-13 in the simulator (Apple audit + own label/44pt checks, en light and sv dark). Real VoiceOver and largest text on the device remain open (backlog). Evidence: `docs/EVIDENCE.md` 4.8.
- [x] 4.9 **Milestone QA** (O): all screens vs mockups, en/sv, both orientations
  - Done 2026-10-13 on the simulator by the implementing session (not an independent reviewer). Evidence: `docs/EVIDENCE.md` 4.9.

## Phase 5 - Impact replay and media (needs Phase 1/3) - F16
- [ ] 5.1 Media package: impact package (frames + manifest, still, deterministic composite), atomic finalise, pending/complete/partial/failed states, recovery, storage checks
- [ ] 5.2 Replay UI: scrub, frame-step on PTS, composite/still/original tabs, share image (mockups 06, 14, 21)
- [ ] 5.3 Real capture end-to-end wiring: camera -> detection -> measurement -> persistence -> UI -> voice (replace fixture provider with production provider)
- [ ] 5.4 **Dev** G3 walkthrough: full practice session on device, kill/relaunch, low-storage, interruption, thermal
- [ ] 5.5 F23 Instruments: SLOs on each certified profile (cold start <3 s, result p95 <=3 s, 30-min session, no leaks); **You** run, attach traces

## Phase 6 - Commerce and privacy - WP07
- [ ] 6.1 **You**: App Store Connect app record (bundle id `com.allerhed.golflaunchr` unless brand changes), Pro subscription group, Monthly 49 SEK + Annual 499 SEK, StoreKit configuration file for local testing
- [x] 6.2 F19 Allowance ledger: 50 intro shots, 10/month, idempotent resets, clock-rollback safety, arming-time reservation (heavy unit tests on boundaries 49/50/51, 9/10/11)
  - Done 2026-10-13 (rules, tests, Home line and arming gate on the simulator). The StoreKit entitlement (6.3) and real ledger writes from capture (5.3) are NOT built. Evidence: `docs/EVIDENCE.md` 6.2.
- [x] 6.3 F19 StoreKit 2: products, purchase/restore/manage, verified entitlements, offline revalidation window, paywall + plan comparison + exhausted screens
  - Done 2026-10-14 against the local StoreKit configuration in the simulator. Sandbox/TestFlight purchases, App Store Connect products and a real refund are NOT RUN (6.1, 6.6). Evidence: `docs/EVIDENCE.md` 6.3.
- [x] 6.4 F19a Offer-code redemption UI + complimentary display + partner runbook (`docs/PARTNER_ACCESS.md`); **You** create offers in App Store Connect
  - Done 2026-10-14 for the app side and the runbook (`docs/PARTNER_ACCESS.md`). Creating offers in App Store Connect and every sandbox/device redemption test remain yours / NOT RUN. Evidence: `docs/EVIDENCE.md` 6.4.
- [x] 6.5 F21 Privacy: delete all/media-only, export-before-delete, redacted diagnostics bundle, no-upload network audit; owner approves retention wording
  - Done 2026-10-15 in the simulator. Owner still approves the retention wording and the trial-identity policy (backlog H4). Evidence: `docs/EVIDENCE.md` 6.5.
- [ ] 6.6 Sandbox + TestFlight purchase tests on device (new, active, expired, refund, overlap); attach evidence
- [ ] 6.7 **Milestone QA** (O)

## Phase 7 - Mode breadth (G4) - WP06
- [ ] 7.1 F11 Target drill
- [ ] 7.2 F12 Ladder drill (resumable, event-sourced)
- [ ] 7.3 F13 Driving range + challenges (original virtual range, personal bests)
- [ ] 7.4 F14 Skill tracking
- [ ] 7.5 F15 Native virtual golf: original fictional courses, rules engine, auto-putt, save/resume, original art (**You**: approve art direction)
- [ ] 7.6 **Milestone QA** (O) and G4 device check with real shots

## Phase 8 - Integrations (G5) - WP08, optional for first release
- [ ] 8.1 **You**: choose a provider with documented protocol and licence access; without this, F15 external stays out of scope and is not advertised
- [ ] 8.2 Adapter, setup UI, reconnect/duplicate-event tests, real provider session evidence

## Phase 9 - Hardening and release readiness (G6) - WP09
- [ ] 9.1 (O) Independent full QA pass (`qa-reviewer`): T01-T22 from spec 08, en and sv, both orientations; evidence table per feature ID in `docs/EVIDENCE.md`
- [ ] 9.2 Device matrix: **You** test every claimed iPhone model; support list generated only from passing profiles
- [ ] 9.3 Security/privacy review: permissions strings (en/sv), Privacy Manifest (`PrivacyInfo.xcprivacy`), App Privacy answers, no data leaves device
- [ ] 9.4 Performance and battery/thermal review on device; crash-free soak
- [ ] 9.5 Licence/provenance audit: all assets original, third-party deps listed, no ShotVision material
- [ ] 9.6 Final scope statement: precise list of shipped vs omitted features (release without G4/G5 is "core launch monitor" only)

## Phase 10 - App Store launch
- [ ] 10.1 **You**: decide final brand name/trademark and domain; name/subtitle within 30 chars per locale (spec 01); keep bundle id stable
- [ ] 10.2 (S) App icon (original; 2026-10-12: icon added from owner-supplied artwork, see PROVENANCE, rights to be confirmed), launch screen, marketing/version/build numbers, `Release` config
- [ ] 10.3 (S) Screenshots for required iPhone sizes in en + sv generated from the real app (shipping behaviour only), via UI-test screenshot script
- [ ] 10.4 (S+O) Store metadata en/sv: description, keywords (no competitor names), promo text, what's new, support URL, privacy policy URL (**You**: host pages; Swedish native review)
- [ ] 10.5 **You**: Age rating, App Privacy nutrition labels, export compliance, EU DSA trader status, tax/banking agreements, subscription review info
- [ ] 10.6 Archive and upload: signing, `xcodebuild archive` + upload (via Xcode Organizer or `xcrun altool`/Transporter)
- [ ] 10.7 TestFlight internal test, then external beta with real golfers; triage feedback (loop through relevant phases)
- [ ] 10.8 App Review submission (with demo/review notes explaining camera setup, test account not needed), respond to reviewers
- [ ] 10.9 Release (manual release after approval); post-launch monitoring: crash reports (Xcode Organizer), reviews, support inbox
- [ ] 10.10 Retrospective: update `docs/DECISIONS.md`, backlog for v1.1 (e.g. additional devices, spin work, Apple Watch is out of scope per spec)

---

## How we work through this
1. Pick the next unchecked item (or a phase) and say "do 2.2". I run `new-feature` for it.
2. Each item ends only with VERIFY OK + evidence, commit, push, and the box ticked here.
3. Opus (planner) at the start of each phase and at each milestone QA; Sonnet for the rest.
4. Owner (**You**) items are tracked here too; I will remind you when work is blocked on one.
5. Phases 0, 1 (build part) and 2 can start now in parallel; Phase 3 waits for 1.6; Phases 5-7 wait for 3.7 for anything claiming real measurement.
