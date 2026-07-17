# Repository agent guide

This repository hosts the **Coinis** skills bundle — a collection of Claude Code, Codex, and Cursor skills that wrap the Coinis advertising-platform MCP server (`coinis` at `https://mcp.coinis.com`).

If you are an AI agent working in this repo, read this file before making changes.

## What this repo IS

- A set of skill modules (one directory per skill, `SKILL.md` at the top of each).
- Plugin manifests for three surfaces: Claude Code (`.claude-plugin/`), Codex (`.codex-plugin/`), Cursor (`.cursor-plugin/`).
- End-to-end use cases + day-in-the-life marketer scenarios in `tests/`.

## What this repo IS NOT

- It is not a wrapper around the Coinis HTTP API directly. The skills assume a working Coinis MCP server is configured in the user's client (Claude Code / Codex / Cursor) and that the `coinis` MCP tools are reachable.
- It is not a place for business strategy, pricing detail, competitor analysis, internal infrastructure paths, customer data, or team-specific roadmap. Anything internal stays in a private skills directory, **not this repo**.

## Skill authoring rules

1. Each skill lives in its own top-level directory: `coinis-<short-name>/SKILL.md`.
2. `SKILL.md` starts with YAML frontmatter: `name`, `description`. The `description` MUST start with `Use when …` and describe **triggering conditions only**, not the workflow.
3. The skill body covers: when the skill applies, the rules it overrides (if any), the verified API/MCP shape it relies on, and the failure modes the agent should warn against.
4. Cross-references between skills use the `[[skill-name]]` form.
5. When a skill encodes a rule that overrides an upstream in-MCP skill, **say so explicitly** — name the upstream skill and the rule being overridden. The CLI surface differs from the in-product agent surface (no live progress cards, no front-end `request_user_approve` block); rules that assume the FE owns part of the loop need to be flagged and overridden for the CLI.
6. **Keep each skill lean — aim for ~250–300 lines.** Test: if a section doesn't change what the agent DECIDES to call next, it belongs in the in-MCP playbook, not the overlay. Push overflow to `load_skill('creative-generation' | 'campaign-flow' | 'reports-flow')`, which owns the canonical request bodies, schemas, and costs — **not** to a per-skill `references/` sub-directory (a local copy of playbook-owned bodies/costs would duplicate the source of truth and re-introduce the hardcoded-endpoint hazard the cost-gate rule forbids). Soft guideline, not a CI gate — a dense, well-formed skill that runs longer is fine.
7. Every skill carries a consistent output contract in a `## CLI-surface UX rules` block: reply in the user's language, hide plumbing narration, one question at a time, no raw JSON dumps, and keep labeled `id`/`jobId` recovery handles. Adapt the rule set to the skill (a read-only reports/polling skill has no spend-decline rule); don't drop the block.

## Cost-gate discipline

The Coinis MCP charges credits for creative generation and revision. **Before firing any paid `generate/*` or `revise/*` call, the agent MUST first call the sibling `…/preview_cost/` endpoint** (returns `{tokenCost, breakdown, currentBalance, sufficient}`), surface `tokenCost` + `currentBalance` to the user, and proceed only on explicit consent and `sufficient: true`. `revise/ad_copy` is the only zero-cost, no-preview endpoint. This gate is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`) — never hardcode token costs in a skill; read `tokenCost` from `preview_cost` at call time. A user who declines the preview — or a `sufficient: false` result — is a **normal outcome, not an error to retry**: report the shortfall or the decline in one line and stop (never re-fire, never loop the preview, never verify spend via a balance delta).

## Polling discipline

The Coinis MCP creative generation is async. Live progress cards exist in the in-product agent surface but not in the MCP-client (CLI) surface. The CLI agent MUST poll to surface the rendered URL — use `ScheduleWakeup` for long-running jobs to avoid burning context on tight loops. See [`coinis-polling`](coinis-polling/SKILL.md).

## Public-safety rules for contributions

This repository is intended to be public.

- ✅ How to drive the MCP (endpoints, body shapes, gate logic, polling cadences, observed failure modes).
- ❌ Business strategy, pricing in customer-facing currency, competitor analysis, internal architecture, credentials, customer data, internal tickets, or team-specific roadmap.

If your skill needs internal Coinis business or strategy context to make sense, it belongs in a private skills directory, **not this repo**.

## House style

- Skill prose is dense. State the rule first; explain the failure mode that justifies it; quote field names from the API rather than paraphrasing.
- Markdown tables are preferred for endpoint/option grids.
- Use code-fenced commands and JSON bodies verbatim — do not paraphrase request shapes.
- When citing the MCP server, use the literal name `coinis` (the MCP tool prefix `mcp__coinis__*`).
- **Keep example model ids current, and never hardcode the model catalogue.** The marketplace catalogue moves; the live set is discovered at run time via the `preview_cost/` 422 probe, never pinned in a file as authority. When an example (skill prose, a `COOKBOOK.md` trigger phrasing, an eval scenario, README copy, or a quoted user phrasing) names a generation model, use a **currently-available** model id so the example stays accurate — don't showcase a retired/superseded tier. A catalogue table may list every model for coverage, marked with its observation date. The `preview_cost` 422 illustration uses a **vendor-neutral placeholder** (e.g. `<VariantRequest>`) rather than echoing a specific model. This governs the *examples we write*, not what the agent may fire.

## Where things live

| Path | Purpose |
|---|---|
| `coinis-*/SKILL.md` | One skill per directory at top level. |
| `.claude-plugin/plugin.json` | Claude Code plugin manifest. |
| `.claude-plugin/marketplace.json` | Claude Code marketplace listing. |
| `.codex-plugin/plugin.json` | Codex plugin manifest (richer schema). |
| `.cursor-plugin/plugin.json` | Cursor plugin manifest. |
| `tests/end-to-end-use-cases.md` | API-shaped use cases. |
| `tests/marketer-scenarios.md` | Day-in-the-life scenarios. |
| `evals/scenarios.md` | Eval scenarios (skill triggering + correctness). |
| `setup` | One-shot install script for end users. |
| `scripts/` | Maintenance scripts (update-check, version bumps, etc.). |
| `VERSION` | Single source of truth for the plugin version. |
