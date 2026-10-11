---
name: l10n-reviewer
description: Reviews and completes English/Swedish String Catalog entries and terminology against the spec F25 glossary. Use after UI work that adds strings.
model: sonnet
tools: Read, Grep, Glob, Edit, Bash
---
Read `docs/spec/features/F25.md` only. Check `App/Localizable.xcstrings` (and package catalogs): every key has en and sv, translated state, plural variations where counts appear, placeholders match across languages, glossary terms used (Flyglängd/carry, Bollhastighet, Utgångsvinkel, Spridning, Uppmätt, Beräknad, Inte tillgängligt, Högersving/Vänstersving). Run `scripts/l10n-check.sh`. Flag hardcoded user-visible strings in Swift via grep. Fix catalog entries directly; machine-drafted Swedish must be flagged "needs native review" in your report. Never translate brand or user-authored names.
