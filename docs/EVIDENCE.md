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

### D1 smoke recording on device  (G1 plan D1; closes the device part of 1.2 and 1.3)
- **Status:** D1 **PASSED** (owner recorded 11 clips on an iPhone 17 Pro Max, iOS 27.0.1, Debug harness; analysed 2026-10-11). Clips and manifests: `Validation/DeviceReports/D1-smoke-2026-10-11/` (videos git-ignored, checksum index committed). This is smoke data from one device, one lens, one indoor scene with a ball resting on a laptop. **It is not a G1 result and not accuracy evidence.**
- **What was measured (probe tool reading the saved files with AVAssetReader, plus manifests):**
  - Format: ultra-wide, 1920x1080, 240 fps, FOV 106.2 deg (platform-reported), binned. All 11 files decode, size 1920x1080, every frame an HEVC key frame (all-intra confirmed), PTS monotonic.
  - Manifest vs file: frame counts, gap events and missing-frame counts agree exactly for all 11 clips. The manifests can be trusted.
  - Rate held: manual clips 239.9 fps over 1.997 s (480 frames), 0 gaps, 100% of intervals within +/-10%. Clip size ~25 MB per 2 s, so the encoder met ~100 Mbit/s on average.
  - Thermal: nominal throughout (short runs; says nothing about 30-minute behaviour, P2).
  - Exposure (auto, living-room light): median 1/253 s at ISO ~746. At that exposure a 45 m/s ball moves ~18 cm (about 4 ball diameters) during one frame. **H2 confirmed in the real device: indoor auto-exposure is unusable for ball tracking; fixed short exposure and much more light are required.**
- **Defects found (tracked as 1.3a):**
  1. Motion trigger fires right after Start: 4 of 8 motion clips are short (~1.3 s, only ~0.05 s pre-roll) and each has a 10-13 frame gap exactly at the trigger, which is stream start-up, not shot activity.
  2. Steady-state drops: isolated single missing frames roughly every 1-2 s (`frameWasLate`), e.g. 1 gap in each of three otherwise full 2 s motion clips. Of 11 clips only the 3 manual ones were gap-free (P1 would fail at ~27%). Cause unproven: suspect per-frame callback work (device property reads, luma grid) and encoder backpressure; frame sizes vary 45 KB to 470 KB under all-intra.
  3. Manifest `droppedByReason` is a run total, not per window (misleading).
  4. Orientation: the saved scene is rotated 90 deg (phone held in portrait), and the manifest only says "sensor-landscapeRight". Capture must be landscape (spec F22); record device orientation.
  5. The video container starts with an empty sample (0 bytes) and a few extra samples compared with keyframes; harmless for analysis but note for the analysis tool.
- **Rubber duck:** (1) is the data real? frames viewed from two clips show the actual room; (2) does the manifest lie? cross-checked against the files; (3) is 239.9 fps the whole story? only for manual windows, motion clips show drops, so "held 240 fps" is true only within those limits; (4) are 11 clips enough? no: one scene, one lens, no strike.
- **NOT RUN:** any real golf strike, outdoor/range, other lenses and formats, left-handed setup, 30-minute run, flicker analysis, TrackMan pairing.
- **Verdict:** D1 passed with defects; 1.2 and 1.3 ticked. Do the 1.3a fixes before the TrackMan sessions (1.4).

### 1.3a Harness fixes from D1  (PLAN item 1.3a) - PARTIAL
- **Status:** implemented and verified off-device; **not re-measured on the camera after the fixes: NOT RUN.** Item 1.3a stays unchecked. `scripts/verify.sh --ui` passes (Capture package 61 tests, 12 UI tests, Release separation check).
- **Fixed:** (1) motion trigger ignores the first 2 s after Start (`warmupFrames`); (2) manifest drop counts are per clip window plus a separate run total (drops carry the newest frame time); (3) manifest records physical device orientation, exposure setting (requested/applied duration and ISO, ISO clamp, stops of light shortfall), callback timing and frame-size stats, and the UI warns when not landscape; (4) fixed exposure presets 1/1000, 1/2000, 1/4000 trade duration for ISO to hold auto brightness and report the shortfall when ISO runs out; (6) exposure device reads every 8th frame, encoder call timed separately, encoder backlog tracked; plus (new) the run stops cleanly when the app leaves the foreground or the encoder fails 10 frames in a row (previous behaviour: 3,242 silent "unknown" drops and an incomplete clip after the phone locked).
- **Unattended autorun (debug only):** `-harnessAutorun <s> -harnessExposure auto|1000|2000|4000 -harnessTrigger manual|motion -harnessSaveEvery <s>` records, saves clips on a timer, writes `autorun-*.json`, exits. Used to measure without tapping.
- **Device finding from the first autorun (old build, then phone locked mid-run):** callback time mean 1.2 ms, p99 3 ms, max 18-27 ms, 0.2% of frames over the 4.17 ms budget. 0.0022 x 240 = ~0.5 overruns/s, matching the observed ~0.5 drops/s. First saved clip: 480 frames, 0 gaps. All-intra frame size 44-61 KB in a static scene (the 470 KB seen earlier was a changing scene). The second clip was cut short by the phone locking (encoder failing every frame), which is now handled.
- **Tests (mutation-checked):** warm-up boundary exact (mutated +1: failed), window-only drop attribution (mutated to run totals: failed; the first attempt at that code edit had not applied because the formatter reflowed the line, caught because the old test still passed), exposure maths (inverted formula: 6 failures), timing percentile buckets, frame size stats, new manifest fields round trip, autorun argument parsing.
- **NOT RUN:** steady-state drop rate after the fixes, fixed-exposure behaviour on the real camera (does `setExposureModeCustom` hold; real light shortfall), 10-minute run, thermal, orientation reading on the phone, backgrounding handling on the phone.
- **Verdict:** partial. Next: unlock the phone and run autorun A (auto) and B (1/2000) for 60 s each.

### 1.3a device measurements 2026-10-12 (autorun, iPhone 17 Pro Max, ultra-wide 1080p240, living room, phone face-up or portrait, manual saves every 10 s)
- **Run A, auto exposure, 45 s, idle UI:** 11,555 frames; 7 gap events / 18 missing overall (most at stream start-up); `frameWasLate` 6; callback mean 1.27 ms, p99 2.75 ms, max 19.6 ms, 0.087% of frames over the 4.17 ms budget; **encode call** mean 0.58 ms, p99 1.5 ms, max 19.3 ms (the spikes come from the encode call); encoder backlog max 3; thermal nominal. The four saved 2 s windows had 0, 0, 0 and 1 missing frames (1 in 1,919). Compare D1 motion clips (about 0.5 drops/s) and the owner's hands-on manual clips taken in the UI (3 and 9 missing in 2 s windows, callback over budget 0.2%): interacting with the screen while recording hurts capture.
- **Run B, fixed 1/2000 s, 45 s:** plan reported `1/2000 s at ISO 750 (3.0 stops darker than auto: ISO limit)`. **The camera was already at its ISO ceiling (about 750) at auto 1/253 s in this room, so short exposure is impossible without roughly 8x more light.** The image was nearly black (mean luma 0.00 to 0.06). Dark noisy all-intra frames were 486-526 KB (about 980 Mbit/s equivalent) versus 35-50 KB for static bright scenes, the encode call p99 rose to 2.25 ms, 49 gap events / 69 missing / 55 `frameWasLate` (over budget 0.46%). So noise drives bit rate and drops.
- **Verified on device:** per-clip drop attribution (window drops now equal that clip's missing frames: 1/1 and 2/2); exposure plan arithmetic and applied values recorded in the manifest; unattended autorun end to end (launch via `devicectl`, summary file, clips pulled back); phone lock => run stops cleanly.
- **Implications for the bay visit:** (1) the bay's light level is now the decisive unknown: expect to need an exposure of at most 1/1000 s and a bright bay; test the main (wide) lens, which gathers more light than the ultra-wide (`-harnessLens wide`); (2) cap the encoder rate to protect against noise bursts; (3) tell the owner not to touch the screen while recording.
- **Bug found by data, not tests:** the app-level engine kept its own untimed drop log, so per-clip drops were empty even though the Capture package tests passed. Fixed by using the pipeline log.
- **NOT RUN:** main-lens runs, rate-cap effect on drops, 10-minute run, motion trigger on device after the warm-up fix, touch-interaction load measurement.

### App icon  (PLAN item 10.2, partial)
- **Status:** icon added and verified on the simulator and built for the device; launch screen, version numbers and Release config remain open, so 10.2 stays unchecked. Not looked at on the phone's actual home screen by me (device screen not visible to me).
- **What:** owner-supplied concept art (`docs/branding/app-icon-source.webp`) turned into a 1024x1024 opaque PNG by `scripts/make-app-icon.swift` (artwork bounds detected, source compression noise snapped to the background colour, mark centred at 86% width; the source's own rounded corners are not carried over because iOS applies the mask). Asset catalog `App/Assets.xcassets/AppIcon.appiconset`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.
- **Checked:** output is 1024x1024 with no alpha channel; `assetutil` finds `AppIcon` at 1024 px in the built `Assets.car`; simulator home screen screenshot shows the masked icon next to system icons (first version at 74% looked small, enlarged to 86%); `scripts/verify.sh` passes.
- **Open:** owner to confirm rights and origin of the artwork (PROVENANCE); optional dark and tinted icon variants (iOS 18) not made; legibility at small sizes (Settings, Spotlight) not reviewed.

(Further records are appended here, newest last.)
