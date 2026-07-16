---
name: coinis-competitor-recreate
description: |
  Use when the user supplies a competitor's ad, creative, or landing page (a URL or an uploaded image) and asks to "recreate it", "do our version of this", "match this competitor's ad in our style", or "remix this ad for our brand" via the Coinis MCP (`coinis`). Triggers on a competitor reference + a recreate/remix intent against the user's own brand/product.
  NOT for: generating a creative from the user's OWN product URL with no competitor reference (use [[coinis-image-from-url]]); video remixes (use [[coinis-video-from-url]]); or template-driven generation with no source ad to mimic (use `generate/image_templates` via [[coinis-image-from-url]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, ScheduleWakeup
argument-hint: <competitor-ad-url-or-image> [+ which brand/product to render it for]
---

# coinis-competitor-recreate

## Overview

`generate/competitor_recreate` is a Coinis-UNIQUE capability: it ingests a competitor's ad/creative and recreates it in the **user's own brand style** (brand palette, voice, product). No competitor analog exists — this is the differentiated endpoint, not a template wrapper.

This skill is a thin CLI overlay. It does NOT redefine the request body — the authoritative shape lives in the in-MCP playbook. **Load it before firing:**

```python
mcp__coinis__load_skill(name="creative-generation")
mcp__coinis__list_endpoints
```

`creative-generation` carries the validation matrix and the exact accepted fields for `competitor_recreate`; `list_endpoints` confirms the method + path are still live. Do not paraphrase the body from memory — discover it at run time, exactly as [[coinis-image-from-url]] does for its endpoints.

## What it does

Analyzes a competitor creative (its layout, hook, composition, offer framing) and regenerates an equivalent creative skinned to the user's brand and product. **Confirm the exact ingestion semantics — what "analyze" extracts and how it maps onto the user's brand — via `load_skill('creative-generation')` before describing the output to the user.** Do not promise a 1:1 clone; it is a brand-restyled recreation, not a copy.

## Accepted inputs

The endpoint takes a competitor source (URL and/or image) plus a brand/product target. **The exact field names and whether URL, image, or both are accepted are NOT documented here — discover them via `load_skill('creative-generation')` / `list_endpoints`.** [[coinis-image-from-url]] already lists `generate/competitor_recreate` in its image-credit-spend row and Quick-reference family, so it shares the same renderer class and workspace/product plumbing as `generate/image_templates`.

| Field | Status |
|---|---|
| Competitor source (URL) | verify via `load_skill('creative-generation')` |
| Competitor source (image / upload key) | verify via `load_skill('creative-generation')` |
| `productId` (the user's product to render for) | required — same plumbing as `generate/image_templates`; verify exact key via `load_skill('creative-generation')` |
| `outputFormats`, `quantity`, `tone`, `style`, `additionalInformations` | verify support per `load_skill('creative-generation')` — do NOT assume the `image_templates` enum carries over unchanged |

Flag every field above as unconfirmed until the playbook returns its schema. If `image_urls`/`image_keys`-style fields appear, the same XOR-never-both rule from [[coinis-image-from-url]] is the safe default — confirm in the playbook.

## Cost — confirm via `preview_cost` before firing

`generate/competitor_recreate` spends workspace tokens, so gate the fire behind a cost preview. Before the POST, call the preview endpoint and surface the figures to the user:

```
POST generate/competitor_recreate/preview_cost/
→ { tokenCost, breakdown, currentBalance, sufficient }
```

Surface `tokenCost` + `currentBalance`, then proceed only on **explicit user consent AND `sufficient: true`**. Do NOT hardcode the cost — call `preview_cost` for the figure each time; it can shift with quantity/format. If `sufficient: false`, stop and tell the user the balance is short. (`revise/ad_copy` is the only zero-cost exception in the wider creative pipeline — it needs no preview.)

The cost/spend-gate logic is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`); load it to confirm the authoritative preview shape before firing.

## When to use vs `generate/image_templates`

| Situation | Endpoint |
|---|---|
| User points at a **competitor ad/creative** and wants their version of it | `generate/competitor_recreate` (this skill) |
| User wants a creative built from a **template / brand style** with no source ad to mimic | `generate/image_templates` via [[coinis-image-from-url]] |

If there is no competitor reference in the request, route to [[coinis-image-from-url]] — `competitor_recreate` without a source creative has nothing to analyze.

## Brand / product setup prerequisite

This endpoint renders for the user's product, so a `productId` (and its parent brand) must exist first. The brand-target rule is owned by [[coinis-image-from-url]]: **no domain match → silently create the brand; domain match → ask use-existing vs parallel.** If the user has no product yet, run the [[coinis-image-from-url]] brand/product setup sequence (`analyze_product` → create brand → create product) to obtain the `productId`, THEN fire `competitor_recreate`. Do not invent a product id, and do not bundle product-create with the generate fire — the `productId` must land before the generate call references it.

## Polling

Render-status polling is owned by [[coinis-polling]]. `competitor_recreate` is the same renderer class as `image_templates`: **first poll at 60 s, re-poll every 30 s while `processing`.**

```
GET /api/workspaces/{wid}/generated_creatives/{cid}/
```

Wait for `actionStatus: success`, then quote `imageUrl`. On `failed`, read `errorMessage` and stop. For batches of several recreations, sort by `id` desc (not `createdAt`) per [[coinis-polling]]. Use `ScheduleWakeup` only if you fan out many at once; a single 60-s inline poll is usually enough for one fire.

## Surface the fire — single message, plan + result

After the user consents to the previewed `tokenCost` and you POST, write ONE turn bundling: the competitor source used, the brand/product it was rendered for, the composition params fired, the returned creative `id` + `jobId`, the honest creative count, the `tokenCost` that was confirmed via `preview_cost`, and a one-liner inviting redirect ("If the recreation's off, say what to change and I'll re-fire").

## Common mistakes

| Mistake | Reality |
|---|---|
| Firing without a cost preview | Call `generate/competitor_recreate/preview_cost/` first. Surface `tokenCost` + `currentBalance`; proceed only on explicit consent AND `sufficient: true`. |
| Hardcoding the token cost | Don't pin a number. Call `preview_cost` each time — the figure can shift with quantity/format. |
| Paraphrasing the request body from `image_templates` | The accepted fields may differ. Discover via `load_skill('creative-generation')` / `list_endpoints` — don't assume the enum or field names carry over. |
| Firing with no `productId` | The endpoint renders for the user's product. Run the [[coinis-image-from-url]] setup to get a `productId` first. |
| Promising a 1:1 clone of the competitor ad | It's a brand-restyled recreation, not a copy. Confirm semantics via `load_skill('creative-generation')` before describing the output. |
| Routing a no-competitor-reference request here | If there's no source ad to analyze, use `generate/image_templates` via [[coinis-image-from-url]]. |
| Treating a declined preview or `sufficient: false` as an error to retry | It's a normal outcome — report the shortfall/decline in one line and stop. Don't re-fire, don't loop the preview, don't check a balance delta. |

## Red flags — stop and re-check

- About to fire without a cost preview → STOP. Call `generate/competitor_recreate/preview_cost/`, surface `tokenCost` + `currentBalance`, and proceed only on explicit consent AND `sufficient: true`.
- About to hardcode a token cost in the surface line → STOP. Quote the `tokenCost` returned by `preview_cost`, never a guessed number.
- About to fire without a `productId` → STOP. Set up the brand/product first via [[coinis-image-from-url]].
- About to hardcode the request body from this file → STOP. Confirm field names via `load_skill('creative-generation')`; this skill does not pin the schema.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, and CLI flags stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` request/response transcripts). Lead with the rendered URL + a one-line summary — but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles; the async wait model needs them to re-poll and recover ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "polling the job", "calling `preview_cost`", "scheduling a wakeup", or name MCP tools; say "generating your creative…".
4. **One question at a time** — never batch-ask.
5. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait.

These set the defaults the "Surface the fire" step above builds on; don't restate them.

## Related skills

- [[coinis-image-from-url]] — brand/product setup sequence, the brand-target rule, and the image-credit spend convention this endpoint shares.
- [[coinis-polling]] — render-status polling cadence (same class as `image_templates`), the `aiResults[]` shape, sort-by-id rule.
- [[coinis-video-from-url]] — if the user wants a video remix rather than an image recreation.

## Why this skill exists

`competitor_recreate` is a differentiated Coinis capability: it ingests a competitor's creative and recreates it in the user's own brand style, with no template analog. Without an explicit skill, an agent misroutes a competitor-recreate request to the plain template endpoint, or fires without previewing the spend. This skill pins the routing, the cost-preview gate, and the brand-target prerequisite — while deliberately NOT pinning the request body, which must be discovered at run time via `load_skill('creative-generation')`.
