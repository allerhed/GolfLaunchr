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

### 1.3a closed: late-frame queueing, lens comparison (device, 2026-10-12)
- **Table (40-48 s unattended runs, four 2 s windows each; "missing" = frames absent from the PTS sequence):**

  | run | whole run missing | windows missing / frames |
  |---|---|---|
  | ultra-wide, auto, discard late | 18 and 22 | 1/1919 and 3/1917 |
  | ultra-wide, fixed 1/2000, discard late | 69 | 5/1923 |
  | wide, auto, discard late | 35 and 54 | 7/1913 and 1/1919 |
  | wide, fixed 1/2000, discard late | 61 | 14/1914 |
  | **wide, auto, queue late (no discard)** | **5** | **0/1920** |
  | **wide, fixed 1/2000, queue late** | **14 (one start-up gap)** | **0/1928** |

- **Finding:** callback spikes of ~19 ms (the encode call stalls occasionally) became lost frames because the camera was set to discard frames that arrive while the callback is busy. Queueing them absorbs the spike (callback max rose to 60 ms with nothing lost, encoder backlog max 9). Remaining loss is the stream start-up gap (10-14 frames), irrelevant to a recording that runs for minutes. Run-to-run noise is large (two identical wide-auto discard runs: 7 and 1 missing in windows), so lens and exposure effects cannot be ranked from these runs; the queueing effect is large (0 of 3,848 windowed frames) and consistent.
- **Light (decisive for the bay visit):** ultra-wide 1080p240 tops out at ISO about 750; the wide (main) lens at 1080p240 at ISO about 2160 with 75 deg field of view. In the living room auto exposure already sat at the ISO ceiling at about 1/250 s, so 1/2000 s is 3.0 stops darker than a normal exposure on both lenses; the wide lens image is about 1.5 stops brighter than the ultra-wide at the same shutter (mean luma 0.19 at 1/2000 s ISO 2160). Whether this is enough depends entirely on bay lighting, which is unmeasured.
- **Proposed change to criterion P1 (needs owner approval):** the current wording (whole 2 s window gap-free in 95% of captures) is dominated by irrelevant frames and by start-up. Proposed: P1a every frame has a PTS and no frame is out of order; P1b no missing frame in the impact-critical window (about 0.15 s either side of impact) in at least 95% of valid strikes, and any missing frame is flagged; P1c steady-state loss after a 10 s warm-up under 0.1% of frames. Rationale: every frame carries its own timestamp, so a missing frame removes one observation but does not corrupt timing (F23 asks for zero loss in the required window, which P1b tests directly).
- **Decision:** the harness queues late frames by default (`-harnessDiscard` restores the old behaviour).
- **NOT RUN:** 10-minute run, motion trigger on the device after the warm-up fix, effect of touching the screen during recording, indoor bay light, outdoor light.
- **Verdict:** 1.3a closed. G1 is still NOT RUN: no strike has been recorded.

### 1.5 Offline analysis tooling  (PLAN item 1.5; G1 plan A1, A2)
- **Status:** VERIFIED on synthetic clips (`swift test`, 32 tests in `Packages/Analysis`; full `scripts/verify.sh` passes) and on the 11 real D1 clips. The writer timescale fix (see below) compiles and is installed on the phone but has **not yet produced a clip I could analyse: NOT RUN** (phone locked).
- **Synthetic checks (A1/A2):** injected gaps located and counted; a disc moving 6 px/frame at 0.5 mm/px gives 0.72 m/s, and missing frames do not inflate speed because timestamps are used; mains flicker at 100 and 50 Hz recovered in frequency and depth; slow brightness swings no longer hide flicker (20 Hz floor); sharp vs blurred checkerboard ranks correctly and a flat image scores 0; annotation file round trip, bad values rejected (also when hand edited), P4 counts only post-impact localised frames with the boundary exact and unknown impact = unknown not fail; manifest consistency names each mismatch.
- **Real D1 clips (all 11):** frames, gap events and missing frames agree exactly with the manifests and with the earlier manual probe. The tool independently reproduced the harness findings from the file alone: start-up gap ("13 missing after frame 0") and a motion trigger at frame 1 (score 79.5, luma 0.08 at start) in the start-up clips; trigger frames 179/240/377 in the hand-wave clip. Living-room mains flicker detected in three clips: 100 Hz, 0.37-0.77% modulation (negligible at 1/253 s, but a short exposure will modulate far more: P9 still open).
- **Bugs found by running on real data (none of the synthetic tests could):** (1) older manifests could not be decoded because new required fields had been added (`runDroppedByReason`): made optional, regression test added. (2) The tool reported "jitter on every interval, 0% within tolerance" although the manifest said perfect pacing: the saved `.mov` stores timestamps at the container default timescale 600, so 240 fps frames are 3/2/3/2 ticks apart (3.3 and 5 ms). Fixed at the source (240,000 timescale in `ClipWriter`) and the analyser now detects coarse quantisation and reports a within-one-tick figure; it deliberately does not flag perfectly paced streams (my first rule did, caught by tests).
- **Rubber duck:** (1) is "consistent" vacuous? mutation: a manifest claiming a clean clip against a file with a gap yields three named mismatches (tested); (2) quantisation rule mutated to always flag: a test failed, restored; (3) motion grid cannot see a ball (a 5 px disc covers under one grid sample; score 0.35 vs threshold 6): documented in tests, the grid detector is for large movements only; (4) disc tracker could be mistaken for the product detector: documented as a self-check only.
- **NOT RUN:** analysis of a real golf strike, any ball detection on real frames, blur measurement on a ball, human annotation (no annotator has used the template yet), the writer fix on a new clip.
- **Verdict:** VERIFIED for tooling; says nothing about measurement feasibility (G1 still NOT RUN).

### Writer timescale fix, proven on the device (follow-up to 1.5; 2026-10-12)
- Two clips recorded by the fixed harness (wide lens, auto, 480 frames each) analysed with `g1-analyze`: **jitter 0, non-monotonic 0, 100.00% of intervals within tolerance, no quantisation note, manifest consistent**. The D1 clips (old writer) showed jitter on every interval from 1/600 s quantisation. Fix confirmed.

### 2.1 Real persistence store  (PLAN item 2.1; F20; T03, T09, T13)
- **Status:** VERIFIED (package + gate). The app does not use the store yet (features adopt it later), so nothing was run in the simulator or on the phone.
- **Automated:** `Packages/Persistence` 36 tests pass; `scripts/verify.sh` passes (lint, all package tests, build, Release separation).
- **Covered:**
  - One repository contract (commit atomic and idempotent, concurrent duplicate commits, conflicting duplicates, invalid references, sequence uniqueness, synthetic rejection T13, exclude/restore/delete T09, ledger survives deletes, credits per kind, ordering) runs against **both** the in-memory fake and SQLite.
  - **Real crash tests (T03):** a helper executable SIGKILLs itself mid-commit. Killed after the shot insert, or after the ledger insert but before commit: reopening shows **no shot and no ledger entry**, and the retry commits exactly once. Killed after commit: **exactly one shot and one ledger entry**, the retry is reported as already committed.
  - Thrown failures mid-commit roll back; data and exclusions survive close/reopen; foreign keys enforced; an unreadable stored record is an error, never a fake record.
  - Migrations: fresh DB at v1 with the step recorded; no re-apply; v1->v2 keeps every record and ID and the migration really ran; a failing step rolls back completely (still v1, no half-added column); a newer database is refused and not modified; non-contiguous lists rejected.
  - Corrupt file (not a database): refused with `.corrupt`, bytes unchanged.
  - `MediaDirectory`: staged -> atomic commit, never overwrites, SHA-256 checked against the known value for "abc", unsafe paths (`..`, absolute, empty parts) rejected, orphan scan and removal touch only orphans and staging leftovers, exact-case matching.
- **Mutation check:** transactions removed (statements autocommit): the kill-mid-commit tests, the thrown-rollback tests and the failing-migration test all failed; restored. Another bug was found by a test, not by reading: the orphan scan mis-computed paths because of the macOS `/var` vs `/private/var` symlink.
- **Human check:** opened a real test database with the independent `sqlite3` tool: WAL mode, `user_version` 1, five tables, migration row, one session/shot/ledger, shot stored as contract JSON.
- **NOT RUN:** use from the app, OS-level power loss (process kill is tested, a device power cut is not), migrations of real user data (none exists yet), media tied to database records (ShotMedia contract is not in Domain yet), performance with large histories, encryption/data protection class on iOS, iCloud backup exclusion, low-storage behaviour, tests leave temporary folders behind.
- **Verdict:** VERIFIED for the store; not yet integrated.

### 2.2 My Bag (F08)  (PLAN item 2.2; T08)
- **Status:** VERIFIED on the iPhone 17 simulator (en and sv, portrait and landscape). Installed (Debug) on the owner's iPhone 17 Pro Max but **not exercised on the device by me: NOT RUN**. Per-club distances/images (mockups 09/15) and "Map this club" are other features and not built.
- **Automated:** `scripts/verify.sh --ui` passes: Domain 52 tests (loft rule boundaries 1.0/70.0 and 0.99/70.01, NaN/inf, nil stays nil; names trimmed/1-40/case+diacritic duplicates, reuse of an archived name, restore into a clash refused; snapshot stays frozen after rename and loft change; `loftRevision` only when the loft changes; archive keeps the ID and history resolves; reorder renumbers contiguously and ignores bad offsets; club count never shrinks; Codable round trip), Persistence 43 tests (bag parity on both backends, survives reopen, newer-version and unreadable bag refused, the real v1->v2 migration keeps shots and adds an empty bag), app unit tests 21 (seed once and never again, stored names not re-translated, unreadable store not seeded over, failed save keeps the shown bag, changes written before shown, Swedish decimal comma, draft survives, stale-write regression), UI tests 19 incl. `BagUITests` x7.
- **UI cases run:** add a club and see its loft; bad loft (two decimal points) disables Save with the reason; Swedish seed names, `56,5` accepted and shown as `56,5°`, duplicate name refused in Swedish; archive by swipe -> "Archived (1)" -> restore; rotating with the editor open keeps the typed text; **the bag survives app relaunch through the real SQLite file**; largest accessibility text; landscape with the rail.
- **Bugs found by looking, not by the first tests:** (1) after a successful Save the club was stored but the editor stayed open showing empty fields: a dismissing text field wrote its empty value back through the draft binding and re-created the draft. My first English UI test passed anyway because it never asserted the sheet closed. Fixed (writes ignored without a draft), regression unit test mutation-checked, UI helper now asserts the editor closes. (2) A filled-in editor field had no visible label (placeholders vanish): fields are now labelled rows. (3) Test-script issues, not app bugs: the decimal pad has no letters, and a row under the floating tab bar needs scrolling before swiping.
- **Visual review:** screenshots (gitignored) compared with mockups 09/15 for layout only: title "My Bag"/"Min bag", add button, Edit, rows with category and optional loft, chevrons, archived section; dark Swedish landscape with the rail. The mockup's club photos and carry bars are intentionally absent.
- **Rubber duck:** (1) "no guessed stock loft": seeded lofts all nil (tested); (2) "cannot orphan shots": no delete API, count never shrinks (tested); (3) rotation losing state: draft in the store (UI test); (4) save failure showing unsaved data as saved: tested with a failing repository; (5) seed re-translation: tested; (6) data loss when the stored bag is unreadable: refuses to seed over it (tested at store and repository level).
- **NOT RUN / open:** VoiceOver walkthrough on a device; Swedish terminology review by a native golfer (seed names Trä 3, Hybrid 4, Järn 7, Pitching/Gap/Sand/Lob wedge are proposals; "Bag" kept as the tab label); owner confirmation of Q1/Q2; very long club names in the row at large text; reordering by drag (Edit mode) was not exercised by a UI test; what the bag looks like with 100 clubs.
- **Verdict:** VERIFIED (simulator).

### 2.3 Sessions and history (F10)  (PLAN item 2.3; T09)
- **Status:** VERIFIED on the iPhone 17 simulator (en and sv, portrait and landscape) using **debug-only demo data**: no real shot has ever been recorded, so this proves the screens and the data handling, not measurement. Not run on the physical phone: NOT RUN.
- **Built:** Progress tab with Sessions/Trends; filter chips (time: all/7/30 days, mode, club) with a "no matches / clear filters" state; session list (mode, local date and time, duration, clubs, shot and excluded counts, "Demo data" badge); session detail (included/total, average estimated carry and measured ball speed with their provenance, shot rows); shot detail (all 13 metrics with provenance, quality, failure reason and uncertainty; exclusion state); exclude/restore; confirmed permanent delete of a shot or a whole session; rotation keeps the open session.
- **Automated (gate passes):** Analytics 14 tests (summaries, filters; mutation: counting excluded shots failed 2 tests), app unit tests 32 (exclude/restore recompute from the database, delete keeps the credit ledger, failed writes keep the shown state, filters, concurrent-load regressions, demo fixtures through real SQLite), UI tests 29 incl. 10 for History (list newest first and labelled demo; honest empty state without demo data; filters narrow and clear; exclude/restore changes "6 of 6" to "5 of 6" and the mean 117 m to 112 m and back; delete shot confirm and cancel; delete session leaves the others; exclusion survives relaunch with no re-seeding; Swedish labels and local time; unavailable carry shown as "Unavailable, Ball hidden", never 0; rotation keeps the open session).
- **F10 acceptance mapping:** failed/unavailable measurements do not enter averages (tested); deleting a session keeps the credit ledger and other sessions (tested at store and UI level); dates shown in local time, stored UTC (UI test shows local time, storage unchanged); no empty or non-finite chart (no charts yet: NOT RUN). **NOT RUN:** deleting media with measurements (media records do not exist yet), "removes unreferenced clips" (no clips linked), per-club aggregates and dispersion plots (F10a, 2.4), target outcomes and notes, linked replay (Phase 5), rejected-capture counts and data-quality summary (rejections are not stored).
- **Bugs found by looking at the screens and by repeating until a failure made sense:**
  1. *Third shot row not drawn on first opening a session* (summary said "3 of 3", list showed 2 rows, plenty of empty space; reopening fixed it). Data was right (the heading's value was 3, one reload). Removing `swipeActions` made the row appear, so swipe actions on these rows were the trigger on this iOS 27 simulator. Replaced by a long-press menu plus VoiceOver actions (more discoverable too). Before finding this I wrongly blamed scrolling and a tab-bar overlap; a diagnostic that exposed the data count settled it.
  2. *Concurrent first loads* (`HistoryStore`, `BagStore`): the guard checked only the state, so two overlapping loads would both run. Unit tests fail on the old code (the bag was saved twice); fixed. It was not the cause of bug 1 (the symptom stayed), but it was a real defect.
  3. *Crash tests from 2.1 were flaky* (3 of 5 runs failed): `kill(getpid(), SIGKILL)` on a multithreaded process lets the calling thread run on to COMMIT before the signal lands, so "killed before commit" sometimes committed. Fixed by blocking after the kill; 12 of 12 passes since. **This means the 2.1 evidence ("crash tests pass") was true only some of the time until now.** SQLite's atomicity was never in question; the simulation of the crash was.
  4. Release contained the string `-uiTestSeedHistory` (parsed outside the debug block): caught by the separation check, flag now parsed in Debug only.
  5. Layout flaws seen in screenshots: shot rows wrapped mid-word ("Mea-sured"), unavailable metrics said "Unavailable" twice and a hidden-ball carry was also labelled "Unsupported", list cards lacked separators and duration. All fixed.
- **Test-script notes (not app bugs):** cells have no label (the spoken text is on the cell's button child); the destructive action's identifier is not kept by the system; confirmations appear as a native popover that is cancelled by tapping outside; a row under the floating tab bar can be "hittable" while covered.
- **Rubber duck:** (1) numbers drifting from the database: every change reloads from the database (unit test with a second store over the same data); (2) demo data mistaken for real: badge on every demo session and shot, none shown without the flag (UI test); (3) failed write showing a changed state: tested; (4) deleting history giving back credits: ledger unchanged (tested); (5) rotation losing the open session: navigation paths live in the shell model (UI test); (6) Swedish decimals/time: UI test.
- **Open / NOT RUN:** VoiceOver walkthrough on a device; Delete is only in the shot menu, not in the shot detail screen; Swedish wording review; large-history performance; the Trends tab is a placeholder; swipe actions could be reconsidered once the iOS list issue is understood.
- **Verdict:** VERIFIED (simulator, demo data).

(Further records are appended here, newest last.)

### 2.4 F09 + F10a analytics (logic) — 2026-10-12

**Implemented (`Packages/Analytics`):** `ShotAnalysis.swift` (ClubSelection All/Some with toggle and visible empty selection, `AnalysisFilter` with club OR / other AND, `AnalysisFilterEditor` draft/Apply/Cancel/Clear, `ShotSelection`, `ClubProfile` with n, mean, median, P10/P90, sample SD, range, lateral spread, per-metric means with coverage, `ShotCompare`), `ClubGapping.swift` (signed gaps from unrounded means, bag order kept, no bridging, Selected-clubs-only and mixed-conditions flags), `Dispersion.swift` (points plus a 1-SD covariance ellipse needing 3 non-collinear points).

**Verified:**
- 39 package tests (was 20 in Analytics), including the spec fixtures: means 224/160/130/110 give gaps 64/30/20; 5i+7i gives 30 with Selected clubs only; [120,130,140] gives mean 130, SD 10, range 120-140, P10/P90 122/138. Zero/one/two samples, nulls and invalid values omitted, pooled (not average-of-averages), exclude/restore, carry vs total, club OR / mode AND / session / date, duplicate names, archived (unknown) club ids, empty selection, apply/cancel/clear, inversions, no-data rows, shared eligible IDs across list/averages/dispersion/gapping, shot-to-average delta.
- Independent reference: values from Python `statistics` (23 random values, inclusive quantiles) match to 1e-9.
- Mutation checks: 6 deliberate bugs (gap sign, provisional threshold, ellipse collinearity guard, apply guard, standardised fallback, session scope) each made tests fail; the session-scope mutation initially survived, so a dedicated test was added and re-checked.
- End to end: SQLite store -> HistoryStore -> Analytics over the demo data (PW pooled over two sessions mean 566/6, 7 iron ball-hidden shot omitted not zero).
- Performance: 10,000 shots, 14 clubs, full select + profiles + gap table in well under the 2 s bound (whole 39-test run 0.2 s).
- `scripts/verify.sh`: VERIFY OK.

**Not UI:** no screen was changed, so there was nothing to check in the simulator. Rubber duck outcomes: wrong sign of gaps (caught by mutation), standardised view silently showing recorded numbers (test: zero coverage), 1D data drawing a meaningless ellipse (test), slow on big histories (measured).

**NOT RUN / open:** the Averages, Gapping, Dispersion screens, filter sheet, persistence of applied filters across relaunch, entitlement gating (Pro) and export are not built; Standardised needs a validated flight model (none exists, so it reports zero coverage by design); the advisory gap/overlap heuristic and the "recommend more samples for unstable sets" rule are not implemented; Q-ellipse scale (1 SD) needs owner confirmation of wording.

### 2.5 F17 Export (CSV + JSON v1) — 2026-10-12

**Implemented (`Packages/Export`, wired into the app target):** `JSONExport` (envelope `golflaunchr-export/1`, shots in the unchanged shot contract 1.0, sessions, options recorded), `CSVExport` (one row per shot, 81 columns, SI units in the header, provenance/quality/uncertainty/failure per metric, empty cell for missing, shortest round-trip decimals independent of locale, formula-leading text prefixed with an apostrophe, RFC 4180 quoting), `ExportService` (reads the repositories at export time, `writeTemporary` into a private folder, `discard`, cancellation removes the folder), `ExportOptions` (defaults: demo shots out, device identifier replaced by "omitted", media link and notes out, excluded shots kept with their flag).

**Verified:** 15 package tests + 1 app test over the real SQLite store (16 new). JSON round-trip equals the original shot for every metric, provenance, quality, uncertainty and failure; null stays null; carry survives bit-exact (130.123456789). CSV numbers parse back identically, negatives are numbers, a club named `=cmd|...` cannot start a formula, Swedish text with commas and quotes survives. Deleting a shot or session removes it from the next export. Cancel before and after the file is written leaves the folder empty (the first cancellation tests were vacuous because cancellation fired before any file existed; found by mutation, replaced by one that cancels after the write). Mutation checks: no formula escaping, rounded numbers, synthetic included by default, quoting removed, redaction disabled, cleanup removed: all caught. Independent read: a real export file parsed with Python `csv` and `json` (81 columns on header and row, values as expected).
`scripts/verify.sh`: VERIFY OK.

**NOT RUN / open:** Export screen, share sheet, notes/media prompts and "export before delete" (UI, BACKLOG E11); aggregate/club-average and filter content in exports ("export reproduces analysis", spec F10a) is not included yet; a real spreadsheet (Excel/Numbers) was not opened with the CSV; display-unit option for CSV not built (SI only); clip export; large-history export timing.

### 2.6 Milestone QA: data layer (2.1-2.5) — 2026-10-12

**Method and honesty note:** performed by the same session that wrote the code, not by an independent reviewer or a separate agent, so it is weaker than the plan's intent. I tried to break the data layer with new adversarial tests rather than re-reading the old ones (`Packages/Persistence/Tests/PersistenceTests/MilestoneQATests.swift`).

**Re-run, not trusted:** `scripts/verify.sh` VERIFY OK; the real-SIGKILL and fault-injection SQLite tests 12 of 12 consecutive passes; whole Persistence suite 6 of 6.

**New probes (5, all pass):** 3,000 accepted shots (every commit durable, synchronous=FULL, WAL) read back complete and in order; two connections writing to one file at once lose nothing (80 of 80 shots and credits); extreme doubles (45.123456789012345, 5e-324), millisecond times, emoji/Swedish names survive reopen bit-exact; deleting a session leaves no orphan shots and keeps all credits; a byte copy of the db + WAL taken while the writer is still open (what a crash leaves) recovers on open.

**Finding fixed:** reading 3,000 shots took 0.91 s and 3,000 commits 2.0 s because a new `ISO8601DateFormatter` was built for every date. Now two shared formatters: 0.26 s read, 0.68 s commit (3.5x/3x). A concurrency test (8 tasks x 1,500 round trips) guards the shared formatters.

**Remaining risks (not executed):** power loss on a real device (process kill is tested, a power cut is not); iOS data-protection class and backup exclusion of the database; behaviour when the disk is full or the file is on low-storage devices; migration from a real released v1 file (none exists yet); history screens still reload every shot of every session after each change (fine at 3,000 shots, ~0.3 s; revisit past ~20,000); the export path was checked with Python's parsers but not opened in a spreadsheet; ledger/entitlement logic beyond storing entries belongs to Phase 7.

### 3.5 Flight package — 2026-10-12 (done out of order; UNVALIDATED physics)

**Implemented (`Packages/Flight`):** `Atmosphere` (dry-air density from the environment snapshot: 1.2250 kg/m3 at ISA), `LaunchInputs` (validated SI inputs, spin optional), `FlightModel.compute` (point mass, quadratic drag Cd 0.25, Magnus lift Cl = min(0.30, 0.40 S^0.4), RK4 at 1 ms, ground crossing interpolated, fixed spin axis, no spin decay), `FlightResult` with environment snapshot, air density, version `flight-0.1-unvalidated`, and `measurements()` which maps results to stored metrics as estimated/provisional only.

**Honesty rules enforced by tests:** missing spin gives a zero-lift lower bound that is never stored as carry (carry stays unavailable); no spin axis means no curvature (aim straight gives lateral exactly 0); total distance is always unavailable (no validated runout model); nothing is ever labelled measured or derived.

**Verified:** 13 tests. Vacuum limit equals the analytic parabola (range, apex, time, landing angle); 4 trajectories plus a thin-air case match an independent Python implementation (own RK4, 0.2 ms) to within 0.02 m / 0.005 s; right/left symmetry and sign; lower pressure carries further and the environment snapshot is kept; more spin flies higher; plausibility bounds (driver 70 m/s 11 deg 2700 rpm carries about 219 m, 7 iron 50 m/s 18 deg 6500 rpm about 167 m); determinism; invalid inputs rejected. 6 mutations (drag, axis direction, density temperature, lower-bound flag, lateral sign, ground interpolation) all caught. verify.sh OK.

**Caveats / NOT RUN:** the model is physically plausible but generic: the 7-iron carry (167 m for 50 m/s) looks long against typical real-world figures (about 150-160 m), the drag/lift coefficients are not fitted to anything and spin decay and humidity are ignored. It must not be used for any user-visible number until G2 compares it with TrackMan data (3.6/3.7). It is not yet wired into the app or the Standardised analytics view (which needs per-shot launch inputs), and the F18 pressure source (sensor/manual) is not built.

### 4.1 Onboarding + capability qualification (F01) — 2026-10-12

**Implemented:** `Capture/Capability.swift` (`CapabilityQualifier`: Supported only for an explicitly validated model with a 240 fps format, otherwise Experimental; Unsupported for iOS < 18, no camera, no format >= 120 fps, or < 2 GB free; low storage (< 10 GB) is a warning; typed reasons). App: `Onboarding/` (welcome, safe placement, required swing handedness with a mirrored golfer illustration, device check, "Use history only" on every screen), `SettingsStore` now persists `swingHandedness` (nil until chosen, never inferred) and `onboardingCompleted`; camera permission is requested only when "Check camera" is pressed; denial shows a banner with an Open Settings button; status is shown with symbol + word, not colour. The validated-model list is empty, so nothing can be Supported yet (no G1/G2 evidence).

**Verified:** 7 qualifier tests + 8 store tests (handedness blocks Continue, persists across relaunch, camera not requested before the check, denied/no-camera paths, skip needs nothing, reset for tests). Mutation checks: ignoring the validated list, OS threshold, status downgrade, storage warning each fail tests. 5 UI tests in en/sv, portrait/landscape: full flow with Continue disabled until a choice, Experimental result, Finish to Home, relaunch does not show onboarding again, denied route, no-camera device still reaches History, skip from the first screen in Swedish. Screenshots reviewed in portrait and landscape (button tint, result card scrolled into view in landscape; landscape PNGs from XCUIScreen are rotated 90 degrees, a capture artefact). `scripts/verify.sh --ui`: VERIFY OK (all UI tests).

**Found while testing:** an `accessibilityIdentifier` on the root container hid every child button identifier (tests could not find any button); the first run also hung for 9 minutes without the `-derivedDataPath` the gate uses. Cover content did not inherit the app tint, fixed.

**NOT RUN / open:** real iPhone (actual formats, free-storage figure, camera permission prompt, Settings round trip); VoiceOver and largest Dynamic Type; Swedish wording needs the native review; handedness is not yet editable in Settings (4.5) so a wrong choice cannot be corrected except by resetting; "repeated onboarding does not reset credits" holds by construction (onboarding touches only two settings) but no credit ledger flow exists to test it against; the first-run flow is not offered again from Settings; unvalidated devices are labelled Experimental but nothing yet gates capture on the status (4.2/4.3).

### 4.2 Setup tutorial and environment checks (F02) — 2026-10-12

**Implemented:** `Capture/SetupMonitor` (rolling 1 s analysis of the coarse luma grids: mean luma, clipped fraction, motion score, flicker index from brightness ripple at >= 100 fps, exposure), `SetupReadiness` (typed blockers each with a reason and an action, warnings, test vs scored mode, `canScore` never true in a test), `SetupState` (handedness and calibration travel together: changing side while calibrated needs confirmation and then loses the calibration; the first choice of a side is not a change), `SetupChecks` (checklist rows; not measured = Not checked, never Good), `SetupDiagram` (golfer/phone sides derived from where the target is relative to the golfer at address). App: `Setup/` screen (original top-down diagram mirrored for left-handed, swing-side picker with confirmation dialog, reasons and actions above a five-row checklist, test-setup toggle with banner, Ready button disabled while blocked), entry button on Home, live camera observer behind a protocol, Debug-only fake scenes for tests.

**Verified:** 12 + 4 + 8 new package tests (Capture 89 total), 8 model and string tests in the app (every reason/action/warning/check key exists in en and sv). Mutation checks: test-mode scoring, calibration skip in test mode, forced recalibration, confirmation, window cut-off, flicker frame-rate guard, single-frame readiness: each caught (one survivor found and killed with a new test). UI tests, 5 scenarios in en/sv and portrait/landscape: good scene ready; dark/moving/flicker/no-camera each block with the exact reason and action text and a disabled Ready; test setup arms without calibration and is labelled; side change while calibrated asks first, cancel by tapping outside leaves everything, confirm loses the calibration and mirrors the diagram; Swedish landscape. `scripts/verify.sh --ui` OK (before the last layout reorder; the setup UI tests were rerun after it).

**Found by testing:** the first choice of a swing side with a calibration present asked for confirmation (fixed, unit + UI tests); the confirmation shows as a popover on this iOS (no Cancel button), now anchored to the picker. The sign convention differs from mockup 04: for a right-handed golfer with the target on the right of the page, the golfer must stand on the far (top) side because the target is on their left; the mockup shows the opposite, spec text wins.

**NOT RUN / open:** the live camera observer on a real iPhone (frame callbacks, exposure reading, thermal, backgrounding); all thresholds (dark 0.12, clipped 20%, motion 4.0, flicker 0.02/0.05, shutter 1/1000 and 1/500) are provisional and must be set from G1 clips; flicker needs >= 100 fps frames so the screen runs the camera at the fastest format; no ball detection or phone-orientation (CoreMotion) check yet (mockup shows "Ball detected"); calibration (3.2) does not exist so Calibrate has no action; Ready currently just closes the screen (capture screen is 4.3); VoiceOver and largest Dynamic Type not checked; Swedish wording needs native review; blur/sharpness is covered only through shutter speed.
