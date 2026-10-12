# G1 capture feasibility spike (plan)

Status: planned 2026-10-11 (plan item 1.1). **Nothing here has been run.** Every number below is arithmetic or a hypothesis, not a measurement. Spec: `docs/spec/08-tests-and-gates.md` (G1), `05-science.md`, `14-geometry-handedness.md`, features F03, F04, F23. Claim limits: `docs/CLAIMS.md`.

## 1. Purpose and non-goals

**G1 question (spec 08):** do physical-device recordings contain *genuine events* and *enough trajectory evidence* across a *declared initial speed/light envelope* to justify building a measurement pipeline at all?

The spike decides what can be built next; it does not measure accuracy.
- **Not in scope:** accuracy against a reference launch monitor (G2), production capture UI, detection model training, spin measurement, flight model, any user-facing claim.
- **Output:** a recorded dataset, an analysis report, and a decision at item 1.6: declare the supported device profiles and envelope, narrow the scope (for example distance-only tier), or stop.
- **Geometry is fixed by spec 14:** phone on the opposite side of the ball from the golfer, side-on, landscape, perpendicular to the target line. A prototype that only works from behind the ball fails the contract and must not be substituted.

## 2. Why this is risky: feasibility arithmetic (illustrative)

Ball 42.67 mm. Camera at distance d from the ball, horizontal field of view FOV, 1920 px wide. FOV values are placeholders; the harness must log the real `AVCaptureDevice.Format.videoFieldOfView` per format.

| FOV | d = 0.75 m: view width | mm per pixel | ball diameter |
|---|---|---|---|
| 60 deg (main-lens-like, cropped video) | 0.87 m | 0.45 | ~95 px |
| 70 deg | 1.05 m | 0.55 | ~78 px |
| 100 deg (ultra-wide-like) | 1.79 m | 0.93 | ~46 px |

Ball travel per frame (speed / fps): 20 m/s: 0.083 m @240, 0.167 m @120. 45 m/s: 0.188 m @240, 0.375 m @120. 70 m/s: 0.292 m @240, 0.583 m @120.

Frames with the ball still in view after impact, roughly view width / travel per frame (ignoring that the ball starts mid-frame, so subtract about half): at 60 deg and 0.75 m, 45 m/s: about 4.6 frames @240, 2.3 @120; 70 m/s: about 3.0 @240, 1.5 @120. At 100 deg: 70 m/s: about 6.1 @240. A speed estimate needs at least 2 positions, a launch angle at least 3 well-localised ones. **Hypothesis H1: a narrow field of view leaves too few observations at driver speed; an ultra-wide lens may fix that at the cost of pixels per ball, light and distortion.**

Motion blur = speed x exposure. 45 m/s: 4.5 cm @1/1000 s, 2.2 cm @1/2000, 1.1 cm @1/4000, 0.6 cm @1/8000. 70 m/s: 7.0, 3.5, 1.8, 0.9 cm. A ball is 4.3 cm wide, so blur above about 1/2 ball is a problem. **H2: short enough exposure needs a lot of light; auto-exposure will pick long exposures indoors.**

Other hypotheses: **H3** 240 fps is available at usable resolution only on some formats and lenses, and may be throttled by heat. **H4** indoor LED/fluorescent flicker (100 Hz in Sweden) creates brightness banding at high frame rates. **H5** clubhead is visible for enough pre-impact frames to support club speed (otherwise club speed stays unavailable, consistent with `CLAIMS.md`). **H6** a simple frame-difference trigger finds strikes and rejects practice swings, ball placement and nearby movement well enough to be a baseline. **H7** timestamps (PTS) are reliable and drops are detectable. **H8** a 0.6-0.9 m setup is physically workable (clearance, tripod stability). Distance 0.7-0.8 m is a vendor suggestion (spec S2), not a requirement for us.

**First real data (D1, 2026-10-11, one iPhone 17 Pro Max, ultra-wide 1080p240):** 239.9 fps held in clean windows; indoor auto-exposure chose 1/253 s at ISO ~746, which confirms H2 (blur ~18 cm at 45 m/s). Steady-state frame drops of about one per 1-2 s appeared under load and must be fixed or explained before P1 can be judged. See `docs/EVIDENCE.md`.

## 3. Variables and experiment matrix

| Factor | Levels (initial) | Notes |
|---|---|---|
| Device profile | every iPhone the owner can lend; record `hw.machine` id, OS | Open question Q1. Spec says iPhone 11 onward. |
| Lens | wide (1x), ultra-wide (0.5x), if present | Telephoto excluded (field of view too narrow, see H1) unless a device shows otherwise. |
| Format | enumerate all `AVCaptureDevice.Format`s with `maxFrameRate >= 120`; try the 240 fps and 120 fps ones at the highest resolution each supports | Log width, height, fps range, FOV, pixel format, binned, HDR/video stabilisation support. Disable stabilisation and HDR for the spike if the format allows, and record what was actually applied. |
| Exposure | (a) continuous auto, (b) custom: fixed duration 1/2000 and 1/4000, ISO as auto-limited, (c) locked after ball lock | Log actual duration and ISO per frame. |
| Lighting | outdoor sun, outdoor overcast, indoor bright bay, indoor dim, indoor flicker-prone | Record lux estimate (second phone or `exposureTargetOffset`), light type, mains frequency. |
| Ball speed band | slow < 30 m/s (chips, wedges), medium 30-55 (irons), fast > 55 (driver, 3-wood) | Speed from the reference monitor if present, otherwise from golfer club label plus later annotation. |
| Club | wedge, 7 iron, driver minimum | |
| Handedness | right and left, mirrored setup per spec 14 | Equal coverage (spec 14, T21/T22). |
| Setup | distance 0.6 / 0.75 / 0.9 m, camera height ball-level and 20 cm above | Measured with tape; log CoreMotion pitch/roll. |
| Ball | white practice-range ball, plain white, yellow | Plus optional marked ball for a separate spin-visibility check. |
| Background | grass/turf, net, indoor wall, mat | |

Full factorial is impractical. Plan three tiers:
1. **Smoke (1 device, 1 lens):** about 30 strikes outdoors, mixed clubs. Purpose: prove the harness records usable clips.
2. **Characterisation (per device profile):** for each lens x best 240 fps format x exposure setting, at least 10 strikes per speed band in two lighting conditions (about 60 per condition), right-handed, then a left-handed repeat of the best configuration (30 strikes).
3. **Negatives:** per device and lighting, at least 30 minutes of non-strike activity (practice swings without ball, walking, ball being placed and removed, adjacent person swinging, ball rolling) and one 30-minute continuous run for thermal, memory and dropped-frame behaviour.

Record **every** attempted strike including misses (spec 08). Never keep only the good clips.

## 4. Data to record

**Per clip** (a video file plus a sidecar manifest, schema versioned `g1-manifest/1`):
- Capture: device `hw.machine`, OS and build, app build, camera lens/position, format description (w, h, fps range, FOV, pixel format), requested vs actual fps, stabilisation/HDR applied, orientation, mirrored flag.
- Per frame: presentation timestamp (PTS, as seconds, not assumed from fps), dropped-frame events with reason (`kCMSampleBufferAttachmentKey_DroppedFrameReason`), exposure duration, ISO, lens position, white balance gains, per-frame mean luma (for flicker analysis).
- Session timeline: thermal state changes (`ProcessInfo.thermalState`), low power mode, battery level, memory footprint sample each second, interruption events.
- Setup: handedness, distance and height measured with tape, tilt from CoreMotion, a short stationary calibration clip with a **scale bar** (a 1 m ruler or marked stick with high-contrast 10 cm marks) laid along the target line at the ball plane, and a second still with the ball on its tee mark. Optional checkerboard for lens distortion.
- Shot metadata: id, timestamp UTC, club, ball, lighting category, location type, golfer id (pseudonymous), outcome notes (miss, mishit, thin), trigger type (auto or manual).
- Reference (optional but record when available): reference launch monitor make/model/firmware/mode and its reported ball speed, launch angle, carry. This is for G2 preparation; G1 does not depend on it.

**Storage format decision (default):** HEVC `.mov` written by `AVAssetWriter` from the original sample buffers so PTS is preserved, at a high bitrate chosen to avoid compression smearing the ball (initial: 80 Mbit/s at 1080p240, to be tuned), plus the JSON sidecar. If a device cannot sustain that write rate, log it as a finding rather than lowering quality silently. Raw (uncompressed) capture is a fallback experiment only on short windows. Open question Q5.

**Window:** bounded ring buffer holds pre-impact frames; on trigger, keep 0.75 s before and 1.25 s after the trigger (360 frames at 240 fps). The harness also supports manual "save last N seconds" and a continuous record mode for negatives.

## 5. Harness requirements (hand-off to 1.2 and 1.3)

Item 1.2, `Packages/Capture` (logic, `swift test` where possible without a camera):
- `CaptureFormatCatalog`: enumerate and classify formats; pure value types so selection logic is unit-testable with fixture formats.
- `FrameClock`: PTS-based timing, nominal vs actual frame interval, gap detection (frame gap > 1.5x nominal), dropped-frame accounting with reasons.
- `RingBuffer<Frame>`: bounded by frame count and bytes, no unbounded growth, tested for wrap-around and concurrent producer/consumer.
- `ExposureLogger`, `ThermalLogger`: sampled and timestamped.
- `CaptureSession` wrapper over AVFoundation behind a protocol, so everything above runs against a fake source in tests.
- Separate capture queue; no work on the main thread; no blocking in the sample-buffer callback (F23).

Item 1.3, debug-only harness screen:
- Compile-time separated: new Xcode configuration flag `CAPTURE_HARNESS` set only in `Debug`; harness files wrapped in `#if CAPTURE_HARNESS`. **Check:** a release build must not contain harness symbols (script inspects the binary with `nm`/`strings`), and `verify.sh` should run that check once 1.3 exists.
- Landscape only, preview, record/stop, trigger mode (manual, simple frame-difference), live readout of fps, drops, exposure, thermal state; saves clip + sidecar to the app's Documents (shareable from Files / Finder, no network).
- Clearly labelled "DEBUG HARNESS" on screen. No synthetic events and no accepted shots; it writes no `Shot` and spends no credit.
- Camera permission is requested only when the harness starts (F01).

Item 1.5, offline analysis tooling:
- Swift CLI or test target that reads clip + manifest and reports: frame interval statistics, gaps, per-frame luma flicker spectrum, blur estimate of the ball region, and runs a baseline frame-difference detector.
- A small annotation helper: owner or analyst marks ball centre (x, y) and clubhead visibility per frame for a sampled subset (the pass criteria in section 6 need human ground truth for localisation). Annotation file format `g1-annotations/1`, with annotator id.

## 6. Pass criteria for G1 (proposed; owner approval needed at 1.6)

A criterion is evaluated per **(device profile, lens/format, exposure mode, lighting, speed band)** stratum with at least 10 strikes. A stratum that fails is excluded from the declared envelope; it is not hidden.

| ID | Criterion | Threshold (proposed) |
|---|---|---|
| P1 | Timing integrity: PTS present for every frame; frame interval within +/-10% of nominal | >= 99% of frames in the impact window; whole window free of gaps in >= 95% of captures |
| P2 | Sustained rate: requested fps held for a 30-minute run | actual fps >= 95% of nominal at p95; thermal state reaches no worse than "serious"; memory flat (growth < 5% after warm-up); behaviour on rising thermal state is logged |
| P3 | Genuine event captured: ball visible at impact and leaving | >= 95% of attempted strikes have both a pre-impact stationary ball and at least one post-impact ball frame |
| P4 | Trajectory evidence: annotated ball positions after impact | >= 4 frames with the ball localised (centre error <= 2 px against annotation) in >= 90% of valid strikes in the stratum. At 3 frames a stratum may qualify only for a distance-only tier (decision at 1.6). Fewer than 3: no launch-angle claim. |
| P5 | Blur: ball elongation along motion | median <= 0.5 ball diameters, p90 <= 1.0 |
| P6 | Ball contrast: ball separable from background | annotated centre recoverable in >= 90% of annotated frames (a recorded judgement, plus a simple contrast metric) |
| P7 | Club evidence (informational, gates club speed only) | clubhead visible in >= 3 pre-impact frames in >= 80% of strikes, else club speed stays unavailable |
| P8 | Baseline trigger | detector recall >= 90% on attempted strikes and a recorded false-trigger rate on the negatives. Informational for G1; formal targets are G2 (recall >= 95%, <= 1 false accept/hour). |
| P9 | Flicker | if banding amplitude exceeds an agreed threshold under a light type, that light type is excluded or an exposure-lock mitigation is shown to work |
| P10 | Spin visibility (informational) | record whether any ball marking/dimple structure is resolvable in >= 2 consecutive post-impact frames. The default expectation is **no**, and spin stays "Estimated" (spec 05). |

**Proposed P1 revision (2026-10-12, needs owner approval):** see `docs/EVIDENCE.md` (1.3a closed): P1a PTS present and ordered; P1b no missing frame within about 0.15 s of impact in at least 95% of valid strikes (missing frames flagged); P1c steady-state loss under 0.1% after a 10 s warm-up. The original P1 wording above is kept until approved.

**G1 passes** only if at least one device profile has at least one stratum per speed band the owner wants to support that passes P1-P4 and P5, with the envelope written down. If only slow/medium bands pass, declare that narrower envelope. If nothing passes P4, stop or re-scope (see section 7).

## 7. Decision tree for item 1.6

1. P1/P2 fail on every profile: the platform cannot sustain evidence capture. Stop; re-scope to a non-camera-measurement product (owner decision).
2. P1/P2 pass, P4 fails at driver speed but passes slow/medium: declare a **medium-speed envelope** (no driver claim); consider ultra-wide or larger distance experiments before giving up the fast band.
3. P4 gives only 3 frames: **distance-only tier** (spec 05 and 06 already allow it: lateral-scored drills disabled).
4. P5/P9 fail only in some light: restrict the envelope by light, and make F02 environment checks refuse those conditions.
5. All pass: proceed to Phase 3 with the declared profiles. G2 is still required before any measurement claim.
Any result goes into `docs/EVIDENCE.md` (G1 row) with the report path. The owner signs the envelope; Claude does not.

## 8. Safety, privacy, handling

- Protected hitting area, netting or open range, tripod weighted and stable, nobody in the swing arc or ball path; the owner (not the harness) is responsible for site safety.
- Pseudonymous golfer ids; get consent before recording other people; avoid faces in frame where possible. Clips stay on the device until copied manually.
- Video files are **not** committed (size, personal data). Commit only manifests, annotation files and reports. Store clips outside git with a checksum list in `Validation/DeviceReports/INDEX.md`.

## 9. Test cases

U = unit (Capture package, no camera), A = analysis tooling, D = physical device (owner), all D are NOT RUN until done.
- U1 Format catalogue: fixture format lists classify 240/120 fps formats, exclude formats below 120, rank by FOV and resolution; empty list gives a typed "unsupported" result.
- U2 FrameClock: perfectly paced 240 fps gives zero gaps; one missing frame is flagged as one gap with the right index; jitter within 10% is not a gap; PTS going backwards is an error.
- U3 RingBuffer: capacity respected by count and bytes; oldest evicted first; trigger returns exactly pre+post frames in PTS order; concurrent push/read stress has no loss or crash.
- U4 Dropped-frame accounting records the reason and never counts a dropped frame as captured.
- U5 Manifest: encode/decode round trip; missing optional reference data stays null, never 0.
- U6 Release safety: release build contains no harness symbols (scripted check).
- A1 Analysis tool: a synthetic 240 fps clip with a known bright disc moving at a known speed yields the right speed and frame count, and a clip with an injected gap is flagged.
- A2 Annotation tool: round trip and out-of-bounds rejection.
- D1 Smoke recording on one device: clip plays back, PTS monotonic, manifest complete.
- D2 Per-stratum characterisation (section 3) and negatives; D3 30-minute run; D4 left-handed repeat; D5 flicker run under indoor lights.

## 10. Task list

1. **1.2 (Sonnet, Dev):** `Packages/Capture`: U1-U5, then AVFoundation session. Plan item 1.2 stays unchecked until D1 passes.
2. **1.3 (Sonnet, Dev):** harness screen and release-symbol check (U6). UI verified in the simulator only for layout (no camera there); capture itself NOT RUN until D1.
3. **1.4 (You):** run section 3 with the checklist below, copy clips and manifests, fill `Validation/DeviceReports/INDEX.md`.
4. **1.5 (Sonnet):** analysis tooling A1/A2 and the report generator for section 6.
5. **1.6 (Opus):** evaluate P1-P10, write the report, propose the envelope for owner sign-off.

**D1 smoke test on the phone (owner, ~10 minutes, needed before 1.2/1.3 can be ticked):**
1. Unlock the phone, open GolfLaunchr (Debug build), Settings (gear) > "Open capture harness (DEBUG)".
2. Allow camera access. Pick the first format in the list (highest fps), trigger = manual, Start. Check the live panel: FPS (capture clock) should read near the format rate, dropped/gaps/missing near 0, thermal nominal or fair.
3. Hold the phone steady, wave a ball or hand through the view, tap "Save last 2 s now". A "Saved ..." message appears and the clip is listed.
4. Repeat with trigger = motion (move something in view; adjust the threshold using the live message count).
5. Use "Share clip + manifest" to AirDrop/Files the `.mov` and `.json`, or copy them with `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.allerhed.golflaunchr --source Documents/G1 --destination <folder>` (Claude can run this).
6. Report: format chosen, FPS reading, whether the clip plays with all frames, any error text.
Pass for D1: clip plays, PTS monotonic, manifest complete with real exposure/thermal data, requested fps held.

**Owner recording checklist (1.4):** charge the phone and keep it cool (no case, out of direct sun between runs); disable Low Power Mode; fixed tripod; tape the setup distance and photograph the setup; lay the scale bar and record the calibration clip first; one stationary-ball clip before each series; note club and lighting out loud at the start of each series; record misses; run the negatives for 30 minutes; do not delete anything.

## 11. Rubber duck: how this plan could be wrong

1. **Pass criteria could be satisfied by clips nobody could measure from.** Check: P4 uses human annotation of ball centre, not a detector's own success.
2. **Format availability differs per device and iOS.** Check: never hard-code; the catalogue enumerates and logs, U1 uses fixtures, D1 confirms on the actual device.
3. **High bitrate writing could itself drop frames.** Check: dropped-frame accounting (U4) and a write-rate finding; the criterion measures dropped frames in the saved window.
4. **Disabling stabilisation/HDR might not be possible, silently changing geometry.** Check: the manifest records what was actually applied, and any applied crop or warp is a finding.
5. **Selection bias in what the owner keeps.** Check: record every attempt; the index counts attempts vs clips.
6. **A single lens or speed dominates.** Check: the matrix is per stratum with a minimum count, and strata that fail are reported.
7. **Spec contradiction:** F01 says unvalidated devices cannot be "certified". Check: G1 only declares profiles as *candidate*; certification needs G2.

## 12. Using the TrackMan bay (added 2026-10-11)

Owner has TrackMan bay access. This gives an independent reference for every strike, which makes the characterisation tier double as **G2 pilot data** (the G2 protocol in spec 08 needs same-strike ground truth). It does not change G1 pass criteria, which stay camera-evidence based.

**Reference record per strike** (extends section 4): TrackMan unit model, firmware/software version, mode (indoor/outdoor, and whether the bay uses Combine/indoor simulation), session id, and the metrics it reports: ball speed, launch angle, launch direction, club speed, smash, attack angle, spin rate, carry, total. Record TrackMan's metric definitions and its stated uncertainty. **Do not treat TrackMan carry in an indoor bay as measured landing**: the ball stops at a screen/net, so carry is extrapolated by TrackMan's model (spec 08: reference estimated carry is not direct landing truth). Use ball speed, launch angle and launch direction as the primary reference; use spin, club speed and carry as secondary.

**Strike synchronisation (critical, otherwise pairs are wrong):**
1. Pair by order and by time, not by order alone: log the phone clock (UTC) at each save and the TrackMan shot timestamp from its export; check the offset is stable.
2. Start each series with a visible/audible marker in the clip (a hand clap or phone flash) and note the TrackMan shot number of the first real strike.
3. Record misses and strikes TrackMan did not register; an unpaired strike is kept and labelled, never dropped (spec 08: report every attempt).
4. Export the TrackMan session (CSV or report) after each session and store it beside the clips; do not retype numbers.

**Placement in the bay (physical):** the phone goes on the opposite side of the ball from the golfer (spec 14), perpendicular to the target line, which is also where radar/camera sensors and screens often sit. Check clearance before hitting: the phone must not be in the ball path, not block TrackMan's view of the ball or club, and not be in the swing arc. Prefer a weighted tripod, and a ball-height lens axis. Log the exact positions; if the bay forces a different distance, that is a finding.

**What the bay cannot cover:** outdoor sunlight strata (P-matrix rows "outdoor sun/overcast"), real flight beyond the net, and some lighting variety (bay lighting is usually fixed and bright). Keep outdoor characterisation as a separate range session, or declare the envelope "indoor bay lighting only" at item 1.6. Indoor LED flicker (P9) can be measured here.

**Terms:** check the bay operator's/TrackMan's terms before copying session data out or using it in accuracy claims; ownership of the dataset and any naming of TrackMan in published material is the owner's call. `CLAIMS.md` still forbids accuracy claims before G2, and never name the reference in marketing without permission.

**Effect on tiers:** strikes in the bay satisfy the "characterisation" tier for indoor strata and allow per-stratum bias/MAE pilot numbers against TrackMan for ball speed and launch angle. These are pilot figures on one golfer/session group, not G2 results (G2 needs held-out data, at least ten golfers where possible, spec 08).

### Limited bay access: session protocol (added 2026-10-11)

The owner has the TrackMan app (full shot data available) but must drive to the bay, so visits are scarce. Rules:
1. **Do not go until the harness is ready.** Gate: item 1.3a done and a home rehearsal (steps below) shows no defects. A visit wasted on a harness bug costs more than a week of delay.
2. **Home rehearsal (30 min):** record a 10-minute continuous run at the intended exposure; expect zero gaps in clean windows, correct landscape orientation in the manifest, no spurious startup triggers, thermal not above fair; drop a ball from 30 cm for a fast-moving test target if desired. Check storage: a 2 s clip is about 25 MB, so 150 strikes is about 4 GB; free at least 10 GB before leaving.
3. **Bring:** phone with Low Power Mode off and a full battery plus a charger/cable (the phone gets warm), weighted tripod or clamp, tape measure, scale bar (1 m ruler), a second phone or watch for the clock check, balls (white and yellow if possible), notebook.
4. **Per visit, a fixed script** (about 60-90 min), most important first so a short visit still delivers: (a) setup measurement, scale-bar clip, clock sync clap clip; (b) **exposure sweep** with the same strikes type: fixed 1/1000, 1/2000, 1/4000 s (ISO capped), 10 strikes each, 7 iron (the key unknown is whether short exposures are bright enough in the bay); (c) driver and wedge series at the best exposure, 10 strikes each; (d) one left-handed series if the bay allows; (e) 5 minutes of non-strike activity (practice swings, ball placement) for the false-trigger baseline.
5. **TrackMan data:** after each series open the TrackMan app, confirm the shot count matches your strike count, export the session (or screenshot the shot table if export is not offered) and keep the session id/date and shot numbers. Note any shot TrackMan did not register or you hit but did not save. Record in the manifest/notes which TrackMan shot number pairs with which clip (or at least the first shot of each series).
6. **Manual trigger is the safety net:** use motion trigger for convenience but also tap "Save last 2 s" after every strike you suspect was missed; a missed strike cannot be recovered, a spurious clip can be deleted.
7. **After the visit:** copy clips off the phone the same day (`devicectl` or share), index them, and write the findings into `docs/EVIDENCE.md` before the next visit so the next script can adapt.

## 13. Open questions for the owner (non-blocking for this plan)

- Q1 Which iPhone models can you use, and do you have an ultra-wide model? (determines profiles)
- Q2 **Answered 2026-10-11: the owner has access to a TrackMan bay** (indoor, TrackMan reference). Still open: a range for outdoor strata, and which TrackMan model/firmware (see section 12).
- Q3 Who records and who annotates? Annotation of about 30 frames per stratum is needed for P4.
- Q4 Approve the proposed thresholds in section 6 (they are engineering proposals, spec 08 says owner approval before G2).
- Q5 HEVC at ~80 Mbit/s as the default storage, with raw only as a fallback experiment: acceptable?
- Q6 (partly answered: the owner has the TrackMan app, so shot data can be read out) Which TrackMan model and software version does the bay run, and may session exports be copied out and used for our own validation?
- Q7 How many different golfers can take part in bay sessions? (G2 aims for at least ten; G1 needs only a few.)
