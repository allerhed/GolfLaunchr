# Evidence

Records proof for each feature ID. Rule (CLAUDE.md, spec F24): a feature is **verified** only with evidence here; anything not executed is **NOT RUN** and says so. Evidence is appended in the same commit that ticks the PLAN.md item. Never delete failed runs: mark them superseded and link the fix.

Storage: bulky artefacts (screenshots, traces, clips, reports) live under `Validation/` (`Validation/Screens/` is gitignored, `Validation/DeviceReports/` holds device traces, reports go in `Validation/AccuracyReports/`). This file holds the index and the verdict, not the blobs.

## Status vocabulary

`NOT RUN` -> `IMPLEMENTED` -> `VERIFIED` (automated + simulator) -> `VALIDATED` (physical device / G2) -> `RELEASED`. A simulator can never produce VALIDATED for capture or measurement. Use only these words.

## Per-feature record (copy this block under "Records" for each feature ID)

```markdown
### <ID> <title>  (PLAN item <n.n>)
- **Status:** NOT RUN | IMPLEMENTED | VERIFIED | VALIDATED | RELEASED
- **Date / commit:** YYYY-MM-DD, <short sha> (code), <short sha> (evidence)
- **Spec:** docs/spec/features/<ID>.md, tests <T##,...>, plan docs/plans/<ID>-<slug>.md
- **Build:** Xcode <ver>, iOS <ver>, scheme, configuration, build number
- **Environment:** Simulator <name, OS> | Device <model, OS, lens/format, build id>
- **Automated:** `scripts/verify.sh [--ui]` -> result, test counts (pass/total), log `build/verify.log` excerpt
- **Acceptance mapping:** one row per Acceptance criterion -> test name / manual step -> PASS | FAIL | NOT RUN
- **UI evidence:** screenshots `Validation/Screens/...` for en + sv, portrait + landscape where applicable, compared with mockup <file>
- **Physical-device result:** PASS | FAIL | NOT RUN (+ trace/clip path)
- **Rubber duck (>=3):** failure mode -> how it was checked by running something -> result
- **Unresolved defects:** none | list with severity
- **Verdict:** one line, using the status vocabulary
```

| Acceptance criterion | Evidence (test / step / artefact) | Result |
|---|---|---|
| ... | ... | PASS / FAIL / NOT RUN |

## Measurement evidence (G1 / G2 only)

For each device profile and stratum (lighting, speed band, club category, handedness). From spec 08; every attempted strike is recorded, including misses and rejects.

- Device model, OS, build id, lens/format/fps/exposure
- Reference instrument: make, model, firmware, mode, metric definitions, uncertainty, environmental normalisation; carry definitions checked for match
- Dataset: golfer/session ids, consent, licence, counts attempted / accepted / rejected, split (development / validation / held-out by golfer+session, never adjacent frames); >=10 golfers in final evaluation or disclosed shortfall
- Results per metric: detection recall, false accepts per hour (with hours tested), availability rate, signed bias, MAE, median and p95 absolute error, error by speed/club/light/device/handedness, uncertainty coverage, sample sizes and confidence intervals
- Verdict against the targets in spec 08 (owner-approved before G2)
- Artefacts: raw clips + manifests, analysis script version, report path

## Gate checklist

| Gate | Pass condition (spec 08) | Evidence | Status |
|---|---|---|---|
| G0 Independent requirements | Spec adoption, provenance, capability claim list; no borrowed code/assets | `CLAIMS.md`, `PROVENANCE.md`, this file | Docs complete; owner sign-off pending |
| G1 Capture feasibility | Genuine events, enough trajectory evidence across declared envelope | not started | NOT RUN |
| G2 Measurement qualification | Frozen models, held-out paired dataset, accuracy report | not started | NOT RUN |
| G3 Core product | F01-F10, F16-F25 automated + human paths | not started | NOT RUN |
| G4 Mode breadth | F11-F14 + native F15 with real input | not started | NOT RUN |
| G5 Integrations | Each claimed provider proven | not started | NOT RUN |
| G6 Release | Evidence bundle, final scope statement | not started | NOT RUN |

## Records

Phase 0 (foundation, tooling; no feature IDs):

### 0.1 SwiftLint strict + SwiftFormat lint in verify gate
- **Status:** VERIFIED (tooling). Commit `30f1adf`. Physical-device: not applicable.

(Further records are appended here, newest last.)
