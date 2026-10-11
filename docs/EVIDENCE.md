# Evidence

Records proof for each feature ID. Rule (CLAUDE.md, spec F24): a feature is **verified** only with evidence here; anything not executed is **NOT RUN** and says so. Evidence is appended in the same commit that ticks the PLAN.md item. Never delete failed runs: mark them superseded and link the fix.

Storage: bulky artefacts (screenshots, traces, clips, reports) live under `Validation/` (`Validation/Screens/` is gitignored, `Validation/DeviceReports/` holds device traces, reports go in `Validation/AccuracyReports/`). This file holds the index and the verdict, not the blobs.

## Status vocabulary

`NOT RUN` -> `IMPLEMENTED` -> `VERIFIED` (automated + simulator) -> `VALIDATED` (physical device / G2) -> `RELEASED`. A simulator can never produce VALIDATED for capture or measurement. Use only these words.

## Per-feature record (copy this block under "Records" for each feature ID)

```markdown
### <ID> <title>  (PLAN item <n.n>)
- **Status:** NOT RUN | IMPLEMENTED | VERIFIED | VALIDATED | RELEASED
- **Date / commit:** YYYY-MM-DD, <short sha> (code), <short sha> (evidence)
- **Spec:** docs/spec/features/<ID>.md, tests <T##,...>, plan docs/plans/<ID>-<slug>.md
- **Build:** Xcode <ver>, iOS <ver>, scheme, configuration, build number
- **Environment:** Simulator <name, OS> | Device <model, OS, lens/format, build id>
- **Automated:** `scripts/verify.sh [--ui]` -> result, test counts (pass/total), log `build/verify.log` excerpt
- **Acceptance mapping:** one row per Acceptance criterion -> test name / manual step -> PASS | FAIL | NOT RUN
- **UI evidence:** screenshots `Validation/Screens/...` for en + sv, portrait + landscape where applicable, compared with mockup <file>
- **Physical-device result:** PASS | FAIL | NOT RUN (+ trace/clip path)
- **Rubber duck (>=3):** failure mode -> how it was checked by running something -> result
- **Unresolved defects:** none | list with severity
- **Verdict:** one line, using the status vocabulary
```

| Acceptance criterion | Evidence (test / step / artefact) | Result |
|---|---|---|
| ... | ... | PASS / FAIL / NOT RUN |

## Measurement evidence (G1 / G2 only)

For each device profile and stratum (lighting, speed band, club category, handedness). From spec 08; every attempted strike is recorded, including misses and rejects.

- Device model, OS, build id, lens/format/fps/exposure
- Reference instrument: make, model, firmware, mode, metric definitions, uncertainty, environmental normalisation; carry definitions checked for match
- Dataset: golfer/session ids, consent, licence, counts attempted / accepted / rejected, split (development / validation / held-out by golfer+session, never adjacent frames); >=10 golfers in final evaluation or disclosed shortfall
- Results per metric: detection recall, false accepts per hour (with hours tested), availability rate, signed bias, MAE, median and p95 absolute error, error by speed/club/light/device/handedness, uncertainty coverage, sample sizes and confidence intervals
- Verdict against the targets in spec 08 (owner-approved before G2)
- Artefacts: raw clips + manifests, analysis script version, report path

## Gate checklist

| Gate | Pass condition (spec 08) | Evidence | Status |
|---|---|---|---|
| G0 Independent requirements | Spec adoption, provenance, capability claim list; no borrowed code/assets | `CLAIMS.md`, `PROVENANCE.md`, this file | Docs complete; owner sign-off pending |
| G1 Capture feasibility | Genuine events, enough trajectory evidence across declared envelope | not started | NOT RUN |
| G2 Measurement qualification | Frozen models, held-out paired dataset, accuracy report | not started | NOT RUN |
| G3 Core product | F01-F10, F16-F25 automated + human paths | not started | NOT RUN |
| G4 Mode breadth | F11-F14 + native F15 with real input | not started | NOT RUN |
| G5 Integrations | Each claimed provider proven | not started | NOT RUN |
| G6 Release | Evidence bundle, final scope statement | not started | NOT RUN |

## Records

Phase 0 (foundation, tooling; no feature IDs):

### 0.1 SwiftLint strict + SwiftFormat lint in verify gate
- **Status:** VERIFIED (tooling). Commit `30f1adf`. Physical-device: not applicable.

### 0.3 Domain data-model contracts  (PLAN item 0.3)
- **Status:** VERIFIED (package + app gate). Physical device: not applicable (pure data types).
- **Date / commit:** 2026-10-11, see git log for `0.3:`.
- **Spec:** `docs/spec/06-data-model.md`; tests T02/T04/T08/T14/T16 groundwork only (no repository/export yet).
- **Automated:** `scripts/verify.sh` -> VERIFY OK; `swift test` in `Packages/Domain` -> 32 tests in 4 suites, all pass.
- **Acceptance mapping:** spec JSON example decodes and round-trips (ShotContractTests); encoded keys equal the fixture's keys; missing metric stays nil not 0; NaN/inf, negative speeds/distances, unit/provenance mismatch, unknown metric/mode/schema, bad UUID, sequence 0, bad convention, bad environment all rejected (14 table cases); Session/Calibration/Ledger/Club round-trip; ClubSnapshot is a value copy (T08 basis).
- **Rubber duck:** (1) vacuous rejection cases: guard test asserts each substitution matches the fixture, and it caught one bad case, fixed; (2) tests could pass with validation removed: mutation (deleted the negative-value check) made 2 tests fail, then restored; (3) null vs omitted: encoding test asserts explicit `null` for value/uncertainty95/loftRad/mediaId; (4) fractional-second impact time lost by plain ISO-8601: custom coder, tested to <0.5 ms.
- **Not covered / NOT RUN:** persistence, export (CSV), ModeEvent/ShotMedia/ClubProfile/UserSettings/entitlement entities (later items), synthetic-shot rejection at repository boundary (T13, needs 0.4).
- **Verdict:** VERIFIED.

### 0.4 Persistence protocols + in-memory fake  (PLAN item 0.4)
- **Status:** VERIFIED (package + app gate). Physical device: not applicable.
- **Date / commit:** 2026-10-11, see git log for `0.4:`.
- **Automated:** `scripts/verify.sh` -> VERIFY OK; `swift test` in `Packages/Persistence` -> 15 tests in 2 suites, all pass.
- **Acceptance mapping:** T02 duplicate/concurrent commit (20 parallel commits -> 1 shot, 1 credit); T03 in-memory part (injected fault after shot staged / after ledger staged -> nothing stored, retry commits once); T09 exclude/restore/delete keep ledger, session delete cascades shots only; T13 production store rejects synthetic shots; invalid references, sequence collision, ledger mismatch, conflicting duplicate all rejected with no partial write.
- **Rubber duck:** (1) atomicity test could pass vacuously: mutation (write shot straight to live state) -> 17 issues, restored; (2) synthetic guard test: first mutation did not apply (formatter had wrapped the line), caught by noticing the run still passed; redone, 3 issues, restored; (3) concurrency: actor + 20-task group test; (4) deletion giving free credits: tested ledger survives shot and session delete.
- **NOT RUN:** real crash/kill atomicity and migrations (need the real store, item 2.1); media files and orphan recovery; Club repository (F08).
- **Verdict:** VERIFIED.

### 0.5 App shell, design tokens, formatting layer  (PLAN item 0.5; F22, F18 formatting, F25 numbers)
- **Status:** VERIFIED on iPhone 17 simulator (iOS, Xcode.app). Physical device: NOT RUN. VoiceOver walkthrough on device: NOT RUN.
- **Date / commit:** 2026-10-11, see git log for `0.5:`.
- **Automated:** `scripts/verify.sh --ui` -> VERIFY OK. `Packages/Formatting` 14 tests (conversion round trip T01 for all 13 metrics x 3 unit sets, known values, sv decimal comma, grouping, nil-never-zero, parse incl. U+2212 minus, garbage rejected). App unit tests: WCAG AA contrast >= 4.5:1 for every text token pair in light and dark, settings persistence/reset/corrupt fallback, navigation state. UI tests (10 incl. 2 pre-existing): portrait tab bar en/sv, landscape rail replaces tab bar, rotation keeps selected tab both ways, rail targets >= 44 pt, unit change updates examples (en `109 yd`, `67.1 mph`; sv `67,1 mph`), settings persist across relaunch, largest accessibility text keeps nav and Done hittable in both orientations.
- **Visual review (simulator screenshots, `Validation/Screens/0.5/`, gitignored):** en light and sv dark, portrait and landscape, Home/Bag/Settings. Findings fixed during review: example values were oversized (font), Settings sheet used system grey instead of the palette (now themed per section). Mockups not compared pixel for pixel: this item is shell only, Home content is a skeleton.
- **Rubber duck:** (1) mutated unit factor (yd 0.9144 -> 0.9) and the minus-sign code point: tests failed both times, restored; (2) first Swedish UI expectation was wrong (`108 km/h` vs `108,0 km/h`): the formatter is right (speed 1 decimal), test corrected; (3) rotation could reset tab: UI test rotates twice and checks content; (4) landscape screenshots come out rotated from XCUIScreen: rotated for review only.
- **Tooling note:** the iOS Simulator MCP tool was unusable (xcode-select points at CLT; needs sudo); verification used XCUITest on the simulator via `xcodebuild`, with screenshots captured by a skipped-by-default test.
- **NOT RUN / out of scope:** language override System/English/Svenska (F25), handedness (F18), Dynamic Type visual check beyond the XXXL navigation test, Reduce Motion, pseudo-localisation, native Swedish review, real Home content, capture shell (no rail during capture), physical device.
- **Verdict:** VERIFIED (simulator).

### 1.1 G1 capture spike plan  (PLAN item 1.1; document only)
- **Status:** plan written (`docs/plans/G1-capture-spike.md`). Nothing recorded or measured: G1 stays **NOT RUN**.
- **Checked:** feasibility numbers recomputed with a script (view width, travel per frame, blur); every spec reference and item number in the plan exists; hypotheses H1-H8 and criteria P1-P10 are labelled proposals needing owner approval.
- **Verdict:** planned, not executed. Items 1.2-1.6 follow; 1.4 needs you and a physical iPhone.

### 1.2 Capture package  (PLAN item 1.2; F04, F23) - PARTIAL
- **Status:** logic VERIFIED (macOS `swift test`, 34 tests in 6 suites + full `scripts/verify.sh`). AVFoundation adapter (`CaptureAV`): **IMPLEMENTED, compile-checked only (iOS simulator build). NOT RUN on a device.** Plan item 1.2 stays unchecked until D1 (smoke recording) passes.
- **Covered (G1 plan U1-U5):** format ranking/rejection incl. 120 fps boundary and unknown FOV; frame clock (perfect pacing, 1 and 3 missing frames, +/-10% jitter, 1.5x boundary, repeated/backwards PTS, unknown-vs-perfect); dropped frames counted by reason, never as frames; ring buffer by count and bytes, oversized frame refused, 8-producer concurrent stress; trigger window pre/post in PTS order, gaps inside window visible, pause => incomplete window, resume is a new timing reference, bounded over 5000 frames; manifest round trip with unknowns staying nil; thermal log stores changes only; exposure log bounded.
- **Rubber duck:** (1) gap threshold mutated 1.5 -> 2.5: 6 failures, restored; (2) non-monotonic guard removed: first attempt did not apply (formatter had reflowed the line, test still passed so I checked), redone: failure, restored; (3) two initial test failures were test mistakes (JSON escapes `/`; byte limit arithmetic), not code defects; (4) AV adapter correctness cannot be argued from compilation: real session setup, applied-format lock, drop reasons and sample-buffer delivery are unproven.
- **NOT RUN:** everything on a physical iPhone: format enumeration on real devices, 240 fps hold, drop-reason attachment strings, stabilisation off, rotation angle, permission flow, memory/thermal (F23), harness UI (1.3).
- **Verdict:** partial. Do not report capture as working.

### 1.3 Debug capture harness  (PLAN item 1.3; F04/F23 groundwork) - PARTIAL
- **Status:** simulator-verified for layout, labelling, no-camera handling and build separation. **Recording, encoding, clip writing and the live readouts have never run on a camera: NOT RUN.** The app (Debug) was built, signed and installed on the owner's iPhone 17 Pro Max; launch was refused because the phone was locked, so no on-device result exists. Item 1.3 stays unchecked until D1 passes.
- **Automated:** `scripts/verify.sh --ui` passes: Capture package 44 tests (motion detector incl. inclusive threshold boundary, cooldown, size change; manifest builder incl. window-filtered exposure and incomplete flag; clip naming), harness UI tests (banner "Not shipped", no-camera state, Start disabled, works in landscape, closes back to Settings), release separation check.
- **Separation proof:** Debug app contains 32 harness strings, Release 0. Negative control: a Release build forced with `CAPTURE_HARNESS` showed 14 hits, so the check can fail. The Debug positive control is built into the script.
- **Visual review:** simulator screenshots (portrait and landscape, gitignored). Found nothing to fix beyond the fixes already made (a lint pass, a lazy-list scroll in the UI test).
- **Rubber duck:** (1) harness leaking into Release: separation check with positive and negative control; (2) raw buffers starving the capture pool: design holds only compressed frames, but this is an argument, not a measurement; real-time all-intra HEVC at 240 fps is unproven on-device; (3) clip cannot start with a key frame: all-intra by construction, unproven; (4) the harness could be mistaken for the product: banner on screen, no Shot/credit/measurement created, UI tests assert the label; (5) simulator cannot show any of the camera path.
- **NOT RUN:** D1 smoke recording, encoder throughput, drop behaviour under load, passthrough writer output, manifest exposure/thermal content from a real device, memory over time, share sheet, permission denial flow on device.
- **Verdict:** partial. Do not report capture as working.

(Further records are appended here, newest last.)
