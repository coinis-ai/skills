---
name: coinis-revisions
description: |
  Use when iterating on a creative that ALREADY EXISTS in the Coinis MCP (`coinis`) — the user wants more variations of it, a different aspect ratio, a localized/translated version, a higher-resolution copy, or ad-copy text generated against it. Triggers on "make more like this", "give me a 9:16 version of #3703", "translate this creative to German", "upscale this", "write ad copy for this creative". Covers the five `revise/*` endpoints (`variate`, `resize`, `translate`, `upscale`, `ad_copy`), the source-creative-id prerequisite, and the per-endpoint spend rule (`ad_copy` is zero-cost / no gate; the other four require the `preview_cost` ask-first gate).
  NOT for: a fresh creative from a product URL (use [[coinis-image-from-url]]) or video (use [[coinis-video-from-url]]); or render-status polling mechanics (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, ScheduleWakeup
argument-hint: <source-creative-id-or-url> <variate|resize|translate|upscale|ad_copy> [target e.g. "9:16" | "de" | "+1024px"]
---

# coinis-revisions

## Overview

The `revise/*` family is Coinis's iteration suite — five endpoints that operate on a creative the workspace **already has**, rather than generating one from scratch. There is no competitor analog; this is a Coinis-unique surface. Four of the five (`variate`, `resize`, `translate`, `upscale`) are **paid** and must clear the **`preview_cost` ask-first gate** before firing; `revise/ad_copy` is **zero-cost** and is the only one exempt from that gate. The CLI surface has no front-end approve block, so this skill carries the spend-gate discipline and the source-id prerequisite explicitly. The authoritative cost source is the live `revise/<x>/preview_cost/` response, owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`) — never a hardcoded number.

**Standing rule:** every `revise/*` endpoint requires a **source creative** — an existing creative `id` (or, for some shapes, its rendered `sourceImageUrl`). You cannot revise something that hasn't rendered yet. See [Prerequisite](#prerequisite-every-revise-needs-a-source) below.

**Do NOT invent request bodies.** Only `revise/resize` has a body shape documented here (`{sourceImageUrl, targetAspectRatio}`). For the other four, discover the exact accepted fields at run time via `mcp__coinis__load_skill(name="creative-generation")` and/or `mcp__coinis__list_endpoints` before firing. Any field below marked **verify** is not certain — confirm via `load_skill('creative-generation')`.

## The five endpoints

| Endpoint | What it does | When to use | Spend gate | Creates new id? |
|---|---|---|---|---|
| `revise/variate` | New variations of an existing creative (same product/brand, fresh compositions) | "give me 3 more like #3703" — user liked the direction, wants siblings | `preview_cost` ask-first | Yes (new creative id) |
| `revise/resize` | Reframe the existing creative to a different aspect ratio | "make this a 9:16 story version" — same art, new crop/extend | `preview_cost` ask-first | Yes (new creative id) |
| `revise/translate` | Localize the copy/text baked into the creative to another language | "translate this creative to German" — keep art, swap text | `preview_cost` ask-first | Yes (new creative id) |
| `revise/upscale` | Higher-resolution copy of the existing creative | "give me a print-res version of this" — same image, more pixels | `preview_cost` ask-first | Yes (new creative id) |
| `revise/ad_copy` | Generate ad-copy text (headlines / primary texts / descriptions / CTA) against the creative | "write Meta ad copy for this creative" — text output, no new image | **None — zero-cost, fire directly** | **No** — result lands on the source's `aiResults[]` |

For the four paid revises, run the `preview_cost` gate first (see [Spend gate](#spend-gate--preview_cost-first)), then fire on consent. `revise/ad_copy` is free — fire it directly and surface the result in one turn.

## Per-endpoint notes

### `revise/variate` — more of the same direction
Use when the user liked an existing creative and wants **siblings**, not a redo. The source's product, brand, tone, and style carry over; `variate` produces fresh compositions in that lane. Paid — clear the `preview_cost` gate first. Creates **new creative id(s)** — poll each like a `generate/*` fire (cadence in [[coinis-polling]], `revise/*` row: first poll 30 s, render 20–60 s).

### `revise/resize` — aspect-ratio reframe
Use when the art is right but the **frame is wrong** (square exists, story needed). `revise/resize` is simply the resize tool — there is no separate "premium reframe" endpoint to escalate to. Paid — clear the `preview_cost` gate first. This is the one endpoint with a documented body:

```
POST /api/workspaces/{wid}/generated_creatives/revise/resize/
body: {
  "sourceImageUrl": "<rendered imageUrl of the source creative>",
  "targetAspectRatio": "<e.g. '9:16'>"
}
```

Note `revise/resize` takes the rendered **`sourceImageUrl`**, not just a creative id — fetch the source's `imageUrl` first (`GET /generated_creatives/{source_id}/`, field `imageUrl`). Valid `targetAspectRatio` values: **verify** via `load_skill('creative-generation')` before firing an unfamiliar ratio. Creates a new creative id.

### `revise/translate` — localize the copy
Use when the art stays but the **baked-in text** must change language. Paid — clear the `preview_cost` gate first. Body shape (source reference + target language code) — **verify** field names via `load_skill('creative-generation')`; do not assume `language` vs `targetLanguage` vs `locale`. Creates a new creative id.

### `revise/upscale` — higher resolution
Use when the user wants the **same image at more pixels** (print, high-DPI placement). This is NOT a re-render or a quality reframe — it's an upscale of the existing asset. Paid — clear the `preview_cost` gate first. Body shape — **verify** via `load_skill('creative-generation')`. Creates a new creative id.

### `revise/ad_copy` — text, no new image (special case)
Use when the user wants **ad-copy text** (headlines, primary texts, descriptions, CTA) for an existing creative — e.g. to fill a Meta ad's text fields. **This endpoint is zero-cost and the only revise exempt from the `preview_cost` gate** — fire it directly, no spend ask. **It also does NOT create a new creative id.** The result is appended as a child job to the **source creative's `aiResults[]`** array, under an entry with `action: "ad_copy"`. To retrieve it you re-GET the source creative and read that entry's `result_data` — the exact `aiResults[]` shape (and the `result_data` fields: `headlines`, `primaryTexts`, `descriptions`, `ctaLabel`, `displayLink`) is owned by [[coinis-polling]]. Do NOT poll for a new creative id after `revise/ad_copy` — there isn't one. Body shape — **verify** via `load_skill('creative-generation')`.

## Decision tree

### `revise/variate` vs a fresh `generate/*`
- The product is **already in the workspace** AND the user liked an existing creative → `revise/variate` (paid, clear `preview_cost`; carries the source's lane).
- The product is **new / no existing creative to anchor on**, or the user wants a different product, tone, or style → fresh `generate/image_templates` via [[coinis-image-from-url]].
- Rule of thumb: "more like THIS one" → `variate`. "make me an image of X" with no anchor creative → `generate`.

## Route by the defect the user named — `variate` does not FIX

`revise/variate` is a **blind re-roll**: it produces fresh siblings in the source's lane, with **no critique channel** — it cannot act on "the face is wrong" or "the text is misspelled". Routing a **named defect** to `variate` just spends credits on another random draw that may reproduce the flaw.

When the user rejects a creative, first **name the defect**, then route to the **narrowest** endpoint that addresses it — and **never re-POST the identical body**:

| The user's complaint | Route |
|---|---|
| "wrong frame / need a story version" | `revise/resize` (aspect reframe) |
| "wrong language" | `revise/translate` |
| "need it bigger / print-res" | `revise/upscale` |
| "give me more like this, I like it" | `revise/variate` (the ONE case variate fits) |
| "the text is misspelled / a wordmark is garbled" | **No revise fixes baked-in text.** Regenerate with the copy composited out, or get the ad-copy TEXT via the zero-cost `revise/ad_copy` and place it yourself ([[coinis-marketplace-models]] letterform ban). |
| "the product/person looks wrong" | A reference-locked **fresh** generate ([[coinis-marketplace-models]]), not a revise — the source has the wrong subject baked in. |

A rendered creative is a **durable asset** — classify the complaint before re-firing a paid revise or generate; don't reflexively re-roll. Every mis-routed re-roll is a `preview_cost` gate the user paid through for nothing.

## Establish provenance before you act

Before revising, know **what the creative is**: MCP-made (has a `generated_creatives` id you can revise), platform-UI-made (may need to be looked up first), or a local file the user downloaded (no id — you cannot `revise/*` it; it must be re-registered or regenerated). Acting on a misclassified source wastes a fire. If the user references "the video from earlier" as a **continuity anchor** for a NEW creative ("make one related to this"), that is a **reference asset on a fresh generate**, not a `revise/variate` source — cross-medium "related to this" misroutes to variate constantly.

## Iteration is the norm — "done" is the user's word

**The first render is rarely the deliverable.** Budget several render/critique loops; the bar for "done" is the user's **explicit acceptance**, not `actionStatus: success`. And **a new brief is a new fire** — when the user changes the concept, never carry the previous creative's product, scene line, or params forward; seed a fresh generate from the new brief (optionally reusing a prior successful creative's stored `requestJson` as a starting shape, not its content). Record the deviations the user accepted so a later round doesn't re-offer a fix they already declined to pay for.

## Prerequisite — every revise needs a source

A `revise/*` call operates ON an existing creative. Before firing:

1. You need the **source creative `id`** (and for `revise/resize`, the source's rendered `sourceImageUrl` / `imageUrl`).
2. The source must have **rendered** (`actionStatus: success`) — you can't reliably revise a creative that's still `processing` or `failed`. If the user references a creative that hasn't landed, poll it to `success` first (cadences in [[coinis-polling]]) before revising.
3. If the user names a creative by description ("the square one from earlier") and you don't have the id, recover it via `GET /api/workspaces/{wid}/generated_creatives/?ordering=-id&page_size=3` (sort by `id` desc, NOT `createdAt`; the page-size param is `page_size`, not `limit` — see [[coinis-polling]]).

Without a valid source id (or `sourceImageUrl` for `resize`) the revise call has nothing to act on and will fail.

## Spend gate — `preview_cost` first

`revise/ad_copy` is **zero-cost** — no gate, fire directly.

The other four (`variate`, `resize`, `translate`, `upscale`) are **paid** and require the **ask-first `preview_cost` gate**. Before firing any of them:

1. POST `revise/<x>/preview_cost/` with the same body you intend to fire. The response is `{tokenCost, breakdown, currentBalance, sufficient}`.
2. Surface `tokenCost` and `currentBalance` to the user. **Do not hardcode token numbers** — quote them from this response, which is the authoritative source.
3. Proceed only on **explicit user consent** AND `sufficient: true`. If `sufficient: false`, stop and tell the user the balance is short; do not fire.

This gate is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`) — load it to confirm the exact `preview_cost` path and body before the first paid fire of a session.

## Polling after the fire

Owned by [[coinis-polling]] (`revise/*` rows): first poll at **30 s**, typical render **20–60 s**.

- `variate` / `resize` / `translate` / `upscale` → new creative id; `GET /generated_creatives/{new_id}/`, wait for `actionStatus: success`, quote `imageUrl`.
- `ad_copy` → no new id; `GET /generated_creatives/{source_id}/`, find the `aiResults[]` entry with `action: "ad_copy"` and the `job_id` the POST returned, wait for that entry's `status: "success"`, read `result_data`.

Revises rarely need `ScheduleWakeup` — a single 30-s wakeup then inline re-poll is usually enough.

## Quick reference — endpoints

| Revise | Method | Path | Body |
|---|---|---|---|
| Variate | POST | `/api/workspaces/{wid}/generated_creatives/revise/variate/` | verify via `load_skill('creative-generation')` |
| Resize | POST | `/api/workspaces/{wid}/generated_creatives/revise/resize/` | `{sourceImageUrl, targetAspectRatio}` |
| Translate | POST | `/api/workspaces/{wid}/generated_creatives/revise/translate/` | verify via `load_skill('creative-generation')` |
| Upscale | POST | `/api/workspaces/{wid}/generated_creatives/revise/upscale/` | verify via `load_skill('creative-generation')` |
| Ad copy | POST | `/api/workspaces/{wid}/generated_creatives/revise/ad_copy/` | verify via `load_skill('creative-generation')` |
| Preview cost | POST | `/api/workspaces/{wid}/generated_creatives/revise/<action>/preview_cost/` | same body as the intended fire (paid revises only) |
| Read source / result | GET | `/api/workspaces/{wid}/generated_creatives/{cid}/` | — |

Confirm every path and body against `mcp__coinis__list_endpoints` / `load_skill('creative-generation')` at run time — paths above follow the observed `revise/<action>/` convention but only `resize`'s body is documented.

## Common mistakes

| Mistake | Reality |
|---|---|
| Firing `revise/*` without a source creative id | Every revise acts ON an existing creative. No source id (or `sourceImageUrl` for `resize`) → nothing to revise. |
| Polling for a new creative id after `revise/ad_copy` | There isn't one. The result is on the SOURCE's `aiResults[]` under `action: "ad_copy"`. See [[coinis-polling]]. |
| Firing a paid revise without the `preview_cost` ask | `variate` / `resize` / `translate` / `upscale` are paid and ask-first. POST `revise/<x>/preview_cost/`, surface `tokenCost` + `currentBalance`, fire only on consent AND `sufficient: true`. |
| Running the `preview_cost` gate for `revise/ad_copy` | `ad_copy` is zero-cost and exempt. Fire it directly — no spend ask, no `preview_cost`. |
| Hardcoding a token figure for a paid revise | Never assert a cost number. Quote `tokenCost` from the live `preview_cost` response. |
| Passing a creative `id` to `revise/resize` instead of `sourceImageUrl` | `revise/resize`'s documented body is `{sourceImageUrl, targetAspectRatio}` — fetch the source's rendered `imageUrl` first. |
| Inventing `targetLanguage` / upscale-factor field names | Only `resize`'s body is documented. For the rest, discover fields via `load_skill('creative-generation')` before firing. |
| Revising a creative that's still `processing` | The source must be `actionStatus: success` first. Poll it to success ([[coinis-polling]]) before revising. |
| Treating a declined preview or `sufficient: false` on a paid revise as an error to retry | It's a normal outcome — report the shortfall/decline in one line and stop. Don't re-fire, don't loop the preview, don't check a balance delta. (`revise/ad_copy` is free, so it has no preview to decline.) |

## Red flags — stop and re-check

- About to fire any `revise/*` without a confirmed source creative id (or `sourceImageUrl` for `resize`) → STOP. Resolve the source first.
- About to fire a **paid** revise (`variate` / `resize` / `translate` / `upscale`) without running `preview_cost` and getting explicit consent → STOP. Run the gate; fire only on consent AND `sufficient: true`.
- About to poll for a new creative id after `revise/ad_copy` → STOP. The result is on the source's `aiResults[]`. See [[coinis-polling]].
- About to fire a revise body with field names you haven't verified (anything beyond `resize`'s `{sourceImageUrl, targetAspectRatio}`) → STOP. `load_skill('creative-generation')` first.

## CLI-surface UX rules

The CLI surface has no front-end progress cards or approve block, so this skill owns the conversational output contract. Bundle-wide defaults:

1. **Reply in the user's language** — detect it from their first message; MCP field names, endpoint paths, and CLI flags stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` request/response transcripts). Lead with the rendered URL — or, for `revise/ad_copy`, the returned copy — plus a one-line summary, but **do** hand back the creative `id`/`jobId` as clearly-labeled trace handles; the async wait model needs them to re-poll and recover ([[coinis-polling]]).
3. **Never narrate plumbing** — don't say "polling the job", "calling `preview_cost`", "scheduling a wakeup", or name MCP tools; say "generating your revision…".
4. **One question at a time** — never batch-ask.
5. **A declined or insufficient cost preview (`sufficient: false`, or the user declines) is a clean stop, not an error to retry** — report the shortfall/decline and wait. (`revise/ad_copy` is free, so it has no such gate.)

These set the defaults the fire-then-surface steps above build on; don't restate them.

## Related skills

- [[coinis-polling]] — `revise/*` poll cadence, the `aiResults[]` shape `revise/ad_copy` writes to, and the sort-by-`id` recovery rule.
- [[coinis-image-from-url]] — fresh image generation; the `variate` vs `generate` decision routes here.
- [[coinis-marketplace-models]] — reference-locked fresh generate for a "wrong subject" defect; the letterform ban behind "no revise fixes baked-in text".
- [[coinis-video-from-url]] — fresh video generation (out of scope for `revise/*`).

## Why this skill exists

The `revise/*` suite is Coinis-unique iteration that has no competitor analog, so agents don't bring a prior mental model for it. Two traps recur: (1) `revise/ad_copy` returns no new creative id — agents poll a nonexistent record instead of reading the source's `aiResults[]`; (2) the four paid revises need the ask-first `preview_cost` gate, while the free `ad_copy` does not — conflating the two either burns balance without consent or adds needless friction to a free call. This skill pins the source-id prerequisite and the per-endpoint spend rule, and delegates every unverified body shape (and the authoritative cost figure) to `load_skill('creative-generation')` rather than inventing it.
