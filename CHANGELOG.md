# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
