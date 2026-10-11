## 5. Scientific contract: what can be claimed

### Metric catalogue

The presence of a reference metric does not establish how it is obtained. The proposed implementation classification is conservative until the new pipeline proves otherwise.

| Metric key | Meaning / SI unit | Initial implementation policy |
|---|---|---|
| ballSpeed | Ball centre speed immediately post-impact / m/s | Optical measurement candidate; true 3D speed requires solved projection geometry. |
| clubSpeed | Clubhead speed near impact / m/s | Only measured if clubhead tracking and geometry independently validate; otherwise unavailable. |
| verticalLaunch | Angle above target ground plane / rad | Measured candidate with calibrated 3D geometry; a screen-space angle is insufficient. |
| horizontalLaunch | Azimuth from target line, right positive / rad | Measured only with validated depth/projection handling and handedness tests. |
| spinRate | Rotation magnitude or documented backspin component / rad/s | Estimated by independent model initially; direct measurement requires sufficient image evidence. |
| spinAxis | Spin-axis tilt in declared convention / rad | Unavailable initially; do not manufacture curvature. |
| carry | Horizontal distance to first ground intersection / m | Model estimate with launch/atmosphere assumptions. |
| totalDistance | Carry plus runout / m | Model estimate with explicit surface rules. |
| smashFactor | ballSpeed / clubSpeed / dimensionless | Derived only when both inputs exist; not independent evidence. |
| attackAngle | Clubhead path vertical angle at impact / rad | Unavailable until clubhead-path reconstruction is validated. |
| dynamicLoft | Effective face loft at impact / rad | Unavailable without validated face orientation evidence; model-derived version must say Estimated. |
| apex | Maximum height above origin / m | Derived flight estimate. |
| lateralLanding | Landing right/left from target axis / m | Estimated with available launch/flight inputs; missing spin axis limits interpretation. |

Display spin as rpm via rad/s ×60/(2π), angles in degrees and distance/speed in chosen units. Retain raw SI values and numeric precision; display rounding never enters analytics. For a distance-only capability tier, explicitly disable lateral-scored drills and avoid full-flight claims.

### Observability and feasibility reasoning

At 240 fps, frames are about 4.17 ms apart. An illustrative 70 m/s ball travels approximately 0.292 m between frames. At 120 fps the same ball travels 0.583 m. These are calculated examples, not measured app performance. A narrow field of view may contain too few observations to estimate speed reliably. Short exposure improves blur but reduces light. High nominal FPS is therefore insufficient by itself.

An illustrative 6,000 rpm ball rotates 100 times per second: 2.4 frames per revolution at 240 fps. At 10,000 rpm it rotates about 167 times per second: 1.44 frames per revolution. Texture ambiguity, occlusion and aliasing make direct unmarked-ball spin difficult. A regression model may estimate spin, but cannot be relabelled direct optical measurement. A rotating ball's speed, axis and dimple symmetry must be separately tested.

A single camera observes 2D projections. Known object size and camera intrinsics help, but general depth, out-of-plane club motion and face orientation remain difficult. Nominal lens resolution does not prove metric observability. Do not base accuracy on a model that simply maps club choice to typical golf numbers. The R&D team must demonstrate actual information in captured images, calibrate independently and quantify its limits.

### Minimal pipeline

Capability qualification → geometry/exposure calibration → stationary ball lock → candidate strike → timestamped trajectory/club evidence → quality checks → calibrated observable quantities → estimated quantities/flight → accepted-shot transaction → mode scoring → visual/voice/replay.

Pipeline failures identify stage and reason. Confidence for tracking, geometry and inferred metrics remains separate. Calibrate uncertainty against held-out measured errors; a neural-network confidence output alone is not an accuracy confidence interval.
