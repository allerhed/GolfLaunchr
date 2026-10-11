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
