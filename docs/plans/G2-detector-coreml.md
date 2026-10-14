# Ball and club detection with a custom Core ML model (plan)

Status: **approved by the owner 2026-10-15** (all suggestions accepted, section 13). Feeds plan items 3.1-3.4 (measurement) and 5.3 (real capture wiring). Nothing here is implemented. Every accuracy number below is a target or a calculation, never a result.

## 1. Purpose, scope, non-goals

- **Purpose:** find the golf ball (at address and in the first post-impact frames) and the club head (near impact) in 240 fps side-on iPhone video precisely enough to measure the owner's target metrics (section 3a): **ball** speed, spin rate, vertical launch angle and horizontal (left/right) launch angle; **club** speed, attack angle, club path, and smash factor (ball speed / club speed). The detections are evidence for the measurement pipeline in spec section 5: capability → calibration → ball lock → strike → **timestamped trajectory/club evidence** → quality checks → measured quantities → flight model.
- **In scope:** data collection and labelling, model choice, training, conversion to Core ML, on-device inference, evaluation, versioning, the go/no-go gates.
- **Not in scope:** the flight model (exists, `Flight` package), spin axis, club face angle and dynamic loft (unavailable, spec 5), any user-facing accuracy claim (only G2, `CLAIMS.md`). Spin rate is in scope as a research track (section 3a) but ships as an estimate until a direct method passes G2.
- **Ground rule:** a detector's confidence is not an accuracy interval (spec 5). Accuracy comes only from paired, held-out comparison against the reference launch monitor.

## 2. What the research says (2026-10-15)

| Finding | Source | Consequence for us |
|---|---|---|
| No public golf-ball detection or tracking dataset existed when a YOLOv3 golf study was done; they built their own 2,104 images from slow-motion footage; YOLOv3-tiny scored 0.78 mAP. | [arXiv 2012.09393](https://arxiv.org/pdf/2012.09393) | We must collect and label our own data. A box detector on single frames is a weak baseline. |
| A YOLO11 golf project reported near-perfect validation (P 0.999, R 0.998) yet found the ball in **under 10% of frames** on real swing video: validation used the training augmentation, and default thresholds discarded weak, small detections. | [nishsm/golf-ball-tracking](https://github.com/nishsm/golf-ball-tracking) (read 2026-10-15) | Validate only on real, held-out clips from different sessions. Tune thresholds on real data. Never report augmented-validation numbers. |
| Heatmap networks over several consecutive frames (TrackNet, TrackNetV2, WASB) are the strongest published approach for small, fast, blurred balls; multi-frame input handles blur and short occlusion; WASB beats prior methods by 7.8-16.8% AP across five sports. WASB code is MIT licensed. | [TrackNet](https://arxiv.org/pdf/1907.03698), [TrackNetV2](https://astro.paperswithcode.com/paper/tracknetv2-efficient-shuttlecock-tracking), [WASB](https://arxiv.org/pdf/2311.05237), [WASB code](https://github.com/nttcom/WASB-SBDT) | Main model: a small multi-frame heatmap network, not a box detector. |
| BlurBall labels the ball at the **centre of the blur streak** plus blur orientation and half-length; this labelling improved detection for every model tested and the blur length carries velocity information. | [BlurBall](https://arxiv.org/pdf/2509.18387) | Our label schema records streak centre, orientation, half-length. Blur length becomes a second, independent speed cue. |
| Ball tracking needs a motion model on top of detections (Kalman / physics) to survive blur, occlusion and misses. | [Ultralytics golf post](https://www.ultralytics.com/blog/tracking-golf-balls-using-ultralytics-yolo-models), [KU thesis](https://kuscholarworks.ku.edu/server/api/core/bitstreams/0c65a4f0-1f93-476e-ad57-b1c35b414e0c/content) | The detector proposes; a physics fit decides. Outliers are rejected by the fit, not by the confidence score. |
| Apple Create ML trains a single-image box detector; parameters are batch size, iterations, grid size and the algorithm (full network or transfer learning). | [MLObjectDetector](https://developer.apple.com/documentation/createml/mlobjectdetector), [ModelParameters](https://developer.apple.com/documentation/createml/mlobjectdetector/modelparameters-swift.struct), [WWDC19 424](https://wwdcnotes.com/notes/wwdc19/424) | Good for a fast, licence-clean **baseline** (ball at address, club head boxes). Not for multi-frame, blur attributes or sub-pixel heatmaps. |
| Vision's `VNDetectTrajectoriesRequest` finds parabolic trajectories over frame sequences but needs a still camera and a region of interest, returns several candidates the app must filter, and developers report misses for flying balls. | [WWDC20 10099](https://wwdcnotes.com/documentation/wwdc20-10099-explore-the-action-and-vision-app/), [forum 824962](https://developer.apple.com/forums/thread/824962) | Worth one cheap comparison run; not a foundation (no blur model, no club, opaque). |
| Ultralytics YOLO is AGPL-3.0 (open-source the whole app) or a paid Enterprise licence; YOLOX, RT-DETR and NanoDet are Apache-2.0 (verify upstream files and weights). | [Ultralytics licence](https://ultralytics.com/license), [comparison](https://docs.ultralytics.com/compare/yolox-vs-rtdetr) | No Ultralytics code or weights in the app without an owner decision and a licence. Prefer our own small network or Apache/MIT references, re-implemented clean-room. |
| Core ML runs on CPU, GPU and Neural Engine; the compute-unit setting is a hint; Xcode's Core ML performance report shows per-layer placement; first Neural Engine load can be slow. FP16 by default, INT8 optional. | [MLComputeUnits](https://developer.apple.com/documentation/coreml/mlcomputeunits), [WWDC22 10027](https://developer.apple.com/videos/play/wwdc2022-10027), [forum 758222](https://developer.apple.com/forums/thread/758222), [forum 850058](https://developer.apple.com/forums/thread/850058) | Measure on the real phone, check that layers actually land on the Neural Engine, load and warm the model before the first shot. |
| Custom exposure (`setExposureModeCustom(duration:iso:)`) can silently not apply; durations of at most half a frame are recommended; changing exposure can change frame-duration limits. | [setExposureModeCustom](https://developer.apple.com/tutorials/data/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:).md), [forum 848520](https://developer.apple.com/forums/thread/848520), [forum 844226](https://developer.apple.com/forums/thread/844226) | Read back `exposureDuration`/`iso` per frame (the harness already logs them) and train on the exposures we will actually use. |
| Synthetic data: path-traced renders (Blender Cycles) beat game-engine renders; domain randomisation can match real data for detection; motion blur can be synthesised. | [arXiv 2311.11039](https://arxiv.org/pdf/2311.11039), [BlendTorch](https://ar5iv.labs.arxiv.org/html/2010.11696), [Brooks & Barron](https://openaccess.thecvf.com/content_CVPR_2019/html/Brooks_Learning_to_Synthesize_Motion_Blur_CVPR_2019_paper.html) | Use synthetic data to pre-train and to cover rare cases, never to validate. Start with cheap compositing on our own background plates before any Blender work. |
| Club head: published work uses DeepLabCut or keypoint heatmaps (side-on, 7 iron) or fits a global swing model to per-frame candidates; no public club-head keypoint dataset. GolfDB has 1,400 swing videos with events and boxes, not club-head points, at 30 fps. | [Frontiers 2023](https://doaj.org/article/bfc308cea0ed4514a5b0f541b8fafe6d), [EPFL](https://www.epfl.ch/labs/cvlab/research/completed/research-completed-golf/), [GolfDB](https://arxiv.org/pdf/1903.06528) | Club head is a separate, later model with our own labels; GolfDB is at most a pre-training source and only after its licence is checked. |
| Smartphone launch monitors: no peer-reviewed method found; patents describe single-device monitors and argue that phone frame rates are marginal. Products pair 240 fps cameras with radar. | [US patent 12728313](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12728313), [US 9697613](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9697613), [MLM2PRO](https://rapsodo.com/products/mlm2pro-mobile-launch-monitor-golf-simulator) | We are in research territory: G1/G2 evidence decides, not the plan. A freedom-to-operate review of the single-device patents is an owner question (Q7). |

## 3. Our numbers (calculated, see section 11 for the check)

Side-on, ultra-wide 1920x1080 at 240 fps, measured FOV 106.2 degrees (D1 manifest). Ball 42.7 mm.

| Distance to ball | Ball size | Travel per frame at 45 / 70 m/s | Frames in the half-view after impact at 45 / 70 m/s | Blur at 45 m/s, 1/1000 / 1/2000 / 1/4000 s |
|---|---|---|---|---|
| 0.5 m | 62 px | 270 / 420 px | 3.6 / 2.3 | 65 / 32 / 16 px |
| 0.75 m | 41 px | 180 / 280 px | 5.3 / 3.4 | 43 / 22 / 11 px |
| 1.0 m | 31 px | 135 / 210 px | 7.1 / 4.6 | 32 / 16 / 8 px |

What this means for the model:
1. **The ball is not tiny** (30-60 px, unlike the 10 px balls in broadcast sports). Plain detection is not the hard part.
2. **The hard parts are few observations (2-7 frames), blur, and the club head overlapping the ball at impact.** The design must squeeze everything out of each frame (sub-pixel centre, blur length) and must cope with a ball that is partly hidden or leaving the frame.
3. A narrow lens leaves 1-3 frames at driver speed; the ultra-wide at about 1 m is the likely sweet spot, at the cost of lens distortion at the edges (needs an intrinsic/distortion model, item 3.2).
4. Indoor auto exposure (D1: 1/253 s) smears a 45 m/s ball over 4.2 diameters: the exposure work of G1 is a precondition, and the model must be trained on the exposures we will actually run.

## 3a. Metrics: what we try to measure, and what one side-on camera can see

The phone stands side-on (spec 14): the target line runs **across** the image, so up/down and along-the-target-line motion is seen directly, while left/right (towards or away from the camera) is **depth**, seen only through the change in apparent size. That single fact decides most of this table. Definitions follow the reference launch monitor's conventions so the bay data compares like with like; signs follow our contract (right positive, up positive; handedness handled per spec 14).

| Metric | Evidence needed from the models | Method | What the camera can see (calculated, section 11 item 6) | Provenance at first release | Target (spec 08, or proposed) |
|---|---|---|---|---|---|
| **Ball speed** | Ball centre and radius in each post-impact frame; blur length | 3D displacement per frame over PTS time: in-plane motion from the centres, depth motion from the radius change, scale from the ball's known diameter at address; blur length as a second, independent speed cue | 4-11 frames in view at 30-70 m/s (ultra-wide, 0.75-1 m). Random centre noise alone gives about 0.1% speed noise, so **systematic** errors decide: scale (1% depth error = 1% speed error), lens distortion, rolling shutter | **Measured** after G2 | MAE ≤ max(1.5 m/s, 3%); p95 ≤ max(3 m/s, 6%) |
| **Vertical launch angle** | Ball centres | Angle of the 3D velocity above the ground plane; ground plane from calibration plus the phone's gravity vector | Best-observed metric: the trajectory lies across the image. Random noise about 0.05 deg; camera roll/tilt calibration dominates | **Measured** after G2 | MAE ≤ 2 deg; p95 ≤ 4 deg |
| **Horizontal launch (left/right)** | Ball radius to sub-pixel precision in each frame (edge fit, not the heatmap) | Depth change along the flight from the radius change, plus the start depth at address | **Weak**: 1 deg of left/right changes the radius by only 0.3-0.45 px over the visible flight. Possible only with a sub-pixel radius fit perpendicular to the blur and a precise distortion correction (ultra-wide size changes across the frame far exceed this signal) | **Experimental** until G2 says otherwise; unavailable if it fails | MAE ≤ 2 deg; p95 ≤ 4 deg (spec 08, "if claimed") |
| **Spin rate** | Ball surface features (logo or a marking) in consecutive sharp frames | Research track: rotation per frame from feature tracking on the ball. Baseline: estimate from launch conditions and club (spec 5) | At 240 fps 2,500 rpm turns the ball 62 deg per frame, 7,000 rpm 175 deg, 9,000 rpm 225 deg (looks like 135 deg the wrong way). Because full-swing spin is backspin, the sign is known, which keeps it unambiguous up to 14,400 rpm, **if** a feature is visible in at least 3 sharp frames. Plain dimples are symmetric: an unmarked ball usually gives no usable feature | **Estimated** (labelled so); direct measurement only with a marked ball and only after G2 | Spec 08 estimate: MAE ≤ max(750 rpm, 15%); p95 ≤ max(1,500 rpm, 30%) |
| **Club speed** | Club-head point in the last pre-impact frames | Speed along the arc from the last 2-4 positions, scale from the ball plane (the head is at the ball at impact), depth change from the head's apparent size | 2.4-4 frames in the last 0.5 m at 30-50 m/s; the head is larger than the ball but rotates and blurs; the point must be defined consistently (label: centre of the head silhouette) | **Measured** only after G2; unavailable before | MAE ≤ max(2 m/s, 5%); p95 ≤ max(4 m/s, 10%) |
| **Attack angle** | Club-head point in the last 2-4 frames before impact | Vertical angle of the head's path at the impact frame from an arc fit (side-on view sees it directly) | Seen directly, but from few points on a curved path; the impact frame must be right to within one frame | **Experimental**, then measured if G2 passes | Proposed: MAE ≤ 1.5 deg; p95 ≤ 3 deg (owner approval) |
| **Club path (in-to-out)** | Club-head point **and** its apparent size or a second head point (toe/heel) | Horizontal direction of the head's travel across the target line = depth motion | **Weakest**: like horizontal launch, but the head also rotates as the face closes, so its apparent size is not a clean depth cue. Likely needs a second camera view | **Unavailable** unless a G2 report shows it works; research track only | Proposed: MAE ≤ 2 deg; p95 ≤ 4 deg if ever claimed |
| **Smash factor** | Ball speed and club speed | Ball speed / club speed, **derived**; only when both are measured on the same strike | Errors add: about 3% + 5% gives roughly 6% on smash factor, i.e. about ±0.09 on a 1.45 driver smash | **Derived** (never shown if either input is missing) | Proposed: MAE ≤ 0.08 (what the ball and club speed targets allow: 3% and 5% combine to about 6%, 0.085 on a 1.45 smash; a tighter target would be stricter than its inputs; owner approval) |

**Contract change needed:** our metric catalogue (spec 5, `MetricKey`) has no `clubPath`. Adding it is an additive contract change (new optional metric, SI radians, right positive = in-to-out for a right-handed golfer, mirrored by handedness) and needs the owner's approval through the planner role (Q8). Until then club path is computed only in the research tools, never stored or shown.

**What this means for the models:**
- The ball model must output a **sub-pixel radius**, not just a centre: a classical edge fit inside the detected crop, measured perpendicular to the blur direction, refines the heatmap. Horizontal launch lives or dies on this.
- The club-head model needs **two points** (head centre, and the toe so the head's orientation and size can be followed) to try club path; club speed and attack angle need only the centre.
- Spin needs a **third, optional model or classical tracker** for surface features, and a product decision on marked balls (Q9).
- The **impact frame** is shared by every club metric and by the start of the ball track; it gets its own accuracy criterion (within one frame on 95% of strikes).

## 4. Architecture: geometry first, learned evidence second

Not every frame is analysed live. The capture pipeline already keeps a ring buffer; after a strike trigger the **impact window** (about 40-80 frames around impact) is analysed once, within the spec's result budget (p95 at most 3 s).

1. **Ball lock (at address, live, low rate, about 5 Hz).** Find the stationary ball once the setup is ready (F03). Classical first (bright-disc / circular-edge fit, which the `Analysis` package already prototypes) plus a small learned check that it is a ball and not a lamp, a reflection or a tee. Output: centre, radius (px), which also gives a scale and a distance estimate from the known diameter.
2. **Strike and impact frame.** The existing motion trigger proposes a window; the impact frame is where the ball first leaves its locked position (pixel difference inside the ball disc against the pre-impact median), cross-checked with the club-head track when that model exists.
3. **Post-impact candidates (no ML).** The camera is on a tripod, so a per-pixel background from pre-impact frames plus the ball's known start point and plausible launch cone (0-60 degrees up, a target-line band) gives a small search region per frame. This alone may work in good light (milestone M1 measures that).
4. **Learned ball evidence (main model).** A small heatmap network sees three consecutive **crops** (for example 256x256 px around the predicted region, plus the frame difference) and outputs a heatmap for the streak centre, plus blur orientation and half-length, plus a visibility class (visible, partly hidden by the club, partly out of frame, absent). Multi-frame input in, per-frame output (WASB/TrackNetV2 style, our own implementation).
5. **Track fit and quality gate (no ML).** A robust fit over the 2-7 detections: constant velocity in the image for the first frames (drag and gravity are negligible over 20 ms), rolling-shutter row-time correction, lens undistortion, then 3D direction and speed from the calibration (3.2) and the apparent-size depth cue. Detections the fit rejects are dropped; too few inliers means **ballSpeed unavailable** with a typed failure (`incompleteTrack`, `ambiguousBall`, `occlusion`, `blur`), never a guess.
6. **Club head (second model, later).** A heatmap/keypoint model for the club-head centre (and hosel as a second point if it helps), on pre-impact frames only, trained on our labels. Until validated it is used only to (a) confirm a strike (a club passed the ball) and (b) refine the impact frame. `clubSpeed` stays **unavailable** (spec 5, `CLAIMS.md`) until a G2 report says otherwise.

Why not one end-to-end network that outputs ball speed: the spec requires provenance (measured vs estimated), stage-specific failure reasons and calibrated uncertainty. A black-box regressor would turn a measurement into an estimate and hide failures.

## 5. Model choices (with a baseline ladder)

| Rung | Model | Purpose | Licence |
|---|---|---|---|
| B0 | No ML: background difference + disc fit + track fit | Lower bound; may already be enough in good light | ours |
| B1 | Vision `VNDetectTrajectoriesRequest` on the impact window | One cheap comparison, Apple-only | Apple SDK |
| B2 | Create ML object detector (full network, then transfer learning) on single frames, classes `ball`, `clubhead` | Fast all-Apple baseline; likely good at address, weaker in flight | Apple tooling, our data |
| M | Our multi-frame heatmap net (PyTorch, about 0.5-2 M parameters, HRNet-lite or U-Net-lite stem without early striding), converted with coremltools to an ML Program, FP16 | Main ball model | ours, clean-room from the papers |
| C | Same family, club-head keypoint head | Club head | ours |

Move up a rung only when the rung below fails a stated criterion on the validation set (section 8). If B0 or B2 already passes, we ship the simpler thing.

## 6. Data plan

**Sources, in order of value:**
1. **Bay sessions (paired with TrackMan).** Every strike gives images *and* reference numbers. Precious: split by session and golfer, and a fixed part is the frozen G2 test set that no model ever trains on.
2. **Own practice sessions (unpaired):** home net, range. Images for detection only; different backgrounds, light, mats, grass, ball brands (white, yellow, matte, logos).
3. **Negatives:** practice swings, ball placement, people walking past, a second ball nearby, lamps and reflections (D1 already shows bright window frames and a glass in view), the club resting near the ball.
4. **Synthetic, phase 1: compositing.** Cut real balls from address frames, paste onto real empty background plates from our own clips along physically plausible paths with a line blur kernel of length speed x exposure, brightness and noise matched to the plate. Cheap, controllable, labels are exact.
5. **Synthetic, phase 2 (only if a gap remains): Blender Cycles** renders with randomised light, ball texture, spin, blur and camera distortion.
6. No external datasets (decided 2026-10-15 with the owner's "no external licences" goal): only our own consented clips and composites made from them.

**Volume targets for model v1 (proposals):** 600 real strikes from at least 4 sessions, 2 lenses or distances, 2 light types, both handedness setups; about 3,000 labelled post-impact ball instances; 2,000 address frames (auto-labelled, spot-checked); 3 hours of negative footage (spec 08 already asks for 3 hours per profile). Final G2 evaluation per spec 08: 30 wedge + 30 mid-iron + 30 driver per condition, at least ten golfers aimed for, split by golfer/session.

**Labelling:**
- Tool: **CVAT** run locally (Docker, no upload; open source, check the licence file before use) with track interpolation, or our own minimal labeller inside the existing `g1-analyze` tool if CVAT proves heavy. Clips and frames never leave the owner's machines without consent (section 10).
- Schema `det-annotations/1`, extending the existing `g1-annotations/1`: per frame, `ball` = streak centre (x, y in source pixels, sub-pixel), blur orientation, half-length, radius measured across the blur, visibility class, optional surface-feature point (logo or marking) for the spin track; `clubhead` = centre point, toe point, visibility; per clip: impact frame index, lens, exposure, distance, handedness, light type, golfer ID (pseudonymous), session ID, split.
- Coordinates in the **sensor frame as stored** (D1 frames are stored rotated: orientation comes from the manifest, never guessed).
- Quality: 10% of frames labelled twice; agreement target at most 1.5 px median on the ball centre; disagreements reviewed. Model-assisted labelling (pre-labels from the previous model, human corrects) after v1, with every corrected frame logged.

## 7. Training, conversion, on-device

**Local hardware and licence position (added 2026-10-15, owner asked):**
- Training runs on the owner's own Macs: the **M1 Max MacBook** for training (24 or 32 GPU cores, 32 or 64 GB unified memory), the **M1 Mac mini** (8 GPU cores, 16 GB, measured) for labelling, evaluation, conversion and Create ML baselines. No cloud, no rented GPU, no upload.
- Rough size of the job (a calculation to be replaced by a measurement in M4): a 1-2 M parameter heatmap net on 256 px multi-frame crops costs a few GFLOPs per training sample; 3,000 labelled instances x 100 augmented epochs is about 2 PFLOP, i.e. on the order of an hour on the mini and well under an hour on the M1 Max at realistic MPS efficiency. Memory is not a constraint at this size.
- **No external licence enters the product.** The app ships only our own `.mlpackage` (our architecture, our weights, trained only on our own clips) and Apple's Core ML. Nothing third-party is linked or bundled.
- **Train from scratch, no pretrained weights.** Public pretrained weights come with dataset terms (ImageNet, COCO) or code licences (Ultralytics AGPL-3.0); a tiny model for one narrow scene does not need them. The Create ML baseline B2 uses Apple's own tooling and feature extractor under the developer agreement and is optional.
- **Development tools only** (not shipped, permissive, recorded in `PROVENANCE.md` as dev-only): Python, PyTorch with the Apple MPS backend (BSD-3-Clause), coremltools (BSD-3-Clause), optionally Apple MLX (MIT), NumPy. None of these puts an obligation on the app.
- **Labelling with our own tool** (an extension of `g1-analyze` / a small macOS SwiftUI labeller) instead of CVAT, so no external tool is needed at all; CVAT (MIT, local) remains a fallback if our tool proves too slow.
- **No external datasets.** GolfDB, BlurBall data and similar are dropped from the plan; only our own consented clips and composites made from them.

**Training (local):** Python environment pinned with a lock file; PyTorch on the Apple GPU (MPS); crops make training feasible on an M1 (expected hours, not days, for a model this size; to be measured in M4). Every run records git SHA, dataset manifest hash, config, seed and metrics in a model card (`Validation/Models/<version>/MODEL_CARD.md`). Augmentation: horizontal flip with handedness flip, brightness/ISO noise, HEVC re-encode at our bitrate, blur-length jitter, small rotation and scale. **Validation sets get no augmentation.**

**Conversion:** coremltools to an ML Program (`.mlpackage`), FP16; INT8 only if latency demands it and accuracy holds. Inputs fixed size (for example 3x256x256 crops plus a difference channel), outputs raw heatmaps; peak finding and sub-pixel refinement happen in Swift (simple, testable, same code for every model version).

**Parity test (mandatory):** a fixed set of 50 crops runs through PyTorch and through the Core ML model on the Mac and on the phone; heatmap peaks must agree within 0.25 px and the decoded centres within 0.5 px. A failing parity test blocks the model.

**On device:**
- New package `Detection` (protocols, peak decoding, track fit, failure types; pure Swift, `swift test`) and `DetectionCoreML` (adapter that owns the `MLModel`), mirroring `Capture` / `CaptureAV`.
- Model bundled in the app (never downloaded; F21 no-network rule and the `check-no-upload.sh` audit stay true). Loaded and warmed at app start or setup screen, not at the first shot.
- Batch the 40-80 impact-window crops; target total detection time at most 300 ms on the oldest supported profile, measured with the Xcode Core ML performance report and in-app timing; check that layers actually run on the Neural Engine.
- Model version goes into `ShotVersions.pipeline` (already in the shot contract), so every stored shot says which detector produced it.

## 8. Evaluation and milestones

**Detection metrics (validation and test, real clips only):** ball recall and precision at a 0.25-diameter radius, centre error (median, p95, in px and in mm via the ball scale), blur half-length error, per-strike track success (at least 3 inliers), false strike accepts per hour on negatives, address-ball lock success and false locks (lamps, reflections). **Downstream (what matters):** every metric of section 3a against TrackMan on the held-out set (spec 08 metrics: bias, MAE, median, p95, availability rate, by speed/club/light/handedness): ball speed, vertical launch, horizontal launch, spin (direct track and estimate separately), club speed, attack angle, club path (research only), smash factor. Each metric passes or fails on its own; a failed metric ships as unavailable or experimental, never hidden inside an average.

| Milestone | Work | Exit criterion (proposal) |
|---|---|---|
| M0 | Licence decisions, labelling tool, schema, environment, model-card template | Owner approves this plan and Q1-Q4 |
| M1 | B0 (no ML) on bay and home clips | Report of per-strike track success and speed error; tells us how much ML is needed |
| M2 | Labels v1 from the bay visit + one home session | 600 strikes labelled, double-label agreement measured |
| M3 | B1 and B2 baselines | Numbers on the validation split, same metrics |
| M4 | Heatmap model v1 trained | Beats the best baseline on track success and centre error on validation; no augmented validation |
| M5 | Core ML conversion, parity test, on-device timing | Parity passes; at most 300 ms per impact window on the oldest profile; Neural Engine placement shown |
| M6 | Integration behind a flag; replay of recorded clips through the device pipeline | Device result equals Mac result on 20 clips |
| M7 | Club-head model: centre and toe points | Impact frame within 1 frame on 95% of strikes; club speed, attack angle and club path evaluated against TrackMan; each stays unavailable until it passes G2 |
| M7b | Spin research track: surface-feature tracker on marked balls | Direct spin within the spec 08 estimate target on marked-ball strikes, or the track is closed and spin stays estimated |
| M8 | Freeze model + test set, run the held-out evaluation | Feeds the G2 report (item 3.7); failed metrics ship as unavailable |

## 9. What changes for the bay visit at the end of the week

The bay is the only paired data source, so every visit should also produce training data:
- Record the **full impact window** (not only the G1 timing clips) for every strike, at the exposure sweep settings G1 already plans (1/1000, 1/2000, 1/4000 s) so the model learns the blur we will use.
- Note per strike: golfer (pseudonym), club, handedness, and keep the TrackMan export row ID. **The export must include** ball speed, launch angle, launch direction, spin rate (and axis), club speed, attack angle, club path and smash factor, so every metric in section 3a has a reference.
- Hit at least one series with a **marked ball** (a straight line drawn around the ball's equator, or a dot pattern) for the spin research track, if the owner agrees (Q9).
- Add 10 minutes of negatives (practice swings, ball placement, walking past) and 2 minutes of the empty hitting area (background plates for compositing).
- Ask every golfer for consent to use their clips for training (section 10).
- Measure the camera-to-ball distance with a tape: the D1 manifest says 0.75 m, but the ball in the D1 frame is about 88 px, which means about 0.35 m. The manifest value was a default, not a measurement.

These are added to `docs/BACKLOG.md` (B9-B12).

## 10. Privacy, consent, licences, provenance

- Clips show people. Training use needs each golfer's consent (written, kept with the session notes). Clips and labels stay on the owner's machines; no cloud training or labelling service without a new owner decision. Faces are not needed: crops around the ball and club are what the model sees.
- No ShotVision or other competitor material anywhere in the data or the model (CLAUDE.md clean-room rule). No scraped video.
- Third-party code, weights and datasets: listed in `docs/PROVENANCE.md` with licence and use (training only / shipped). Ultralytics (AGPL-3.0) not shipped without a commercial licence.
- The model is versioned and reproducible from the model card (data hash + code + config).

## 11. Validation of this plan (done 2026-10-15, as a reviewer would)

1. **Arithmetic re-computed with a script** (not copied from the G1 plan): the table in section 3 comes from pinhole geometry with the measured FOV of 106.2 degrees, 1920 px width, ball 42.67 mm. The 1/253 s indoor exposure gives 0.178 m of blur at 45 m/s = 4.2 ball diameters, which matches the G1 plan's "about 18 cm".
2. **Checked against a real frame:** extracted frame 0.5 s of D1 clip `20261011T210411Z-70c716f2` (ball on a laptop). The ball measures 88 px across (a pixel-run measurement along the stored frame's vertical axis; the horizontal run merged with a white chair behind it); at that FOV this implies about 0.35 m from the camera, while the manifest says 0.75 m. Findings: (a) the pixel-size arithmetic is in a plausible range, (b) the setup distance field is not measured and cannot be used as scale, (c) frames are stored rotated, so orientation handling is part of the data pipeline, (d) the frame has bright window frames, lamps, a white chair and a glass in view: a simple brightness threshold already merged the ball with the chair, which is exactly why the classical ball lock needs a learned check (section 4, step 1).
3. **Sources spot-checked** by reading the pages, not only search snippets: the YOLO11 project's "under 10% of frames" and its two causes; WASB code licence (MIT); Create ML parameters (batch size, iterations, grid size, algorithm). Claims that could not be confirmed from a primary page are marked as such in section 2 (licences of YOLOX, RT-DETR, NanoDet: verify upstream).
4. **Repository facts confirmed:** `ShotVersions.pipeline` exists for model versioning; `g1-annotations/1` exists and can be extended; the `Capture` / `CaptureAV` split is the pattern for `Detection` / `DetectionCoreML`; the gate already runs `check-no-upload.sh`, which a bundled model does not violate.
5. **Training hardware:** the development Mac is an Apple M1; Python 3 is present but PyTorch and coremltools are not installed yet (M0 task). Training time on the M1 is unknown until M4: listed as a risk, not assumed.
6. **Per-metric observability re-computed** (script, ultra-wide 106.2 deg, 1920 px): ball radius 20.5 px at 0.75 m and 15.4 px at 1 m; 1 deg of horizontal launch changes the radius by only 0.31-0.45 px over the visible flight; random centre noise of 0.5 px gives about 0.1% speed noise and about 0.05 deg vertical-angle noise, so systematic errors (scale, distortion, rolling shutter, calibration) dominate; 240 fps aliases spin above 7,200 rpm unless the spin direction is known (backspin), which extends it to 14,400 rpm; the club head gives 2.4-4 frames over its last 0.5 m at 30-50 m/s. These numbers are why horizontal launch and club path are marked experimental/research, and spin estimated.

## 12. Rubber duck: how this plan could still be wrong

1. **The ML is not the bottleneck; light is.** If 1/2000 s is too dark indoors (G1 hypothesis H2), no model fixes 4-diameter streaks reliably. *Check:* M1 on the bay's exposure sweep before any training; the blur-aware labels keep long exposures usable for position, but speed accuracy must be shown per exposure.
2. **Too few frames.** At 70 m/s on a narrow view we get 2-3 frames, and the first post-impact frame is often hidden by the club. *Check:* the section 3 table per lens and distance; M1 reports frames-with-ball per strike; if p10 is below 3, the setup distance or lens changes before training.
3. **Overfitting to one bay.** One background, one light, one mat, one golfer. *Check:* split by session; M4 must be evaluated on a home session the model never saw; per-condition metrics, not one average.
4. **Validation leakage** (the YOLO11 project's failure). *Check:* no augmentation on validation/test, split by session and golfer, never by frame; the G2 test set is frozen before M4 and its hash recorded.
5. **Detection good, measurement bad.** Rolling shutter, lens distortion and depth ambiguity can bias speed even with perfect centres. *Check:* downstream speed/launch error against TrackMan is the M4/M8 criterion, not detection AP; rolling-shutter and distortion corrections are tested with the scale-bar and drop-ball clips from the G1 protocol.
6. **Core ML differs from PyTorch** (FP16, op support, layers falling back to CPU). *Check:* parity test with tolerances; the performance report shows placement; latency measured on the oldest profile.
7. **Licences.** A convenient YOLO export would make the app AGPL. *Check:* M0 licence decision; `PROVENANCE.md` row for every third-party item; no Ultralytics package in the app target.
8. **Club head is much harder than the ball** (larger, rotating, blurred, varied shapes). *Check:* the club model is optional for launch and only refines the impact frame; club speed stays unavailable until validated.
9. **Confidence misused as accuracy.** *Check:* uncertainty is calibrated from held-out errors (spec 5); the UI never shows the detector score.
10. **Synthetic data drags the model away from reality.** *Check:* compositing on real plates first; every synthetic addition must improve the real validation numbers or it is dropped.
11. **Left/right is not observable enough from the side.** Horizontal launch and club path hinge on sub-pixel size changes that lens distortion, blur and the head's rotation can swamp. *Check:* horizontal launch is labelled experimental until G2; club path stays research-only; the bay data shows the error directly; if it fails, the honest answer is "unavailable" or a second camera view (Q10), not a tuned model.
12. **Spin from an unmarked ball is mostly not visible.** *Check:* spin ships as an estimate (spec 5); the direct track is limited to marked balls and closes if it cannot meet the estimate target.
13. **Smash factor looks precise but inherits two errors.** *Check:* derived only when both speeds are measured on the same strike; its own error is reported from the bay data, never assumed.
14. **Effort.** Labelling 600 strikes by hand is days of work. *Check:* interpolation in CVAT, auto-labelling at address, model-assisted labelling after v1; M2 records hours spent per 100 strikes.

## 13. Owner decisions (all accepted 2026-10-15)

The owner accepted every suggestion in this plan on 2026-10-15. Where a question offered a choice, the plan's default is what was accepted; it is written out here so nobody has to guess.

- **Q1 Accepted:** layered approach: no-ML baseline (B0), Vision trajectory comparison (B1), Create ML baseline (B2), then our own multi-frame heatmap model (M) and club-head model (C). Move up a rung only when the rung below fails its criterion.
- **Q2 Accepted:** no external licences in the product; own model, own weights, own data; permissive tools (Python, PyTorch, coremltools, optional MLX) for development only, recorded as dev-only in `PROVENANCE.md`; no Ultralytics code or weights.
- **Q3 Accepted:** written consent from every golfer before their clips are used for training; clips and labels stay on the owner's Macs; pseudonymous golfer IDs; clips of a golfer who withdraws consent are deleted with their labels and the next model is retrained without them. Consent text drafted with the bay session notes (backlog B12).
- **Q4 Accepted:** training local on the M1 Max MacBook, everything else on the M1 Mac mini; no rented GPU, no upload.
- **Q5 Accepted:** club-head model after the ball model (milestone M7), using the same data from the start (club points are labelled from the first labelling pass so no clip is labelled twice).
- **Q6 Accepted (plan default):** white balls at launch; yellow and matte balls are collected and evaluated as their own stratum and added to the supported list only when they pass.
- **Q7 Accepted:** a freedom-to-operate review of the single-device launch monitor patents before release (owner arranges; recorded in the backlog as H6).
- **Q8 Accepted:** add `clubPath` to the metric catalogue as an additive, optional metric (SI radians, right positive = in-to-out for a right-handed golfer, mirrored by handedness); proposed targets adopted as the G2 targets: attack angle MAE ≤ 1.5 deg, p95 ≤ 3 deg; club path MAE ≤ 2 deg, p95 ≤ 4 deg; smash factor MAE ≤ 0.08. Implemented when the club work starts (backlog E23); until then club path exists only in research tools.
- **Q9 Accepted:** spin ships as **Estimated** at launch; a marked-ball research track (M7b) runs alongside; a product option "use a marked ball for measured spin" may follow only if M7b passes G2.
- **Q10 Accepted (plan default):** if left/right launch or club path fail from one side-on phone, they ship as **unavailable**; a second camera position is a later product decision, not part of this plan.
