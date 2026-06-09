# Evals

Scenarios that exercise skill **triggering** and **correctness** end-to-end. These are the canary set — when a skill is added or modified, run the relevant scenarios in [`scenarios.md`](scenarios.md) and confirm the agent's behaviour matches the expected flow and rubric.

These are NOT pytest fixtures; they are prose-shaped scenarios the agent must navigate. Each scenario captures:

- A user prompt.
- The expected skill(s) that should trigger.
- The expected MCP calls and order (`coinis` server, `mcp__coinis__*` tools).
- The expected user-facing surface (cost confirmation? polling note? result table?).
- A **PASS / PARTIAL / FAIL** scoring rubric.

## Why evals exist

Skill behaviour is defined in plain markdown, and plain markdown drifts. Without a fixed scenario set + rubric, every `SKILL.md` refactor is a hope. Evals exist to:

1. Catch regressions after a skill edit (routing logic, cost-consent handling, polling cadence).
2. Guard the highest-severity surface in this bundle — the **`preview_cost` consent gate before any paid generate/revise fire**. A paid `generate/*` or `revise/*` firing without first calling `…/preview_cost/` and obtaining explicit user consent (with `sufficient:true`) is a hard FAIL and a release blocker. (`revise/ad_copy` is the only zero-cost / no-preview exception.)
3. Onboard contributors — reading the worked scenarios is faster than reading every `SKILL.md`.

## Coverage

There are 8 scenarios, one focus each:

| Scenario | Skill(s) under test | What it proves |
|---|---|---|
| EVAL-1 | `coinis-image-from-url` | Image from URL: `preview_cost/` + consent before the paid fire. |
| EVAL-2 | `coinis-video-from-url` | UGC video: `preview_cost/` + consent; BE-dropped fields. |
| EVAL-3 | `coinis-batch-patterns` | Fan-out, one up-front `preview_cost/` estimate, honest count math. |
| EVAL-4 | `coinis-polling` | `{"error":""}` post-hoc verification, no refund promise. |
| EVAL-5 | `coinis-campaign-flow-cli` | Meta launch, spend-cap + preview before fire. |
| EVAL-6 | `coinis-reports-cli` | Dollars (not raw units), terminal-width table. |
| EVAL-7 | `coinis-competitor-recreate` | `preview_cost/` + consent; no 1:1-clone over-promise. |
| EVAL-8 | `coinis-revisions` | `revise/*` family: `preview_cost/` + consent, source-id prereq. |

EVAL-1, EVAL-2, EVAL-3, EVAL-7, and EVAL-8 are the **cost-safety canaries** — they are designed to FAIL if the agent fires a paid `generate/*` or `revise/*` without first calling `…/preview_cost/` and obtaining explicit user consent (with `sufficient:true`). Any FAIL on these blocks release.

## How to run a round

There is no automated runner yet — a round is run by a human (or by another agent acting as the user) in a fresh session with the skills installed.

1. Read [`scenarios.md`](scenarios.md).
2. Run each scenario as the literal user prompt in a **fresh** Claude Code / Codex / Cursor session with the `coinis` plugin installed and the Coinis MCP configured (`https://mcp.coinis.com`).
3. Observe the agent's routing, the endpoint(s) it fires, whether it called `…/preview_cost/` and obtained explicit consent before any paid fire, and the user-facing surface.
4. Score each scenario PASS / PARTIAL / FAIL against its rubric (and the global rubric at the top of `scenarios.md`).
5. Record the round using the **round-recording template** at the bottom of `scenarios.md`.

## How to read the rubric

Every scenario uses the same three grades (defined once at the top of `scenarios.md`):

- **PASS** — all hard correctness checks met: right skill(s), right endpoint(s), cost gate honoured (`preview_cost/` + explicit consent before any paid fire), surface shape correct.
- **PARTIAL** — correct routing and no cost-safety violation, but a soft miss (extra narration, an unneeded question, a paraphrased body, a cost/balance not surfaced cleanly, a wrong format choice).
- **FAIL** — any **cost-safety** violation (a paid `generate/*` or `revise/*` fired without first calling `…/preview_cost/` and obtaining explicit consent with `sufficient:true`, or a refund promised), OR wrong skill / endpoint, OR a fabricated body fired as fact. (`revise/ad_copy` is the only zero-cost / no-preview exception.)

A cost-safety violation is **always FAIL**, regardless of how good everything else looks.

## Round vs scenario

- **Round** — a snapshot of the skills at a specific commit, scored against the full scenario set.
- **Scenario** — one user request + expected behaviour + scoring rubric.

Record the commit SHA, date, model id, and skills version (from [`../VERSION`](../VERSION)) per round so rounds are comparable. Compare round-over-round: regression of more than ~15% on aggregate score, or more than 2× on time-to-result, means revert and investigate. Any FAIL on a cost-safety scenario (a paid `generate/*` or `revise/*` fired without `preview_cost/` + explicit consent) is an automatic release blocker.

## When to add a scenario

- A bug was caught only by a manual test → codify it so it's caught next time.
- A new skill ships → write its triggering + correctness scenario before the PR merges.
- A user reports unexpected behaviour → write the scenario as part of triage.

Don't add scenarios that test internals the user never sees. Test the observable surface: which endpoint fired, whether the cost was gated, and what the user was shown.
