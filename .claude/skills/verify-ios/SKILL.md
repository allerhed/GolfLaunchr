---
name: verify-ios
description: End-to-end verification protocol for any GolfLaunchr change (tests first, build, simulator flow, rubber duck, rerun on failure). Use before declaring any code or UI change done.
---
1. Tests exist for the acceptance criteria and failed before the change.
2. `scripts/verify.sh` (add `--ui` for UI). Failure -> fix -> rerun from step 1.
3. UI: iOS Simulator tool -> launch the built app (`build/DerivedData/Build/Products/Debug-iphonesimulator/GolfLaunchr.app`, bundle `com.allerhed.golflaunchr`), interact, screenshot, compare to mockup, repeat with `-AppleLanguages (sv)` and rotation if relevant.
4. Rubber duck: list >=3 failure hypotheses; test each by execution.
5. Report evidence and an explicit NOT RUN list (device capture, accuracy gates, StoreKit, providers). Simulator results never count as capture/measurement validation.
