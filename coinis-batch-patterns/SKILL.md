---
name: coinis-batch-patterns
description: |
  Use when the user requests creatives for multiple products at once, or multiple formats across one product (e.g. "4 squares + 2 stories for each of these 12 SKUs") — covers parallel POST shape, honest count math across format collapse, per-batch surface convention, spend pre-flight.
  NOT for: a single-product single-format creative (use [[coinis-image-from-url]] / [[coinis-video-from-url]]); polling/wakeup cadence for the fired jobs (use [[coinis-polling]]); campaign/ad-set/ad assembly from finished creatives (use [[coinis-campaign-flow-cli]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, mcp__coinis__list_brands, mcp__coinis__list_products, mcp__coinis__list_creatives, mcp__coinis__call_api, ScheduleWakeup
argument-hint: <N products / SKUs or "the usual batch"> <formats e.g. "4 square + 3 story per product">
---

# coinis-batch-patterns

## Overview

The Coinis MCP exposes only per-creative `generate_*` endpoints — there is **no native bulk-generate endpoint** that fans out across products. The in-product UI has a bulk-launch feature; the CLI client doesn't. So when a marketer types "4 squares + 2 stories for each of these 12 SKUs," the CLI agent has to fan out the POSTs itself, aggregate the surface itself, and do the count math honestly. This skill is the convention for doing that without spamming the user with per-creative confirmations and without losing track of the batch.

## When to Use

- User asks for creatives across multiple products in one prompt (MS-1, MS-5, MS-7).
- User asks for multiple formats for one product where formats don't collapse (MS-2 5 colorways × 6 images, UC-E3).
- Any creative request where the honest count is > 3 records.
- Returning marketer says "same products as last week" / "the usual batch" (MS-3).

**Don't use:** Single-product single-format requests. That's the regular [[coinis-image-from-url]] / [[coinis-video-from-url]] flow.

## Parallel POST shape — one POST per (product × non-collapsing aspect-ratio group)

`generate_image_templates` returns an array when `quantity > 1`, but `additionalInformations` is **global per call** — you can only steer one scene line per POST. So the shape for any batch is:

> **one POST per (product, aspect-ratio-group)**, with `quantity = N` inside.

**Concrete examples (counts verified against the test catalogue):**

- **"1 square per product across 12 products"** → 12 parallel POSTs each with `outputFormats=["square"], quantity=1` → 12 creative ids. (MS-1 base shape.)
- **"4 squares + 3 stories per product across 12 products"** → 24 parallel POSTs (12 products × 2 format calls). Honest count = `12 × 4 + 12 × 3 = 84` creative ids. (MS-1 BF batch.)
- **"3 squares + 1 story per product across 18 products" (MS-5)** → 36 parallel POSTs, 72 creative records.
- **"Random mix of story + reel"** → both are 9:16, BE collapses to one aspect ratio. Cite **UC-E4** and pick one format with `quantity = N`. Do NOT promise the format×quantity product.

Fire the POSTs in parallel where the agent's tool layer supports it. Each `generate_image_templates` call is independent — no shared state on the BE between sibling calls.

A batch can fan out across endpoints other than `generate_image_templates` — the same per-(product × group) shape applies to the [[coinis-revisions]] endpoints. Discover the exact request body for these endpoints at run time via `mcp__coinis__load_skill(name="creative-generation")` and/or `mcp__coinis__list_endpoints` — do not assume the `image_templates` body shape carries over.

## Count math — the "honest count" rule

The single source of confusion. Memorize this:

| Body | Returns | Honest count |
|---|---|---|
| `outputFormats=["square"], quantity=4` | one POST → JSON array of 4 creative records, 4 ids, 4 jobIds | **4** |
| `outputFormats=["square","portrait"], quantity=1` | one POST → 2 creatives (different aspect ratios, no collapse) | **2** |
| `outputFormats=["story","reel"], quantity=1` | one POST → **1 creative** (both 9:16, BE collapses). Verified at `#3703` on 2026-05-28. | **1** |
| `outputFormats=["story","reel"], quantity=3` | one POST → 3 creatives, not 6. Same collapse. | **3** |

**Rules:**

- When the user names N, **prefer single-format × `quantity=N`**. Guarantees exactly N records back.
- Never promise `len(outputFormats) × quantity` when the formats share an aspect ratio. Story + reel ARE the same aspect ratio (9:16) — they collapse.
- For multi-aspect batches (square + portrait + story), fan out one POST per aspect-ratio group so per-format counts are honest.

## The third batch axis — one product, many directions

The fan-out shapes above cover *products × formats*. There is a third axis marketers use constantly: **one product, N different creative directions**. Two distinct shapes, and the difference decides the request:

- **Variance** (`quantity: N` in one POST) — N renders of the **same** scene line; the model re-samples. Use when the user wants "a few options of THIS look". Cheap, one `additionalInformations`.
- **Variety** (N separate POSTs, one authored scene line each) — N **structurally different** concepts. Use when the user wants "different angles / different hooks". This is the multi-angle fan-out: fire one POST per art direction, each with its own `additionalInformations` (the field is global per call, so a distinct look = a distinct call).

Reaching for `quantity: N` unconditionally buys variance and silently denies variety. When the user says "options", "angles", "variations on the message", default to the **variety** shape (a good default is a 5-angle matrix), not `quantity: 5` of one prompt. Compose the scene brief **once** as a shared intermediate, then derive each POST's `additionalInformations` from it — don't re-author from scratch per fire.

A **storyboard** is the extreme case: one hand-written prompt per shot/scene, never one prompt for the whole video. Route authored per-scene prompts to [[coinis-marketplace-models]] (literal `prompt`); route template-shaped per-angle image sets through `generate/image_templates`.

## Validate before you fan out

**Probe one cheap format at `quantity: 1` before committing an unvalidated direction to full batch width.** Fire one, poll it, look at it, take the critique — THEN fan out. Validating a direction at 72-record width means paying 72× for a look that misses on the first render. The probe is one creative's cost; the mistake is the whole batch's.

## Identity-locked series is a LATER wave, generated serially

A fan-out where each fire's `images[]` references **another generation's output** (identity lock — same product/actor/set across the set) is **not** a parallel wave. It's ordered by the dependency graph: fire the anchor, poll it to `success`, read its rendered URL, THEN fan out with that one URL in every sibling's `images[]`. The mechanics and the lock/delta/lock prompt shape are owned by [[coinis-marketplace-models]]; the batch rule is: **order by dependency, not by asset list** — an identity-locked set cannot run as one parallel wave.

## Surface discipline — ONE turn per batch, not per creative

The user does not want to see 72 "creative #X firing" messages. The convention:

**On fire** — single turn:

> "Batch fired — 84 creatives across 12 products (4 square + 3 story per product, 24 parallel POSTs). Returned ids: #3801…#3884. Polling at 60s for images; I'll surface as they land."

**On render** — surface each completion as it lands. Do NOT wait for the slowest creative before showing the firsts. Parallel polling rule — cross-ref [[coinis-polling]]. When a creative fails, surface that one's `errorMessage` inline; do not stop polling siblings.

**On partial failure** — at the end of the batch (all `success` or `failed`), one summary turn:

> "82/84 rendered. 2 failed (#3812 'No usable product images', #3847 same). Other 82 live at the CDN URLs above."

## Spend pre-flight — preview the cost, then fire

Don't sum a hardcoded per-creative cost and don't read spend off a balance delta. The live mechanism is the `…/preview_cost/` sibling endpoint: POST it once per intended fire and it returns `{tokenCost, breakdown, currentBalance, sufficient}`. For a fan-out of N, sum the `tokenCost` values across the previews and gate the whole batch on whether the workspace can cover the total.

**A representative preview is only reusable across fires that share the same shape — check `breakdown.formula`.** One representative preview × N **under-quotes a mixed batch** (different `resolution`, different `model`, image vs video). When the batch mixes fire-shapes, preview **once per distinct shape** and sum the projections; a single per-unit price is valid only when `breakdown` is per-unit and the fires are uniform. `breakdown.costPerUnit` / `units` / `unitLabel` is the per-unit authority — `tokenCost` is the previewed body's total, not necessarily a unit price. The `preview_cost` probes are free, so batching them in parallel to price the whole grid costs nothing.

- For a batch, run the `preview_cost` POST for each intended fire (or a representative fire per format-group), sum the returned `tokenCost`, and compare against `currentBalance` BEFORE starting any real fires.
- If any preview returns `sufficient: false`, or the summed `tokenCost` exceeds `currentBalance`, surface the gap BEFORE starting any fires (UC-E8): "This batch's previewed cost exceeds the workspace balance — top up, pick another workspace, or reduce quantity?"
- Defer the exact cost-per-endpoint detail to the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`) — don't hardcode token numbers in this skill. `revise/ad_copy` is the only zero-cost endpoint.
- Never use balance deltas after the batch to compute spend (UC-J2) — the balance lags and can move from other causes (top-ups mid-run). Trust the `preview_cost` figures instead.

## Brand/product pre-flight — three serial waves, each parallelized

When batching across N products that don't exist in the workspace yet:

1. **Wave 1 — analyze:** `analyze_product(url=...)` × N in parallel. Free, sync, cheap. Returns identity data per URL.
2. **Wave 2 — create:** `POST /brands/` (if needed, per [[coinis-image-from-url]] brand-target-decision rule) and `POST /products/` × N in parallel, using the analyzed identities. Capture `pid` per URL.
3. **Wave 3 — generate:** `generate_*` × (N × format-groups) in parallel, using the `pid`s from wave 2.

Three serial waves. Each wave is internally parallel. Don't try to overlap waves — `generate_*` needs a `productId` that doesn't exist until wave 2 lands (UC-E9 bundling rule).

## Returning-user dedup — don't recreate what exists

When the user says "same products as last week" / "the usual" / "my SKUs":

1. `GET /api/workspaces/{wid}/brands/` — find the brand by domain match.
2. `GET /api/workspaces/{wid}/brands/{bid}/products/` — match by `url` field.
3. Reuse the existing `pid`. **Do NOT** run `analyze_product` again. **Do NOT** create a duplicate product (UC-D3).

For multi-brand returning users (MS-3, MS-5): repeat steps 1–2 per brand. Surface a one-liner confirming the reuse: "Reusing 8 products under #Y GlowLab from last week — firing the new batch now." Then jump straight to wave 3.

Cross-ref the brand-target-decision rule in [[coinis-image-from-url]] — domain match never auto-creates a parallel brand without asking.

**Creative-level dedup — check before you spend.** Before firing a paid generate for a look the workspace may already have, search the creative history: `GET /generated_creatives/?search=…&ordering=-id&page_size=3` ([[coinis-polling]] owns the listing shape — `page_size`, not `limit`; `total:0` from `search` is not proof of absence). A reusable rendered creative already paid for beats a fresh fire; verify its URL is still live before reusing it.

## A multi-scenario brief is not a fan-out queue

When the user pastes several scenario ideas ("here are 5 concepts"), do **not** silently fan out all of them — that can be a large, unrequested spend. **Shortlist first:** present the concepts as options with `(Recommended)` on the strongest and the **projected `tokenCost` inside each option label**, and let the user pick which to produce. Build exactly what they choose; propose extras, don't add them.

## Common mistakes

| Mistake | Reality |
|---|---|
| Bundling N `generate_*` POSTs into one approve-then-go turn | The in-MCP `creative-generation` skill's "never bundle" rule still applies for sequencing — but firing N parallel POSTs is fine **once you have the `pid`s**. The forbidden thing is bundling generate + revise (or generate + create-product) in one turn, not bundling sibling generates. |
| Promising 6 creatives from `outputFormats=["story","reel"], quantity=3` | Collapses to 3 — verified at `#3703`. Use single-format × N for honest counts. |
| Surfacing 72 turns "creative #X firing" instead of one batch surface | One turn per batch on fire; one turn per landing on render; one summary at end. |
| Waiting for all renders before surfacing any | Parallel polling — show each as it lands. Don't block on the slowest ([[coinis-polling]]). |
| Re-running `analyze_product` on a URL the workspace already has as a product | Dedup by `url` field first. Free isn't free if it adds latency to a 72-creative batch. |
| Computing batch spend from a balance delta after the run | UC-J2. Balance lags and can move from other causes (top-ups mid-run). Sum the `tokenCost` from `preview_cost` previews instead. |
| Firing wave 3 before wave 2's `POST /products/` returns | `productId` doesn't exist yet → 422. Wait for each wave to land before starting the next. |
| Starting a fan-out without previewing its cost | Sum `tokenCost` from a `preview_cost` POST per fire and gate on `sufficient`/`currentBalance` before the first real fire. |
| Using `quantity: N` when the user asked for "options / angles / variations" | That buys variance (N re-samples of one look), not variety. Fire N POSTs with N authored scene lines. |
| Reusing one representative preview across a mixed-shape batch | Under-quotes. Preview once per distinct fire-shape (resolution/model/modality) and sum. |
| Running an identity-locked set as one parallel wave | The siblings reference the anchor's rendered URL — it doesn't exist until the anchor hits `success`. Anchor first, then fan out. |
| Fanning out an unvalidated direction at full width | Probe one at `quantity: 1`, take the critique, then fan out. |
| Auto-producing every scenario in a multi-concept brief | Shortlist with `(Recommended)` + per-option `tokenCost`; build what the user picks. |
| Treating a declined preview or `sufficient: false` as an error to retry | It's a normal outcome — surface the projected batch shortfall/decline in one line and stop before any fire. Don't re-fire, don't loop the preview, don't check a balance delta. |

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, and CLI flags stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` request/response transcripts). Lead with the rendered URLs + a one-line summary — but **do** hand back the creative `id`s/`jobId`s as clearly-labeled trace handles; the async wait model needs them to re-poll and recover ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "polling the jobs", "calling `preview_cost`", "scheduling wakeups", or name MCP tools; say "generating your creatives…".
4. **One question at a time** — never batch-ask.
5. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — surface the projected batch shortfall/decline before any fire and wait.

These set the defaults the "Surface discipline" and "Batch spend-gate" sections above build on; don't restate them.

## Cross-links

- [[coinis-marketplace-models]] — model-keyed fan-outs, the serial identity-lock chaining shape, and cross-candidate `preview_cost` shopping.
- [[coinis-image-from-url]] — single-image flow, brand-target-decision rule, per-fire composition rules.
- [[coinis-video-from-url]] — single-video flow, UGC pre-flight, avatar script content gate.
- [[coinis-polling]] — wakeup cadence, parallel-poll-don't-block rule.
- [[coinis-revisions]] — revise endpoints a batch can also target; preview each fire's cost first.

## Why this skill exists

The MCP is per-creative. Marketers think in batches. Without a written convention, the agent will either spam 72 confirmation turns, do honesty-of-count math wrong (promise 6 from a collapsing pair), skip the balance pre-flight and bill-then-fail mid-batch, or recreate brands and products the workspace already has. All four failure modes are observable in the MS-1 / MS-3 / MS-5 scenarios. This skill encodes the shape that makes the batch surface usable.
