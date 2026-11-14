---
name: new-feature
description: Run the frame-plan-test-implement-review pipeline for one GolfLaunchr feature ID (Opus frames, plans and reviews; Sonnet implements).
---
Argument: feature ID(s), e.g. `F08`.
0. Agents `product-manager` (opus) and `customer` (sonnet), in parallel, with the IDs -> framing: the golfer's problem, smallest shippable version, out of scope, plain acceptance, and 3-6 customer user stories. Pass both to the planner.
1. Agent `planner` (opus) with the IDs and the framing -> `docs/plans/<ID>-<slug>.md`. If the plan touches architecture, data, network, files, purchases, permissions or third-party code, run `lead-engineer` and `ciso` on the plan (in parallel) and have the planner resolve their findings. Show the user the plan summary and open questions; wait for answers if blocking.
2. Agent `swift-test-writer` with the plan path -> failing tests.
3. Agent `ios-implementer` per plan task (sequential unless tasks touch disjoint files) -> VERIFY OK each. Before each commit, `lead-engineer` reviews the diff; fix "reject" and "approve with changes" items first. Commit + push per task.
4. Agent `l10n-reviewer` if strings were added.
5. At the feature's end only, in parallel: `qa-reviewer` (opus), `ciso` (audit of the feature's diff and the Release build) and `customer` (hands-on simulator review in en and sv). Fix every FAIL, every ciso BLOCKER/HIGH and every customer "would make me quit" via `ios-implementer`, then rerun the reviewer(s) that failed.
6. Agent `product-manager` accepts or rejects against the acceptance criteria and the evidence. Update the status in `docs/plans/<ID>-<slug>.md` (implemented / verified / NOT RUN items). Report to the user.
Pass paths and IDs between agents, not pasted spec.
