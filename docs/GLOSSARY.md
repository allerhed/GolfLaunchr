# Glossary (English / Swedish)

Source of truth for app wording (spec F25). The terms marked **reviewed** have been confirmed by a native Swedish golfer: none have yet; every row is a proposal until the owner signs off (backlog H1). `scripts/l10n-usage-check.sh` fails the gate if the metric and provenance terms in the catalog drift from this table.

| English | Swedish | Where | Status |
|---|---|---|---|
| Carry | Flyglängd | metric.carry | proposed (spec) |
| Total distance | Total slaglängd | metric.totalDistance | proposed (spec) |
| Ball speed | Bollhastighet | metric.ballSpeed | proposed (spec) |
| Club speed | Klubbhastighet | metric.clubSpeed | proposed (spec) |
| Vertical launch angle | Vertikal utgångsvinkel | metric.verticalLaunch | proposed |
| Spin rate | Spinn | metric.spinRate | proposed (spec) |
| Dispersion | Spridning | analysis.tab.dispersion | proposed (spec) |
| Spread (±1 SD) | Spridning (±1 SD) | analysis.card.spread | proposed |
| Measured | Uppmätt | provenance.measured | proposed (spec) |
| Estimated | Beräknad | provenance.estimated | proposed (spec) |
| Derived | Härledd | provenance.derived | proposed |
| Unavailable | Inte tillgängligt | provenance.unavailable | proposed (spec) |
| Provisional | Preliminär | analysis.provisional | proposed |
| Swing handedness | Svingsida | setup.handedness | proposed |
| Right-handed / Left-handed | Högersving / Vänstersving | onboarding.handedness.* | spec (F01) |
| Gapping | Längdskillnader | analysis.tab.gapping | proposed |
| Progress | Framsteg | nav.progress | proposed |
| My Bag | Min bag | bag.title | proposed |

Rules: do not translate brand names, model names or user-authored club names and notes. Units keep their symbols (m, yd, km/h, mph). Spoken text uses the same words as the screens; agreement may differ ("inte tillgänglig" after a common-gender noun).
