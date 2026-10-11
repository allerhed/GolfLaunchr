# GolfLaunchr — iOS golf launch monitor

## 0. Read this first

**Document:** Product and feature specification, implementation contracts, agent work packages, and validation plan. **Version:** 1.7. **Research date:** 11 October 2026. **Document language:** English. **Launch app languages:** English (`en`) and Swedish (`sv`). **Working name:** GolfLaunchr. **Reference product:** ShotVision. **Target:** an independently designed iPhone application with comparable publicly documented product capabilities.

This handover is complete as a specification of the publicly discoverable scope. It is not a certification of exact installed-app parity. Research used the live marketing site, current US and Swedish App Store listings, release notes, official Apple documentation, and a historical hands-on review. No physical iPhone session, purchase flow, simulator connection, or accuracy experiment was executed during this research. Undocumented behaviours have explicit original defaults or release gates below. An agent must never translate “documented by the vendor” into “independently tested”.

The essential risk is measurement, not UI delivery. A working practice dashboard driven by synthetic numbers is a prototype. It is not a launch monitor. Release completion requires real capture, calibrated measurement, independently collected validation data, durable storage, and end-to-end tests on supported physical devices.

### How the implementation team should use this file

1. Read sections 0–5 before writing code. Adopt the original defaults unless the product owner deliberately changes them.
2. Implement G0–G2 before committing to supported devices or paid measurement claims.
3. Use feature IDs F01–F25, contracts, and test IDs as issue and pull-request references.
4. Follow work packages in section 10. Keep research provenance separate from the independently authored code.
5. Treat every unexecuted validation as NOT RUN. Implemented, verified, and released are separate states.
6. Full scope means F01–F25 and all applicable gates. A core-only build must explicitly identify omitted parity features.

## 1. Product description and name

### Product promise

GolfLaunchr turns a supported iPhone, placed securely beside a hitting area, into a golf practice instrument. It detects a shot, produces trustworthy available measurements and clearly labelled estimates, speaks selected results, stores an impact clip, and organises practice into sessions, club distance profiles, drills, and virtual play.

The main customer is a recreational golfer practising at a range or in a properly protected indoor hitting bay. Secondary users are coaches and golfers comparing club gaps. The first release is personal practice software, not a professional club-fitting instrument or a certified substitute for a laboratory launch monitor.

**Jobs to be done:** understand how far each club typically carries; see repeatable changes in speed and launch; practise distance control without touching the phone after every shot; review impact; make structured practice engaging; retain reliable progress data.

### Recommended name: GolfLaunchr

Pronunciation: “golf launcher”. This is the recommended working brand, superseding Loftlio. “Golf” makes the category immediately visible, “Launch” identifies the core purpose, and the shortened ending retains a Web 2.0 character. The spelling is a brand choice, not an SEO trick; pair it with the correctly spelled category phrase “launch monitor” in metadata.

Current naming examples reviewed on 11 October 2026:

| Existing app / title | Naming pattern | Lesson for this product |
|---|---|---|
| Golfboy:Launch Monitor | Golf-prefixed brand plus category | Combine a memorable brand with a searchable product description. |
| GolfTrak: Phone Launch Monitor | Golf-prefixed shortened word plus category | Explain phone-based measurement in metadata; do not imitate the existing brand. |
| Golfshot | Golf plus a familiar action | A direct golf association is clearer than an abstract invented word. |

These names are verified against their current App Store listings or official website (S13–S15). The recommendation is our interpretation of the pattern, not evidence that these names caused their ranking or downloads.

Shortlist:

| Candidate | Strength | Trade-off / preliminary screen |
|---|---|---|
| **GolfLaunchr — recommended** | Golf category plus launch-monitor purpose; room to add a descriptor | Dropped “e” needs consistent pronunciation and correctly spelled category metadata. No exact product surfaced in the preliminary searches. |
| GolfCarryr | Emphasises carry distances and bag mapping | Narrower product meaning; can sound like a golf bag carrier. No exact product surfaced in the preliminary searches. |
| GolfRangr — reject | Clear practice association | An existing Golf Range Robots site uses golfrangr.com (S19). |

Suggested App Store metadata, each within Apple's current 30-character name/subtitle limits (S16):

| Locale | App Store title | Subtitle |
|---|---|---|
| English | GolfLaunchr: Launch Monitor | Carry, speed & shot analysis |
| Swedish | GolfLaunchr: Slagmätare | Slaglängd, fart och analys |

Use the unchanged brand in both languages. Localise descriptions, keywords, screenshot captions, previews, support and purchase-product descriptions. Suggested keyword themes: English—golf practice, carry distance, ball speed, club distance, shot analysis; Swedish—golfträning, slaglängd, bollhastighet, klubblängder, slaganalys. These are research seeds, not measured search-volume findings. Remove duplicated title/subtitle terms when composing final keyword fields, include only shipping capabilities, respect Apple's keyword limits, and never insert competitor names.

For future web discovery, use “GolfLaunchr — iPhone Golf Launch Monitor” as an English landing-page title and “GolfLaunchr — Slagmätare för golf på iPhone” in Swedish, with separate localised pages, language metadata and relevant original explanations. This is metadata guidance, not a request to build a website. Naming improves category clarity; rankings must be evaluated after launch rather than promised.

Exact-name, golf-app and App Store-indexed searches using two search engines did not surface an exact GolfLaunchr app on 11 October 2026. This is preliminary screening, not trademark clearance, domain availability or an App Store reservation. Final checks remain with the product owner. Keep the display name configurable and the bundle identifier stable/brand-independent until approval.

### Scope boundaries

Include automatic shot capture, measurement provenance, practice modes, club mapping, historical analysis, impact replay, voice feedback, commercial entitlements, original virtual golf, and an integration framework with at least one genuinely verified adapter for full integration scope.

Do not silently add GPS course navigation, official handicap submissions, Apple Watch, iPad capture, full-body swing coaching, live multiplayer, betting, external radar hardware, or AI-generated swing diagnoses. These are not established current parity requirements in the evidence examined. Optional cloud sync is an extension; local operation is the default.

## 2. Evidence and reference feature inventory

**Evidence labels:** V = current first-party published statement; H = historical third-party observation; D = independently proposed implementation; U = unresolved. V confirms publication, not performance. Requirements below are D unless expressly identified as V or H.

### Sources

| ID | Source | Purpose and limitations |
|---|---|---|
| S1 | https://www.shotvisionapp.com/ | Current advertised modes and accuracy claim; no reproducible accuracy dataset supplied on the page. |
| S2 | https://apps.apple.com/us/app/shotvision-launch-monitor/id1352247118 | Current description, compatibility, commercial model and release history; version observed 2.9.3. Storefronts may differ. |
| S3 | https://apps.apple.com/se/app/shotvision-launch-monitor/id1352247118 | Swedish compatibility and listed IAP prices; multiple SKUs do not establish the paywall currently offered. |
| S4 | https://www.shotvisionapp.com/legal | Terms and privacy page; dated text does not establish current implementation architecture. |
| S5 | https://www.golflink.com/equipment/shotvision-launch-monitor-app-review | Historical hands-on review; do not assume every old behaviour survives current releases. |
| S6 | https://developer.apple.com/documentation/avfoundation/capture-device-formats | Official device-format configuration guidance. |
| S7 | https://developer.apple.com/library/archive/technotes/tn2445/_index.html | Official frame-drop handling guidance; confirm APIs against shipping SDK. |
| S8 | https://developer.apple.com/documentation/storekit/transaction/currententitlements | Official entitlement API contract. |
| S9 | https://fairwayr.com/ | Existing golf brand. |
| S10 | https://divotly.com/ | Existing golf brand. |
| S11 | https://carryr.io/ | Existing digital service. |
| S12 | https://loftiqo.com/ | Existing homeware brand. |
| S13 | https://apps.apple.com/us/app/golfboy-launch-monitor/id1552366622 | Current Golfboy naming pattern. |
| S14 | https://apps.apple.com/us/app/golftrak-phone-launch-monitor/id1528710964 | Current GolfTrak naming pattern. |
| S15 | https://golfshot.com/ | Current Golfshot brand. |
| S16 | https://developer.apple.com/app-store/product-page/ | Official title/subtitle limits and metadata guidance. |
| S17 | https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog | Official String Catalog guidance; verify implementation against current SDK. |
| S18 | https://developer.apple.com/localization/ | Official internationalisation/localisation guidance. |
| S19 | https://golfrangr.com/ | Existing golf robotics name/domain; rejects GolfRangr candidate. |

### Compact reference inventory

| Reference capability | Evidence | Implementation IDs |
|---|---|---|
| Camera-only iPhone operation; tripod/alignment guidance | V, S1 | F01–F03 |
| Shot Analysis, QuickShot, Map My Bag, drills, virtual courses | V, S1 | F05, F08, F11–F15 |
| Target and ladder practice; session and shot analysis | V, S1 | F09–F13 |
| Ball/club speed, carry/total distance, launch and spin | V, S2 | F04–F06 |
| Impact replay, selectable spoken metrics, challenges | V, S2 release history | F07, F13, F16 |
| Handedness, barometer, skill tracking, simulator integrations | V, S2 release history | F03, F06, F14, F15, F18 |
| Fused ball zone; recommended 0.7–0.8 m device distance | V, S2 v2.8.8 notes | F03 |
| Thirty introductory shots; subscription or lifetime access | V, S2 | F19 |
| iPhone 11 onward; iOS 18 minimum; no iPad support | V, S2/S3 | F01 |
| Smash, attack angle, apex, dynamic loft, dispersion; shot removal | H, S5 | F06, F09, F10 |

The site advertises average measured-metric difference below 3% against GC3 (S1). This is a vendor claim, not a transferable GolfLaunchr acceptance result. Current release notes describe spin models (S2); they do not establish direct optical spin measurement. Historical review found indoor lighting sensitivity and no putting support (S5); both require new-product testing.

### Conflicts resolved

* Old free-tier descriptions were superseded by the current thirty-shot offer.
* Fixed/dynamic zone history was superseded by the documented fused zone; do not recreate obsolete toggles.
* Older iOS compatibility search snippets were superseded by the current iOS 18 listing.
* Multiple monthly/annual SKUs are evidence of listed products, not one confirmed present-day checkout price.
* Apple Watch reviews from 2020–2021 are insufficient to establish current watch functionality.
* Simulator integration exists as a category; no specific provider, protocol, included licence, or course catalogue was confirmed.

## 3. Original product decisions

| Area | Default decision | Consequence |
|---|---|---|
| Platform | Native Swift/SwiftUI, minimum iOS 18 | Recheck current SDK and deployment requirements at implementation kickoff. |
| Devices | Candidate pool iPhone 11 and newer; certify by model/camera/format | Marketing support list is generated only from passing physical tests. |
| Capture | Built-in rear camera, side-on view from the opposite side of the ball to the golfer | Phone is beside the target line, aimed across it at the ball/impact region; never a behind-ball/downrange capture geometry. Exact lens/format/offset/height come from validated device profiles. |
| Swing handedness | Explicit Right-handed / Left-handed setting, chosen during onboarding and editable in Settings/setup | Both are mandatory; mirror golfer/phone placement while preserving target coordinates; recalibrate after changes. |
| Screen orientation | Landscape mandatory for camera capture; browsing, history/review and settings adapt to portrait/landscape | Portrait capture shows Rotate your iPhone guidance and cannot arm; rotation/device movement pauses arming and requires landscape geometry requalification. |
| Identity | Guest-first, local data; no login required for core use | No backend dependency for measurement or local history. |
| Network | Core practice works offline after installation/entitlement provisioning | Purchases and external integration can require connectivity. |
| Units | Independent distance m/yd and speed m/s, km/h, mph | Store SI; never mutate raw measurements on unit changes. |
| Language | Multilingual from the first release; complete English (`en`) and Swedish (`sv`) | Both are mandatory launch scope, with architecture ready for additional locales; see F25. |
| Ball | Regulation-size real golf ball initially | Foam balls and putting remain unsupported until separately validated. |
| Free allowance | 50 introductory accepted persisted shots, then 10 shots per calendar month starting the following month | No subscription enrolment required; invalid captures do not spend credit; no rollover; deleting a shot does not refund it. |
| Monetisation | Complimentary partner Pro via Apple free offer codes (F19a), plus Free + one Pro tier: 49 SEK/month or 499 SEK/year, Swedish consumer prices including VAT | Monthly and annual grant identical Pro access; annual billed upfront; no lifetime product at launch; localise actual prices from StoreKit. |
| Historical data | Read and export retained data after entitlement expiry | Expiry returns capture to the Free allowance; stored records remain readable/exportable. |
| Replay | Automatically save an impact still, chronological club/ball composite and original impact frame sequence for every accepted shot | Durable shot media is retained until explicit deletion; 1 GB applies only to regenerable preview cache. Save failures are visible; never claim missing media was saved. |
| Courses | Original fictional courses; no borrowed famous-course assets | Famous venues require separate legitimate content rights. |
| Simulator | Documented approved protocol only | Unknown provider behaviour is a blocking integration dependency. |
| AI | Optional future explanatory assistant | Generative models must not fabricate sensor results or diagnose swing faults. |

These defaults resolve product choices for the agents. They do not prove camera feasibility, name availability, or provider integration access.

## 4. Functional requirements

Priority P0 = scientific and reliability foundation; P1 = core saleable practice product; P2 = complete advertised mode breadth. P2 is required for full-scope completion, even if a limited first release ships earlier.

### F01 — Onboarding and capability qualification [P0]

**Purpose:** establish whether the device and current environment can support a reliable session.

Explain secure tripod placement, ball/swing clearance and protected hitting area. Request camera permission only when setup starts. Inspect available camera formats, supported frame durations, OS, storage and validated device profile. Show Supported, Experimental or Unsupported with specific reasons. Swing handedness is an explicit required choice with Right-handed and Left-handed options (Swedish: Högersving and Vänstersving); show a simple stance illustration rather than inferring the user's swing from their writing hand. Persist the choice; units are editable and persisted. Offer history access without camera permission.

**Acceptance:** denial offers a Settings route and does not crash; unvalidated devices cannot acquire “certified” status; lack of microphone permission cannot block camera-only use; repeated onboarding does not reset shot credits; unsupported devices can read imported or existing history.

### F02 — Setup tutorial and environment checks [P0]

**Purpose:** help a golfer achieve repeatable geometry without guessing.

Provide independently authored diagrams and live overlays for target line, ground plane, device orientation and ball position. The phone must be across the ball from the golfer, capturing a side-on view: golfer—ball—phone lie approximately on a line perpendicular to the target line, with the ball between golfer and phone. The camera faces the ball/impact region across the target line, not down the fairway. Mirror golfer/phone placement for left/right-handed swing setups, with sign conventions verified by fixtures. Use top-down guidance to avoid ambiguous perspective illustrations. Keep the device outside the swing envelope and flight line; validate exact offset/height/lens and capture region experimentally. Estimate brightness, blur, motion and flicker risk from frames. Offer a test setup without spending trial credit. Indicate the exact reason capture is blocked and the action to correct it.

**Acceptance:** a moving device, lost calibration or unsuitable exposure disables arming; changing handedness forces confirmation/recalibration; a test ball placement cannot generate a scored shot. Initial distance guidance may use 0.7–0.8 m as a research starting point, but shipping setup must use the new pipeline's measured geometry and safety constraints.

### F03 — Calibration and ball-lock state [P0]

**Purpose:** convert image positions into physically meaningful estimates.

Persist a versioned calibration record containing camera/lens, format, image transform, intrinsic/distortion information where available, target coordinate transform, scale method, capture orientation, device pose and timestamp. A known ball diameter can be one scale input; it is not sufficient by itself to solve general 3D motion. Ground/target alignment and optical geometry require an explicit calibrated method. Calibration confidence is independent of ball detection confidence.

Use one guided ball-placement region. Acquire a stable stationary-ball lock; tolerate a club grounded near the ball without changing scale. Show Seeking ball, Adjust position, Ball locked, Ready, Processing and Reposition device. Freeze calibration inputs at arming; invalidate on movement, lens/zoom/format changes or loss of required geometry. Audio prompts obey user settings.

**Acceptance:** stationary ball and club waggle do not create shots; a ball leaving the placement region cancels readiness; format/pose changes cannot reuse stale calibration; each shot links to exactly one calibration version and a frozen swing-handedness snapshot; both handedness profiles enforce the opposite-side side-on placement. Exact thresholds are profile parameters determined at G1, not arbitrary universal constants.

### F04 — Automatic shot capture [P0]

**Purpose:** accept one genuine strike exactly once.

Run a bounded timestamped pre-impact ring buffer and post-impact collection. Detect candidate movement, track ball/club evidence, distinguish a strike from handling, a practice swing or nearby golfer activity, and evaluate frame integrity. Camera is the baseline trigger; optional audio may later corroborate a strike with separate permission. Use presentation timestamps rather than assumed nominal FPS. Debounce based on tracking state, then require a new stable ball lock.

**Acceptance:** valid strike creates one candidate and at most one accepted shot; rejected candidate exposes a reason and spends no credit; no fake completion while computation is pending; foreground interruption pauses capture and demands requalification; club selection is frozen at arming and cannot be retroactively changed by a late UI tap.

### F05 — Practice capture and QuickShot [P1]

**Purpose:** let the golfer begin open practice or a lightweight single-club session.

Offer QuickShot with last-used club/settings and the same calibration checks as other modes. It reduces navigation, never measurement safeguards. Standard Practice permits explicit club switching between shots, a target carry setting, shot count and session notes. Accepted results update large metric cards, latest-shot list and a visual trajectory if supported. Pause, resume and end are explicit. Ending a session summarises data; an interrupted session is recoverable.

**Acceptance:** QuickShot persists history normally; a club change is applied only to the next armed shot; ending with zero accepted shots creates no misleading averages; double-tapping end cannot duplicate a session; target changes do not rewrite previous target snapshots.

### F06 — Metrics and flight model [P0]

**Purpose:** expose useful data without hiding how it was produced.

Implement the metric catalogue in section 5. Every metric has value-or-null, SI unit, provenance, uncertainty where supportable, quality status and model version. UI labels distinguish measured/estimated/unavailable. Do not generate club speed from a guessed smash factor, then present both as independent measurements. A missing spin value must not be replaced by a club-table value labelled measured.

Flight modelling consumes verified launch inputs and declared assumptions. Support standard atmosphere and optional pressure-adjusted mode; obtain absolute pressure only from a validated sensor/API or explicit manual input. Snapshot all inputs, pressure source, temperature, air-density calculation and model version. Do not assume relative altitude is absolute altitude. Carry is flight-to-ground distance; total adds an explicit surface/runout model. Unavailable inputs produce an estimated range or a missing result, as agreed at G2.

**Acceptance:** setting pressure mode recalculates a new derived view consistently across result cards and bag mapping; raw values remain unchanged; calculations are deterministic for versioned input; trajectory shape does not invent measured spin axis; an unsupported metric displays unavailable, never 0; all G2 thresholds pass before measurement marketing.

### F07 — Spoken and visual feedback [P1]

**Purpose:** report results without moving the phone.

Allow independent selection of carry, ball speed and vertical launch angle, with additional metrics only if enabled by design. Speak selected metrics in stable order, including units and estimate qualification. Provide ready/reposition prompts, mute, system audio routing and a preview. Visual and accessibility text always accompany status audio. Maintain a bounded speech queue; replace obsolete unspoken results instead of reciting a backlog. Avoid speaking during the next strike capture window when it would impair an optional audio trigger.

**Acceptance:** preferences persist; multiple selected metrics all speak correctly; target/drill start uses the same audio pipeline; silent mode does not block capture; headphone disconnection does not crash; pressure and unit changes affect spoken values consistently.

### F08 — My Bag: club management [P1]

**Purpose:** give every shot a stable club identity.

Create/edit/archive clubs with custom name, category, optional loft, optional brand/model and sort order. Seed an editable common bag; include duplicate lofts and multiple wedges. Archive preserves historical IDs and name snapshots. Updating loft affects future estimation inputs only unless the golfer explicitly requests a versioned recalculation.

**Acceptance:** deleting/archiving a club cannot orphan shots; renaming does not silently alter historical snapshots; custom loft rejects non-finite and nonsensical values; no mandatory manufacturer catalogue or guessed stock loft.

### F09 — Map a Club / Bag mapping [P1]

**Purpose:** build a repeatable distance profile for each club.

Select one or several clubs and collect a proposed minimum of ten included accepted shots per club. Show count, mean, median, sample SD, 10th/90th percentiles, longitudinal/lateral dispersion where available, and confidence/coverage notes. Ten is a product default, not proof of sufficient scientific confidence. Recommend more samples for unstable sets. The golfer explicitly includes/excludes shots; automatic anomaly flags do not delete data. Separate measured-condition profiles from standardised-condition profiles. Compare gaps between adjacent clubs without forcing distance to increase monotonically.

**Acceptance:** exclude/restore immediately recomputes statistics and drill-derived summaries without changing original measurement records; fewer than ten shots is labelled provisional; zero/one-shot sets show no SD; mixed clubs cannot enter a single-club profile; pressure/model changes have visible version context.

### F10 — Activity history and session analysis [P1]

**Purpose:** review practice and audit the data behind summaries.

List sessions with mode, time, duration, clubs, accepted/rejected counts and data-quality summary. Filter by date, mode and club. Detail contains included shot table, per-club aggregates, dispersion plot, target outcomes, notes and linked replay. Shot detail includes inputs, measurement provenance, uncertainty, exclusion state and diagnostic reasons. Permit exclusion, restoration and confirmed permanent deletion of shots or whole sessions; recompute dependent results transactionally.

**Acceptance:** failed captures cannot contaminate averages; deleting media alone does not remove measurements; deleting a session removes unreferenced clips and memberships while preserving credit ledger; no empty or non-finite chart; dates display in local time while storage uses UTC.

### F10a — Detailed shot review, club averages, gapping and multi-club filters [P1, original addition]

**Purpose:** review every recorded shot, understand repeatable club distances and compare gaps using one clearly defined data selection. Extends F09/F10; screenshots supplied by the owner are functional inspiration, not assets to embed or copy.

**Navigation:** Progress → session → Shots / Averages / Gapping; Dispersion is reachable from Shots/Averages. My Bag → club profile opens the same analysis with that club selected. Tapping a shot row or dispersion point opens Shot detail, then F16 impact still/composite/original frames. Tapping a club average opens its detailed metric profile and View all shots. Back preserves selected filters, scroll, tab and selected shot. Selection never resumes camera arming implicitly.

**Shared filter contract:** single or multiple club IDs, session/date range, mode, inclusion state, Carry/Total distance and As recorded/Standardised conditions apply consistently to shot list, comparison baseline, club averages, dispersion and gapping. All clubs means every eligible club within the current scope; selecting specific clubs clears All clubs. Multi-select combines clubs using OR; other filter categories combine using AND. Clear restores defaults (all clubs, current session, included shots, carry, as recorded); Apply commits a draft atomically, Cancel leaves prior filters. No selected clubs is a visible empty selection and Apply is disabled until one or All clubs is selected. Persist applied filters during navigation/relaunch; identify the scope explicitly. Archived clubs with historical shots remain selectable. Distinct clubs with identical display names remain separate IDs.

**Shot-specific data:** shot number/ID, original club snapshot, date/time, mode/session, inclusion state, conditions/model version, data-quality diagnostics, every available metric in the section 5 catalogue, units and measured/estimated/unavailable labels. Initial cards: carry, total, ball speed and launch angle; additional supported metrics in Measurement details. Unsupported metrics show unavailable, never a fabricated zero. A saved near-impact image links to source-frame review; media failure does not hide measurements. Compare the shot with the same club's mean under the active filters, identifying sample count and whether the shot itself is included. Default baseline includes all included eligible shots, including the selected shot if included; exclusion changes the baseline. Show no comparison when the selected shot lacks a comparable value. Exclude/restore is reversible, recomputes analysis and does not refund Free credits; permanent deletion requires confirmation.

**Club averages/profile:** cards per selected club show included sample count, mean distance and Spread (±1 SD); detail includes median, 10th/90th percentile, range (shortest–longest), supported metric means, valid sample count for each metric and longitudinal/lateral dispersion where supported. Label averages of estimated distances Estimated; metric provenance must remain honest. Do not use the ambiguous Variation label for both SD and range. Sample SD uses n−1 and is unavailable for fewer than two valid samples; fewer than ten eligible distance samples is Provisional. Null/non-finite/rejected/excluded data is omitted from that metric calculation, never zero-filled. Quantiles use a documented linear interpolation algorithm. Aggregates are computed from eligible shots, not an unweighted mean of session averages. Missing metric coverage is visible.

**Gapping:** compare mean carry by default (or total when explicitly selected) between neighbouring selected clubs in the user's bag order. Gap to next = mean distance for current row minus next row, calculated from unrounded SI means. Keep signed results: zero means equal means; negative means the next club's mean is longer. Never sort distances to conceal inversions, force monotonic gaps or silently merge clubs. Last eligible row has no next gap. Rows with no valid distance remain visible as No data and break comparison; do not bridge them as if data existed. Show included counts and provisional status. With a subset, label Selected clubs only and warn that missing clubs can make gaps look larger. Any gap/overlap advisory is a transparent configurable product heuristic, not a fitting diagnosis or universal ideal. Gap means and distribution overlap are distinct concepts; SD bands are not confidence intervals for a mean.

**Conditions:** As recorded uses each shot's saved conditions/model; mixed conditions carry a comparison warning. Standardised is a versioned derived view using the declared standard atmosphere/surface and supported flight inputs; do not overwrite original shots. If standardisation cannot be computed, mark that shot unavailable for that view and disclose reduced coverage. Provenance remains estimated. Carry and Total must not be mixed in a single gap table. Export includes filters, calculation/normalisation version and inclusion policy for reproducibility.

**Dispersion:** use an original labelled grid with longitudinal/carry and lateral axes, stable club colours plus symbols/text (not colour alone), dots linked to shot IDs and optional disclosed spread ellipses. Present estimated landing positions as estimates, not GPS-measured real landing coordinates. No satellite imagery, geolocation or mapped range licence is required. Unknown lateral data permits distance-only plotting and a clear limitation. At least three non-collinear valid points are required for a 2D covariance ellipse; show dots/1D spread otherwise. Ellipse legend explains its mathematical scale and does not claim guaranteed 68%/95% coverage. Filters remove unrelated points and recompute each club's summary/ellipse. Tap selects a point; overlapping dots offer a shot picker; zoom/reset and an accessible shot-list alternative are available.

**UI/localisation/orientation:** individual original screens: Shot detail, Club averages, Club metric profile, Club gapping, Shot dispersion and multi-club filter sheet. Portrait uses cards and stacked summaries; landscape uses compact filters, master/detail and wider plots/table, preserving the identical selection and values. These are review screens, so both orientations work while capture remains landscape only. English/Swedish labels include Shot details / Slagdetaljer, Club averages / Klubbgenomsnitt, Club gapping / Längdskillnader, Filter clubs / Filtrera klubbor, All clubs / Alla klubbor, Carry / Carry, Total / Totalt, As recorded / Registrerade förhållanden, Standardised / Standardiserade, Spread (±1 SD) / Spridning (±1 SD). Native Swedish review remains required.

**Entitlements:** individual shot records, basic results, filters needed to find one's records and saved impact media remain accessible in Free and after expiry. New advanced club-average/profile, dispersion and gapping computation is available during introductory access and active paid/complimentary Pro. Previously saved analysis remains readable/exportable after expiry. A Free user sees a clear advanced-analysis upgrade preview; filtering history is not a loophole for recomputing locked Pro analytics, and paywalls cannot hide existing records.

**Acceptance:** deterministic fixture with club means 224/160/130/110 m produces signed gaps 64/30/20 m; selecting 5 iron and 7 iron yields 30 m with Selected clubs only. Fixture [120,130,140] m gives mean 130 m, sample SD 10 m, range 120–140 m and (linear-interpolated) P10/P90 122/138 m. Unequal session sample sizes are correctly pooled. Test zero/one/two samples, nulls, exclusion/restoration/deletion, duplicate names, archived clubs, filter OR/AND, cancelled drafts, empty filters, inversion/missing-club rows, carry/total switching and standardisation coverage. Verify list/dots/averages/gaps share the same eligible IDs, shot-to-average delta matches, orientation/back/relaunch preserve selection, units change display only and export reproduces analysis. All app/device UI tests remain NOT RUN until attached evidence exists.

### F11 — Target drill [P2]

**Purpose:** practise one carry distance with transparent scoring.

Choose target distance, lateral tolerance (only when validated), longitudinal tolerance, club restrictions and attempt count; defaults 100 m target, ±5 m longitudinal, ten accepted attempts. No universal distance default is imposed after user customisation. With lateral data, hit requires both tolerances; without it, explicitly label Distance-only and score longitudinal tolerance only. Display hit/miss, signed short/long and left/right errors, streak, progress and final summary.

**Acceptance:** a boundary error exactly equal to tolerance is a hit; invalid capture does not advance attempt; an excluded shot is removed from progress and scoring; history preserves original drill configuration. Result-only accuracy uncertainty is displayed and must not be confused with the target tolerance.

### F12 — Ladder drill [P2]

**Purpose:** practise changing carry distance deliberately.

Default targets: 50, 75, 100, 125 and 150 m, one accepted hit required per rung, ten attempts maximum per rung, ±5 m longitudinal tolerance; all configurable before start. A hit advances; a miss remains at the rung; exhausted attempts marks the rung failed and ends the run. Save incomplete progress and permit resume. Offer ascending/descending order. Changing units converts targets, not the physical task.

**Acceptance:** no rung skips; invalid shots spend neither attempts nor progression; replay/reload cannot double-advance; edits to past included shots trigger deterministic recomputation from the event sequence; original ordering and configuration are persisted.

### F13 — Driving range and challenges [P2]

**Purpose:** make open practice and scored tasks visually engaging.

Provide an original virtual range with target markers, shots and distance grid. Challenges are versioned configurations using the shared scoring engine: closest-to-target over ten attempts and ten-shot target-hit count are the initial original definitions. Persist personal bests with configuration/version and condition tags. Do not compare mixed configurations or falsely call estimated horizontal flight a measured shot curve.

**Acceptance:** a replay of the same accepted event never increases score twice; leaderboard/personal-best entries identify rules; unavailable lateral data enables only distance-based challenges; reference challenge names and rules are not assumed.

### F14 — Skill tracking [P2]

**Purpose:** reveal repeatable changes across comparable practice.

Original implementation shows target-hit rate, median absolute carry error, within-club carry variability and validated lateral spread by week/month. Require ten comparable included attempts before showing a non-provisional trend. Include sample count, conditions and club filters. No unexplained composite Skill score. Future composite indices require published weights and versions.

**Acceptance:** exclusions and deletion propagate to trends; sparse samples say Insufficient data; pressure/model changes are flagged; trends describe statistical changes without inventing coaching causality.

### F15 — Virtual golf and simulator connections [P2]

**Purpose:** turn accepted launch events into playable virtual rounds.

Native original mode: select fictional course, tee and nine/eighteen holes; orient aim; choose club; hit; see calculated flight and landing; update lie, score and hole progress; save/resume. Implement fairway, rough, bunker, out-of-bounds and water as original versioned rules. Default water/OOB penalty is one stroke plus a rule-defined drop; label gameplay simplified, not official competitive rules. A landing on the putting area triggers configurable auto-putt based on disclosed distance bands (≤3 m one, >3–10 m two, >10 m three putts); make bands part of course/rules version. Do not claim to measure putts. Maximum hole strokes configurable, default ten. Allow practice/reset without spending more than actual accepted capture credits.

Third-party mode: provider selection, provider-specific setup, local-network permission when necessary, connectivity status, explicit armed state, one event per accepted shot, schema/unit negotiation, acknowledgment, disconnect handling and logs stripped of personal data. No provider-specific release claim until G5 passes. Unknown provider licences and APIs are not permission to invent an integration. Do not retry an unacknowledged shot into a provider that has no deduplication guarantees; reconcile or request user confirmation.

**Acceptance:** same input/config produces same landing and score; interruption restores current hole/lie without duplicate stroke; all penalties and auto-putts are explained; rejected shot has no effect; third-party connection passes a real provider session, unit mapping, reconnect and duplicate-event tests. Unsupported spin axis must not be transmitted as a measured zero.

### F16 — Saved impact image, frame composite and replay [P1]

**Purpose:** inspect the capture evidence around impact.

Save approximately one second before and one second after the detected event where capture resources allow; this is a configurable original window. Show an impact marker, play/pause, scrub, previous/next captured frame, frame index and relative timestamp. Review is available immediately and from history. The frame-step contract follows encoded presentation timestamps, including variable intervals, rather than 30 fps UI assumptions. Preserve a frame-index manifest or equivalent reliable decoder index. If dropped frames occur, mark the gap; do not pretend interpolated frames are captured evidence.

**Per-shot impact package (mandatory):** automatically persist the original captured impact-window sequence (high-frame-rate clip with reliable frame manifest, or lossless source frames), one best available near-impact still, and an independently rendered multi-frame composite showing chronological clubhead/ball positions from before contact through initial launch. Link all three to the immutable shot ID and original orientation/handedness/calibration. The camera remains side-on, across the ball from the golfer; this is impact-region capture, not a full-body swing video. Save inside the app without asking for Photos permission; Photos export is optional user action.

Generate the composite deterministically from actual captured frames using a fixed background and validated club/ball masks/tracking. Use 4–8 suitable sampled positions where available, timestamped and ordered, with restrained transparency and a Frame composite label. Do not fabricate club positions, in-between frames, a full swing or unseen ball flight. If segmentation/visibility is insufficient, retain the original frames and still, show Composite unavailable with a reason, and allow retry from source; never manufacture evidence. If exact contact is between frames, label the still Nearest captured frame with its real time rather than claiming exact contact. Mirroring presentation must not alter stored source evidence or target coordinate signs.

**Capture layout:** landscape only, slim header (mode, club, readiness/settings), dominant side-on camera pane, right-side last-shot metric stack, saved-impact thumbnail and pause/end controls. No bulky navigation rail inside active capture. Live preview shows the current single camera frame and alignment overlay; the chronological composite belongs to the saved-shot preview/review, not a fake live multi-club scene. Selecting a saved thumbnail pauses arming before opening review. Review provides Composite / Impact still / Original frames, chronological thumbnail strip, play/pause/scrub/one-frame steps, metrics with provenance, and Share image. Portrait remains supported for review, history and settings. English/Swedish labels include Frame composite / Bildsekvens, Impact still / Bild vid bollträff, Original frames / Originalbildrutor, Rotate your iPhone / Vrid din iPhone.

**Durability and storage:** commit a media manifest with pending/complete/partial/failed states, relative paths, checksums, frame presentation timestamps and composite version. Finalise files atomically and recover pending work after a crash. Show Saved only after the promised package is durable; expose partial/missing artifacts individually. Measurement save success and media save success are separate. A media failure cannot erase an otherwise accepted shot, and retry never spends another Free credit. Keep shot media until explicit user deletion; warn and block new arming when insufficient storage would prevent saving a package. Preview cache eviction must not delete source frames, composite or still. Deleting a shot/session removes its unreferenced media; deleting just media preserves measurements and reports the absence. No silent downgrade to a still-only capture mode. Determine supported frame rate, buffering window and package size through physical-device benchmarks before release.

**Acceptance:** next/previous advances exactly one decodable captured frame, endpoints clamp and no frames are silently skipped; rotation does not misalign overlays; missing/evicted media shows a useful empty state; save failure cannot lose the shot; last-used playback speed persists.

### F17 — Data export and sharing [P1, original addition]

**Purpose:** make results useful to golfers, coaches and validation teams.

CSV exports carry SI values and optional chosen display units, metric provenance, quality, club/session IDs, exclusions, conditions and model version. JSON exports use the versioned schema below and include trial-independent historical records. Clips export through the system share sheet only on user action. Aggregate share cards use original graphics and identify estimates. Ask whether to include notes/media; omit diagnostic device identifiers by default.

**Acceptance:** exported numeric values round-trip without changing measurements; nullable metrics remain null; formula-leading CSV text is escaped safely; deleting data removes future export eligibility; cancellation leaves no persistent temporary media.

### F18 — Settings and environmental adjustment [P1]

**Purpose:** keep setup, results and analytics consistent.

Settings include System/English/Svenska language selection (F25), an explicit Swing handedness row opening Right-handed / Left-handed choices (Högersving / Vänstersving in Swedish), distance/speed units, voice metrics, replay retention, visual theme, standard/ambient atmosphere, manual pressure/temperature when permitted, and privacy choices. Calibration-required settings state their consequence before change. Ambient inputs have timestamps and source. Barometer absence offers manual/standard mode, never a silent fabricated value.

**Acceptance:** the handedness setting persists across relaunch and is also available during setup; changing it pauses arming, clears the old ball lock, mirrors placement guidance and requires recalibration before capture resumes; existing shots retain their original handedness/calibration snapshots; all screens and voice use one formatting layer; changing display units does not affect scoring; manual environmental values are range-checked; stale inputs are flagged; stored shots keep environmental snapshots and revised views are explicitly labelled.

### F19 — Freemium allowances and Pro subscriptions [P1]

**Purpose:** let golfers establish trust through free practice and subscribe for sustained practice and analysis. This is the owner-approved launch commercial model; competitor inventory in section 2 remains historical research evidence, not our product policy.

**Products and pricing:** Free costs 0 SEK. Pro Monthly costs **49 SEK/month**; Pro Annual costs **499 SEK/year**, billed upfront, both including VAT for Sweden. Both auto-renew and grant identical features. Use one StoreKit subscription group at the same entitlement level, with monthly/annual durations. No lifetime product, advertisements or per-shot paid credits at launch. Other storefronts use configured regional prices; render StoreKit product prices rather than hard-coded checkout amounts. Annual is approximately 41.58 SEK/month and saves 15.1% against twelve monthly payments (588 SEK); label any monthly equivalent as annual billing, never as an actual monthly charge. The annual plan becomes cheaper than monthly from the eleventh paid month. Do not retain prior 99/799 SEK proposal or its 33% saving in product copy.

**Free allowance:** 50 one-time introductory accepted/persisted shots, with access to all shipping implemented modes and analysis features for those shots. No subscription enrolment or automatic billing for this allowance. When the 50th shot commits, introductory access ends. Ten recurring free shots become available on the first day of the following calendar month and each month thereafter, with no rollover. Persist the reset time zone at introductory activation (device zone initially) and show the next reset date; later language, region or time-zone changes do not reset usage or advance the period. Before introductory exhaustion, monthly credits do not accumulate. A subscription purchase does not reset introductory usage; paid captures consume no Free credits. On expiry/revocation, unused introductory credits remain available; if already exhausted, use the current monthly balance or wait for its reset. Monthly grants during paid membership do not bank beyond the current month.

**Free after introduction:** guided setup/calibration/device checks, both swing handedness settings, English/Swedish, portrait/landscape, all validated metrics and provenance labels for allowed shots, voice feedback, impact replay and basic session results. Existing recorded data and user-created club records remain readable/exportable. New advanced club mapping, dispersion/trend analysis, target/ladder drills and original virtual golf require Pro after introductory access; basic free practice is available within the monthly allowance. Display locked features clearly; never silently unlock advanced computation by reopening history. Existing saved analysis remains readable. Setup checks and measurement quality are identical across tiers.

**Pro:** unlimited accepted capture, full local history and analysis, club mapping/gapping, dispersion/progress, target/ladder drills, original virtual golf and all core replay/voice functions. Include only implemented and validated functionality in purchase claims. Third-party simulator licences, paid external services, cloud video storage and future generative coaching are not promised as unlimited included benefits. Any future bundle requires its own cost/licensing decision.

Maintain a separate append-only usage ledger keyed by shot ID with allowance kind (introductory/monthly/paid/complimentary), period ID, cost and commit timestamp. Atomically check allowance, accept/persist a shot and spend one available Free credit; rejected captures, calibration attempts, duplicate processing and explicitly labelled demo fixtures spend none. Shot deletion/exclusion does not refund a credit. Reserve permission at arming so concurrent expiry/reset events cannot produce inconsistent limits; finish an already permitted shot and settle the ledger once. Block subsequent arming when no allowance/entitlement remains. Show remaining shots before practice and a dismissible upgrade offer after the last allowed result, never during an armed swing. Offer return to history/settings and show the next free reset date. When a mode requires Pro, ask before starting that mode.

Use verified StoreKit transactions and entitlement updates. Allow offline use of last verified subscription entitlement subject to the documented seven-day revalidation window, capped by known expiry; no paid grace following known revocation. Offline Free usage works with a persisted ledger and period boundary; never grant duplicate periods on clock rollback. A guest allowance is device-local; do not promise reinstall-resistant global limits without a backend/account design. Document clock/reinstall limits; device-clock manipulation must not create unlimited free grants.

**Commerce UI:** individual plan comparison, allowance exhausted, purchase result and subscription management screens; adaptive portrait/landscape and complete English/Swedish. Display actual localised price, billing period, auto-renewal, annual upfront total, terms/privacy, restore purchases and management links. Provide pending/cancelled/failed purchase states. Loading failure offers retry and does not masquerade as zero-priced access. Keep an explicit Continue Free/dismiss route. Neither annual nor monthly has an additional auto-renewing trial at launch; the app allowance is the free evaluation.

**Acceptance:** test introductory shots 49/50/51 and monthly shots 9/10/11; final allowed shot commits and the next cannot arm without another allowance. Invalid attempts do not spend. First monthly grant occurs only next month after introductory exhaustion; reset is idempotent and unused credits expire without rollover. Purchase/retry cannot double-grant; restore works; cancellation preserves access through known expiry; expiry/refund/revocation returns to the correct Free state and leaves historical data readable/exportable. Paid use does not consume/reset Free credits. A crash between capture and commit cannot double-spend. Test exhausted Free while offline, calendar/year boundaries, clock rollback, time-zone/language changes, safe purchase timing, and dismissal. Verify 49/499 SEK configured products and the 15.1% annual saving in both languages. StoreKit/device acceptance is NOT RUN until evidence is attached.

### F19a — Complimentary partner Pro access [P1, original addition]

**Purpose:** provide free full Pro access to selected influencers and sponsored athletes without changing public subscription pricing. This is owner-authorised gifting, not a consumer discount checkout or a second paid tier.

**Launch route:** Apple subscription offer codes configured as Free with automatic paid renewal disabled, linked to the existing Pro subscription group. Prefer a unique one-time-use code or, for small campaigns, a unique custom code with a redemption limit of one. Default target periods: three months for influencers and six months for sponsored athletes, using supported Apple offer durations and eligibility. Verify those configurations in App Store Connect before distribution; if a target duration is unavailable, explicitly select a supported term rather than falsely promising an arbitrary grant. Longer partnerships are handled by a new eligible offer after owner review, never by a hidden perpetual entitlement. No general public sponsor code or client-side hard-coded Pro override.

Apple source S20: https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/ (reviewed 11 October 2026). Current documentation supports free offers without automatic renewal, recipient eligibility settings, one-time/custom codes, redemption expiry and usage limits. Code redemption expiry is separate from the access duration after redemption. Do not infer access duration from the six-month code-validity limit. One-time codes currently require batches of at least 500; distribute only assigned codes and protect the remainder. A unique custom code limited to one redemption is a practical alternative for a small programme. Codes grant access to whoever redeems them first; they are not identity-bound invitations. Verify intended recipients through the normal partnership process, but do not claim that this prevents forwarding.

**Operator workflow:** use App Store Connect for offer creation, code issuance/deactivation and supported redemption reporting at launch; a custom admin web console/backend is not required. Maintain a restricted partner register containing partner ID/name, influencer/athlete category, campaign, owner, offer reference, assigned code reference, intended term, redemption deadline, issued/confirmed/expired/deactivated status and review date. Protect unredeemed codes as secrets; exclude them from app analytics/logs. Record redemption as confirmed only with attributable evidence; issuing a code does not prove activation. Separate partner sponsorship counts from paying subscribers/MRR. No automatic message sending is implied by code creation.

**iOS flow:** Settings → Membership → Redeem offer code (Swedish: Medlemskap → Lös in erbjudandekod) opens Apple's supported redemption sheet; redemption URLs also work. Handle cancellation, invalid/expired/already-used/ineligible code, pending processing and offline failure without falsely unlocking Pro. Refresh verified StoreKit entitlements after redemption and on relaunch. Show Pro access — Complimentary / Pro-åtkomst — Kostnadsfri where verified offer metadata identifies the partner offer, with actual entitlement end date and No charge when this access ends / Ingen debitering när denna åtkomst upphör. If metadata cannot establish sponsorship, display verified Pro access neutrally rather than guessing. Full Pro features and unlimited capture apply while verified access is active; complimentary shots do not consume or reset Free credits. Guest-first core use remains unchanged; no GolfLaunchr account is required for Apple-code redemption. Same Apple account restore follows StoreKit; never promise gifting across arbitrary accounts.

**Expiry and overlap:** after complimentary access ends, recompute all verified entitlements; retain Pro if another valid paid entitlement applies, otherwise return to the correct Free balance and keep history/media readable/exportable. Suppress upgrade prompts while Pro access is valid. Apple handles existing subscription/offer interactions; redemption must not be represented as cancelling, refunding or stopping renewal of a pre-existing paid subscription. Warn existing subscribers to review Apple's redemption terms and their subscription management before applying an offer. The no-charge statement applies to the complimentary offer itself, not unrelated existing subscriptions. Verify new, active and expired subscriber cases before release.

**Deactivation limitation:** disabling an Apple code/offer prevents future redemption; it does not terminate already-redeemed access. The operator UI/register must distinguish Disable unredeemed code from Revoke active access and must not offer a false instant-revoke action. For launch, review before renewal and allow redeemed access to run its verified term. If identity-bound invitations, arbitrary durations or early revocation become required, implement a separately reviewed authenticated partner entitlement service with signed expiring grants, secure issuance/audit and bounded offline refresh. This service is a future extension, not a completed or hidden launch dependency; a local toggle is insufficient.

**Acceptance (NOT RUN until tested):** sandbox and physical-device tests cover redemption sheet and URL, successful free offer with no paid auto-renew, invalid/expired/used/ineligible codes, cancellation/offline, verification delay, relaunch/restore, same-account device change, duplicate redemption, end-of-term downgrade, active paid-subscription overlap and preserved Free ledger/history/media. Test code deactivation before and after redemption and show the documented difference. Verify English/Swedish text and actual expiry dates. Attach screenshots of configured free/no-auto-renew offers and observed lifecycle outcomes before distributing real codes. No codes are created or distributed by this specification update.

### F20 — Persistence, offline operation and recovery [P0]

**Purpose:** ensure every displayed accepted shot exists durably.

Use a transactional local repository and serial accepted-shot writer. Persist measurements before final success feedback. Store media as files with database references and recover orphan/staged files. Record schema migrations and resumable mode state. Interrupted capture candidates are discarded or marked incomplete, never promoted to measurements. Handle low storage, backgrounding, camera contention and thermal events with explicit pause reasons.

**Acceptance:** killing the app after success preserves exactly one shot and trial entry; schema migration preserves counts/IDs; offline accepted practice, replay and history work; media cache eviction cannot corrupt database; low storage blocks new arming when necessary and preserves already committed shots.

### F21 — Privacy, deletion and support [P1]

**Purpose:** give users control and diagnosable failures.

Process capture on device by default. No video upload or model-training reuse without separate explicit opt-in. Offer delete all local data, media-only deletion and export before deletion. Keep entitlement recovery distinct from deleting practice data. Support offers an optional redacted diagnostic bundle with app/model/format versions, frame-drop counts, failure codes and logs; clips require separate opt-in. If future cloud accounts exist, implement account deletion and server/media purge before shipping them.

**Acceptance:** a network audit during core practice shows no media exfiltration; diagnostic preview shows content before sharing; opt-out stops optional analytics; clear-data does not accidentally cancel App Store purchases or reset an intentionally retained trial ledger without disclosure. Owner must approve retention wording and trial identity policy before release.

### F22 — Accessible original UI [P1]

**Purpose:** operate comfortably outdoors and without relying solely on sound/colour.

Use an original dark/light design with large legible numbers, high contrast and labels for all status and chart points. Support adaptive portrait and landscape for browsing/review on iPhone; camera capture requires landscape. Portrait uses compact bottom navigation; landscape browsing uses a leading rail and master/detail panes. Active capture uses a slim header and preview/metrics panes without a bulky navigation rail. Do not merely stretch portrait content. Preserve state across rotation; pause capture and requalify physical calibration when orientation changes. Support Dynamic Type, VoiceOver, Reduce Motion and at least 44-point touch targets. Limit motion during capture. Alerts identify corrective action. New screens: Home, Mode chooser, Setup, Capture, Shot detail, Replay, Session summary/history, My Bag, Club profile, Drill configuration/results, Range, Skill trends, Course chooser/round, Integration setup, Settings, Paywall and Support.

**Acceptance:** accessibility audit covers the whole main flow; text enlargement causes no blocked primary actions; VoiceOver can operate calibration guidance and replay buttons; colour-blind users can distinguish readiness and target results; screens use original assets/copy and no reference screenshots embedded as product art.

### F23 — Performance and diagnostics [P0]

**Purpose:** sustain capture without sacrificing event frames.

Separate capture queue, pipeline work, persistence and main-thread presentation. Bound buffers and processing backlog. Record actual FPS, exposure, blur, dropped frame reasons, per-stage timing, memory and thermal state. Proposed product SLOs: cold home <3 seconds, configured camera preview <2 seconds after permission, result p95 ≤3 seconds after impact, 30-minute continuous practice without crash or unbounded memory growth, zero frame loss in an accepted metric's required impact/trajectory window. These are validation targets, not measured results.

**Acceptance:** Instruments traces substantiate SLOs on every certified profile; impact-frame loss invalidates affected metrics; degraded thermal condition pauses/requalifies rather than silently changing the scale/FPS; no new actionable runtime warnings or unresolved crashes in the tested flow.

### F24 — Release integrity and evidence [P0]

**Purpose:** prevent agents from declaring untested parity complete.

Each feature has implementation status, automated test result, physical end-to-end result, artefact links and unresolved defects. Demo pipelines are compile-time-separated from production providers and visually labelled. App Store screenshots contain only shipping behaviour. Release checklist includes licence provenance, permissions, privacy disclosure, purchase sandbox outcomes, physical-device matrix, independent accuracy report, replay checks and simulator evidence.

**Acceptance:** release cannot pass with an unexecuted applicable gate, hidden mock, undocumented unsupported metric, invented SDK, copied asset, or a blocker labelled future work. A partial release gets a precise partial scope statement.

### F25 — Multilingual product: English and Swedish at launch [P1]

**Purpose:** provide equally complete English and Swedish experiences from the first production release and make additional languages straightforward to add.

**Scope:** every app-authored user-facing string in onboarding, calibration/status/error guidance, metrics/provenance labels, drills, virtual courses, history, charts, replay, settings, paywall, support, accessibility labels, spoken feedback and exported human-readable summaries. Include permission-purpose strings, embedded diagrams/captions, original tutorial material, legal/privacy explanations and App Store metadata/screenshots. Platform-owned purchase sheets and third-party interfaces follow their own locale behaviour; do not promise that our app controls them.

**Architecture:** use Xcode String Catalogs (`.xcstrings`) or a comparably typed resource system with stable semantic keys, translator context, plural forms and formatted placeholders (S17/S18). No user-visible hardcoded English or sentence fragments assembled by concatenation. Keep internal identifiers, analytics keys, schema fields and machine-readable CSV/JSON keys language-independent. Localise system permission purpose resources using the appropriate platform mechanism. Include catalog coverage checks in CI and retain a documented translation workflow for future locales.

**Language selection:** default to the device/app preferred language when supported, otherwise English. Offer Settings → Language with System, English and Svenska. Persist the override. Switch app-authored interface and speech together, cancelling stale queued speech. Apply changes between captures: if a shot is armed/processing, finish or safely pause it, then refresh presentation. Changing language must not require another account, delete/reinterpret data, reset trial, change physical units, or invalidate calibration.

**Regional formatting:** language and measurement units are separate settings. Use the selected language with the device's regional conventions where supported; persist any explicit region override separately. Respect decimal/group separators, dates, plural forms, time-zone display and measurement formatting. Accept locale-valid numeric input (including Swedish decimal commas). Raw storage uses SI, UTC and locale-neutral numbers. CSV exports declare delimiter/encoding and quote locale-formatted content correctly; default machine exports retain invariant keys and numbers.

**Speech:** request an English voice for English and a Swedish voice for Svenska; use matching pronunciation of metric labels, numbers and units. Check voice availability at runtime. Where voice resources are unavailable offline, show a localised explanation and visual feedback; do not silently read English text as Swedish or block capture. Generate speech from raw numeric values with locale-aware formatting rather than string replacement.

**Swedish terminology:** maintain a reviewed glossary; proposed starting terms are “Flyglängd (carry)” for carry, “Total slaglängd” for total distance, “Bollhastighet” for ball speed, “Klubbhastighet” for club speed, “Utgångsvinkel” for launch angle, “Spinn” for spin, “Spridning” for dispersion, “Uppmätt” for measured, “Beräknad” for estimated, and “Inte tillgängligt” for unavailable. Have a native Swedish reviewer familiar with golf confirm the terms and clarity. Do not translate brand names, model/provider names or user-authored club names and notes automatically.

**Translation quality:** machine-assisted drafts are permitted, but native-language review and human end-to-end testing in both languages are required. Include text expansion, long club names, VoiceOver, maximum Dynamic Type, plural counts and pseudo-localisation in layout tests. Future locales may need different scripts/text directions; avoid architecture assumptions that only Latin/left-to-right text exists.

**Acceptance:** English and Swedish are both complete before G3/G6 can pass; zero missing keys, placeholders, untranslated app-owned strings or broken plural forms in shipping flows; supported language changes persist after relaunch and leave measurements/scores/credits invariant; voice status/errors and all selected metric announcements use the selected language; Swedish decimal input works; both localised App Store metadata sets pass character-limit checks; a native Swedish review and the English/Swedish physical-device walkthrough are attached as evidence. Unavailable third-party localisation is disclosed rather than misreported as complete app coverage.

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

## 6. Data model and module contracts

### Persisted entities

| Entity | Required fields / invariants |
|---|---|
| UserSettings | units, swingHandedness (right/left; no automatic inference), appLanguage (system/en/sv), optional regionOverride, audio, media retention, atmosphere mode, schemaVersion |
| Club | UUID, category, label, optional loftRad, archivedAt; immutable ID |
| Calibration | UUID, deviceProfileID, format/lens/pose/scale/transform, quality, createdAt, calibrationVersion |
| Session | UUID, mode, createdAt/endedAt, club/config snapshots, recovery state |
| Shot | UUID, sessionID, sequence, clubID/name/loft snapshot, swingHandedness snapshot, calibrationID, impactTimeUTC, raw metrics, derived metrics, quality, versions, exclusion status |
| ShotMedia | shotID, artifactKind (sourceSequence/impactStill/composite/preview), relative file path, checksum, frame timestamp/index manifest, impact offset, orientation/handedness/calibration snapshot, composite version, durable save state; preview-only eviction |
| Environment | pressurePa/temperatureK/altitude if used, source/time, standardisation flags |
| ModeEvent | shotID, modeConfigVersion, sequence, inclusion revision; idempotent |
| ClubProfile | clubID, source shot IDs/revisions, condition/model view, aggregates, generatedAt |
| TrialLedger | acceptedShotID unique, allowanceKind (introductory/monthly/paid/complimentary), periodID, credit cost, committedAt; separate from deletable history; retain legacy entity name for migration |
| FreeAllowanceState | introductoryConsumed, introductoryExhaustedAt, resetTimeZone, nextResetAt, grantedPeriodIDs; idempotent monthly grants; no rollover |
| EntitlementCache | productID, verified transaction ID, type, offerID/type where verified, source (paid/complimentary), expiry/revocation, lastVerifiedAt; no card data or unredeemed codes |
| CourseRound | course/rules version, hole, lie/aim, stroke events, auto-putt/penalty events |

Derived summaries are reproducible views, not a second truth. Data migrations retain raw source measurements and versions. Hard-delete of shots invalidates affected views. Ledger should contain only minimal usage IDs and no golf/video data.

### Interfaces (language-neutral; implement typed Swift equivalents)

* `CapabilityService.qualify(device, cameraFormat) -> CapabilityReport`
* `CalibrationService.calibrate(frames, setup) -> CalibrationResult`
* `CaptureService.events() -> stream<CaptureEvent>`
* `MeasurementPipeline.evaluate(candidate, calibration, clubSnapshot) -> MeasurementResult`
* `FlightModel.compute(launchInputs, environment, surface, modelVersion) -> FlightResult`
* `ShotRepository.commitAccepted(shot, mediaReference?, trialCost) -> DurableReceipt` (atomic/idempotent)
* `ModeEngine.reduce(config, orderedIncludedEvents) -> ModeState`
* `AnalyticsEngine.aggregate(includedShots, conditionView) -> Aggregates`
* `FeedbackService.present(durableReceipt, selectedMetrics, units)`
* `ReplayService.frame(shotID, capturedFrameIndex) -> FrameResult`
* `EntitlementService.status() -> verified/expired/pending/unavailable`
* `SimulatorAdapter.connect(config); send(shotID, launchPayload); disconnect()`
* `ExportService.export(selection, schemaVersion, privacyOptions) -> file`

Measurement failures are typed: unsupportedProfile, calibrationInvalid, insufficientLight, blur, frameGap, occlusion, ambiguousBall, incompleteTrack, unsupportedMetric, thermalPause, storageFailure. Unknown is a reason, not a zero measurement.

### Example JSON shot contract

This is a synthetic schema fixture, not a ShotVision record or evidence of accuracy. Include it only in test/demo resources.

```json
{
  "schemaVersion": "1.0",
  "id": "11111111-1111-4111-8111-111111111111",
  "sessionId": "22222222-2222-4222-8222-222222222222",
  "sequence": 1,
  "mode": "practice",
  "swingHandedness": "right",
  "clubSnapshot": {"id": "33333333-3333-4333-8333-333333333333", "name": "7 iron", "loftRad": 0.5235987756},
  "calibrationId": "44444444-4444-4444-8444-444444444444",
  "impactTimeUTC": "2026-10-11T11:00:00Z",
  "coordinateConvention": "targetForward-rightPositive-upPositive",
  "metrics": {
    "ballSpeed": {"value": 45.0, "unit": "m/s", "provenance": "measured", "quality": "valid", "uncertainty95": null},
    "clubSpeed": {"value": null, "unit": "m/s", "provenance": "unavailable", "quality": "unsupported", "uncertainty95": null},
    "verticalLaunch": {"value": 0.3141592654, "unit": "rad", "provenance": "measured", "quality": "valid", "uncertainty95": null},
    "spinRate": {"value": 628.3185307, "unit": "rad/s", "provenance": "estimated", "quality": "provisional", "uncertainty95": null},
    "carry": {"value": 130.0, "unit": "m", "provenance": "estimated", "quality": "provisional", "uncertainty95": null}
  },
  "environment": {"pressurePa": 101325, "temperatureK": 288.15, "source": "standard"},
  "versions": {"pipeline": "demo-1", "flight": "demo-1", "deviceProfile": "fixture-only"},
  "included": true,
  "mediaId": null,
  "isSynthetic": true
}
```

All metric names follow section 5; optional keys may be omitted, but present missing values are null. Units and provenance are mandatory. `uncertainty95`, when supplied, is an absolute half-width in the metric's SI unit and requires calibration evidence. Consumers reject NaN/infinity, negative speeds/distances and invalid references. Synthetic events cannot enter production trial, analytics or simulator streams.

## 7. Capture state machine and navigation

| State | Trigger | Next state / action |
|---|---|---|
| Idle | Start with permission/entitlement | Qualifying |
| Qualifying | Profile/format/environment pass | Calibrating |
| Qualifying | Unsupported/denied | Blocked with recoverable action |
| Calibrating | Geometry passes | SeekingBall |
| SeekingBall | Stationary ball and valid pose | Ready |
| Ready | Candidate movement/strike | Capturing |
| Capturing | Window gathered | Processing |
| Processing | Quality sufficient | Committing |
| Processing | Invalid | Rejected → SeekingBall |
| Committing | Durable receipt | Result → SeekingBall |
| Committing | Storage/entitlement conflict | Paused with preserved diagnostics |
| Any active state | Device moved/format changed | Calibrating after safe cancellation |
| Any active state | Background/thermal/interruption | Paused |
| Paused | Resume | Qualifying |
| Any session state | End | Summary / recovered history |

No background process promotes an incomplete candidate. UI state mirrors the pipeline state, not a timer-based approximation. Simulator send and speech are downstream of commit. Club selection is snapshotted before Ready; future selection may be queued while processing but cannot alter the in-flight shot.

Home offers Practice, Bag and Progress, with mode chooser for QuickShot, target, ladder, range and courses. Settings/entitlements are reachable from Home. History leads to session, then shot, then replay. Original screen composition is intentionally left to the design team; interaction and failure behaviours above are normative.

## 8. Acceptance tests and release gates

### Automated and fixture tests

| ID | Test | Required result |
|---|---|---|
| T01 | Unit conversion round-trip | SI values invariant; displayed rounding never changes scores. |
| T02 | Duplicate candidate/commit/event | One shot, one credit, one mode outcome, one simulator delivery intent. |
| T03 | Crash before/after transaction | No half shot/ledger pair; committed shot recovered once. |
| T04 | Missing/NaN metric | Typed validation or null; no chart/scoring corruption. |
| T05 | Replay with irregular frame timestamps; impact package save/relaunch | Frame stepping visits every captured frame once in each direction; still/composite reference real source timestamps; durable source/still/composite survive relaunch and preview eviction; partial failures visible and retry spends no extra credit. |
| T06 | Target boundaries | Error equal to tolerance hits; error above misses. |
| T07 | Ladder progression/reload/exclusion | Deterministic reconstruction; invalid shots do not advance. |
| T08 | Club rename/archive/loft edit | Stable historical identity and input snapshots. |
| T09 | Exclude/delete/reinclude | Correct dependent aggregates, media and mode outcomes. |
| T10 | Atmosphere/model toggle | Consistent new derived views; raw metrics unchanged. |
| T11 | Entitlement expired/revoked/pending | Correct gating, no data lockout, no duplicate grant. |
| T24 | Detailed review/multi-club selection/averages/gaps | F10a fixtures pass; same filter scope across views; signed/unrounded gap calculations, honest SD/range/coverage, retained user records under Free and both review orientations. |
| T23 | Partner free offer redemption/expiry/deactivation | Verified full Pro, no complimentary auto-charge; used/invalid codes fail safely; disable does not revoke redeemed access; restore and paid overlap preserve correct entitlement. |
| T12 | Introductory #49/#50/#51; monthly #9/#10/#11; period reset | Final permitted shot commits; next cannot arm without allowance; invalid captures spend none; first reset next month; no rollover/double-grants; paid use preserves Free balance. |
| T13 | Synthetic provider into production | Rejected at repository/export-to-simulator boundary. |
| T14 | JSON/CSV export round-trip | IDs, nulls, units, provenance and inclusion preserved. |
| T15 | Course penalties/auto-putt/recovery | Versioned deterministic scores and position. |
| T16 | Mirrored handedness fixture | Same target coordinate signs and equivalent measurements. |
| T17 | en/sv catalog coverage, placeholders and plurals | Zero missing translations or malformed formats; no user-visible raw keys. |
| T18 | System/English/Svenska switch and relaunch | Correct persisted language; unchanged data, units, credits and scores. |
| T19 | Swedish numeric input, voice and accessible layouts | Decimal commas parsed correctly; correct voice or disclosed unavailability; no truncation/blocking. |
| T20 | Localised store metadata and summaries | Name/subtitle limits respected; English/Swedish content complete and export schema invariant. |
| T21 | Opposite-side side-on geometry, both handedness options | Phone/ball/golfer cross the target line, ball between them; camera sees impact from opposite side; no behind-ball diagram or downrange camera guidance. |
| T22 | Handedness change during Ready/processing and relaunch | Old lock/calibration cannot accept another shot; safe pause and mirrored recalibration; stored shots keep original handedness; choice persists. |

Examples for analytics: included carry [100, 110, 120] m gives mean 110 m and sample SD 10 m. Removing 120 gives mean 105 m and sample SD ≈7.0711 m. Percentiles use a specified method: sorted linear interpolation at index (n−1)p (type 7); the three-shot set gives P10=102 and P90=118. Excluded shots never enter those calculations. A 100 m target with ±5 m tolerance accepts 95 and 105 m, rejects 94.99 and 105.01 m before display rounding.

### Human end-to-end validation protocol

These tests must be performed by the implementation/review team; they were not executed during this research.

1. Install a clean production-like build on each candidate physical device. Record model, OS, build, lens/format and entitlement fixture. Simulator tests may verify UI, never camera accuracy.
2. Follow the visible setup instructions as a first-time golfer. Deny and later grant camera permission; verify the phone is on the opposite side of the ball from the golfer and aimed across the target line; repeat mirrored left-handed and right-handed setup; change handedness while armed and confirm recalibration; set feet/target line; test dim/flickering light and device movement. Confirm clear block/recovery messages.
3. Hit real wedge, iron and driver shots in an authorised, protected test environment. Include mishits, club grounding, waggles, adjacent player movement and ball repositioning. Observe accepted/rejected events directly.
4. Use QuickShot, then a multi-club session, bag mapping, target and ladder. Listen to multiple metric feedback through speaker and headphones. Confirm no touching is required between valid shots.
5. Inspect impact clips by scrubbing and single-frame stepping; compare against captured timestamps and source frame count. Reopen the clip from history after relaunch.
6. Exclude a shot, restore it, delete it and delete a session. Compare aggregates with an independently calculated expected table. Change units and atmosphere view; raw measurements must remain unchanged.
7. Test fifty-shot introductory exhaustion, ten-shot monthly exhaustion/reset and StoreKit sandbox monthly/annual at 49/499 SEK, cancellation, pending, restore and revocation. Repeat on offline launch, calendar boundaries, clock rollback/time-zone change and after known expiry; verify downgrade to Free and retained history.
8. Run a native round, trigger penalties and auto-putt, kill/relaunch, resume. Connect each claimed third-party provider and inspect actual received units and one-shot behaviour.
9. Interrupt with a call/background, change camera availability, fill storage, disconnect network, and run thirty-minute thermal/performance checks. Confirm no falsely accepted shots or lost prior data.
10. Repeat the main setup/capture/drill/replay/purchase/history paths in English and Swedish, including a native Swedish reviewer, language override/relaunch, decimal input and Swedish spoken metrics. Use VoiceOver and large text, then export/delete data and inspect network traffic. Check device logs and Instruments for new errors, frame loss, latency and memory growth.
11. Attach recordings/screenshots, log excerpts, dataset reports and exact build identifiers to feature status. Fix failures and rerun the affected end-to-end path and appropriate regressions before declaring it verified.

### Scientific validation design

Collect synchronised same-strike ground truth from an independent suitable launch monitor, with club-data capability where those metrics are claimed. Do not compare unrelated historical swings. Record reference firmware, mode, reported metric definitions, uncertainty/limitations and environmental normalisation. Check that carry definitions and altitude/temperature conditions match before comparing. Reference estimated carry is not direct measured landing ground truth; validate actual landing where practical for distance claims.

Minimum proposed validation per candidate device profile: 30 wedge, 30 mid-iron and 30 driver strikes under each advertised supported lighting condition, spanning slow/medium/fast ball speeds and both handedness setups. Include separate negative-event sequences. Start with wedge/iron/driver categories, then extend to hybrids, fairway woods and partial/chip shots before claiming those supported categories. Record every attempted strike, including misses and rejects. Never select only successful readings to report accuracy. Split development, validation and held-out final evaluation by golfer/session, not randomly adjacent frames. Aim for at least ten golfers in the final evaluation; disclose if fewer or speed coverage is incomplete.

Report detection recall, false accepts per hour, metric availability rate, signed bias, MAE, median and p95 absolute error, error by speed/club/light/device/handedness, and estimated uncertainty coverage. Avoid percentage errors near zero launch/attack angles. Proposed initial release targets below are original engineering targets and require owner approval before G2; they are not source product claims.

| Outcome | Proposed target for each advertised supported stratum |
|---|---|
| Valid strike detection recall | ≥95% with attempted strikes as denominator |
| False accepted shots | ≤1/hour in at least 3 hours of negative-event testing per profile |
| Ball speed | MAE ≤max(1.5 m/s, 3% of reference median speed); p95 ≤max(3 m/s, 6%) |
| Vertical launch | MAE ≤2°; p95 ≤4° |
| Horizontal launch, if claimed | MAE ≤2°; p95 ≤4° |
| Club speed, if claimed | MAE ≤max(2 m/s, 5% of reference median speed); p95 ≤max(4 m/s, 10%) |
| Estimated carry | MAE ≤max(5 m, 5% of median carry); p95 ≤max(10 m, 10%) |
| Estimated spin, if displayed | MAE ≤max(750 rpm, 15% of median spin); p95 ≤max(1500 rpm, 30%); label estimate |

Capture availability for each advertised metric must be ≥90% of genuine strikes within a supported stratum; otherwise narrow its supported scope rather than hiding nulls. Statistical reports show confidence intervals and sample sizes; three hours without false events does not conclusively prove a rare-event rate. Repeat more testing when interval uncertainty prevents a credible conclusion. Attack angle, dynamic loft, total distance and apex need separately approved error criteria and independent appropriate reference data before they receive reliable/validated labels. They remain experimental/unavailable until then.

### Gates

| Gate | Deliverable | Pass condition |
|---|---|---|
| G0: Independent requirements | Spec adoption, provenance, capability claim list | No borrowed code/assets; all choices and unknowns assigned. |
| G1: Capture feasibility | Physical-device traces and optical/calibration method | Genuine events and sufficient trajectory evidence across a declared initial speed/light envelope. |
| G2: Measurement qualification | Frozen models, held-out paired dataset, accuracy report | All claimed metric/device/condition targets pass; failed metrics unavailable or clearly experimental. |
| G3: Core product | F01–F10 and F16–F25 | Automated checks and human practice/paywall/recovery/replay paths pass. |
| G4: Mode breadth | F11–F14 and native F15 | Real input drives correct drills, trends and rounds. |
| G5: Integrations | Each claimed provider adapter | Real provider connection, permissions/licence, units, one-shot delivery and reconnection proven. |
| G6: Release | Evidence bundle and final scope statement | Every applicable gate passed; no blocker, mock or unexecuted check concealed. |

A release without G4/G5 can be described as a narrower core launch monitor only. It cannot be described as full advertised-scope parity. A release without G2 is a research prototype regardless of how polished it looks.

## 9. Rubber-duck review and resolved assumptions

This is an explicit design review, not a claim of external human testing.

| Challenge | Review conclusion | Resolution in handover |
|---|---|---|
| “Does listing spin prove it is measured?” | No; current release notes name spin models. | Provenance labels; estimate-only initial policy; G2 spin test. |
| “Can one screen-space displacement yield true ball speed?” | Only with defensible calibrated geometry and observability. | Geometry record; profile qualification; no unconditional promise. |
| “Can estimated distances support bag gapping?” | Useful if reproducible, but inputs/conditions must remain visible. | Condition-separated profiles, sample counts and versioned recomputation. |
| “Does a camera session on the iOS Simulator validate capture?” | No. | Physical-device G1/G2/G3 evidence mandatory. |
| “Could missing readings make accuracy look better?” | Yes, selection bias. | Attempt denominator, availability and rejection counts. |
| “Do famous courses mean we should copy their maps?” | No content access/licence established. | Original fictional courses; licensing gate for named venues. |
| “Can virtual golf work without measured putting/spin axis?” | Yes as disclosed simplified gameplay, with limits. | Auto-putt rules and no claimed measured curvature. |
| “Does a simulator category identify its protocol?” | No. | Provider discovery and real adapter verification; unknown remains a gate. |
| “Can cloud LLMs replace the measurement pipeline?” | They cannot create missing physical evidence. | Deterministic instrument pipeline; AI explanations optional later. |
| “What if a user excludes/deletes a shot?” | Analytics and scores must change; trial use must not. | Recomputable views and separate minimal ledger. |
| “Can an agent ship arbitrary default prices?” | No real products configured. | StoreKit product configuration owned; no hardcoded paywall prices. |
| “Does an empty web result prove the name is free?” | No; one search engine missed an existing Loftiqo brand. | Stronger search cross-check; GolfLaunchr remains provisional. |
| “Are fifty introductory shots enough to prove accuracy?” | No; trial quota is commercial, unrelated to qualification. | Larger paired dataset and held-out performance testing. |

## 10. Work packages for a team of implementation agents

These are delegation instructions for the future implementation team; no implementation agents were run during this research.

| Package | Owner role | Features | Dependencies | Reviewable output |
|---|---|---|---|---|
| WP01 | Product/integration coordinator | Spec, IDs, scope, decisions | None | Frozen contracts, issue board, claim list, provenance record |
| WP02 | Camera/vision researcher | F01–F04, F23 | WP01 | Capture harness, calibration, genuine event pipeline, device traces; G1 |
| WP03 | Measurement/physics engineer | F06, F18 | WP02 evidence | Independent models, uncertainty method, paired evaluation; G2 |
| WP04 | Data/domain engineer | F08–F10, F17, F20 | WP01 contracts | Repository, schema migrations, exports, analytical fixtures |
| WP05 | iOS experience engineer | F01–F03 UI, F05, F07, F10a UI, F16, F22 | WP01; WP02 for real verification | Original screens, voice, replay and accessible flows |
| WP06 | Practice/gameplay engineer | F11–F15 native | WP03/04 typed events | Deterministic modes and original course rules/content |
| WP07 | Commerce/privacy engineer | F19, F19a, F21 | WP04, configured StoreKit products | Trial ledger, verified paid/complimentary entitlements, partner offer redemption, operator runbook, privacy and support flows |
| WP08 | Provider integration engineer | F15 external | Approved provider docs/access; WP03 | Approved adapter, captured live provider evidence; G5 |
| WP09 | Independent QA/release reviewer | F24, T01–T22, all gates | Each package | Human end-to-end evidence in English/Swedish, test report, precise completion status |
| WP10 | Localisation engineer and native Swedish reviewer | F25; strings/voice across all features | WP01 keys/terminology; WP05/07 UI | Complete en/sv catalogs, glossary, metadata, speech checks and native-language review |

WP04/05/07 can work on explicitly labelled fixtures while vision research continues. Their outputs are blocked from real-product verification until the actual provider exists. WP06 cannot accept guessed ball data as evidence. Coordinator alone merges contract changes; other agents must request them rather than silently changing schemas. Independent reviewer reproduces outcomes without trusting implementation-agent summaries.

### Recommended repository layout

```text
docs/PRD.md
docs/DECISIONS.md
docs/EVIDENCE.md
docs/VALIDATION.md
docs/CLAIMS.md
App/Features/
Packages/Capture/
Packages/Measurement/
Packages/Flight/
Packages/Domain/
Packages/Persistence/
Packages/Analytics/
Packages/Modes/
Packages/Commerce/
Packages/Replay/
Packages/Integrations/
Tests/Unit/
Tests/Integration/
Tests/Fixtures/
Tests/UI/
Validation/DeviceReports/
Validation/AccuracyReports/
Assets/Original/
```

SwiftData or SQLite can implement the repository, but the accepted-shot/ledger atomicity contract is mandatory. AVFoundation manages capture/media; Vision/Core ML may support independently trained detection; Accelerate/Metal are optimisation candidates only after profiling. Speech uses the platform speech synthesis facilities. StoreKit 2 manages purchases. Cloud services are not required for the original local-first scope. Use String Catalogs for English and Swedish; no localisation backend is needed for core operation. All API availability and framework choices must be checked against current Apple SDK documentation at kickoff.

### Copy-ready coordinating-agent instruction

> Implement the independently specified iPhone golf practice product in this handover. Start by freezing feature IDs, typed contracts, clean-room provenance and the claimed device/metric envelope. Prioritise a physical-device capture feasibility spike and independently paired measurement validation before polishing UI. Organise work using WP01–WP10, with one contract owner and an independent reviewer. Build original code, art, copy, course assets and models. Do not ingest ShotVision binaries, private APIs, proprietary datasets or assets. Use fixtures only in labelled test/demo paths, and prohibit synthetic events in production. Ship complete English and Swedish interfaces, guidance, speech, accessibility and store metadata under F25. Implement every F01–F25 requirement for full scope; if an external dependency or measurement gate prevents completion, report the exact blocker and remaining requirements, not a completion claim. Verify changes end-to-end on physical supported iPhones, check logs and Instruments, attach evidence to feature IDs, and rerun affected paths after fixes. All release claims must match passing G0–G6 evidence. Never call a successful build, convincing animation or plausible number a validated launch monitor.

## 11. Open dependencies and what is genuinely complete

| Dependency | Owner | Required action | Blocks |
|---|---|---|---|
| Final name/domain/trademark/App Store reservation | Product owner | Authoritative availability and similarity checks | Commercial branding, not initial engineering |
| Test iPhones and paired ground-truth equipment | Research/QA | Procure access; run protocol and freeze support envelope | G1/G2 and accuracy claims |
| Independent detection training/validation data | Vision team | Collect with consent; record licences and split methodology | Reliable camera pipeline |
| Specific simulator providers and API/licence access | Integration owner | Choose provider, obtain official docs and access | G5/full external integration scope |
| Course assets | Product/design | Create original assets or license content | Virtual course release |
| StoreKit product IDs/prices | Commercial owner | Configure actual products in App Store Connect | Paid purchase release |
| Reliable attack angle/dynamic loft/total/apex criteria | Physics/product | Define reference/thresholds, validate or mark experimental | Those reliable metric claims |
| Exact undocumented source-app rules/screens | Optional parity researcher | Inspect authorised installed app if pixel/behaviour parity is demanded | Exact source parity only; original defaults already specified |

**Completed here:** current public feature discovery; source-conflict review; independent functional specification; failure states; measurement/provenance policy; schemas/contracts; deterministic original drill/game defaults; acceptance examples; scientific validation protocol; agent handover instructions; preliminary name screening; mandatory English/Swedish localisation scope and acceptance tests.

**Not completed here:** running or measuring either application, proving camera accuracy, buying/testing subscriptions, connecting simulators, licensing courses, legally clearing the name, or implementation. These are expressly visible dependencies and gates, not hidden omissions. Public evidence cannot settle them. The team can start implementation with this specification without mistaking unanswered scientific questions for solved engineering.

## 12. Handover validation performed

On 11 October 2026, the document was reviewed against the current public mode inventory and the retrieved release history. The review checked that recent capabilities—impact replay, multiple voice metrics, fused ball placement, handedness, atmospheric handling, challenges, skill tracking and external integrations—were represented or explicitly gated. Historical review-only metrics are labelled H rather than promoted to current first-party guarantees.

An executable structural check of version 1.1 confirmed 25 contiguous feature headings (F01–F25), all 20 test IDs and all seven gate IDs. It parsed the embedded JSON successfully and confirmed its synthetic flag and permitted metric provenance values. Independent arithmetic checks passed for the mean/sample-SD examples, illustrative high-speed frame displacement and rad/s-to-rpm conversion. Markdown code fences are balanced. This checks specification structure and examples, not the proposed application's runtime.

Human-style desk review walked through first use, failed permission, poor setup, valid strike, rejected strike, trial exhaustion, exclusion/deletion, interruption, bag remapping, replay loss, drill reconstruction and virtual-round recovery. The resulting safeguards are explicit in the feature requirements. This was a document walkthrough; it was not a physical-device usability or measurement test. No unexecuted acceptance test is recorded as passed.
### Version 1.1 change record

Replaced the working brand with the recommendation GolfLaunchr following current app naming research; added English/Swedish metadata proposals and preliminary collision-screen limitations. Changed multilingual support from optional readiness to mandatory launch delivery: F25, UserSettings language fields, WP10, T17–T20, bilingual human verification and G3/G6 release inclusion. Technical handover prose remains English. No app localisation runtime or native Swedish reviewer test has been executed at specification stage.

## 13. UI design direction and screen flow — version 1.2

User direction: a modern, fluid, easy-to-use iPhone interface that works in both portrait and landscape, from launch through practice and settings. This supersedes the earlier portrait-shell default. English and Swedish remain mandatory.

### Visual foundation

Use forest green (#103A2D), warm ivory (#F6F5EE), a restrained mint/lime accent (#BFE77B), dark readable type, large metric numerals, generous spacing, rounded cards and subtle translucent navigation surfaces. Validate actual colour contrast in implementation; a generated concept cannot certify accessibility. Use native iOS-feeling controls and motion that respects Reduce Motion. Select a single original golf-ball/flight-arc logo after design review.

Primary navigation is Home, Bag and Progress; Settings is reachable by a gear or more menu. Generated concepts may show a fourth Settings item for exploration; implementation must choose one consistent navigation pattern rather than mixing them.

### Main flow and layout contract

| Screen | Main action | Portrait | Landscape |
|---|---|---|---|
| Launch | Automatically reach welcome/home | Centred brand mark, no artificial loading delay | Centred mark, same visual treatment |
| Welcome | Start as guest; choose English/Svenska | Benefit illustration, language choice, bottom CTA | Illustration on one side; benefits and actions on the other |
| Home | Start practice / select mode | Dominant practice card and mode shortcuts | Navigation rail; practice/action area beside recent activity |
| Setup | Qualify physical capture | Guidance then preview/readiness controls | Large preview beside concise checks and capture CTA |
| Live practice | Strike, receive result, pause/end | Rotate your iPhone guidance; capture cannot arm | Dominant side-on camera pane, slim header, side metrics, saved-impact thumbnail and pause/end |
| Shot detail/replay | Review captured frames | Video then playback/metric cards | Video and controls left; metrics and actions right |
| Session summary | Review shots or finish | Aggregate cards and plots | Summary column beside plot/table |
| Activity history | Select session or inspect trends | Filtered cards | Session master list and selected detail |
| My Bag | Select/map club | Club list and mapping CTA | Club master list and profile pane |
| Target drill | Complete configured attempts | Target feedback and progress | Target visualization beside outcomes/actions |
| Virtual golf | Continue fictional course round | Course map then club/round controls | Map beside metrics/lie/score controls |
| Settings | Edit language, units and preferences | Grouped rows and language picker | Category list beside selected preference form |

Additional required production screens remain in F22: mode chooser, club edit/map progress, ladder configuration/run/results, challenge configuration/results, skill trends, course chooser, simulator setup, membership/paywall, support and all error/empty/permission/interruption states. The first visual concept set illustrates the main flow; it does not replace those functional requirements.

### Interaction and orientation rules

* Reserve comfortable touch areas and safe areas; avoid controls beneath camera cutouts or the home indicator.
* Keep a stable primary action within reach; separate destructive End/Delete actions from ordinary capture/next controls.
* Transition smoothly between cards/panes, but never animate fake live measurements. Values in concept art are illustrative.
* Rotation preserves selected club, session, drill/round progression, filters and replay position. Capture geometry is requalified before another strike; visual rotation alone is not proof of a valid physical setup.
* Setup illustrations must show the phone opposite the golfer across the ball, perpendicular to the target line, with a side-on camera view. Mirror for left/right swings and preserve the target direction. Behind-ball illustrations and downrange camera previews are superseded. Exact distances/heights and capture limits require independently validated profiles.
* Speech and metric labels preserve Measured/Estimated/Unavailable in both languages.
* Courses use original fictional assets. No concept copy may promise famous/real courses or unproven accuracy.
* Onboarding remains guest-first. If two start buttons appear in an exploratory mockup, consolidate them into a clear primary 'Get started' guest path; account creation is not a prerequisite.
* Screen concepts are generated raster references, not interactive or device-tested UI. Implementers must verify both orientations, small/large supported iPhones, Dynamic Type, VoiceOver and English/Swedish text expansion.

### Visual review and completion boundary

Review generated concepts for text, scientific claims, brand/navigation consistency, camera guidance and legibility. Correct invented placement instructions or accuracy claims before presenting them as normative. Physical touch behaviour, contrast, rotation recovery and measurement validity require implementation tests. Screen concept delivery must never be reported as completion of the app or of its full UI-state catalogue.

## 14. Mandatory camera geometry and handedness — version 1.3

The product owner's placement correction is authoritative: **place the phone on the opposite side of the ball from the golfer**. The ball lies between golfer and phone, across rather than along the intended ball-flight/target line. Capture looks side-on at impact and early ball motion. A rendered course/trajectory view is a separate virtual visualisation; it must not masquerade as the physical camera's downrange preview.

For a top-down illustration with target direction pointing right: right-handed setup shows golfer below the target line and phone above it; left-handed setup shows golfer above and phone below. The target direction remains right in both diagrams. This is an illustration convention; actual scene geometry is determined by calibration. Do not mirror recorded video indiscriminately or flip numerical left/right shot direction according to handedness. Keep the target-space right-positive convention consistent.

Settings and setup must expose **Swing handedness → Right-handed / Left-handed**, with reviewed Swedish labels **Svingfattning → Högersving / Vänstersving**. Both setups receive equal capability qualification and landscape capture/measurement validation, with portrait/landscape browsing and review support. Changing the preference safely pauses arming, invalidates the current ball lock/calibration, mirrors guidance, and requires setup again. Preserve the original preference in each historical shot.

The side-on requirement supersedes any earlier ambiguous behind-ball imagery or implicit camera-layout assumption. Capture, calibration, candidate detection, model training, confidence and accuracy tests must all use this geometry. If a prototype can only measure from behind the ball, it fails the required capture contract and must be revised; do not silently substitute its geometry.

Visual review of the corrected first-use board and new handedness/setup/settings board confirms the diagram places the ball between golfer and phone with the target arrow perpendicular to that axis. Physical clearance, camera observability and measurement accuracy remain subject to G1/G2. This is a visual/specification correction, not a completed hardware test.

Version 1.3 also repairs escaped line separators in the acceptance-test table and adds T21/T22 to make placement and settings behaviour explicit.



### Version 1.4 change record — freemium and approved pricing

On 11 October 2026 the owner approved **49 SEK/month and 499 SEK/year** for Pro. This version adopts Free + one Pro tier, fifty introductory shots followed by ten monthly shots, no lifetime product at launch, identical measurement quality, retained history on downgrade, and explicit English/Swedish commerce screens. It updates defaults, F19, ledger contracts, T12 and the manual commerce walkthrough. Annual arithmetic was checked: 499/12 = 41.58 SEK/month; 1 - 499/(49×12) = 15.1% saving. Pricing/allowances are product decisions, not measured conversion outcomes. No StoreKit purchase, physical-device test or willingness-to-pay experiment was executed by this document edit.


### Version 1.5 change record — landscape capture and saved impact evidence

Owner direction on 11 October 2026: capture must be in landscape, with a saved chronological club-and-ball image and underlying frames for every captured shot. This supersedes earlier portrait-capture mockups and orientation contracts. Browsing/review/settings remain adaptive. F16 now specifies automatic durable source frames, a near-impact still and a deterministic composite, honest unavailable states, storage/recovery rules and individual capture/review screens. Existing 49 SEK/month and 499 SEK/year prices remain unchanged. Visual mockups are illustrative; real frame extraction/compositing, landscape arming, device performance and media persistence tests are NOT RUN.


### Version 1.6 change record — complimentary influencer/athlete access

Owner direction on 11 October 2026 adds free partner Pro access. F19a specifies Apple free offer codes with no paid auto-renewal, suggested three-/six-month terms, restricted issuance tracking, redemption/restore UX, paid-subscription overlap, honest deactivation limits and T23 verification. Public pricing remains 49 SEK/month and 499 SEK/year. No real code issuance, redemption, purchase lifecycle test or partner outreach was performed; all operational acceptance remains NOT RUN.


### Version 1.7 change record — detailed practice review

Owner references on 11 October 2026 extend shot-specific review, club averages, club gapping and one/multiple-club filters. F10a defines shared selection, calculations, dispersion navigation, provenance, condition views, Free/Pro behaviour, localised adaptive review screens and T24. Existing landscape-only capture, saved impact package, sponsored Pro and 49/499 SEK pricing remain unchanged. Mockup numbers are illustrative, not an accuracy dataset. No implemented analysis or physical-device review test was run during this specification update.
