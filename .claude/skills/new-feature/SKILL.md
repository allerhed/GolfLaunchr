---
name: new-feature
description: Run the frame-plan-test-implement-review pipeline for one GolfLaunchr feature ID (Opus frames, plans and reviews; Sonnet implements).
---
Argument: feature ID(s), e.g. `F08`. Agents are the ClaudeCOE kit's `coe:` agents (project specifics in `.claude/coe.md`) plus the local `planner`. Model overrides below are part of this pipeline: pass them as the Agent tool's `model`.
0. `coe:product-manager` (brief mode, `model: opus`) and `coe:customer` (brief mode), in parallel, with the IDs -> framing: the golfer's problem, smallest shippable version, out of scope, plain acceptance, and 3-6 customer user stories. Pass both to the planner.
1. Agent `planner` (opus) with the IDs and the framing -> `docs/plans/<ID>-<slug>.md`. If the plan touches architecture, data, network, files, purchases, permissions or third-party code, run `coe:lead-engineer` (design mode) and `coe:ciso` (threat-model mode) on the plan (in parallel) and have the planner resolve their findings. Show the user the plan summary and open questions; wait for answers if blocking.
2. `coe:test-writer` with the plan path -> failing tests.
3. `coe:implementer` per plan task (sequential unless tasks touch disjoint files) -> VERIFY OK each. Before each commit, `coe:lead-engineer` (code mode) reviews the diff; fix "reject" and "approve with changes" items first. Commit + push per task.
4. `coe:l10n-reviewer` (`model: sonnet`) if strings were added.
5. At the feature's end only, in parallel: `coe:qa-reviewer` (`model: opus`), `coe:ciso` (attack mode: audit of the feature's diff and the Release build) and `coe:customer` (hands-on simulator review in en and sv). Fix every FAIL, every ciso BLOCKER/HIGH and every customer "would make me quit" via `coe:implementer`, then rerun the reviewer(s) that failed.
6. `coe:product-manager` (acceptance mode, `model: opus`) accepts or rejects against the acceptance criteria and the evidence. Update the status in `docs/plans/<ID>-<slug>.md` (implemented / verified / NOT RUN items) and apply any PLAN.md/BACKLOG.md/DECISIONS.md edits the product manager returned. Report to the user.
Pass paths and IDs between agents, not pasted spec.
