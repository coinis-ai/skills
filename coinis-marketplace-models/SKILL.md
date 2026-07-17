---
name: coinis-marketplace-models
description: |
  Use when a creative request names a generation model, asks which models are available, asks for a quality/price tradeoff between models, needs the model prompt authored verbatim, needs arbitrary reference images pinned to a render, or needs one subject held identical across a series — the `generate/marketplace_proxy` family on the Coinis MCP (`coinis`).
  NOT for: template-driven image creatives from a product + scene direction (use [[coinis-image-from-url]]); URL-driven UGC video (use [[coinis-video-from-url]]); revising an existing creative (use [[coinis-revisions]]); render-status polling (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, mcp__coinis__list_my_workspaces, mcp__coinis__call_api, ScheduleWakeup
argument-hint: <what to generate> [model] [aspect ratio] [reference image URL]
---

# coinis-marketplace-models

## Overview

`generate/marketplace_proxy` is the **only Coinis surface where the model is a request parameter**, and the only one where the string you write is the string the model sees. `generate/image_templates` and the UGC/V1 pipelines pick the provider server-side and compose the prompt from product data — so "which model?" is a question to ask **here and nowhere else**; asking it on the template path invents a knob the API doesn't have.

This is the surface practitioners reach for when the creative has to be art-directed rather than templated. It is paid, model-keyed, and its accepted params **follow from the model**, not from the family.

**Fire it through `call_api`, not the typed tool.** The typed `generate_marketplace_proxy` MCP tool JSON-stringifies `images` and `params` before sending, producing a 422 that blames the wrong field:

```
POST /api/workspaces/{wid}/generated_creatives/generate/marketplace_proxy/
body: {"model": "<vendor id>", "prompt": "<literal>", "images": ["https://…"], "params": {…}}
```

`images` must be a **real JSON array** and `params` a **real nested object**. Flattening the model settings to the top level — the shape other vendors use — 422s. The canonical body is owned by the playbook: `load_skill('generate-marketplace-proxy-video')` (exact server-side skill name) and `load_skill('creative-generation')` for the gate.

## When to Use

- The user names a model, or asks what models exist / which to use.
- The user authored a specific scene, shot, or aesthetic and the wording must survive verbatim.
- A reference image that is **not** a workspace product must be pinned to the render.
- One product/person/set must stay identical across several renders.
- A hard param constraint (e.g. a 5 s clip) falls outside the internal pipelines' contract.

**Don't use:** template-shaped brand/product ads ([[coinis-image-from-url]]); URL-driven UGC ([[coinis-video-from-url]]).

## Routing — three generate families, different authorship

| Brief | Endpoint | Who writes the model prompt |
|---|---|---|
| Product + scene direction, template-shaped ad | `generate/image_templates` ([[coinis-image-from-url]]) | BE composes it; user words land in `additionalInformations` |
| Product-page URL → UGC video | the UGC pipeline ([[coinis-video-from-url]]) | BE, from the scraped page |
| Named model / authored prompt / arbitrary refs / identity lock | `generate/marketplace_proxy` (this skill) | **You do** — `prompt` is literal |

Route by **deliverable and authorship**, never by "which model is best". A duration/param constraint outside one pipeline's contract means **switch pipelines, not negotiate the brief**.

## Discovery — the 422 IS the schema

**Never state the model catalogue from memory, and never hardcode it here — the server states it.** There is no `list_models` endpoint; the allowed `model` enum lives in the endpoint's own pydantic validation.

**`list_endpoints` returns `{method, path, summary, tags}` — paths, never body schemas — and can return empty for a family that is live.** `list_endpoints(filter="marketplace")` came back contentless minutes before six `marketplace_proxy` renders landed (observed 2026-07-08). **An empty catalogue read is not evidence a capability is absent** — do not tell the user it doesn't exist on that basis.

**The free schema source is the `preview_cost/` sibling.** POST it with a deliberately-invalid `model`; the discriminated union answers with every accepted model id in `detail[].ctx.expected`, each variant's numeric bounds in `detail[].ctx.le`, and each variant's required media in its `{"type": "missing"}` rows:

```
POST /api/workspaces/{wid}/generated_creatives/generate/marketplace_proxy/preview_cost/
body: {"model": "<deliberately-invalid>", "prompt": "test"}
→ 422, e.g. "Input should be <MarketplaceVideoModel.VEO_3_1_FAST: 'veo-3.1-fast'>"
         + {"loc": ["body","HappyHorseRequest","images"], "msg": "Field required"}
```

**Probe `preview_cost/` ONLY — never `generate/`.** `preview_cost` bills nothing and its 422s cost nothing; a satisfying body on `generate/` **IS** the fire. Never let a paid call be the one that discovers the schema.

Treat that 422 as authoritative in both directions — it is the always-current catalogue **and** a definitive "not supported" answer. Don't retry the probe, don't guess model names, don't hardcode a list.

**Constraints are per-model, not per-family.** The same 422 states each model's caps and required inputs — some cap duration, some require `images`, some require a source video. **Choose the `model` and compose its `params` in ONE decision:** a model picked first and parametrised second returns a validation error that reads like a schema bug, and the agent starts rewriting the body instead of changing the model. Never carry an enum across families by analogy — the marketplace `params.aspectRatio` enum is not the UGC one.

**A clean `preview_cost` 200 prices the `model` — it does not validate the body.** Preview the price; discover the body from the validator.

## Model choice — preview every candidate, then let the user pick

`preview_cost` is **free, creates no record, and never bills**, and `tokenCost` is keyed on `model` + params, not on prompt text. So price the whole candidate grid **during planning, before a real prompt exists**, using a byte-identical placeholder body per candidate (`{"model": "<candidate>", "prompt": "test", …}`).

Then surface the matrix as ONE question with a **craft-justified** recommendation, and let the user choose:

> "Three 5 s vertical clips. Seedance 2.0 — 390 total: highest fidelity, most reliable on the on-screen text beats. Seedance 1.5 Pro — 51 total: good motion, text can garble. Veo 3.1 Fast — 84 total at 6 s (it can't do 5 s). Which?"

**Never silently default to the cheapest, and never assume pricier is better.** Previewing only the model you already picked hides the trade-off: the user overpays on filler, or gets the cheap tier on a hero asset, and never knew there was a choice. Spend up on hero assets, down on filler. Equal `tokenCost` across a resolution step → take the higher resolution.

Choose by three ordered checks, never by name recognition:

1. **Does it accept `images[]`?** Only a model that takes a reference can identity-lock a packshot across a set. The 422 names each variant's required media.
2. **What does `preview_cost` actually return for that `model`?** Read `tokenCost` per candidate at call time — never carry a tier price in memory.
3. **Does it hold an "exact same scene as the reference" instruction?** Required whenever one subject must persist across renders.

A model tier change **re-opens the spend gate** — re-preview and re-ask; the quote the user approved was for a different body.

**There is no audio or music model in the union** — an audio probe matches nothing. A brief asking for a music bed or voiceover cannot be served by any Coinis call. Say so in one line and let the user plan the audio elsewhere. Never substitute a video model for a music request: the render bills either way and the user discovers the silence after paying.

## Prompt craft — what this API does and does not give you

**There is no negative-prompt field.** Avoid-intent must be written as **positive** scene wording — an affirmative end-state, never "avoid X". ("No software UI shown" belongs in the positive prose; the model has no exclusion channel.)

**There is no `seed`, no guidance/strength, no temperature, no style preset.** Reference chaining is the only consistency lever (below). Don't promise reproducibility the API can't deliver.

### Never let a generation model render letterforms

**Never ask a video model to render on-screen text, a wordmark, a logo, or an outro.** The seedance family invents and misspells them. Observed shipping from the platform: `"A WHOLE CAMPAIN!"`, `"TO CONIS AI."`, and a fabricated `"Ⓒ Conis"` end-card the prompt never asked for.

Prompt for the **visual only**. Split every brief into:

- **SHOT** — camera, motion, framing, grading, subject → goes into `prompt`.
- **SCREEN** — the literal on-screen copy → **never** goes into `prompt`.

If the brief doesn't label them, do the split yourself and read the SCREEN copy back for confirmation. This defect is **invisible to the wait loop** — burned-in-text errors still return `actionStatus: success` with a populated URL, so [[coinis-polling]] cannot catch it. And **no `revise/*` endpoint repairs baked-in text**: the only fix is another paid render.

If the user wants burned-in copy, say the model cannot be trusted with letterforms, and either reserve the region (below) or tell them up front that on-screen text will be decorative. Same rule for logos — brand-exact wordmarks and hex are unreachable by the generator, and a paid re-fire will not fix them.

**Reserve the compositing region** when copy or a logo will be overlaid downstream: ask the prompt for clean negative space where the text will land, rather than asking for the text.

## Identity lock — `images[]` is the invariant, the prompt is the variable

When a brief states an invariant and varies only production, **prompt wording alone does not hold identity**: N independent text-only fires return N different-looking products, each render individually fine and the set unusable — and it already billed.

**Bind the reference explicitly.** Passing `images[]` alone does not tell the model the reference is authoritative for object identity — it reads it as style inspiration and invents a plausible-but-wrong subject. Name the subject inside `prompt` as:

> `the exact <material/colour> <BRAND IN CAPS> <product noun> from the reference image`

inline in the clause where the subject acts — never a bare noun, never a trailing note. The literal token `exact` plus the pointer `from the reference image` is what binds them. A wrong-product ad renders beautifully, is worthless, and survives review because nothing looks broken.

### Output→reference chaining (the only consistency lever)

To render N creatives sharing one product / actor / set:

1. Fire **ONE anchor**.
2. Poll it to `actionStatus: success` ([[coinis-polling]]) and read its rendered URL.
3. Fan out with **that one URL** in every sibling's `images[]`.

**This is serial, not parallel** — a fan-out started off a `processing` anchor has no URL to reference yet. Order the batch by the dependency graph, not the asset list ([[coinis-batch-patterns]]).

Each chained sibling's `prompt` takes the **lock / delta / lock** shape:

> `Exact same scene as the reference image: the same <invariant>, same <invariant>, same <invariant>. Only <one axis> changes: <delta>. Everything else identical to the reference.`

Repeat the literal word `same` before each invariant noun phrase, change exactly **ONE** axis per sibling, and always close with the catch-all lock. Re-describing the scene fresh invites the model to re-sample it: axes you didn't name (lighting, background, wardrobe) drift silently, and drift is only visible after the render is paid for.

Pick the reference strategy per continuity axis — chain-reference for a character, a fixed packshot reference for a product.

**Verify a reference URL resolves before spending on it.** A reference is an input to a paid call; a stale or 404 URL burns the fire. Check it returns 200 with non-zero bytes first — especially when reusing a URL harvested from an earlier session.

## Reference assets — public https only

The BE fetches references over the network: **public `https` URLs only**. It cannot read a local path, a CLI chat attachment, or base64. A local file must be hosted first:

```
POST /api/workspaces/{wid}/generated_creatives/presigned_upload_url/
body: {"filename": "...", "contentType": "..."}     ← lowercase `filename`; `fileName` 422s
→ PUT the bytes to the returned URL → use the returned public URL in `images[]`
```

The presigned URL is short-lived — upload promptly rather than composing the whole batch first.

## Cost gate

`marketplace_proxy` is a paid `generate/*`: POST the sibling `.../marketplace_proxy/preview_cost/`, surface `tokenCost` + `currentBalance`, and fire only on explicit consent AND `sufficient: true`. **Preview the model you are actually about to fire** — cost differs per model, so a quote from a cheaper sibling is not a quote. The body you preview MUST equal the body you fire, including every cost-affecting param. Gate mechanics are owned by `load_skill('creative-generation')`; never hardcode a token figure here.

On video, the quoted `tokenCost` is a **reservation upper bound**, not the charge — report settled spend from the creative record, never the quote ([[coinis-polling]]).

## Polling

Owned by [[coinis-polling]]. Match the cadence to the output type: image output ≈ the `image_templates` class (first poll 60 s); video output ≈ the video class (first poll 180 s, `ScheduleWakeup`).

`actionStatus: success` means it rendered — **not** that it's correct. Open the asset before quoting it.

## Common mistakes

| Mistake | Reality |
|---|---|
| Hardcoding or reciting the model catalogue | It moves. Probe `preview_cost/` with an invalid `model` and read the enum out of the 422. |
| Probing a bogus `model` against `generate/` | That's the fire. Probe `preview_cost/` only. |
| Reading an empty `list_endpoints(filter=…)` as "the family doesn't exist" | Observed contentless for a live family. Not evidence of absence. |
| Firing through the typed `generate_marketplace_proxy` tool | It stringifies `images`/`params` → 422 blaming the wrong field. Use `call_api` with real JSON types. |
| Flattening `params` to the top level | 422. `params` is a nested object; `images` is a real array. |
| Picking the model, then composing `params` | Constraints are per-model. Choose model + params in one decision, or the 422 reads like a schema bug. |
| Previewing only the model you already chose | Hides the trade-off. Preview every candidate — previews are free — and let the user pick. |
| Defaulting to the cheapest model silently | Spend up on hero assets. Present the matrix with a craft reason. |
| Carrying the UGC `aspectRatio` enum onto marketplace | Different family, different bounds. Read them off the validator. |
| Asking a video model for a wordmark, caption, or outro | It invents and misspells them (`"A WHOLE CAMPAIN!"`, `"Ⓒ Conis"`). Prompt the visual; composite copy outside the model. |
| Writing "avoid X" in the prompt | No negative-prompt field exists. Write the positive end-state. |
| Holding a subject constant by re-describing it in text | Returns N different subjects. Chain the anchor's rendered URL into every `images[]`. |
| Fanning out before the anchor reaches `success` | No `imageUrl` exists yet to reference. The chain is serial. |
| Passing `images[]` without naming it in the prompt | Read as style inspiration. Say "the exact … from the reference image". |
| Passing a local path or base64 as a reference | Public https only. Host it via `presigned_upload_url` (`filename`, lowercase). |
| Proposing a model for a music/voiceover request | No audio member exists in the union. Say so; don't 422 on the user's credits. |
| Reporting the video quote as spend | The quote is a reservation upper bound. Settled cost lives on the record. |

## Red flags — stop and re-check

- About to send a bogus/probe value to `generate/*` instead of `preview_cost/` → STOP. That call bills.
- About to name a model id from memory without a live probe → STOP. The catalogue is the server's.
- About to fire without previewing the other viable candidates → STOP. Previews are free; the choice is the user's.
- About to ask any generation model for a logo, wordmark, or exact copy string → STOP. Prompt the visual; composite the copy.
- About to fan out an identity-locked set in parallel → STOP. Anchor first, then chain its URL.
- About to change the model tier after consent → STOP. Re-preview and re-ask; the gate was for a different body.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, model ids, and CLI flags stay English. Compose `prompt` itself in **English**, and ship any user-authored copy string verbatim in the language they typed it.
2. **No raw JSON dumps** (no 422 bodies, no `call_api` transcripts). Translate a probe result into one plain line — but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "probing preview_cost", "reading the 422", or name MCP tools; say "checking what's available…".
4. **One question at a time** — with one carve-out: the model/price matrix is a single question, so present the candidates together rather than serially.
5. **Show the literal `prompt` alongside the cost at the gate** — a prompt the user cannot see is a prompt she cannot correct, and the re-fire costs another render.
6. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait.

## Related skills

- [[coinis-image-from-url]] — template-driven image generation; brand/product setup; the routing counterpart.
- [[coinis-video-from-url]] — URL-driven UGC and the internal video pipelines; where a param constraint sends you here.
- [[coinis-batch-patterns]] — fan-out shapes, the serial-chaining wave order, and batch cost projection.
- [[coinis-polling]] — render polling, settled-spend reporting, and the inspect-before-quoting rule.
- [[coinis-revisions]] — iterating on a creative that already rendered.

## Why this skill exists

The marketplace family is where the practitioners do their best work, and it was the one generate family the bundle didn't cover at all — so agents either never reached it, or reached it with the `image_templates` mental model and 422'd on a stringified body. Three facts make it different from every other Coinis surface and are worth pinning once: the **model is a request parameter** (so there is a choice to preview, and the catalogue is the server's to state via a free 422 probe, not this file's to recite); the **prompt is literal** (so authorship, and the letterform ban, are the agent's responsibility); and **no seed exists** (so identity across a set rides on chaining an anchor's rendered URL into `images[]`, serially). Everything else — the canonical body, the per-model params, the costs — belongs to `load_skill('generate-marketplace-proxy-video')` and is deliberately not duplicated here.
