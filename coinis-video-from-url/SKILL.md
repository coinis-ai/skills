---
name: coinis-video-from-url
description: |
  Use when creating a video creative (UGC URL-mode, UGC image-mode / stills-to-video, video-to-video, cinematic, avatar, or talking-head) via the Coinis MCP (`coinis`). Covers the URL-driven UGC pipeline whose accepted fields differ sharply from image generation, the brand-target rule (silent create on unknown domain), the per-render credit cost (call `preview_cost` for the figure), and the longer async render times.
  NOT for: image creatives (use [[coinis-image-from-url]]); revising an existing creative via the `revise_*` family (no URL, different flow); polling cadence mechanics (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_skills, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, mcp__coinis__list_avatars, mcp__coinis__get_avatar, mcp__coinis__generate_ugc_video, mcp__coinis__generate_cinematic_video, mcp__coinis__generate_talking_head_video, mcp__coinis__call_api, ScheduleWakeup
argument-hint: <product-page-url> [aspect-ratio 9:16|16:9] [ugc|video-to-video|avatar|talking-head]
---

# coinis-video-from-url

## Overview

The Coinis MCP exposes several video generators. They differ in input shape, cost, and what gets persisted server-side. The biggest trap: the body schema is NOT a copy of `generate_image_templates` with one extra field — the URL-driven UGC tool ignores most product/script knobs and runs straight off the URL + aspect ratio. Sending tone/script/language/quantity gets you a silent 200, not a 422. (UGC also has an image mode that animates uploaded stills — see "UGC image mode" below.)

**Standing rules:**

| Layer | Rule |
|---|---|
| New brand from unknown domain | Silently create. No ask. |
| New brand from matching domain | Ask: use existing vs create parallel. |
| Video credit spend (UGC, video-to-video) | Surface the `preview_cost` figure (`tokenCost` + `currentBalance`), proceed only on explicit consent AND `sufficient: true`. The in-MCP `creative-generation` playbook owns the gate; `load_skill('creative-generation')`. |
| Avatar video / talking-head | Script the avatar speaks is user-authored content — **still ask** for the script before firing. Authorship, separate from the spend gate. |
| Motion direction (video-to-video) | Ask once for direction if not provided, then run the spend gate. Surface plan with result. |

**The spend gate is owned by the in-MCP `creative-generation` playbook** — before any paid `generate/*` or `revise/*` call, POST the sibling `…/preview_cost/` endpoint and surface `tokenCost` + `currentBalance`; proceed only on explicit consent AND `sufficient: true`. Same gate as [[coinis-image-from-url]]. Don't hardcode token numbers — read them from `preview_cost`.

**Avatar/talking-head ask remains** because the user MUST hand the agent the words the avatar speaks — there is no sensible default for spoken script. That's a content gate, separate from the spend gate.

**Avatar endpoints additionally require an `avatarId`, and it IS discoverable — via the dedicated `list_avatars` / `get_avatar` tools** (and `GET /api/workspaces/{wid}/avatars/`), not via `list_endpoints`. `list_avatars(workspace_id=…)` returns the workspace's stock + custom avatars, each with an `id` to pass as `avatarId`. (An earlier version of this skill claimed avatars were uncallable from the CLI — that was looking in `list_endpoints`; the avatar registry has its own tool.) When the user wants a specific avatar, `list_avatars` first and let them pick; don't ask them to supply a raw id.

## When to Use

- User asks for "a video", "UGC video", "stills-to-video", "video-to-video", "cinematic video", "avatar video", "talking head" via the Coinis MCP.
- User pastes a brand or product URL and asks for a video.
- A scheduled task is generating video creatives.

**Don't use:** For images — that's [`coinis-image-from-url`](../coinis-image-from-url/SKILL.md). For revising an existing creative (`revise_*` family) — different flow, no URL.

## The video endpoints — at a glance

| Tool | Endpoint | Primary input | Cost | Notes |
|---|---|---|---|---|
| `generate_ugc_video` (URL mode) | `/generated_creatives/generate/ugc_video/` | **`url`** = HTML product page URL; `aspectRatio` = **`'9:16'` or `'16:9'` ONLY** (no 1:1, no 4:5) | Per-render — run `preview_cost` before firing. | URL-driven. Many fields silently dropped; `{"error": ""}` is NOT credit-safe. See failure-mode note below. |
| `generate_ugc_video` (image mode) | `/generated_creatives/generate/ugc_video/` | uploaded still(s); `aspectRatio` = `'9:16'` or `'16:9'` | Per-render — run `preview_cost` before firing. | UGC supports an image mode that animates uploaded stills. See "UGC image mode" below; defer body shape to `creative-generation`. |
| `generate_video_to_video` | `/generated_creatives/generate/video_to_video/` | source video, prompt | Per-render — run `preview_cost` before firing. | Style transfer / re-animation. |
| `generate_cinematic_video` | `/generated_creatives/generate/cinematic_video/` | see `creative-generation` | Per-render — run `preview_cost` before firing. | Cinematic V1 — seven fixed-duration flows (cinematic 10/15/20/30, product-shot 15, product-doc 15, product-spec 10). Has its own in-MCP skill `generate-cinematic-video`; don't invent the body shape. |
| `generate_avatar_talking_head` (avatar video / talking-head) | `/generated_creatives/avatar/talking_head/` | `productId`, `prompt` (REQUIRED — the spoken script) | Per-render — run `preview_cost` before firing. | `prompt` IS the script. Never invent it; ask the user. Talking-head adds provider-specific avatar/voice params. |

**For a named/chosen video model, an authored prompt, or pinning an arbitrary public image URL as the literal first frame — that's `generate/marketplace_proxy` ([[coinis-marketplace-models]]), not the pipelines above.** The pipelines here pick the provider server-side; `marketplace_proxy` is the only video surface where the model and the literal prompt are yours. Pinning a first frame there is `images` + `imageRole: "first-frame"` with no upload round-trip.

**A hard param constraint re-shops the pipeline — it does not round the user up.** Each pipeline has a fixed contract: the cinematic V1 pipeline ships seven flows with fixed durations (cinematic 10 / 15 / 20 / 30 s, product-shot 15 s, product-doc 15 s, product-spec 10 s — defer the current set to `load_skill('generate-cinematic-video')`), so a "5 s clip" request falls outside all of them and cannot be served by rounding up to the nearest — pivot to `marketplace_proxy` (which does short arbitrary durations) and reload that playbook. When a duration/aspect/param falls outside one family's contract, **switch families, don't negotiate the brief**.

**The `…/preview_cost/` route is not always a sibling of the fire path.** `generate/cinematic_video/preview_cost/` 404s ("not in the OpenAPI catalogue"); the working preview for that pipeline is `generate/v1/tvc/submit/preview_cost/`. A "not in the catalogue" error is a **route-discovery trigger** (`list_endpoints(filter="preview_cost")`), not proof the capability is gone. Never assume `<fire_path>/preview_cost/` exists — confirm it.

**No music or audio model exists on this MCP.** A brief asking for a music bed or voiceover track is a capability boundary, not a retryable failure — say so and let the user plan audio outside the platform. Never substitute a video model for a music request.

**`generate_ugc_video` failure-mode notes** (pulled out of the table above so the cells stay terse):

- **Silently-dropped fields (URL mode).** `productId` / `script` / `tone` / `language` / `quantity` / `videoProvider` are all dropped. BE picks the video provider; any user-supplied value is ignored. Sending them creates a false sense the agent steered the output.
- **URL mode vs image mode.** In URL mode, passing a direct image URL (jpg/png/webp) FAILS at the scrape stage with `500: The URL returned a file type that <scraper> cannot process: image/jpeg` — the BE scraper accepts HTML pages, PDFs, and common document formats only. To animate a still, use UGC **image mode** (upload the still) — see "UGC image mode" below.
- **`{"error": ""}` is NOT credit-safe** (distinct from 422 and 500). May or may not create a record + bill credits — observed both shapes. Confirmed 2026-05-27: sending `productId`+`brandId` alongside `url` returned `{"error": ""}` AND created a successful render that billed full cost (the response serializer fails on the early-stage record, but the BE has already created it, reserved tokens, and dispatched the provider call).
- **Verify post-hoc, not by balance.** List `/generated_creatives/` and sort by `id` desc — not by `createdAt` and not by reading the balance field, both of which mislead (see "Common mistakes" and [[coinis-polling]]).

## Pre-flight

Load both skills at the start so you have the cross-cutting rules in context:

```python
mcp__coinis__load_skill(name="creative-generation")
mcp__coinis__load_skill(name="brand-product-setup")
```

The `creative-generation` skill owns the spend gate: before any paid `generate/*` or `revise/*` call, POST the sibling `…/preview_cost/` endpoint → `{tokenCost, breakdown, currentBalance, sufficient}`, surface `tokenCost` + `currentBalance`, and proceed only on explicit consent AND `sufficient: true`. (`revise/ad_copy` is the only zero-cost exception.) Also load-bearing from `creative-generation`: the avatar-script-is-mandatory rule (content authorship, separate from spend), and the "never bundle `generate_*` + `revise_*`" sequencing rule.

## UGC pre-flight — verify the URL has product imagery FIRST

**Critical:** UGC's first internal stage is `discovery` — it scrapes the URL for product images and renders the video FROM those images. If the page only has logos, hero graphics, abstract illustrations, or screenshots, discovery fails with `"No usable product images on the page"` and the creative goes to `actionStatus: failed`.

**Refund behaviour (observed; treat as best-effort):** balance was unchanged after a discovery-stage failure, suggesting the credits were refunded. Do NOT promise the user a refund — verify post-hoc by checking the balance delta.

**Pre-flight check — before firing UGC:**

1. If the URL is a known **product page** (e.g. an e-commerce SKU page with `<img>` tags showing the product) — proceed. Most retailer product pages work.
2. If the URL is a **brand homepage / SaaS landing page** — DO NOT use UGC URL mode. The page likely has logos and hero illustrations, not product photography. Surface to the user: "This homepage doesn't have product photos UGC URL mode can use. Three alternatives: (a) paste a specific product/feature page URL, (b) an avatar / talking-head video (`avatar/talking_head/`) with a script you provide, (c) UGC **image mode** from an existing still."
3. If you can `analyze_product(url=...)` and the returned `imageUrls[]` array has at least 2 entries that look like JPG/PNG/WEBP product shots — UGC will likely succeed. If it returns `imageUrls: []` or only logos/icons — UGC will fail.

The cheapest pre-flight is `analyze_product` — it's free, fast (sync), and tells you whether the page has scrapeable product imagery.

## UGC video flow (the most common path)

### 1. Resolve workspace

`list_my_workspaces` → pick the highest-balance workspace. UGC video has a non-trivial per-render cost — run `preview_cost` for the figure before firing.

### 2. Brand-target (per standing rule)

`GET /api/workspaces/{wid}/brands/` and compare URL eTLD+1 to each brand's `website`:

- **No domain match** → silently create brand from `analyze_brand_identity` data (full identity: name, vertical, colors, voice, language, logo, description).
- **Domain match** → one-line ask: "Use `#X <Brand>` or create parallel?"

This is the same gate as [`coinis-image-from-url`](../coinis-image-from-url/SKILL.md) step 3.

### 3. Product — OPTIONAL for UGC

UGC URL mode's `generate_ugc_video` does NOT use `productId` — the BE drops it. **Don't create a placeholder product just for UGC URL mode.** If the user also wants images later, then create the product (it's needed for `generate_image_templates`). Otherwise skip.

For the avatar / talking-head endpoint (`avatar/talking_head/`) — yes, product is required, follow the brand-product-setup flow.

### 4. Preview cost, get consent, then fire

POST the sibling `…/generate/ugc_video/preview_cost/` endpoint with the composed body → `{tokenCost, breakdown, currentBalance, sufficient}`. Surface `tokenCost` + `currentBalance`; fire `generate_ugc_video` only on explicit consent AND `sufficient: true`. The gate is owned by the in-MCP `creative-generation` playbook.

**Composition rules (apply, run `preview_cost`, then fire):**

- `url`: an **HTML product page** URL. Direct image URLs (jpg/png/webp) FAIL in URL mode — the BE scraper rejects binary content types. If the user only has an image (a local file or a CDN asset), use UGC **image mode** instead (upload the still — see "UGC image mode" under "Other video tools").
- `aspectRatio`: default `9:16`. Valid: `9:16`, `16:9`. (No 1:1, no 4:5 — would 422.)
- Send ONLY `url` + `aspectRatio`. **Critical: `productId` and `brandId` are NOT silently dropped — sending them breaks the BE's `discover_from_url` step and returns `{"error": ""}` while still creating a record and billing credits (verified 2026-05-27). Let the BE auto-discover/upsert product+brand from the URL.** Other fields (`script` / `tone` / `language` / `quantity` / `videoProvider`) are silently dropped — sending them creates a false sense the agent steered the output.

```
POST /api/workspaces/{wid}/generated_creatives/generate/ugc_video/
body: {
  "url": "https://...",
  "aspectRatio": "9:16"
}
```

Capture `id` (creative id) and `jobId` (trace handle). The figure to quote is the `tokenCost` from the `preview_cost` call you ran before firing — never a balance delta.

### 5. Surface the fire — single message, plan + result combined

Right after the POST, write ONE turn that bundles:

- The plan that was fired (workspace, `currentBalance` from `preview_cost`, `url`, `aspectRatio`, brand, `tokenCost`, render ETA ~2–5 min). Note the quote is a **reservation upper bound** on video — settled spend comes off the creative record later ([[coinis-polling]]), so don't present the quote as the final cost.
- The returned creative `id` and `jobId`.
- **Be honest about what a re-fire can steer.** UGC URL mode is URL-driven — a re-fire is a fresh stochastic **re-roll off the same `url` + `aspectRatio`**, not a redirect. Those two are the only levers you actually control; don't invite "say what to change" as if scene/tone/script were tunable here (the BE drops those fields). If the user wants real art direction over a video, that's `marketplace_proxy` ([[coinis-marketplace-models]]) or a different product page URL.

The cost was surfaced and consented before the POST (via `preview_cost`); this turn confirms what was fired and hands back the ids.

### 6. Poll for completion

UGC renders take longer than images. Cadence and `ScheduleWakeup` integration are owned by [[coinis-polling]]. Short version: first poll at 180 s; observed renders up to ~9 min on 2026-05-28 (creative `#3646`) — past the original 2–5 min envelope. Don't give up before ~10 min unless `actionStatus: failed`.

```
GET /api/workspaces/{wid}/generated_creatives/{creative_id}/
```

Watch `actionStatus`: `processing` → `success` (then `videoUrl` is populated) or `failed` (then `errorMessage`).

Rendered assets land on the workspace's configured CDN; the GET response is authoritative for the final URL.

### 7. Final surface (after render completes)

One short line: `"UGC video #<id> ready: <videoUrl>"`. No menu.

## Other video tools — quick deltas

### UGC image mode — animating uploaded stills (supported)

`generate_ugc_video` has an **image mode** alongside its URL mode: it animates uploaded stills directly. The in-MCP `creative-generation` skill confirms this — there is NO need to publish the still on a public HTML page first.

- **URL mode vs image mode.** URL mode runs off an HTML product page and the BE scraper rejects a direct image URL (`500: ... file type that <scraper> cannot process: image/jpeg`). That rejection applies only to URL mode. To animate a still, use **image mode** (supply the uploaded still) — don't route a raw image URL through URL mode.
- `generate_video_to_video` requires a source VIDEO, not a still — distinct from UGC image mode.
- The avatar / talking-head endpoint (`avatar/talking_head/`) synthesises a talking person, not motion on the user's image.

**If the user has a still and wants a video,** the primary route is UGC **image mode** — load `creative-generation` for the exact body shape, then run `preview_cost` and gate the spend as usual. Don't tell the user stills-to-video is unsupported; it is.

### Avatar video / talking-head (`generate_avatar_talking_head`)

- Both the avatar-video and talking-head intents fire against `…/generated_creatives/avatar/talking_head/`.
- Required: `productId` + `prompt` (the SCRIPT the avatar speaks, verbatim).
- **Never invent the script.** Ask explicitly: "What should the avatar say?" The avatar speaks the prompt as-is.
- Once the user supplies the script, run `preview_cost`, surface `tokenCost` + `currentBalance`, and fire on consent. (The script ask is the content gate; the spend gate is separate.)
- Talking-head uses provider-specific avatar/voice selection params.

### `generate_video_to_video`

- Style transfer on an existing video. Source video + prompt.
- Ask once for the motion / style direction if not given, then run `preview_cost`, surface `tokenCost` + `currentBalance`, and fire on consent.

### `generate_cinematic_video`

- Real premium cinematic endpoint — seven fixed-duration V1 flows (cinematic 10/15/20/30, product-shot 15, product-doc 15, product-spec 10). Has its own in-MCP skill — `load_skill('generate-cinematic-video')` for the body shape; don't invent it here.
- Same spend gate: `preview_cost` → surface `tokenCost` + `currentBalance` → fire on consent.

## Quick reference — endpoints

| Op | Method | Path |
|---|---|---|
| Analyze brand (sync) | POST | `/api/onboarding/brand_intel/analyze_brand/` |
| List brands | GET | `/api/workspaces/{wid}/brands/` |
| Create brand | POST | `/api/workspaces/{wid}/brands/` |
| UGC video (URL + image mode) | POST | `/api/workspaces/{wid}/generated_creatives/generate/ugc_video/` |
| Video-to-video | POST | `/api/workspaces/{wid}/generated_creatives/generate/video_to_video/` |
| Cinematic video | POST | `/api/workspaces/{wid}/generated_creatives/generate/cinematic_video/` |
| Avatar video / talking-head | POST | `/api/workspaces/{wid}/generated_creatives/avatar/talking_head/` |
| Preview cost (usually a sibling of the paid generate/revise — confirm; cinematic's lives at `generate/v1/tvc/submit/preview_cost/`) | POST | `/api/workspaces/{wid}/generated_creatives/generate/<endpoint>/preview_cost/` |
| Read creative | GET | `/api/workspaces/{wid}/generated_creatives/{cid}/` |

## Common mistakes

| Mistake | Reality |
|---|---|
| Skipping the `preview_cost` call before firing | Don't. The `creative-generation` playbook owns the spend gate: POST `…/preview_cost/`, surface `tokenCost` + `currentBalance`, fire only on consent AND `sufficient: true`. |
| Routing a direct image URL (jpg/png/webp) through UGC **URL mode** to "animate the image" | URL mode FAILS with `500: file type that <scraper> cannot process: image/jpeg`. To animate a still, use UGC **image mode** (upload the still) — it IS supported. See "UGC image mode". |
| Telling the user stills-to-video is unsupported | Wrong. UGC has an **image mode** that animates uploaded stills. Load `creative-generation` for the body shape. |
| Treating a probe-with-real-fields as "not really firing" | If you POST a body that satisfies validation to `generate_ugc_video`, it FIRES (real cost, real creative record). Use `preview_cost` to learn the figure without firing; a body missing required fields returns 422 without burning credits. Once you know the required fields, the next POST IS the fire. |
| Treating `{"error": ""}` as credit-safe | NOT safe. Observed billing full cost while returning empty error — the BE creates the record + reserves tokens BEFORE the response serializer runs. Verify with a `GET /generated_creatives/` sorted by `id` desc, not by the balance field. |
| Verifying spend by reading the balance field immediately after a fire | Balance lags reservations on some workspaces and reflects settled spend only. Use the `tokenCost` from `preview_cost`, not balance deltas. |
| Sorting `GET /generated_creatives/` by `createdAt` desc to find "the latest" | Default sort is unreliable when multiple creatives share `createdAt` (bulk image fans-out write the same timestamp). Sort by `id` desc instead — ids are monotonic. |
| Creating a placeholder product just for UGC URL mode | UGC URL mode drops `productId`. Skip the product step unless the user also wants images. |
| Sending `script` / `tone` / `language` / `quantity` to `generate_ugc_video` URL mode and expecting them honored | The BE silently drops them. URL mode is URL-driven. If the user wants a specific spoken script, use the avatar / talking-head endpoint (`avatar/talking_head/`) instead, which uses the `prompt` as the spoken script. |
| Firing UGC URL mode on a brand homepage / SaaS landing page | URL mode's discovery stage scrapes for product images; brand homepages typically only have logos/hero graphics → `"No usable product images on the page"` failure. Pre-flight with `analyze_product` first. |
| Inventing the `prompt` for the avatar / talking-head endpoint | The prompt is the spoken script. Avatar will say whatever you wrote. Always ask the user — content authorship, separate from the spend gate. |
| Hard-coding a UGC cost from memory | Don't. Read `tokenCost` from the `preview_cost` call for this fire — costs can shift. |
| Polling at 60s like image generation | Videos render slower than images — observed up to ~9 min. Schedule a wakeup at 180s minimum. |
| Treating a declined preview or `sufficient: false` as an error to retry | It's a normal outcome — report the shortfall/decline in one line and stop. Don't re-fire, don't loop the preview, don't check a balance delta. |

## Red flags — stop and re-check

- About to fire `generate_avatar_talking_head` (avatar / talking-head, `avatar/talking_head/`) without an explicit script from the user → STOP. Ask: "What should the avatar say?" (Content gate, separate from the spend gate — still required.)
- About to fire any paid `generate/*` without having run `preview_cost` and surfaced `tokenCost` + `currentBalance` → STOP. Run the gate first.
- Polling more often than every 60s → wasteful; bump the interval.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, and CLI flags stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` request/response transcripts). Lead with the rendered URL + a one-line summary — but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles; the async wait model needs them to re-poll and recover ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "polling the job", "calling `preview_cost`", "scheduling a wakeup", or name MCP tools; say "generating your creative…".
4. **One question at a time** — never batch-ask. (The avatar-script ask stays its own turn.)
5. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait.

These set the defaults the "Surface the fire" step above builds on; don't restate them.

## Related skills

- [[coinis-marketplace-models]] — model-keyed `generate/marketplace_proxy` video: named model, authored prompt, first-frame pinning, identity lock. Where a param-constraint pivot sends you.
- [[coinis-image-from-url]] — image creative generation; brand-target-decision rule.
- [[coinis-polling]] — render-status polling, settled-spend-from-record, and `ScheduleWakeup` cadences per video type.
- [[coinis-batch-patterns]] — multi-product video fan-out.
- In-MCP `creative-generation` (`load_skill('creative-generation')`) — owns the `preview_cost` spend gate and the `generate/*` + `revise/*` body shapes (including UGC image mode).
- In-MCP `generate-cinematic-video` (`load_skill('generate-cinematic-video')`) — body shape for `generate/cinematic_video`.

## Why this skill exists

The UGC URL-mode body shape is sharply different from `generate_image_templates`, and the BE silently drops the fields that don't belong — sending `script` / `tone` / `language` / `quantity` returns a 200 but ignores those values. That trap, plus the URL-mode-vs-image-mode split (URL mode rejects raw images; image mode animates uploaded stills), plus the discovery-stage refund behaviour, plus the avatar registry living in `list_avatars` (not `list_endpoints`), plus the fact that a re-fire re-rolls rather than steers, are all worth capturing once instead of re-discovering them by burning videos.

The spend gate is the in-MCP `creative-generation` playbook's `preview_cost` model — surface `tokenCost` + `currentBalance` and fire only on consent AND `sufficient: true`; the avatar script ask is preserved as a separate content gate because the spoken words are authorial content, not a cost decision.
