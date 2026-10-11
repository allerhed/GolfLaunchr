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
