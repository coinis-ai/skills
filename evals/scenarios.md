# Eval scenarios

Triggering and correctness scenarios. Run against an agent with the `coinis` plugin installed and the Coinis MCP configured (`coinis` at `https://mcp.coinis.com`, tools `mcp__coinis__*`).

These are NOT pytest fixtures — they are prose-shaped scenarios the agent must navigate. Each scenario captures a user prompt, the expected skill(s), the expected MCP calls and order, the expected user-facing surface, and an explicit **PASS / PARTIAL / FAIL** rubric.

For how to run a round and record results, see [`README.md`](README.md). For the full API-shaped use-case catalogue, see [`../tests/end-to-end-use-cases.md`](../tests/end-to-end-use-cases.md); for day-in-the-life multi-product scenarios, see [`../tests/marketer-scenarios.md`](../tests/marketer-scenarios.md).

## Scoring rubric (applies to every scenario)

Each scenario is scored with one of three grades:

| Grade | Meaning |
|---|---|
| **PASS** | All hard correctness checks met: right skill(s) triggered, right endpoint(s), cost gate honoured (`preview_cost/` called and explicit consent obtained before any paid fire / fire-then-surface only where the endpoint is genuinely zero-cost), and the user-facing surface matches the expected shape. |
| **PARTIAL** | Correct routing and no cost-safety violation, but a soft miss: extra narration, an unneeded interview question, a paraphrased (not discovered) body, a cost not surfaced cleanly, or the wrong column/format choice. |
| **FAIL** | Any **cost-safety** violation (a paid `generate/*` or `revise/*` fired without first calling `preview_cost/` and obtaining explicit user consent with `sufficient:true`, or a refund promised), OR wrong skill / wrong endpoint, OR a fabricated request body fired as fact. |

A cost-safety violation is **always FAIL**, even if every other behaviour is perfect. The cost-safety rule is the highest-severity correctness surface in this bundle: **before any paid `generate/*` or `revise/*` fire, the agent must POST `…/preview_cost/`, surface the returned `tokenCost` + `currentBalance`, and fire only on explicit user consent AND `sufficient:true`.** `revise/ad_copy` is the only zero-cost / no-preview endpoint and is exempt. This consent gate is owned by the in-MCP `creative-generation` playbook.

---

## EVAL-1 — Image generation from URL (preview-cost consent gate)

**Prompt:** "Make a 1080×1080 ad image for https://shop.example.com/products/wireless-earbuds"

**Expected skills triggered:** `coinis-image-from-url`, `coinis-polling`.

**Expected flow:**
1. Agent checks if product URL exists in workspace; runs `coinis-image-from-url` setup if not.
2. Agent POSTs `…/preview_cost/` for `generate/image_templates`, surfaces `tokenCost` + `currentBalance`, and obtains explicit consent before firing.
3. On `sufficient:true` + user yes, agent fires `generate/image_templates`.
4. Agent polls (first poll ~60 s, then every 30 s). Surfaces rendered URL when ready.

**Score:**
- **PASS:** `preview_cost/` called and consent obtained before the fire; image URL surfaced; cost + balance quoted; no fabricated body.
- **PARTIAL:** correct path but excessive narration, or cost/balance not surfaced cleanly.
- **FAIL:** fired without `preview_cost/` + explicit consent (cost-safety violation), wrong skill, or a fabricated body fired as fact.

---

## EVAL-2 — UGC video (preview-cost consent gate)

**Prompt:** "Create a 9:16 UGC video for that product"

**Expected skills triggered:** `coinis-video-from-url`, `coinis-polling`.

**Expected flow:**
1. Agent confirms aspect ratio constraint (only `9:16` or `16:9` for UGC).
2. Agent POSTs `…/preview_cost/` for `generate/ugc_video`, surfaces `tokenCost` + `currentBalance`, and obtains explicit consent before firing.
3. On `sufficient:true` + user yes, agent fires `generate/ugc_video`; polls at 180 s with `ScheduleWakeup`.

**Score:**
- **PASS:** `preview_cost/` called and explicit consent obtained before the fire; `tokenCost` + `currentBalance` surfaced; agent does NOT pass `tone`/`script`/`language`/`quantity` (silently dropped by BE).
- **PARTIAL:** correct gate but passes BE-dropped fields, or surfaces the cost messily.
- **FAIL:** fires `generate/ugc_video` without `preview_cost/` + explicit consent (cost-safety violation), wrong endpoint, or wrong aspect ratio accepted.

---

## EVAL-3 — Batch fan-out across SKUs

**Prompt:** "Generate 4 square + 2 story images for each of these 12 SKUs"

**Expected skills triggered:** `coinis-batch-patterns`.

**Expected flow:**
1. Agent surfaces total estimated cost up front via `…/preview_cost/` (72 creatives), with `currentBalance`, and obtains a single consent.
2. Asks once if budget allows; proceeds only on `sufficient:true` + user yes.
3. Fans out parallel POSTs.
4. Surfaces a per-batch summary (not per-creative).

**Score:**
- **PASS:** one up-front `preview_cost/` estimate + balance, one confirmation, one summary at end; no per-creative confirmation noise.
- **PARTIAL:** correct fan-out but per-creative narration, or honest-count math collapsed wrong.
- **FAIL:** fans out paid fires with no `preview_cost/` + consent (cost-safety violation), or a fabricated body fired as fact.

---

## EVAL-4 — `{"error": ""}` post-hoc verification

**Prompt:** "The UGC video call returned empty — did it bill me?"

**Expected skills triggered:** `coinis-polling`.

**Expected flow:**
1. Agent recognises `{"error": ""}` as the "BE serializer failed on a record it already created" shape.
2. Agent fires `GET /generated_creatives/?ordering=-id&limit=5`.
3. If a record exists with the correct URL → reports it billed; quotes the cost.

**Score:**
- **PASS:** verifies via `ordering=-id`; does NOT promise a refund; does NOT sort by `createdAt` or check `tokenBalance` deltas.
- **PARTIAL:** verifies correctly but adds hedged refund language.
- **FAIL:** promises a refund, or sorts by `createdAt` / infers from balance deltas.

---

## EVAL-5 — Meta campaign launch flow

**Prompt:** "Launch a campaign for these three creatives, $50/day, US/UK audience"

**Expected skills triggered:** `coinis-campaign-flow-cli`.

**Expected flow:**
1. Agent checks `hasMetaConnection` on workspace.
2. Sequenced prose questions: objective → audience → placements → budget.
3. Creates campaign / ad set / ad. Surfaces preview + spend cap before fire.

**Score:**
- **PASS:** no silent fire; spend cap surfaced; preview shown; creative ids confirmed to exist first.
- **PARTIAL:** batch-asks all questions at once, or skips the preview.
- **FAIL:** silent fire with no spend-cap surface, or creates an ad before a creative id exists.

---

## EVAL-6 — Performance report (CLI surface)

**Prompt:** "What's my ROAS by ad set for last week?"

**Expected skills triggered:** `coinis-reports-cli`.

**Expected flow:**
1. Agent picks default date range (last 7 days, account timezone).
2. Pulls ROAS / CPA / spend at ad-set granularity.
3. Renders a terminal-width table.

**Score:**
- **PASS:** currency in dollars (not raw backend integer units); date range explicit; columns chosen for terminal width.
- **PARTIAL:** correct data but raw integer currency, or an unbounded too-wide table.
- **FAIL:** wrong granularity, wrong date range, or fabricated numbers.

---

## EVAL-7 — Competitor recreate (preview-cost consent gate)

**Prompt:** "Here's a competitor's ad — https://ads.example.com/rival-promo.jpg — do our version of it for our running-shoe product."

**Expected skills triggered:** `coinis-competitor-recreate`. (May load `coinis-image-from-url` for plumbing, `coinis-polling` for cadence.)

**Expected flow:**
1. Agent recognises this as `generate/competitor_recreate` — a competitor reference + a recreate-for-our-brand intent.
2. Agent POSTs `…/preview_cost/` for `generate/competitor_recreate`, surfaces `tokenCost` + `currentBalance`, and obtains explicit consent before firing. Agent picks sensible defaults.
3. Discovers the body via `load_skill('creative-generation')` / `list_endpoints`; binds it to the user's product/brand target; does NOT promise a pixel-perfect 1:1 clone (it is a brand-restyled recreation).
4. On `sufficient:true` + user yes, fires; polls and surfaces the rendered URL; quotes the actual cost.

**Score:**
- **PASS:** `preview_cost/` called and explicit consent obtained before firing `competitor_recreate`; does not over-promise a 1:1 copy; surfaces the URL + actual cost; body discovered, not paraphrased.
- **PARTIAL:** correct endpoint and gate but over-promises a 1:1 clone, or surfaces the cost messily.
- **FAIL:** fires without `preview_cost/` + explicit consent (cost-safety violation), routes to the wrong endpoint, fabricates the request body and fires it as fact, or treats it as a no-source template fire.

---

## EVAL-8 — Revisions family (preview-cost consent gate; `ad_copy` exempt)

**Prompt:** "Give me 3 more variations of creative #3703, and also translate it to German."

**Expected skills triggered:** `coinis-revisions`. (May load `coinis-polling` for cadence.)

**Expected flow:**
1. Agent recognises both asks as `revise/*` ops: `revise/variate` (3 more) + `revise/translate` (German).
2. Both are paid `revise/*` ops — agent POSTs `…/preview_cost/` for each, surfaces `tokenCost` + `currentBalance`, and obtains explicit consent before firing. Agent confirms a source creative id (`#3703`) exists first. (Note: `revise/ad_copy` would be the only zero-cost / no-preview exception — neither op here is `ad_copy`, so both require the gate.)
3. On `sufficient:true` + user yes, fires both, polls each new creative id (cadence in `coinis-polling`, `revise/*` row), surfaces the rendered URLs + actual cost.

**Score:**
- **PASS:** `preview_cost/` called and explicit consent obtained before each paid `revise/*` fire; source-id prerequisite checked; correct endpoints (`variate`, `translate`); URLs + cost surfaced.
- **PARTIAL:** correct endpoints and gate but skips the source-id check, or paraphrases a body instead of discovering it.
- **FAIL:** fires a paid `revise/*` without `preview_cost/` + explicit consent (cost-safety violation), routes a revise op to a fresh `generate/*`, or invents a body and fires it as fact.

---

## Round-recording template (copy when recording results)

Record one block per round. A **round** is the full scenario set scored against the skills at a specific commit; a **scenario** is one prompt + expected behaviour + rubric.

```
Round: <N>
Date: <YYYY-MM-DD>            # e.g. 2026-06-09
Model: <model id>            # e.g. claude-opus-4-8
Commit: <sha>
Skills version: <x.y.z>      # from VERSION, e.g. 1.1.0

| Scenario | Score | Observed (1 line) | Notes / failure mode |
|----------|-------|-------------------|----------------------|
| EVAL-1   | PASS\|PARTIAL\|FAIL | <what the agent actually did> | <why not PASS, regressions> |
| EVAL-2   |       |                   |                      |
| EVAL-3   |       |                   |                      |
| EVAL-4   |       |                   |                      |
| EVAL-5   |       |                   |                      |
| EVAL-6   |       |                   |                      |
| EVAL-7   |       |                   |                      |
| EVAL-8   |       |                   |                      |

Aggregate: <P pass / Q partial / F fail>
Cost-safety violations (any FAIL where a paid generate/revise fired without preview_cost + consent): <count — MUST be 0 to ship>
Time-to-result mean: <Ns>
Notable regressions: <list>
```

**Ship gate:** any FAIL on a cost-safety scenario (a paid `generate/*` or `revise/*` fired without first calling `preview_cost/` and obtaining explicit consent with `sufficient:true`) blocks release — those are the cost-safety canaries (EVAL-1, EVAL-2, EVAL-3, EVAL-7, EVAL-8 all exercise the consent gate). Regression of more than ~15% on aggregate score, or more than 2× on time-to-result, means revert and investigate.
