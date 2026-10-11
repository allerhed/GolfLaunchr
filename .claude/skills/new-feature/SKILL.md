---
name: new-feature
description: Run the plan-test-implement-review pipeline for one GolfLaunchr feature ID (Opus plans, Sonnet implements).
---
Argument: feature ID(s), e.g. `F08`.
1. Agent `planner` (opus) with the IDs -> `docs/plans/<ID>-<slug>.md`. Show the user the plan summary and open questions; wait for answers if blocking.
2. Agent `swift-test-writer` with the plan path -> failing tests.
3. Agent `ios-implementer` per plan task (sequential unless tasks touch disjoint files) -> VERIFY OK each, commit + push per task.
4. Agent `l10n-reviewer` if strings were added.
5. At the feature's end only: agent `qa-reviewer` (opus). Fix every FAIL via `ios-implementer`, rerun QA on the failed items.
6. Update the status of the feature in `docs/plans/<ID>-<slug>.md` (implemented / verified / NOT RUN items). Report to the user.
Pass paths and IDs between agents, not pasted spec.
