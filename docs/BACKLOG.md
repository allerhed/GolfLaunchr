# Deferred validation backlog

Everything that is **NOT RUN** or waiting on a person, a device or an owner decision, in one place, so nothing is lost between items. Created 2026-10-12. The TrackMan bay visit is planned for the **end of the week**, so the first sections are ordered around it. Update this file in the same commit that closes or adds an item; evidence for a closed item goes in `docs/EVIDENCE.md`.

**Owner column:** *You* = needs the owner or a physical action; *Claude* = can be done in a session; *Both*. **When:** *Before bay*, *At bay*, *After bay*, *Later*.

## 1. Before the bay visit (do these first; a wasted visit costs far more than a delay)

| # | Item | Owner | Why it matters | Source |
|---|---|---|---|---|
| B1 | Unlock the phone and run the **home rehearsal**: 10-minute continuous recording, auto and fixed exposure, both lenses; expect zero gaps in clean windows, thermal not above "fair", correct landscape orientation in the manifest | Both (Claude can start it with `-harnessAutorun 600` once the phone is unlocked) | The harness has only been run for 40-60 s windows; a 10 min run is the real heat/memory test | 1.3a NOT RUN |
| B2 | **Motion trigger on the device** after the warm-up fix (move something in view; confirm no trigger in the first 2 s and one clip per movement) | Both | The trigger is the convenience path at the bay; the manual button is the safety net | 1.3a |
| B3 | **Touching the screen while recording**: compare drops with idle (autorun showed ~0.05%; hands-on clips lost more) | Both | Decides whether the bay protocol must say "do not touch the phone" | 1.3a |
| B4 | **Backgrounding / lock mid-run**: confirm it stops cleanly with an incomplete clip and a clear message | Both | A phone that locks in the bay must not lose the previous clips | 1.3a |
| B5 | Free storage check (>= 10 GB), Low Power Mode off, charger, weighted tripod or clamp, tape measure, 1 m scale bar, balls | You | Practical gating items | G1 plan section "Limited bay access" |
| B6 | **Approve the proposed P1 revision** (clean impact window instead of whole-window gap-free) and the other G1 thresholds in `docs/plans/G1-capture-spike.md` section 6 | You | The pass criteria must be agreed before data is judged | EVIDENCE 1.3a closed |
| B7 | Answer the bay questions: TrackMan model/software version, may session exports be copied out and used, how many golfers can take part, any outdoor range access | You | Plan Q6, Q7; data-use terms | G1 plan section 13 |
| B8 | Decide the **exposure sweep presets** to bring (1/1000, 1/2000, 1/4000 at ISO ceiling) and which lens first (wide has ~1.5 stops more light than ultra-wide) | Both | The decisive unknown is bay light | EVIDENCE 1.3a |

## 2. At the bay (script in `docs/plans/G1-capture-spike.md`, sections 3, 12 and the "Limited bay access" protocol)

| # | Item | Owner |
|---|---|---|
| T1 | Setup measurements, scale-bar clip, clock-sync clap, ball on tee mark photo | You |
| T2 | **Exposure sweep**: 10 strikes each at fixed 1/1000, 1/2000, 1/4000 s, 7 iron | You |
| T3 | Driver and wedge series (10 each) at the best exposure | You |
| T4 | Left-handed series if the bay allows | You |
| T5 | ~5 minutes of non-strike activity (practice swings, ball placement) for the false-trigger baseline | You |
| T6 | After each series: confirm TrackMan shot count equals your strike count; export the session (or screenshot the shot table); note unpaired strikes; tap "Save last 2 s" after any strike the trigger may have missed | You |
| T7 | Measure the bay's light (a lux reading from a second phone is enough) and note the lighting type and any flicker | You |

## 3. After the bay

| # | Item | Owner |
|---|---|---|
| A1 | Copy clips off the phone the same day (`devicectl` or share), index with checksums in `Validation/DeviceReports/`, write findings into EVIDENCE before the next visit | Both |
| A2 | Run `g1-analyze` on every clip; check timing, flicker (P9), exposure shortfall, trigger behaviour | Claude |
| A3 | **Annotate ball position** on a sampled subset (about 30 frames per stratum) with the annotation template: needed for P4 | You (or an agreed annotator) |
| A4 | Pair clips with TrackMan shots; pilot bias and error for ball speed and launch angle (pilot figures only, not G2) | Claude |
| A5 | Item **1.6 G1 review**: declare the supported envelope (or narrow / stop) for owner sign-off | Claude proposes, You decide |

## 4. Physical-device checks that do not need the bay

| # | Item | Owner | Source |
|---|---|---|---|
| D1 | **VoiceOver walkthrough** of Home, Bag (add/edit/archive/restore), Progress (list, session, shot detail, shot actions), Settings | You | 0.5, 2.2, 2.3 |
| D2 | Dynamic Type at the largest sizes on a real phone (rows, rail, editor, filter chips) | You | 0.5, 2.3 |
| D3 | Reduce Motion, dark/light on device, rotation behaviour on device | You | 0.5 |
| D4 | The new app icon on the real home screen, and at small sizes (Settings, Spotlight) | You | App icon |
| D5 | Bag and history on the device: add clubs, reopen the app, kill and reopen, low-storage behaviour | You | 2.1, 2.2 |
| D6 | Permission flow: camera denied then granted, in the harness and later in setup | You | 1.3 |
| D7 | iOS data protection class and backup exclusion for the database; behaviour on OS-level power loss (a process kill is tested, a power cut is not) | Claude (settings), You (power-cut) | 2.1 |
| D8 | Pseudo-localisation and long Swedish strings in layout tests | Claude | 0.5, F25 |

## 5. Human reviews and owner decisions

| # | Item | Owner |
|---|---|---|
| H1 | **Native Swedish golfer review** of terms: Trä 3, Hybrid 4, Järn 5-9, Pitching/Gap/Sand/Lob wedge, Min bag, Framsteg, Flyglängd, Uppmätt/Beräknad/Härledd, Slag, Målövning, Stegövning, Bagkartläggning, Demodata | You |
| H2 | Confirm **club contract extension** (brand, model, sortOrder, loftRevision) and **loft range 1-70 degrees** (a putter's loft may be unset) | You |
| H3 | Confirm rights and origin of the **app icon artwork** (PROVENANCE) and sign the G0 attestation | You |
| H4 | Sign off the proposed G2 accuracy targets in spec 08 before any accuracy claim | You |
| H5 | Trademark / domain / App Store name clearance for "GolfLaunchr" | You |
| H6 | Decide whether swipe actions on shot rows should return once the iOS list problem is understood (currently a long-press menu) | You |

## 6. Engineering follow-ups (Claude, later)

| # | Item | Source |
|---|---|---|
| E1 | Add **Delete** to the shot detail screen (today it is in the shot menu and VoiceOver actions only) | 2.3 |
| E2 | Media records (`ShotMedia`) and "deleting a session removes unreferenced clips" (needs Phase 5) | 2.1, 2.3 |
| E3 | Rejected-capture counts and a data-quality summary in history (rejections are not stored yet) | 2.3 |
| E4 | Performance with large histories (hundreds of sessions and thousands of shots): list loading, summaries recomputed on every change | 2.1, 2.3 |
| E5 | Persistence tests leave temporary folders behind; clean up | 2.1 |
| E6 | Language override System/English/Svenska, handedness setting (F25, F18) | 0.5 |
| E7 | Release configuration, launch screen, version numbers (10.2) | App icon |
| E8 | A second look at the iOS 27 `swipeActions` row drawing glitch with a minimal repro; consider reporting to Apple | 2.3 |
| E10 | Build the UI for 2.4: Averages, Gapping, Dispersion, Club metric profile and the multi-club filter sheet (portrait + landscape, en/sv), filter persistence across relaunch, Pro gating, export; add as a plan item | 2.4 |
| E11 | Export UI: share sheet, include notes/media prompt, export-before-delete, aggregate/analysis content and filters in exports, optional display units in CSV; open one exported CSV in Numbers/Excel and Sheets to confirm columns and the apostrophe escape look right | 2.5 |
| E12 | Fit and validate flight coefficients (Cd, Cl vs spin parameter, spin decay) against TrackMan carry/apex pairs from the bay; add runout/surface model for total distance; wire Flight into Standardised conditions | 3.5 |
| E13 | Onboarding on the real phone: permission prompt, Settings round trip, actual capability report (formats, free storage), VoiceOver, Dynamic Type; add handedness to Settings (4.5) and a way to re-run onboarding | 4.1 |
| E14 | Setup on the real phone: live observer (frames, exposure, thermal), tune thresholds from bay clips, add CoreMotion steadiness and ball detection, check the flicker row under real lamps, wire Calibrate (3.2) and Ready (4.3) | 4.2 |
| E15 | Practice on the phone: start, rotate gate and orientation request on the real iPhone, kill the app mid-session and confirm recovery; target carry / shot goal / notes UI; trajectory view; replace the Debug demo shot with the real pipeline (5.3) | 4.3 |
| E9 | Dark and tinted app icon variants (iOS 18) | App icon |

## 7. Gates still NOT RUN

G1 capture feasibility, G2 measurement qualification, G3 core product (F01-F10, F16-F25 automated + human paths), G4 mode breadth, G5 integrations, G6 release. See `docs/EVIDENCE.md` gate table.

## 8. Known weak spots to watch (found while testing)

- UI tests relaunch the app per test and take minutes; they passed repeatedly, but scrolling-dependent steps were fragile on this simulator. Prefer tests that need no scrolling.
- The in-memory fake and SQLite share one test suite (parity); keep it that way for any new repository method.
- Crash tests use a helper process that now blocks after `kill`; if a crash test ever fails intermittently again, treat it as a defect in the simulation first, then in the store.
