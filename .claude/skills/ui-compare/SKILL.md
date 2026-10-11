---
name: ui-compare
description: Compare a running GolfLaunchr screen with its mockup like a human reviewer.
---
1. Find the mockup row in `docs/mockups/INDEX.md`; Read only that PNG.
2. Launch the app in the simulator, navigate to the screen, screenshot (`scripts/screenshot.sh <name>`), Read the screenshot.
3. Compare: layout/hierarchy, labels (en and sv), states (empty/loading/error), colours/contrast, touch targets, orientation behaviour. Mockup data is illustrative; spec text wins on conflicts. List concrete differences; fix or justify each.
