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
