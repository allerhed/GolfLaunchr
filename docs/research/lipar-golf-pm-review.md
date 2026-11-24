# LiPAR Golf: product-manager review (2026-11-24)

Status: **proposal for the owner**. Clean-room: ideas only; none of their text, UI, names or assets are used. Every LiPAR fact below is the vendor's own claim from their site and App Store listing, not independently verified.

Sources: [lipargolf.com](https://www.lipargolf.com/) (pages `/launch-monitor`, `/how-it-works`, `/swing-coaching`, `/the-greens`, `/games`, `/support`, `/roadmap`, read 2026-11-24), [App Store listing](https://apps.apple.com/us/app/lipar-golf-monitor/id6789924935), [DeepSwing 2026 roundup](https://deepswing.io/blog/best-launch-monitor-apps-2026?lang=en).

## What LiPAR is (short)
- Phone-only iPhone app, no hardware, iPhone 13 Pro or newer; unsupported devices are told so. Launched July 2026. "Patents pending".
- 240 fps capture, on-device inference on the Neural Engine, results about 2 s after impact. LiDAR only for putting, not ball flight.
- Setup: a guided AR room setup marks the ball spot, aim and phone position; explicitly "no calibration". Lighting is named as the most common cause of poor captures.
- 13 numbers per shot (ball speed, launch angle and direction, spin and spin axis, shot shape, carry, apex, hang time, club speed, attack angle, club path, face angle). They say ball speed, launch, carry and shot shape are strongest; spin and club delivery are inferred; the FAQ calls all of them estimates. A "verdict" compares each shot with the club's expected performance.
- Accuracy claim: within 2% of an unnamed professional monitor for ball speed, carry and spin, with no sample size or conditions.
- Also: frame-by-frame replay, shot cards, history views, games (a wedge test with spoken random targets, power, sequence), leaderboards, pose-based swing coaching with an AI coach chat, LiDAR putting, optional Apple Watch.
- Business model: everything free; account required; videos, measurements, body motion, coach chats and location are uploaded; ads via Meta and TikTok with event tracking; uploads cannot be turned off, only account deletion.

## 1. Verdict
LiPAR validates our core bet: a phone-only, 240 fps, on-device launch monitor is a real market, and golfers accept a guided setup. "No calibration" and "result in about 2 s" sell. It threatens us in three ways: (a) free with 13 numbers makes our Pro tier look thin on breadth; (b) they show spin, spin axis, club path and face angle without stated validation, so our honest "unavailable" can look like missing features; (c) their "patents pending" adds to the freedom-to-operate risk (backlog H6). Our defensible difference is the opposite of their model: no account, no upload, no ads, and a published per-metric validation. That only holds once G1/G2 produce real numbers; until then we are a research prototype and cannot out-claim anyone. Their free price is paid with data, which in Sweden and the EU is a positioning gift, not a reason to drop our price.

## 2. Comparison

| Area | LiPAR | GolfLaunchr (spec/plan) |
|---|---|---|
| Device | iPhone 13 Pro+ (LiDAR); unsupported get a message | F01 supported/experimental/unsupported per profile; floor from the G1 envelope (1.6) and device matrix (9.2); no LiDAR dependency |
| Setup | Guided AR; "no calibration"; no distances published | F02/F03 diagrams, checks, calibration record; distance typed by hand (B11); D1 showed the typed 0.75 m was a default (ball size said about 0.35 m) |
| Metrics | 13 per shot, all "estimates" | F06/CLAIMS: ball speed, launch, club speed measured after G2; carry estimated; spin estimated; spin axis unavailable; club path research-only (detector plan 3a) |
| Provenance | Hedged in the FAQ only | Measured / derived / estimated / unavailable on every number; nil never 0 |
| Accuracy | "Within 2%", no n, no reference named | Nothing claimable before G2; spec 08 targets; per-metric report |
| Replay/share | Slow motion of every frame, shot cards | F16 composite/still/frame step (5.1/5.2 not built), F17 export; no shot card yet |
| Practice/games | Wedge test, power, pose games | F11 target drill done (distance-only); F12-F15 not built |
| Coaching | Positions, index, AI chat | Out of scope |
| Putting | LiDAR putting | Out of scope |
| Social | Global leaderboards, seasons | None; no backend |
| Privacy/model | Free, account, upload, ads | 50 + 10/month free, Pro 49/499 SEK (F19), no account, no upload (F21, audit in the gate) |
| Onboarding | Sign-in first, then AR setup | F01 device report, camera permission when setup starts, handedness |

## 3. Adopt (proposals)

| # | Idea | Value | Lands in | Size | When | Precondition |
|---|---|---|---|---|---|---|
| A1 | **Measured setup geometry** with ARKit/LiDAR where available (camera-to-ball distance, ground plane, aim) instead of a tape measure | Removes our weakest link for scale, and so for ball speed | F02, F03, B11 | L | Next, as a 1-week spike after the bay visit | ARKit and the 240 fps capture session cannot run together, so AR is a setup step that records the geometry and hands over; pose frozen and invalidated on movement (F03). LiDAR is Pro-only: keep the fallback (ball size + typed distance, labelled). Never a requirement. |
| A2 | **Uncertainty per number** (± shown with each value) | Users see how far to trust each number; beats a footnote | F06, plan 3.4, shot detail | M | Design now | ± only from our own validation errors (G2), never invented |
| A3 | **Result verdict vs the golfer's own club average** ("longer than your 7-iron average") | Instant "was that good?" without external claims | F10a (logic exists), result card | S | Next | At least 5 validated shots for that club; neutral wording, no coaching |
| A4 | **Wedge test preset** on the target drill (5 random targets, spoken) | Fun, structured wedge practice | F11 preset, F07 voice | S | Later | Validated carry at wedge speeds (G2); distance-only scoring as today |
| A5 | **Lighting guidance as a first-class setup step**, with a plain fix per failed check and a "why this capture was rejected" screen | Light is their top failure cause and our decisive unknown | F02, B8/T7 | S | Now | None |
| A6 | **Latency stretch goal** about 2 s (gate stays p95 ≤ 3 s) | Keeps the practice rhythm | F23 | S | Later | After 5.5 traces; not advertised |
| A7 | **Device list = tested profiles only** | Honest "works on these phones" | F01, 9.2 | S | When G1 closes | G1 profiles |
| A8 | **Shareable shot card** (local image, validated and labelled values only) | Word of mouth without uploads | F16/F17 share image | S-M | After 5.2 | No leaderboard |

Deferred: **shot shape** (draw/fade/slice) needs spin axis or a validated horizontal launch plus face and path; add it only as a label derived from validated inputs.

## 4. Do not copy
- Uploads, ad SDKs and advertising IDs, mandatory sign-in, and uploads that cannot be turned off: contradicts F20/F21 and our no-upload audit.
- A wall of 13 numbers where half are inferred: keep the catalogue tiered, validated metrics first, the rest labelled or hidden.
- An accuracy percentage without sample size, conditions and reference (forbidden by `docs/CLAIMS.md`).
- AI coach chat, swing index, pose coaching: off-mission and unverifiable on our evidence.
- Leaderboards and seasons: need a backend and identity; on-device personal bests (F13) are enough.
- LiDAR putting and an Apple Watch dependency: out of scope.
- Their text, UI, names, assets or feature names. Their roadmap admits once advertising features that did not exist: a lesson for our own claims discipline.

**Positioning after G2:** "Your swings never leave your phone"; every number labelled measured, estimated or unavailable; a published validation report per metric with sample size and envelope; a free tier with no account (sv: "Inga konton, ingen uppladdning"). No competitor names in store copy (CLAIMS rule 7).

## 5. Risks and owner questions (with recommendations)
1. **Free competitor, pricing pressure.** Keep F19 pricing for now and compete on trust, not breadth; revisit after TestFlight conversion data.
2. **Their "patents pending" plus the existing H6 patents.** Commission the freedom-to-operate review before any public release or marketing, and watch LiPAR's filings. A watch item, not a blocker today.
3. **Device floor.** Do not mirror their iPhone 13 Pro floor; ours comes from G1 profiles. If A1 is adopted it is an optional enhancer on Pro models, with the manual path certified on the same profiles.
4. **Breadth perception gap.** Approve a short "Why some numbers are unavailable" explainer (F06/F21 copy, en/sv) so missing metrics read as honesty.
5. **Spin and club metrics.** Stay on the detector plan's metric policy (3a); do not chase 13 numbers.
6. **Scope.** Park games, coaching and social. Put A1, A2, A3 and A5 into PLAN after the bay visit; A4, A6 and A8 into the backlog.

## 6. How LiPAR handles bad indoor lighting (investigated 2026-11-24)

Sources read: [how it works](https://www.lipargolf.com/how-it-works), [support](https://www.lipargolf.com/support), [launch monitor](https://www.lipargolf.com/launch-monitor), [home](https://www.lipargolf.com/), [App Store listing and release notes](https://apps.apple.com/us/app/lipar-golf-monitor/id6789924935). All vendor statements; nothing tested.

**What they say:** light is the user's job. The only guidance is that high frame rates need light and that a dim garage bay is the most common cause of a poor capture. Accuracy "depends on lighting" among other factors. They say their model was trained on beta users' shots in their own garages and bays. Release notes mention better swing detection in bright outdoor light and, for putting, better ball finding indoors with a plain white ball. When the ball flight cannot be seen, newer versions keep the swing data instead of asking for a reshoot (older versions asked the golfer to hit again).

**What they do not say:** no light levels, no light check in setup, no dim-light warning or quality indicator, no exposure, shutter, ISO, torch, HDR or flicker handling, no 120 fps fallback, no lamp advice. No App Store review mentions light.

**Reading (inference, not stated):** they appear not to solve dim light in the camera at all. They capture at 240 fps, put the burden on the room, and rely on a model trained on real garage footage, which probably tolerates some motion blur, plus graceful degradation when the ball is not seen.

**What we take from it (backlog E28, E33, E34):**
1. Make light visible and actionable in setup (E28): we already measure what they do not (applied exposure, ISO shortfall, flicker); turn it into a plain check with a fix per problem and an honest reason when a capture is rejected.
2. Do not depend only on very short shutters (E33): train and evaluate the ball model on the whole exposure sweep with blur-streak labels (detector plan), and report accuracy per exposure so the supported envelope states the light it needs.
3. Degrade gracefully (E28): keep the club and swing evidence when the ball flight is unreadable, with a typed reason, never a guessed number.
4. Try cheap fill light (E34): measure whether the iPhone's own torch adds useful light at 0.75-1 m without flicker or heat problems.
5. Keep our stricter stance: publish the light conditions each metric was validated in, rather than a generic "needs enough light".

Third-party lighting guides for indoor launch monitors (not LiPAR-specific) suggest roughly 500-1000 lux, diffused light on the mat rather than into the lens, and blocking low sun through doors and windows; their colour-temperature advice disagrees: [Golf Simulator Advisor](https://golfsimulatoradvisor.com/golf-simulator-lighting-interference-accuracy/), [GolfRepublic](https://golfrepublic.org/do-golf-launch-monitors-need-special-lighting-indoors/), [Golfbays](https://golfbays.co.uk/blogs/news/golf-simulator-lighting). Our own numbers matter more: at 1/2000 s a 45 m/s ball still smears 22 mm, and D1's indoor auto exposure was 1/253 s.
