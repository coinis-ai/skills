---
name: coinis-image-from-url
description: |
  Use when creating an image creative via the Coinis MCP (`coinis`) and the user supplies (or implies) a product URL the workspace doesn't yet have. Covers the auth checkpoint that blocks silent brand creation, the brand/product setup sequence, and the credit-spend approve gate.
  NOT for: a product that already exists in the workspace (load the in-MCP `creative-generation` playbook and fire directly); video creatives (use [[coinis-video-from-url]]); a named model / authored prompt / arbitrary reference images (use [[coinis-marketplace-models]]); the competitor-recreate flow (use [[coinis-competitor-recreate]]); multi-product / multi-format fan-outs (use [[coinis-batch-patterns]]); render-status polling (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_skills, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, mcp__coinis__list_brands, mcp__coinis__list_products, mcp__coinis__get_product, mcp__coinis__list_creatives, mcp__coinis__call_api, ScheduleWakeup
argument-hint: <product URL> [format e.g. "square"/"story"] [quantity N] [tone/style hints]
---

# coinis-image-from-url

## Overview

End-to-end recipe for Coinis MCP (`coinis`) image generation in Claude Code. The in-app agent surface renders front-end approve blocks the CLI doesn't have, so this skill carries the gate logic explicitly.

**Standing rules:**

| Layer | Rule |
|---|---|
| New brand from unknown domain | Silently create. No ask. |
| New brand from matching domain | Ask: use existing vs create parallel. (Domain dedup is NOT server-enforced — verified 2026-05-28 with brand #778 created in parallel to #757; this gate must be enforced agent-side.) |
| Image credit spend (`generate/image_templates`, `generate/competitor_recreate`) | Before firing, POST the sibling `…/preview_cost/` and surface `tokenCost` + `currentBalance`; proceed only on explicit consent AND `sufficient: true`. The `creative-generation` playbook owns this gate (`load_skill('creative-generation')`). For a competitor-ad-driven recreate (not a product URL), use [[coinis-competitor-recreate]]. |
| Video credit spend | Approve-gate logic lives in [[coinis-video-from-url]]. |

**Spend gate:** before any paid `generate/*` or `revise/*` fire, POST the sibling `…/preview_cost/` endpoint, which returns `{tokenCost, breakdown, currentBalance, sufficient}`. Surface `tokenCost` + `currentBalance` to the user and proceed only on explicit consent AND `sufficient: true`. Do NOT hardcode token numbers — read `tokenCost` from the preview. This gate is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`); the recipe below is a CLI-specific overlay around it.

## When to Use

- User pastes a product URL and asks for an image / creative.
- User says "create image" / "generate creative" and the workspace's `list_products` returns 0.
- Any `generate_*` call that needs a `productId` you don't have yet.

**Don't use:** When the product already exists in the workspace — jump straight to the `creative-generation` skill (load via `load_skill`). When the user named a model, authored a literal prompt, or handed you arbitrary reference images — that's [[coinis-marketplace-models]].

## STOP — is this a BRAND-AWARENESS request? (check FIRST, before any resolution)

Before resolving a workspace or product, decide whether this is a **product ad** or a **brand-awareness post** — they use different endpoints. Owned by the in-MCP `generate-image-templates` playbook; mirrored here because the CLI has no form to route it.

- User asked for **brand awareness / a brand post / an awareness campaign / a post "for &lt;brand&gt;"** and did **not** name a specific product or product URL → this is **NOT** `generate/image_templates`. Resolve the brand (`list_brands(search="&lt;name&gt;")`) and fire **`generate/social_post/`** (preview via `generate/social_post/preview_cost/`) with `brandId`. Do this **even if the brand has products**.
- User named a product or product URL → product ad → continue with `generate/image_templates` below.

Getting this wrong spends credits on the wrong creative shape. Confirm the exact `social_post` body via `load_skill('creative-generation')` — don't assume the `image_templates` fields carry over.

## Mandatory pre-flight

Load `creative-generation` AND `brand-product-setup` from the MCP at the start:

```python
mcp__coinis__load_skill(name="creative-generation")
mcp__coinis__load_skill(name="brand-product-setup")
```

These carry validation matrices and the approve-gate rules. The recipe below is a Claude-Code-specific overlay, not a replacement.

## Flow

### 1. Resolve workspace

`list_my_workspaces` → pick the highest-balance workspace with `hasMetaConnection: true` unless the user named one. Cache the id.

**An empty `list_my_workspaces` result means "unknown", not "none".** The convenience tool has been observed returning no output on a session with hundreds of workspaces. Don't tell the user they have no workspace — fall back to `GET /api/workspaces/` (a different, larger shape keyed differently: `tokenBalance` IS present, but Meta connectivity is the `facebookAccess` field, not `hasMetaConnection`), then ask which one and take the display `name` verbatim.

### 2. Analyze the product URL (free, sync)

```
POST /api/onboarding/brand_intel/analyze_product/
body: {"url": "<product-url>"}
```

Returns `name`, `description`, `imageUrls[]`, `productAiSummary`, `productCategory`. Keep this payload — feeds product creation in step 4.

### 3. Brand-target decision — branch on URL domain

`GET /api/workspaces/{wid}/brands/` and compare the URL's eTLD+1 against each brand's `website` field (and `name`).

**Two branches:**

- **No domain match** → SILENTLY create a new brand. No "ask". Skip straight to step 4 with the analyzed identity data prefilled. The auto-mode classifier may flag the mutation on first attempt — if it does, cite this rule when retrying or asking permission. Do NOT default back to presenting the gate.
- **Domain match** → present a one-line choice: "Use existing `#Y <SomeBrand>`, or create a parallel entry?" This branch is the only place the gate fires. A bare "yes" or "use existing" picks existing; "new" / "parallel" creates.

The three-option gate ("No Brand / existing / new") is retired — it produced friction without changing behaviour.

### 4. Create brand (no-match branch)

Use the full identity data from `analyze_brand_identity` when available — name, website, vertical, language, colors (primary/secondary/accent), voiceTags, categories, logoUrl, description. Don't skimp: a fully-populated brand makes downstream `tone`/`style` inference better.

```
POST /api/workspaces/{wid}/brands/
body: {
  "name": "...",
  "website": "https://host",
  "vertical": "...",
  "language": "<iso>",
  "description": "...",
  "primaryColor": "#...",
  "secondaryColor": "#...",
  "accentColor": "#...",
  "voiceTags": [...],
  "categories": [...],
  "logoUrl": "https://..."
}
```

Required: `name` only. Capture returned `id` as `brand_id`.

### 5. Create product

```
POST /api/workspaces/{wid}/brands/{brand_id}/products/
body: {
  "name": "<from analyze>",
  "description": "<short, includes key specs + price>",
  "category": "<productCategory from analyze>",
  "url": "<original URL>",
  "image_urls": ["<imageUrls[0..N], drop any with '<!--' or non-jpg/png/webp tails>"]
}
```

`image_urls` XOR `image_keys` — never both. Capture returned `id` as `product_id`.

### 6. Preview cost, confirm, then fire

Before firing `generate_image_templates`, POST the sibling `…/preview_cost/` endpoint with the composed body to get `{tokenCost, breakdown, currentBalance, sufficient}`. Surface `tokenCost` + `currentBalance`, and fire only on explicit consent AND `sufficient: true`. Read `tokenCost` from the preview — never hardcode it. (`load_skill('creative-generation')` owns the gate.)

**Composition rules (apply when building the body):**

- `outputFormats`: default `["square"]`. **Valid enum**: `'square', 'feed', 'portrait', 'story', 'reel'`. **`landscape` / `16:9` is NOT supported** — sending it 422s with `"Input should be 'square', 'feed', 'portrait', 'story' or 'reel'"`. If the user asks for a wide/banner format, surface that the API doesn't have one and offer `feed` (4:5 portrait crop) as the closest substitute.
- `quantity`: default `1`. If the user said "N images", use single format × quantity N (avoids the story+reel 9:16 collapse).
- `tone`: default `professional`. Override only if brand `voiceTags` clearly imply playful/casual/luxury.
- `style`: default `clean-minimal`. Tech/SaaS → keep; lifestyle/consumer → consider `bold` or `photo-realistic`.
- `resolution`: a **cost-affecting** field — `1K` / `2K` / `4K`, and the price scales with it. Explore cheap, finish expensive: prove a direction at the default resolution, then re-fire only the keeper at `2K`/`4K`. **The body you preview MUST equal the body you fire, `resolution` included** — a 4K quote fired at 1K, or vice-versa, mismatches the charge. Only send it when the user picked a size.
- `additionalInformations`: **not "one scene line" — a 4-part spine addressing a compositor**, in order: (1) the **angle** / marketing hook for this specific creative, (2) the scene / setting, (3) any brand-direction cue (palette, mood — see cross-branding note below), (4) **reserved negative space** where a headline/CTA will sit if one is wanted on-canvas. Derive it from product name + description + brand vertical/palette. NO placeholders, NO "AI choice".

**Letterforms — the model cannot spell.** `generate/image_templates` has **no `prompt` field and no negative-prompt field**; `additionalInformations` is the only text channel, and exclusions go in **positively** ("clean uncluttered background", not "avoid clutter"). Do **not** ask it to render a wordmark, a logo, or an exact copy string — the diffusion model invents and misspells them, and no `revise/*` repairs baked-in text. For literal on-canvas words, either request clean negative space and composite the copy downstream, or generate the ad-copy TEXT separately via `revise/ad_copy` ([[coinis-revisions]]) and place it yourself. Brand-exact logos/hex are unreachable by the generator; a paid re-fire will not fix them.

**Cross-branding is prompt-only.** The backend styles the creative with the **product's own brand** (colors + voice, resolved from `productId`) — you cannot attach a different brand's identity via a `brandId` from history. To put brand B's look on brand A's product (e.g. a Coinis end-card on a partner product), write that direction into `additionalInformations`; the creative still attaches to the product's own brand server-side.

**One POST per art direction, not per format.** A single POST with multiple `outputFormats` gives every format the *same* `additionalInformations` — there's no per-format layout steer. When each placement needs its own composition, fire one POST per art direction (see the multi-angle fan-out in [[coinis-batch-patterns]]); splitting a multi-placement set across formats in one call re-rolls the look and it drifts.

**Honest count math:**

- `outputFormats: ["square"], quantity: 4` → **4 separate creative records** (one POST returns a JSON array of 4 creatives, each with its own `id` and `jobId`). NOT one creative with 4 images.
- `outputFormats: ["story", "reel"], quantity: 3` → both story and reel are 9:16, so the formats collapse to one aspect ratio. The honest count is `1 × 3 = 3` creatives — NOT 6. Rule: when the user names N, prefer single format × quantity N, never overlap collapsing formats. **Confirmed at BE 2026-05-28** — creative `#3703` fired with `outputFormats=["story","reel"], quantity=1` returned exactly one record. For multi-product fan-outs see [[coinis-batch-patterns]].
- For batches across multiple non-collapsing formats (e.g. 4 square + 3 story + 3 portrait = 10 total), fire **multiple POST calls in parallel** — one per format. Per-variation prompts only work this way because `additionalInformations` is global per call.

```
# 1. Preview the spend
POST /api/workspaces/{wid}/generated_creatives/generate/image_templates/preview_cost/
body: {
  "productId": <id>,
  "outputFormats": ["square"],
  "quantity": 1,
  "tone": "...",
  "style": "...",
  "additionalInformations": "..."
}
# → {tokenCost, breakdown, currentBalance, sufficient}
# Surface tokenCost + currentBalance; fire only on consent AND sufficient: true.

# 2. Fire (same body)
POST /api/workspaces/{wid}/generated_creatives/generate/image_templates/
body: { ...same as above... }
```

The generate POST returns immediately with creative `id`, `jobId`, `actionStatus: processing`.

### 7. Surface the result

Right after the generate POST lands, write a turn that bundles:

- The plan that was fired (table or short bullet list — workspace / product / brand / outputFormats / quantity / tone / style / scene line).
- The returned creative `id` and `jobId`.
- The honest creative count.
- A one-liner inviting redirect: "If the scene's off, say what to change and I'll re-fire."

The cost was already surfaced and consented to at the preview_cost step; this turn confirms what landed.

### 7b. User-supplied images — register BEFORE generating from them

When the user attaches a photo (a product shot, a face to feature) and you'll base a generation on it, the BE needs a **public https URL** — it cannot read a CLI chat attachment, a local path, or base64. Host it first:

```
POST /api/workspaces/{wid}/generated_creatives/presigned_upload_url/
body: {"filename": "...", "contentType": "..."}     ← lowercase `filename`; `fileName` 422s "Field required: filename"
→ PUT the bytes to the returned URL → the public URL is the reference
```

Feed the resulting public URL as the product image (via `create_product` `image_urls`) or, for a reference-locked / likeness / named-person render, use [[coinis-marketplace-models]] (which pins `images[]` to the render). Preserving a specific person's likeness is a **reference-image** problem, not a prompt adjective — the marketplace path owns it.

### 8. Poll for the rendered URL

Polling cadences, the `aiResults[]` shape (`revise/ad_copy` has a different result shape that doesn't create a new id), the sort-by-`id`-desc rule for recovery, and the `ScheduleWakeup` integration are owned by [[coinis-polling]]. Short version: image_templates renders in 60–80 s (verified 2026-05-28 across `#3632`/`#3635`/`#3637`); first poll at 60 s.

```
GET /api/workspaces/{wid}/generated_creatives/{id}/
```

Wait for `actionStatus: success`, then quote `imageUrl`. Rendered assets land on the workspace's configured CDN; the GET response is authoritative for the final URL.

## Quick reference — endpoints

| Step | Method | Path |
|---|---|---|
| Analyze product | POST | `/api/onboarding/brand_intel/analyze_product/` |
| List brands | GET | `/api/workspaces/{wid}/brands/` |
| Create brand | POST | `/api/workspaces/{wid}/brands/` |
| List products | GET | `/api/workspaces/{wid}/brands/{bid}/products/` |
| Create product | POST | `/api/workspaces/{wid}/brands/{bid}/products/` |
| Generate image | POST | `/api/workspaces/{wid}/generated_creatives/generate/image_templates/` |
| Read creative | GET | `/api/workspaces/{wid}/generated_creatives/{cid}/` |

## Common mistakes

| Mistake | Reality |
|---|---|
| "User gave URL → ask before creating the brand" | Only ask if the domain MATCHES an existing brand. No-match = silently create. |
| "I'll skip the approve gate — user already said yes to brand creation" | Brand-create approval ≠ credit-spend approval. Brand-gate has its own no-match rule; the spend gate runs `preview_cost` and needs consent + `sufficient: true`. Video-spend-gate is owned by the video skill. |
| "I'll hardcode the token cost from memory" | Don't. Read `tokenCost` from the `preview_cost` response every time — it varies with format/quantity. |
| Sending `outputFormats: ["landscape"]` or `["16:9"]` | 422. Not in the enum. Use `feed` or `portrait` as the closest substitute; tell the user the API doesn't have a wide format. |
| Assuming `quantity: N` gives one creative with N images | No — gives N separate creative records (N ids, N jobIds). Each renders independently and can fail independently. Track them as a batch in the surface line. |
| Bundling brand-create + product-create + generate into one mega-approve | The upstream skill forbids bundling `generate_*` with anything else — `source_creative_id` doesn't exist until the prior step lands. Same logic: don't pre-confirm spend on data that doesn't exist yet. |
| Putting `story` + `reel` in `outputFormats` and promising 2 creatives | Both are 9:16 — they collapse. You get 1. Use single-format × N quantity for honest counts. |
| Sending both `image_urls` and `image_keys` on `create_product` | 422. They are mutually exclusive. |
| Retrying the import via `import_from_url` when homepage scrape returns 0 SKUs | The endpoint is for catalogue pages, not homepages. Use `analyze_product` on the specific product page instead. |
| Firing `image_templates` for a "brand awareness post for &lt;brand&gt;" with no product | Wrong endpoint. That's `generate/social_post/` with `brandId` — even if the brand has products. Check the brand-awareness STOP first. |
| Asking `additionalInformations` to render a wordmark / logo / exact copy | No prompt field, no text engine — the model misspells baked-in text and no `revise/*` fixes it. Reserve negative space; composite copy, or use `revise/ad_copy` for the text. |
| Treating `list_my_workspaces` returning empty as "user has no workspace" | It means "unknown". Fall back to `GET /api/workspaces/` and ask. |
| Passing a chat attachment / local path as a product image | BE needs a public https URL. Register via `presigned_upload_url` (`filename`, lowercase) first. |
| One POST with several `outputFormats` for placements that each need their own look | Same `additionalInformations` for all → drifted look. One POST per art direction. |
| Firing `2K`/`4K` on the exploration pass | `resolution` re-prices the fire. Prove the direction cheap, re-fire the keeper at higher res; preview the exact resolution you'll fire. |
| Treating a declined preview or `sufficient: false` as an error to retry | It's a normal outcome — report the shortfall/decline in one line and stop. Don't re-fire, don't loop the preview, don't check a balance delta. |

## Red flags — stop and re-check

- About to `POST /brands/` for a domain that MATCHES an existing brand without explicit yes → STOP. Ask first.
- About to fire `generate/image_templates` or `generate/competitor_recreate` without first calling `preview_cost` and getting consent → STOP. Surface `tokenCost` + `currentBalance` and confirm `sufficient: true` first.
- About to fire `generate_*video*` without consulting [[coinis-video-from-url]] → STOP. Video gates are owned there.
- Treating the brand-creation gate as universal (always asking) → No domain match = silent create.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, and CLI flags stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` request/response transcripts). Lead with the rendered URL + a one-line summary — but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles; the async wait model needs them to re-poll and recover ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "polling the job", "calling `preview_cost`", "scheduling a wakeup", or name MCP tools; say "generating your creative…".
4. **One question at a time** — never batch-ask.
5. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait.

These set the defaults the "Surface the fire" step above builds on; don't restate them.

## Related skills

- [[coinis-marketplace-models]] — model-keyed `generate/marketplace_proxy`; named model, literal prompt, arbitrary reference images, identity lock across a series.
- [[coinis-video-from-url]] — video creative generation (UGC, V2V, avatar). Distinct spend rules; avatar is a content gate.
- [[coinis-polling]] — render-status polling, `aiResults[]` shape, `{"error":""}` recovery.
- [[coinis-batch-patterns]] — multi-product / multi-format fan-out and honest count math.
- [[coinis-competitor-recreate]] — competitor-ad-driven `generate/competitor_recreate` flow.

## Why this skill exists

The brand-target-choice gate has to be a hard step, not an optional courtesy — the CLI surface has no front-end approve block to fall back on, so the agent must enforce the gate itself. The same is true for the spend gate: the CLI has no front-end cost card, so the agent must call `preview_cost`, surface `tokenCost` + `currentBalance`, and get explicit consent (with `sufficient: true`) before firing. That gate is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`); this skill is the CLI-specific overlay that enforces it around the brand/product setup sequence.
