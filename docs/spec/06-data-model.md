## 6. Data model and module contracts

### Persisted entities

| Entity | Required fields / invariants |
|---|---|
| UserSettings | units, swingHandedness (right/left; no automatic inference), appLanguage (system/en/sv), optional regionOverride, audio, media retention, atmosphere mode, schemaVersion |
| Club | UUID, category, label, optional loftRad, archivedAt; immutable ID. Extension (DECISIONS.md 2026-10-11, pending owner confirmation): brand?, model?, sortOrder, loftRevision; shots store a `ClubSnapshot` (id, name, loftRad?, loftRevision) |
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
