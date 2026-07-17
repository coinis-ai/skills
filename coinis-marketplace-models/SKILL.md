---
name: coinis-marketplace-models
description: |
  Use when the user explicitly asks for a marketplace generation model — names one (Seedream, Seedance, Veo, Gemini Image, GPT Image, Grok, Runway), asks which image or video models are available, asks for a quality/price tradeoff between them, needs the model prompt authored verbatim, needs arbitrary reference images pinned to a render, or needs one subject held identical across a series — the `generate/marketplace_proxy` family (image + video) on the Coinis MCP (`coinis`).
  NOT for: any generation request that does NOT name a marketplace model — use `generate_image_templates` ([[coinis-image-from-url]]), `generate_ugc_video` / `generate_cinematic_video` ([[coinis-video-from-url]]) instead; revising an existing creative (use [[coinis-revisions]]); render-status polling (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, mcp__coinis__generate_marketplace_proxy, mcp__coinis__call_api, ScheduleWakeup
argument-hint: <what to generate> [model] [aspect ratio] [reference image URL]
---

# coinis-marketplace-models

## Overview

`generate/marketplace_proxy` is the **only Coinis surface where the model is a request parameter**, and the only one where the string you write is the string the model sees. It serves **both modalities** — image and video — off one discriminated union keyed on `model`. `generate/image_templates` and the UGC/cinematic pipelines pick the provider server-side and compose the prompt from product data, so "which model?" is a question to ask **here and nowhere else**; asking it on the template path invents a knob the API doesn't have.

This is the surface practitioners reach for when the creative has to be art-directed rather than templated. It is paid, model-keyed, and its accepted params **follow from the model**, not from the family.

```
POST /api/workspaces/{wid}/generated_creatives/generate/marketplace_proxy/
body: {"model": "<model id>", "prompt": "<literal>", "images": ["https://…"], "params": {…}}
```

`images` is a **real JSON array**; `params` a **real nested object**. Flattening model settings to the top level — the shape other vendors use — 422s. The canonical bodies are owned by the playbooks: `load_skill('generate-marketplace-proxy-image')`, `load_skill('generate-marketplace-proxy-video')`, and `load_skill('creative-generation')` for the gate. Fire via the typed `generate_marketplace_proxy` tool or `call_api` — both are live.

> **OBSERVED-2026-07-08, may already be fixed — not a standing rule:** one client build JSON-stringified `images`/`params`, producing a 422 blaming the wrong field. If you see that, retry the same body through `call_api`. Do not pre-emptively avoid the typed tool.

## When to Use

- **The user explicitly names a marketplace model**, or asks what models exist / which to use.
- The user authored a specific scene, shot, or aesthetic and the wording must survive verbatim.
- A reference image that is **not** a workspace product must be pinned to the render.
- One product / person / set must stay identical across several renders.
- A hard param constraint falls outside the internal pipelines' contract.

## Routing — only on an explicit model ask

| Brief | Endpoint |
|---|---|
| Any image ask that does **not** name a marketplace model | `generate_image_templates` ([[coinis-image-from-url]]) |
| Any video ask that does **not** name a marketplace model | `generate_ugc_video` / `generate_cinematic_video` ([[coinis-video-from-url]]) |
| **User explicitly asks for a marketplace model** (image or video) | `generate/marketplace_proxy` — this skill; `prompt` is literal, **you** author it |

The playbook says it plainly: *"Only use this tool when the user explicitly asks for a marketplace model — for the normal from-scratch generator use `generate_image_templates`."* Route by **the explicit ask**, never by "which model is best". A param constraint outside one pipeline's contract means **switch pipelines, not negotiate the brief**.

## Catalogue — observed 2026-07-17, re-probe to confirm

The table below is **dated; the server is the authority**. Re-probe before quoting it back.

| Modality | `model` |
|---|---|
| Image | `seedream-5.0-lite`, `seedream-4.5`, `seedream-4.0` |
| Image | `gemini-2.5-flash-image`, `gemini-3.1-flash-image`, `gemini-3-pro-image` |
| Image | `gpt-image-2`, `grok-imagine-image-quality` |
| Video | `seedance-2.0`, `seedance-2.0-fast`, `seedance-1.5-pro`, `seedance-1.0-pro`, `seedance-1.0-pro-fast` |
| Video | `veo-3.1`, `veo-3.1-fast`, `grok-imagine-video`, `happy-horse`, `gen4.5`, `aleph-2` |

Listing is coverage, not recommendation. **When you name a model in an option, use the house models — Seedream for image, Seedance 2.0 or newer for video**; superseded tiers are not a default choice.

## Discovery — the 422 IS the live schema

There is no `list_models` endpoint; the allowed `model` enum lives in the endpoint's own pydantic validation. **The free schema source is the `preview_cost/` sibling.** POST it with a deliberately-invalid `model`; the discriminated union answers with every accepted model id in `detail[].ctx.expected`, each variant's numeric bounds in `detail[].ctx.le`, and each variant's required media in its `{"type": "missing"}` rows:

```
POST /api/workspaces/{wid}/generated_creatives/generate/marketplace_proxy/preview_cost/
body: {"model": "<deliberately-invalid>", "prompt": "test"}
→ 422, e.g. "Input should be <MarketplaceVideoModel.SEEDANCE_2_0: 'seedance-2.0'>"
         + {"loc": ["body","<VariantRequest>","images"], "msg": "Field required"}
```

**Probe `preview_cost/` ONLY — never `generate/`.** `preview_cost` bills nothing and its 422s cost nothing; a satisfying body on `generate/` **IS** the fire. Never let a paid call be the one that discovers the schema.

**`list_endpoints` returns `{method, path, summary, tags}` — paths, never body schemas — and can return empty for a family that is live** (observed contentless minutes before six `marketplace_proxy` renders landed). **An empty catalogue read is not evidence a capability is absent.**

Treat the 422 as authoritative in both directions — the always-current catalogue **and** a definitive "not supported". Don't retry the probe, don't guess model names.

**Constraints are per-model, not per-family.** **Choose the `model` and compose its `params` in ONE decision:** a model picked first and parametrised second returns a validation error that reads like a schema bug, and the agent starts rewriting the body instead of changing the model. Never carry an enum across families by analogy — the marketplace `params.aspectRatio` enum is not the UGC one.

**A clean `preview_cost` 200 prices the `model` — it does not validate the body.** Preview the price; discover the body from the validator. `preview_cost` **MUST carry the same `model`** as the real call — the discriminator changes the price.

## Image side — Seedream and siblings

Canonical body: `load_skill('generate-marketplace-proxy-image')`. What changes your next call:

- **Seedream `params`** — `aspectRatio`: `1:1` (default) / `9:16` / `16:9`; `sequentialImageGeneration`: `disabled` / `auto`; `maxImages`: int 1–15, **only meaningful with `sequentialImageGeneration: auto`**.
- **All three Seedream versions cost the same — flat.** The version is the **user's preference, NOT a cost trade-off**. If they don't name one, **ask**. Do not build a price matrix across Seedream tiers; there is nothing to trade off. (Cost-shopping candidates is **video** guidance.)
- **`images` — 0 to 10 reference URLs**, hard cap. Register attached uploads first, then pass the returned URLs.
- **Seedream image params have no `seed`.** Don't promise image reproducibility.
- Other image models, at a glance (probe for bounds): `gemini-2.5-flash-image` → `aspectRatio`, ≤3 refs. `gemini-3.1-flash-image` → `aspectRatio` + `imageSize` 512/1K/2K/4K + `thinkingLevel` minimal|high, ≤14 refs. `gemini-3-pro-image` → `aspectRatio` + `imageSize` 1K/2K/4K, ≤11 refs. `gpt-image-2` → `size`, `quality` low|medium|high, `n` 1–10, `outputFormat`, `background`, ≤16 refs. `grok-imagine-image-quality` → `aspectRatio` + `resolution` 1k|2k + `n` 1–10, ≤3 refs.

### `productId` auto-seeds the reference — first-choice identity lock

**When `productId` is set AND no explicit `images` are passed, the product's own catalog images seed the generation reference automatically** — so an ad meant to feature the product shows the **real** product, not an invented stand-in.

For a **workspace product, this is the first choice**: pass `productId`, pass no `images`, and the identity is locked without a chain and without an anchor render. Manual anchor-chaining (below) is for a **non-product subject** — a person, a set, a look — or an anchor you generated yourself. Passing explicit `images` alongside `productId` overrides the auto-seed: only do that deliberately.

## Video side — Seedance and siblings

Canonical body: `load_skill('generate-marketplace-proxy-video')`. What changes your next call:

- **Seedance `params`** — `aspectRatio`: `9:16` / `16:9` (default) / `1:1` / `4:3` / `3:4` / `21:9`; `resolution`: `480p` / `720p` (default) / `1080p` / `4K`; `duration` int seconds (default 5); `imageRole`: `first-frame` (default) / `first-last` / `reference`; plus `seed`, `watermark`, `cameraFixed`, `generateAudio` (bool, default false).
- **`images` by `imageRole`** — `first-frame`: 0 (text→video) or exactly 1; `first-last`: exactly 2, **mutually exclusive with `videoUrl`/`audioUrl`**; `reference`: 0..N.
- **`videoUrl` / `audioUrl` are TOP-LEVEL args, NOT inside `params` — never nest them.** `videoUrl` is **REQUIRED on `aleph-2`**; otherwise **Seedance 2.0 / 2.0-fast only**. `audioUrl` requires ≥1 image.

Per-model caps (observed 2026-07-17, re-probe to confirm):

| model | resolutions | duration | imageRole modes | media input |
|---|---|---|---|---|
| `seedance-2.0` | 480/720/1080/**4K** | 4–15 | first-frame, first-last, reference (≤9) | videoUrl / audioUrl |
| `seedance-2.0-fast` | 480/720 | 4–15 | first-frame, first-last, reference (≤9) | videoUrl / audioUrl |
| `seedance-1.5-pro` | 480/720/1080 | 4–12 | first-frame, first-last (≤2) | — |
| `seedance-1.0-pro` | 480/720/1080 | 2–12 | first-frame, first-last (≤2) | — |
| `seedance-1.0-pro-fast` | 480/720/1080 | 2–12 | first-frame only | — |

Others: `veo-3.1`/`veo-3.1-fast` → `durationSeconds` 4/6/8, `resolution` 720p/1080p, `aspectRatio` 16:9/9:16, `referenceMode`. `grok-imagine-video` → `duration` 1–15. `gen4.5` → `ratio`, `duration` 2–10. `aleph-2` → `ratio`, `videoUrl` required, ≤5 refs.

**"Animate this / from this image"**: resolve the prior creative id, read its `imageUrl` ([[coinis-polling]]), pass `images=[url]` with `imageRole=first-frame`, and carry its `productId`.

## Video model choice — preview every candidate, then let the user pick

**Cost varies sharply per video model** (unlike the flat Seedream tiers). `preview_cost` is **free, creates no record, and never bills**, and `tokenCost` is keyed on `model` + params, not prompt text — so price the whole candidate grid **during planning, before a real prompt exists**, using a byte-identical placeholder body per candidate (`{"model": "<candidate>", "prompt": "test", …}`).

Surface the matrix as ONE question with a **craft-justified** recommendation:

> "Three 5 s vertical clips, 9:16. Seedance 2.0 at 1080p — &lt;tokenCost&gt; total: highest fidelity, and the only tier that can go to 4K if you want a master later. Seedance 2.0 Fast — &lt;tokenCost&gt; total: same 4–15 s range and reference support, but caps at 720p. Which?"

Quote whatever `preview_cost` returned — never a figure from memory. **Never silently default to the cheapest, and never assume pricier is better.** Spend up on hero assets, down on filler. Equal `tokenCost` across a resolution step → take the higher resolution. Flag video as expensive up front.

Choose by three ordered checks, never by name recognition:

1. **Does it accept `images[]`, and in which `imageRole`?** Only a model that takes a reference can identity-lock a subject across a set.
2. **What does `preview_cost` actually return for that `model`?** Read `tokenCost` per candidate at call time.
3. **Does it hold an "exact same scene as the reference" instruction?** Required whenever one subject must persist.

A model tier change **re-opens the spend gate** — re-preview and re-ask; the quote the user approved was for a different body.

**There is no audio or music model in the union** — an audio probe matches nothing. A brief asking for a music bed or voiceover cannot be served by any Coinis call. Say so in one line. Never substitute a video model for a music request: the render bills either way and the user discovers the silence after paying.

## Prompt craft

**There is no negative-prompt field.** Avoid-intent must be written as **positive** scene wording — an affirmative end-state, never "avoid X". ("No software UI shown" belongs in the positive prose; the model has no exclusion channel.)

### Never let a generation model render letterforms

**Never ask a model to render on-screen text, a wordmark, a logo, or an outro.** It invents and misspells them. Observed shipping from the platform: `"A WHOLE CAMPAIN!"`, `"TO CONIS AI."`, and a fabricated `"Ⓒ Conis"` end-card the prompt never asked for.

Prompt for the **visual only**. Split every brief into:

- **SHOT** — camera, motion, framing, grading, subject → goes into `prompt`.
- **SCREEN** — the literal on-screen copy → **never** goes into `prompt`.

If the brief doesn't label them, do the split yourself and read the SCREEN copy back for confirmation. This defect is **invisible to the wait loop** — burned-in-text errors still return `actionStatus: success` with a populated URL, so [[coinis-polling]] cannot catch it. And **no `revise/*` endpoint repairs baked-in text**: the only fix is another paid render.

If the user wants burned-in copy, say the model cannot be trusted with letterforms, and either reserve the region or tell them up front that on-screen text will be decorative. Same rule for logos — brand-exact wordmarks and hex are unreachable by the generator.

**Reserve the compositing region** when copy or a logo will be overlaid downstream: ask the prompt for clean negative space where the text will land, rather than asking for the text.

## Identity lock — the reference is the invariant, the prompt is the variable

When a brief states an invariant and varies only production, **prompt wording alone does not hold identity**: N independent text-only fires return N different-looking subjects, each render individually fine and the set unusable — and it already billed.

**A `seed` does not solve this.** Seedance video params *do* expose `seed`, but a seed repeats a **sample** — same body, same output. It does **not** carry a subject's identity across a *different* scene, and the Seedream image params have no seed at all. **The reference image is what binds identity.**

**Order of preference:** workspace product → `productId` with no `images` (auto-seed, above). Non-product subject → anchor-chaining, below.

**Bind the reference explicitly.** Passing `images[]` alone does not tell the model the reference is authoritative for object identity — it reads it as style inspiration and invents a plausible-but-wrong subject. Name the subject inside `prompt` as:

> `the exact <material/colour> <BRAND IN CAPS> <product noun> from the reference image`

inline in the clause where the subject acts — never a bare noun, never a trailing note. The literal token `exact` plus the pointer `from the reference image` is what binds them. A wrong-subject ad renders beautifully, is worthless, and survives review because nothing looks broken.

### Output→reference chaining — for a non-product subject

To render N creatives sharing one actor / set / look you generated:

1. Fire **ONE anchor**.
2. Poll it to `actionStatus: success` ([[coinis-polling]]) and read its rendered URL.
3. Fan out with **that one URL** in every sibling's `images[]`.

**This is serial, not parallel** — a fan-out started off a `processing` anchor has no URL to reference yet. Order the batch by the dependency graph, not the asset list ([[coinis-batch-patterns]]).

Each chained sibling's `prompt` takes the **lock / delta / lock** shape:

> `Exact same scene as the reference image: the same <invariant>, same <invariant>, same <invariant>. Only <one axis> changes: <delta>. Everything else identical to the reference.`

Repeat the literal word `same` before each invariant noun phrase, change exactly **ONE** axis per sibling, and always close with the catch-all lock. Re-describing the scene fresh invites the model to re-sample it: axes you didn't name (lighting, background, wardrobe) drift silently, and drift is only visible after the render is paid for.

**Verify a reference URL resolves before spending on it.** A reference is an input to a paid call; a stale or 404 URL burns the fire. Check it returns 200 with non-zero bytes first — especially when reusing a URL harvested from an earlier session.

## Reference assets — public https only

The BE fetches references over the network: **public `https` URLs only**. It cannot read a local path, a CLI chat attachment, or base64. A local file must be registered/hosted first:

```
POST /api/workspaces/{wid}/generated_creatives/presigned_upload_url/
body: {"filename": "...", "contentType": "..."}     ← lowercase `filename`; `fileName` 422s
→ PUT the bytes to the returned URL → use the returned public URL in `images[]`
```

The presigned URL is short-lived — upload promptly rather than composing the whole batch first.

## Cost gate

`marketplace_proxy` is a paid `generate/*`: POST the sibling `.../marketplace_proxy/preview_cost/`, surface `tokenCost` + `currentBalance`, and fire only on explicit consent AND `sufficient: true`. **Preview the model you are actually about to fire** — the `model` discriminator sets the price, so a quote from a sibling is not a quote. The body you preview MUST equal the body you fire, including every cost-affecting param. Gate mechanics are owned by `load_skill('creative-generation')`; never hardcode a token figure here.

On video, the quoted `tokenCost` is a **reservation upper bound**, not the charge — report settled spend from the creative record, never the quote ([[coinis-polling]]).

## Polling

Owned by [[coinis-polling]]. Match the cadence to the output type: image output ≈ the `image_templates` class (first poll 60 s); video output ≈ the video class (first poll 180 s, `ScheduleWakeup`).

`actionStatus: success` means it rendered — **not** that it's correct. Open the asset before quoting it.

## Common mistakes

| Mistake | Reality |
|---|---|
| Reaching here for a generation the user didn't tie to a named model | Marketplace is for an **explicit** model ask. Otherwise `generate_image_templates` / `generate_ugc_video` / `generate_cinematic_video`. |
| Reciting the catalogue table as current | It's dated. Probe `preview_cost/` with an invalid `model` and read the enum out of the 422. |
| Probing a bogus `model` against `generate/` | That's the fire. Probe `preview_cost/` only. |
| Reading an empty `list_endpoints(filter=…)` as "the family doesn't exist" | Observed contentless for a live family. Not evidence of absence. |
| Price-shopping Seedream 4.0 vs 4.5 vs 5.0-lite | They're **flat-cost**. The version is preference — ask which; don't build a matrix. |
| Skipping the price matrix on video | Video cost varies sharply per model. Preview every candidate — previews are free. |
| Passing `images` alongside `productId` "to be safe" | `productId` + no `images` auto-seeds the product's own catalog images. Explicit `images` override that. |
| Passing more than 10 reference images | Image `images` caps at 0–10. |
| Nesting `videoUrl` inside `params` | Top-level arg. Never nest. Required on `aleph-2`; else Seedance 2.0 / 2.0-fast only. |
| Flattening `params` to the top level | 422. `params` is a nested object; `images` is a real array. |
| Picking the model, then composing `params` | Constraints are per-model. Choose model + params in one decision. |
| Reaching for `seed` to hold a subject across scenes | A seed repeats a sample, not an identity — and Seedream has none. Bind identity with the reference. |
| Carrying the UGC `aspectRatio` enum onto marketplace | Different family, different bounds. Read them off the validator. |
| Asking a model for a wordmark, caption, or outro | It invents and misspells them (`"A WHOLE CAMPAIN!"`, `"Ⓒ Conis"`). Prompt the visual; composite copy outside the model. |
| Writing "avoid X" in the prompt | No negative-prompt field exists. Write the positive end-state. |
| Passing `images[]` without naming it in the prompt | Read as style inspiration. Say "the exact … from the reference image". |
| Fanning out before the anchor reaches `success` | No `imageUrl` exists yet to reference. The chain is serial. |
| Passing a local path or base64 as a reference | Public https only. Host it via `presigned_upload_url` (`filename`, lowercase). |
| Proposing a model for a music/voiceover request | No audio member exists in the union. Say so; don't 422 on the user's credits. |
| Reporting the video quote as spend | The quote is a reservation upper bound. Settled cost lives on the record. |

## Red flags — stop and re-check

- About to send a bogus/probe value to `generate/*` instead of `preview_cost/` → STOP. That call bills.
- About to name a model id from the table without a live probe → STOP. The table is dated; the catalogue is the server's.
- About to fire a **video** without previewing the other viable candidates → STOP. Previews are free; the choice is the user's.
- About to pick a Seedream version for the user → STOP. Flat cost, so it's their preference. Ask.
- About to chain an anchor for a workspace product → STOP. `productId` with no `images` already locks it.
- About to ask any generation model for a logo, wordmark, or exact copy string → STOP. Prompt the visual; composite the copy.
- About to fan out an identity-locked set in parallel → STOP. Anchor first, then chain its URL.
- About to change the model after consent → STOP. Re-preview and re-ask; the gate was for a different body.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, model ids, and CLI flags stay English. Compose `prompt` itself in **English**, and ship any user-authored copy string verbatim in the language they typed it.
2. **No raw JSON dumps** (no 422 bodies, no `call_api` transcripts). Translate a probe result into one plain line — but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "probing preview_cost", "reading the 422", or name MCP tools; say "checking what's available…".
4. **One question at a time** — with one carve-out: the video model/price matrix is a single question, so present the candidates together rather than serially.
5. **Show the literal `prompt` alongside the cost at the gate** — a prompt the user cannot see is a prompt she cannot correct, and the re-fire costs another render.
6. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait.

## Related skills

- [[coinis-image-from-url]] — template-driven image generation; brand/product setup; where a non-model image ask goes.
- [[coinis-video-from-url]] — URL-driven UGC and the internal video pipelines; where a non-model video ask goes.
- [[coinis-batch-patterns]] — fan-out shapes, the serial-chaining wave order, and batch cost projection.
- [[coinis-polling]] — render polling, settled-spend reporting, and the inspect-before-quoting rule.
- [[coinis-revisions]] — iterating on a creative that already rendered.

## Why this skill exists

The marketplace family is where the practitioners do their best work, and it spans **both** modalities — an agent that knew only the video half reached for `image_templates` on a Seedream ask, or 422'd on a body it guessed. Four facts make this surface different from every other Coinis one and are worth pinning once: the **model is a request parameter** (so the catalogue is the server's to state via a free 422 probe, and the table here is dated); the **prompt is literal** (so authorship, and the letterform ban, are the agent's responsibility); **cost behaves differently per modality** (Seedream flat, video sharply variable); and **identity rides on the reference, not a seed** — `productId` auto-seeding for a workspace product, a chained anchor URL for anything else. Everything else — the canonical bodies, the full per-model params, the costs — belongs to `load_skill('generate-marketplace-proxy-image')` / `load_skill('generate-marketplace-proxy-video')` and is deliberately not duplicated here.
