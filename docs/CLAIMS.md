# Capability and claim list (G0)

What GolfLaunchr **may** and **may not** claim, in the app, App Store metadata, screenshots, support copy and marketing. Source of truth for spec sections 0, 5, 8 (gates) and F24. If a claim is not allowed here, it must not ship. Changing this file needs the owner's approval (planner agent drafts, owner signs off).

## How to read a claim's status

Status vocabulary matches CLAUDE.md and spec F24. These are different states and must never be conflated:

| Status | Meaning | May appear in user-facing copy? |
|---|---|---|
| **Planned** | In the spec, no code yet | No |
| **Implemented** | Code exists, compiles | No |
| **Verified** | Automated tests + simulator evidence recorded in `EVIDENCE.md` | Only for non-measurement features (UI, storage, export) |
| **Validated** | Gate G2 passed on named devices/conditions with an independent accuracy report | Yes, only within the declared envelope |
| **Released** | Shipped, gate G6 passed | Yes |
| **NOT RUN** | Never executed | No, and say "NOT RUN" in reports |

Current state of every row below: **Planned / NOT RUN** unless `EVIDENCE.md` says otherwise.

## Hard rules (always)

1. A working screen or a plausible number is not a launch monitor. Without G2, the product is a **research prototype**, not a "launch monitor".
2. Never present a vendor statement as our result. The reference product's "<3% vs GC3" (spec S1) is a vendor claim about another product; it is not ours and is never quoted as ours.
3. Never present an **estimate** as a **measurement** (spec F06, section 5). Every shown metric carries its provenance: measured, derived, estimated, or unavailable.
4. Missing metric = unavailable (nil), never 0 and never a club-typical number.
5. No claim without a stated envelope: device model(s), lighting, speed range, club categories, handedness, setup geometry.
6. Simulator runs prove UI only. Capture and measurement need a physical iPhone.
7. Do not name competitors in metadata or keywords; do not imply affiliation with, or equivalence to, any other product or launch monitor.
8. Marketing/App Store screenshots show only shipping behaviour (F24). No mocks, demo data or fixtures unless clearly labelled as demo.

## Claim matrix

Metric keys from spec section 5. "Initial policy" is the most that may be claimed once the gate passes; until then every row is **not claimable**.

| Capability / metric | May claim (after gate) | May NOT claim | Gate needed | Current |
|---|---|---|---|---|
| Ball speed | "Measured" ball speed, within validated envelope and accuracy targets from spec 08 | "Radar-grade", "tour accurate", any % better than the validated MAE | G1 + G2 | NOT RUN |
| Vertical launch angle | "Measured" if calibrated 3D geometry validated | Screen-space angle presented as launch angle | G1 + G2 | NOT RUN |
| Horizontal launch angle | "Measured" only if explicitly validated and handedness-tested (T16, T22) | Any claim before depth/projection handling is validated | G2 (if claimed) | NOT RUN |
| Club speed | "Measured" only if clubhead tracking independently validated | Inferred from ball speed or club choice | G2 (if claimed) | NOT RUN |
| Spin rate | "Estimated" (model), labelled as such | "Measured spin", "optical spin", "radar spin" | G2 (label Estimated) | NOT RUN |
| Spin axis | Nothing; unavailable | Any spin-axis or curvature value | none initially | Unavailable |
| Carry distance | "Estimated carry" with launch + atmosphere assumptions stated | "Measured carry", "exact carry", landing-spot verified | G2 | NOT RUN |
| Total distance | "Experimental" or unavailable until criteria approved | "Reliable"/"validated" total distance | separate approval + reference data | Experimental/Unavailable |
| Smash factor | Derived, only when ball and club speed both exist | Independent evidence of strike quality | follows inputs | Unavailable |
| Attack angle | Unavailable until clubhead-path reconstruction validated | Any value | separate approval | Unavailable |
| Dynamic loft | Unavailable, or "Estimated" if model-derived | "Measured" | separate approval | Unavailable |
| Apex | Derived flight estimate, labelled | "Measured" | G2 | Experimental |
| Lateral landing | Estimated only; limited by missing spin axis | Shot-shape or curve claims | G2 | Experimental |
| Automatic shot detection | Recall and false-accept rates as measured in G2 (targets: recall >=95%, <=1 false accept/hour, owner approval needed) | "Never misses", "no false shots" | G1 + G2 | NOT RUN |
| Supported devices | Only device profiles listed in the G1-declared support envelope | "Works on any iPhone", unlisted models | G1 | NOT RUN |
| Putting | Nothing | Any putting support | none | Out of scope |
| Indoor use | Only lighting conditions in the validated envelope | "Works in any light" | G2 per lighting stratum | NOT RUN |
| Accuracy figure (any %) | A figure from our own G2 report, with sample size, CI, envelope | A figure not from our report; one that omits rejects/misses | G2 | None exists |

## Non-measurement capabilities

These can be described as shipped once **Verified** per CLAUDE.md Definition of Done and covered by `EVIDENCE.md`. Anything involving camera capture inside them stays NOT RUN until a physical device run.

| Capability | Feature IDs | Claimable when |
|---|---|---|
| Sessions, history, exclusion/restore, confirmed delete | F10 | Tests + simulator evidence; crash/kill atomicity (T03) |
| My Bag club management | F08 | Tests (T08) + simulator evidence |
| Club averages, gapping, dispersion, multi-club filters | F09, F10a | Fixtures T24 + review orientations; honest SD/range/coverage |
| Data export CSV/JSON | F17 | Round-trip T14 |
| English + Swedish UI, units, decimal comma | F25, F18, F22 | T17-T20, native Swedish review |
| Offline-first, local data, no backend | F20, F21 | Network inspection during human protocol step 10 |
| Impact replay (still/composite/frame step) | F16 | T05 on physical device captures |
| Freemium allowance and Pro | F19, F19a | StoreKit sandbox outcomes (T11, T12, T23); products configured in App Store Connect |
| Target / ladder drills, skill tracking | F11-F14 | G4 with real input |
| Virtual golf (native) | F15 | G4; **original** course assets only |
| Simulator/provider integration | F15 | G5 per named provider with real connection. Do not claim an integration that has no verified adapter |

## Scope statements allowed in a partial release

- Without G2: "Research prototype". No launch-monitor wording, no accuracy figures.
- G2 only for a subset of metrics: list exactly those; the rest are shown as unavailable or labelled Experimental.
- Without G4/G5: "core launch monitor" only; not full advertised-scope parity.
- Distance-only tier (no lateral): disable lateral-scored drills and make no full-flight claim.

## Open items (from spec section 11) that block specific claims

Final name/trademark/domain clearance (branding only, not engineering); test iPhones and paired ground-truth equipment (G1/G2); simulator provider and licence (G5); course assets (virtual course release); StoreKit product IDs and prices (paid release); approved error criteria for attack angle, dynamic loft, total distance, apex.
