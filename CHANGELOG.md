# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
