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
