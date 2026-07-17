# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-07-17

Correction-and-completion release. 1.3.0 shipped the marketplace-models skill and the craft rules against a stale tool inventory, and three of its claims turned out to be wrong. This pass verifies them against the live Coinis MCP, corrects them, and folds in the **image** half of the marketplace family that 1.3.0 covered only for video.

### Fixed

- **The typed `generate_*` / `analyze_*` / `revise_*` tools are live — 1.3.0's "phantom tool" claim was wrong.** 1.3.0 stripped the typed tools from every creative skill's `allowed-tools` and routed all generation through `call_api`, on the belief that the typed marketplace tool stringified `images`/`params` and 422'd. The server serves all of them (`generate_image_templates`, `generate_ugc_video`, `generate_cinematic_video`, `generate_talking_head_video`, `generate_marketplace_proxy`, `analyze_and_create_product`, `analyze_and_create_brand`, `revise_creative_*`). Restored the typed tools to `allowed-tools` wherever a skill uses them — both the typed path and `call_api` are valid. The old stringify 422 is now recorded as a possibly-already-fixed client observation, not a standing reason to avoid the tool.
- **There is no bare `analyze_product` tool.** `coinis-batch-patterns` documented a two-step `analyze_product` → `POST /products/` wave; the real call is `analyze_and_create_product`, which analyses the URL and creates the product in one shot and returns the `pid`. Corrected the multi-product wave order and the dedup rule — a re-run *creates a duplicate product*, it is not merely wasted latency.
- **Seedance video exposes `seed` — 1.3.0's "no seed" rationale was false.** 1.3.0 stated the marketplace family has no `seed` and cast reference chaining as the only consistency lever on that basis. Seedance video params do expose `seed`, but a seed repeats a *sample* — it does not carry a subject's identity across a different scene, and the Seedream image params have no seed at all. The reference image remains the identity lever; the rationale is now stated correctly.
- **The cinematic V1 pipeline is not "15s/30s".** It ships seven fixed-duration flows (cinematic 10/15/20/30, product-shot 15, product-doc 15, product-spec 10). `coinis-video-from-url` corrected the durations in the endpoint table, the pipeline-pivot rule, and the quick-reference note; the pivot-to-marketplace rule still holds for a 5 s ask, and detail defers to `load_skill('generate-cinematic-video')`.

### Added

- **`coinis-marketplace-models` — image side.** The skill now covers the Seedream image models and their siblings alongside the video half — the discriminated union is keyed on `model` and serves both modalities off one family. Encodes:
  - **Seedream tiers are flat-cost** — the version (`seedream-5.0-lite`, `seedream-4.5`, `seedream-4.0`) is the user's preference, not a price trade-off, so there is nothing to cost-shop; ask which one when they don't name it. Candidate cost-shopping is **video** guidance — video cost varies sharply per model.
  - **`productId` auto-seeds the reference** — passing `productId` with no explicit `images` seeds the product's own catalog images, so a workspace product's identity locks across a set without a manual anchor chain. Manual output→reference chaining is now scoped to a **non-product** subject (an actor, a set, an invented character).
  - Per-model image params and caps — Seedream `aspectRatio` / `sequentialImageGeneration` / `maxImages`, the 0–10 reference cap, and the Gemini / GPT / Grok image siblings at a glance — plus a dated catalogue table carrying a re-probe reminder (the `preview_cost/` 422 remains the authority).

### Changed

- **`coinis-marketplace-models` routing tightened** — the family is reached **only on an explicit marketplace-model ask**; any generation the user did not tie to a named model routes to `generate_image_templates` / `generate_ugc_video` / `generate_cinematic_video`. Route by the explicit ask, never by "which model is best".
- **`coinis-revisions`** — corrected the `revise/variate` description: it **edits the user's current image** via `sourceImageUrl` (same product/composition, tweaked details, steered by a required `prompt`), rather than producing fresh compositions. Reach for it when the user points at an image and wants *that* image changed; `generate_image_templates` is only for a whole new image.
- **`coinis-image-from-url`** — added the "edit this image" routing note handing off to `revise_creative_variate` ([[coinis-revisions]]) when the source *is* the subject.
- **`coinis-batch-patterns`** — the `productId` auto-seed as the first-choice identity lock for a workspace product (the whole set stays one parallel wave); manual chaining reserved for non-product subjects.
- **`CLAUDE.md`** — the model-example house rule now spans both modalities: Seedance 2.0 or newer for video, Seedream for image, with non-house ids allowed only as catalogue coverage; the `preview_cost` 422 illustration uses a vendor-neutral placeholder rather than a real non-house variant.
- **`COOKBOOK.md`** — an image-side routing row for `coinis-marketplace-models` (Seedream model choice); the skill count is unchanged at 9.
- Version bump 1.3.0 → 1.4.0 across `VERSION` and all four plugin manifests.

## [1.3.0] - 2026-07-17

Craft-rules release. This pass encodes how the creative endpoints actually behave in sustained production use — the model-choice surface, the reference-image mechanics that hold a subject steady across a set, and the failure modes that a `success` status hides — plus several factual corrections to the existing skills.

### Added

- **`coinis-marketplace-models`** — a new skill for the `generate/marketplace_proxy` family: the only Coinis surface where the model is a request parameter and the `prompt` is passed through literally. It encodes:
  - **Model discovery from the validator** — there is no `list_models` route, so the accepted `model` enum and each model's per-model constraints are recovered by POSTing a deliberately-invalid `model` to the free `…/preview_cost/` sibling and reading the 422. Probe `preview_cost/` only — a satisfying body on `generate/` is the fire.
  - **Cost-shopping across candidates** — previews are free and priced on `model` + params, so every viable model is priced with a byte-identical body and the trade-off is put to the user with a capability-based recommendation, rather than silently defaulting to the cheapest.
  - **Keep generated text out of the render** — image and video models invent and misspell wordmarks, logos, and on-screen copy; no `revise/*` repairs baked-in text, and the defect survives the wait loop because the job still reports `success`. Prompt the visual, reserve the space, composite copy outside the model.
  - **Reference-image identity lock** — the family exposes no `seed`, so holding one product/person/set identical across a series means chaining the anchor's rendered URL into every sibling's `images[]`, serially, with an explicit lock/delta/lock prompt shape and the subject named as "the exact … from the reference image".
  - **Fire via `call_api`** — the typed marketplace tool serialises `images`/`params` as strings and 422s; the raw path with real JSON types is the working call.

### Changed

- **`coinis-image-from-url`** — brand-awareness check runs first (a "post for &lt;brand&gt;" with no product is `generate/social_post/`, not `image_templates`); `additionalInformations` documented as a 4-part compositor spine with reserved negative space rather than "one scene line"; literal copy routed to `revise/ad_copy` instead of the renderer; the `resolution` cost ladder (prove cheap, finish expensive — and preview the exact resolution you will fire); one POST per art direction; user-supplied images registered via `presigned_upload_url` (lowercase `filename`); brand styling resolves from the product, so cross-branding is prompt-only; an empty `list_my_workspaces` means "unknown", not "none".
- **`coinis-polling`** — **corrected a wrong query param**: the page-size arg is `page_size`, not `limit` (`limit` is silently ignored, returning a full page); the listing is a context bomb, so keep it tiny; `actionStatus: success` is a liveness signal, not a quality check — open the asset before quoting or attaching it; `failed` still bills, so diagnose and reword rather than re-firing the identical body through `…/{id}/retry/`; report settled spend from `aiGenerationTokenCost` on the record instead of the reservation quote; a five-outcome failure taxonomy; the render wait is a work slot.
- **`coinis-video-from-url`** — **corrected a stale claim**: `avatarId` is discoverable via the dedicated `list_avatars` / `get_avatar` tools (the previous note looked only in `list_endpoints`); a URL-driven re-fire is a fresh re-roll, not steering; `…/preview_cost/` is not always a sibling of the fire path, so a catalogue miss is a discovery trigger rather than proof a capability is gone; a hard duration/param constraint switches pipeline families instead of rounding the brief; no music or audio model exists on this surface; a video quote is a reservation upper bound.
- **`coinis-batch-patterns`** — the one-product/many-directions axis: `quantity: N` buys variance (N re-samples of one look) while N POSTs buy variety (N authored scene lines); validate one render before committing an unvalidated direction to full batch width; a reference-locked set is a serial, dependency-ordered wave, not a parallel one; mixed-shape batches need one preview per distinct shape; a multi-concept brief is shortlisted with per-option cost rather than auto-produced; check for an already-rendered creative before spending.
- **`coinis-revisions`** — route by the defect the user named (`variate` is a blind re-roll with no critique channel; a wrong-subject defect is a reference-locked fresh generate); establish a creative's provenance before acting on it; iteration is the norm and "done" is the user's explicit acceptance; a new brief is a new fire.
- **`coinis-campaign-flow-cli`** — `actionStatus: success` is a render signal, not a quality signal: view the asset before attaching it to a live ad.
- **Frontmatter `allowed-tools`** corrected across the creative skills to the tools the MCP actually serves — the typed `generate_*` / `analyze_product` entries were phantom; generation goes through `call_api`.

## [1.2.1] - 2026-07-16

### Added

- **CLI-surface UX contract** — every `coinis-*` skill now carries a `## CLI-surface UX rules` block: reply in the user's language, no raw JSON dumps, no plumbing narration, one question at a time, and keep labeled `id`/`jobId` recovery handles. Paid-generation skills additionally frame a declined `preview_cost` / `sufficient: false` as a normal outcome, not an error to retry.
- `.github/ISSUE_TEMPLATE/config.yml` — routes MCP/auth and account/credit questions to their owning channels so the skills repo's issues stay about skills.
- `COOKBOOK.md` — a "Patterns these recipes share" closer distilling four cross-cutting principles (preview-then-cheap-iterate, render-hero-once, creative-`id` hand-off, playbook-owns-prompts-and-costs).
- `INSTALL.md` — an "Updating" section mapping each install door to its update command.

### Changed

- CI (`validate-skills.yml`) now also enforces a `NOT for` routing clause and non-empty `argument-hint` + `allowed-tools` in every skill's frontmatter.
- `CLAUDE.md` — added a soft ~250–300-line skill budget (overflow belongs in the in-MCP playbook via `load_skill(...)`, not a per-skill `references/` dir) and codified the UX-block requirement; noted that a declined preview / `sufficient: false` is a normal outcome.
- `CONTRIBUTING.md` — a ratchet against loosening a CLI-surface UX rule without an explicit reason.
- `.github/ISSUE_TEMPLATE/skill_request.md` — an anti-sprawl gate ("why a separate skill, not an addition?") with a forced choice and routing prompt.

## [1.2.0] - 2026-06-09

### Removed

- Four skills whose endpoints and cost model do not exist on the live Coinis MCP,
  confirmed by an MCP-parity audit: `coinis-cost-gates` (`/coinis:cost-gates`),
  `coinis-product-shots` (`/coinis:product-shots`), `coinis-ad-clone`
  (`/coinis:ad-clone`), and `coinis-smart-resize` (`/coinis:smart-resize`). The
  `generate/ad_clone`, `generate/product_shots`, and `generate/smart_resize`
  endpoints — and the "premium 10,000-token tier" they described — are not present
  on the server.

### Changed

- Credit-spend gating now documents the live mechanism: the MCP's
  `…/preview_cost/` endpoint (`{tokenCost, breakdown, currentBalance, sufficient}`)
  is called before any paid `generate/*` / `revise/*` fire, with `revise/ad_copy`
  the sole zero-cost endpoint. The discredited per-record `aiGenerationTokenCost`
  field and the hardcoded tier table were removed from all surviving skills, the
  cookbook, and the eval suite.
- Bundle reduced from twelve skills to eight; surviving skills, manifests, README,
  COOKBOOK, evals, and install docs updated accordingly.
- `coinis-reports-cli`: corrected the report column from the non-existent
  `revenue` to `purchase_value`.
- Version bump 1.1.0 → 1.2.0 across `VERSION` and all four plugin manifests.

## [1.1.0] - 2026-06-09

### Added

- Five new skills covering the remaining MCP generate surface: `coinis-product-shots`
  (`/coinis:product-shots`), `coinis-ad-clone` (`/coinis:ad-clone`),
  `coinis-smart-resize` (`/coinis:smart-resize`), `coinis-competitor-recreate`
  (`/coinis:competitor-recreate`), and `coinis-revisions` (`/coinis:revisions`).
- Endpoint routing table mapping each user intent to its `mcp__coinis__*` endpoint,
  cost tier, and owning skill.
- `allowed-tools` and `argument-hint` frontmatter on the skill command surfaces.

### Changed

- Version bump 1.0.0 → 1.1.0 across `VERSION` and all four plugin manifests.
- Shortened the marketplace plugin description to a benefit-led one-liner.
- Plugin keywords: dropped `mcp`; added `ai-image` and `ai-video`.

## [1.0.0] - 2026-06-09

### Added

- Initial public release of the Coinis MCP skills bundle — seven skills:
  image creative generation, video creative generation, cost gates, async-job
  polling, multi-product batch patterns, the Meta campaign flow, and
  performance reports.
- Plugin manifests for Claude Code (`.claude-plugin/`), Codex
  (`.codex-plugin/`), and Cursor (`.cursor-plugin/`).
- Per-platform "connect any agent" guides.
- One-shot `setup` install script.
- End-to-end use cases and day-in-the-life marketer scenarios under `tests/`.
- Eval scenarios for skill triggering and correctness under `evals/`.
