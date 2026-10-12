# Provenance and clean-room statement

GolfLaunchr is an independently designed and implemented iPhone golf practice app. It aims for comparable *publicly documented* capabilities of a reference product (ShotVision, spec S1-S5). It is not affiliated with, endorsed by, or derived from that product or its makers.

## Rules

1. **Original work only.** All source code, UI, icons, illustrations, copy (en and sv), sounds, voice strings, course assets, machine-learning models and training data are authored by the project or are explicitly licensed, with the licence recorded below.
2. **Not used, ever:** the reference app's binaries, decompiled or extracted resources, private APIs, network traffic captures, proprietary datasets, screenshots, store imagery or text copied verbatim. No code, asset or screenshot from it enters this repository, including as test data or mockup reference.
3. **Public information only for reference.** The spec's research draws on public web pages and App Store listings (sources S1-S19 in `docs/spec/02-evidence.md`). That research is kept separate from implementation: the spec states requirements, and code is written from the requirements. "Documented by the vendor" is never treated as "independently tested".
4. **Mockups** in `docs/mockups/` are inspiration only and are never embedded in the app.
5. **Dependencies.** No third-party dependencies without the owner's approval (CLAUDE.md). Each approved one is recorded in the table below with name, version, licence and purpose. Developer tooling (XcodeGen, SwiftLint, SwiftFormat) is build-time only and is not shipped.
6. **Data for detection/measurement models** must be collected by us with consent, with licence and split methodology recorded in `Validation/` and summarised in `EVIDENCE.md`. No scraped or third-party-owned footage.
7. **Names.** Competitor names are not used in the app, metadata or keywords. "GolfLaunchr" is a working brand; no trademark, domain or App Store clearance has been done (spec 11) and none is implied.
8. **Accuracy numbers** from the reference vendor are never repeated as ours (see `CLAIMS.md`).
9. **AI assistance.** Code is written with AI coding agents under the owner's direction. Agents must follow rules 1-8; generated output that reproduces recognisable third-party code or assets is rejected.

## Third-party components shipped in the app

| Component | Version | Licence | Purpose | Approved by / date |
|---|---|---|---|---|
| none | | | | |

## Build-time tools (not shipped)

| Tool | Purpose |
|---|---|
| XcodeGen | Generates the gitignored `.xcodeproj` from `project.yml` |
| SwiftLint, SwiftFormat | Lint and format gate in `scripts/verify.sh` |

## Third-party assets (images, fonts, sounds, course data, datasets)

| Asset | Source | Licence / consent | Where used |
|---|---|---|---|
| App icon artwork (`docs/branding/app-icon-source.webp`, composed into `App/Assets.xcassets/AppIcon.appiconset` by `scripts/make-app-icon.swift`) | Supplied by the owner in chat on 2026-10-12 | Owner supplied; **how it was produced and the owner's rights to it are to be confirmed by the owner** (spec 13: one original logo after design review) | App icon |

## Attestation (G0)

Owner confirmation that the above holds at G0: _pending owner sign-off_ (name, date).
