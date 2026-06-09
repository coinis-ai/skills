# Contributing

Contributions are welcome. This repo is public; everything you add must be public-safe (see [CLAUDE.md](CLAUDE.md) for the criteria).

## Git workflow

All changes go through pull requests. No direct pushes to `main`.

```bash
# 1. Branch from main
git checkout main && git pull
git checkout -b <type>/<short-description>
# e.g. feat/coinis-competitor-recreate, fix/reports-column-typo, docs/readme-skill-table

# 2. Make changes, commit with clear messages
git add -A
git commit -m "<type>(<scope>): short summary

- Why this change is needed (not just what)
- Reference any eval scenario or observed MCP response that justifies the rule
- Note any breaking changes to a skill's interface"

# 3. Push and open a PR
git push -u origin <branch-name>
gh pr create
```

### Branch naming

| Prefix | Use for |
|---|---|
| `feat/` | New skill, new endpoint coverage, new triggering scenario. |
| `fix/` | Wrong default, broken cross-reference, version desync, spend-preview error. |
| `refactor/` | Internal cleanup with no change to skill rules or triggering. |
| `docs/` | README, CONTRIBUTING, eval/test prose only. |

### Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): summary`, where `<scope>` is the skill directory it touches. Examples scoped to Coinis skills:

- `feat(coinis-competitor-recreate): add the preview-cost confirm-before-fire rule`
- `fix(coinis-polling): correct the per-creative-type cadence for video revisions`
- `docs(coinis-revisions): clarify which revise endpoints require a preview-cost gate`

## Adding a new skill

1. Create a top-level directory `coinis-<short-name>/` with a `SKILL.md` file.
2. Frontmatter:
   ```yaml
   ---
   name: coinis-<short-name>
   description: Use when <triggering condition>. Covers <one-line scope>. NOT for: <case A> (use [[coinis-other-skill]]).
   argument-hint: "[primary-arg] [--flag <value>]"
   allowed-tools: mcp__coinis__*
   ---
   ```
   - The `description` must start with `Use when …` and describe **triggering conditions only**, not the workflow.
   - Append a **`NOT for:`** clause naming the neighbouring skill that *does* own the excluded case (use the `[[skill-name]]` cross-reference form). This keeps the agent from mis-triggering when two skills sit near each other (e.g. cheap image vs. premium product-shots).
   - **`argument-hint`** — the slash-command argument shape shown to the user (e.g. `"[product-url] [--format square|story]"`). Required on any skill exposed as a `/coinis:<name>` command.
   - **`allowed-tools`** — the tool allow-list the skill needs. Coinis skills almost always scope to `mcp__coinis__*`; widen only when a skill genuinely needs another tool, and justify it in the PR.
3. The body should cover:
   - **When this applies** — the trigger, in prose, plus negative examples (when it does NOT apply).
   - **Rules being overridden** — if this skill contradicts an upstream in-MCP skill, name the upstream skill and the rule.
   - **Verified shape** — the endpoint, request body, and observed response. Quote field names.
   - **Common mistakes / failure modes** — what to warn against.
4. Add a row to the table in [`README.md`](README.md).
5. Register the skill in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) so it appears in the Claude Code marketplace listing.
6. (Optional) Add a triggering scenario to [`evals/scenarios.md`](evals/scenarios.md) and an end-to-end use case to [`tests/end-to-end-use-cases.md`](tests/end-to-end-use-cases.md).

## Editing an existing skill

- Skill rules are derived from field-tested behaviour. If you're changing a rule, link to (or quote) the evidence (an MCP response, an observed failure shape, a measurement).
- Don't loosen a spend gate without an explicit reason; every paid `generate/*` / `revise/*` fire must remain gated behind a `preview_cost` check and explicit user confirmation (`revise/ad_copy` is the only zero-cost exception).
- If you remove a "Common mistake" block, leave a note explaining why the mistake is no longer possible.

## Cross-surface compatibility

This repo ships plugin manifests for three surfaces:

- **Claude Code** (`.claude-plugin/`)
- **Codex** (`.codex-plugin/`)
- **Cursor** (`.cursor-plugin/`)

Skill content (the `SKILL.md` files) is shared across all three. If a behaviour differs between surfaces, encode that difference in skill prose ("on Codex, …" / "on Claude Code, …"). Don't fork the skill into per-surface variants.

## Version bumps

The plugin version is in [`VERSION`](VERSION) and mirrored in each plugin manifest's `version` field. When you bump:

- **Patch** (1.0.x) — skill rule clarifications, doc fixes, new failure-mode notes.
- **Minor** (1.x.0) — new skill, new endpoint coverage in an existing skill.
- **Major** (x.0.0) — breaking rename of a skill, removal of a skill, manifest schema changes.

Update all three plugin manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`) plus `VERSION` in the same commit.

## Public-safety check

Before pushing:

- No business strategy, pricing in customer-facing currency, competitor analysis, internal infrastructure paths, credentials, customer data, internal tickets, or team-specific roadmap.
- No internal hostnames other than the public Coinis MCP endpoint (`https://mcp.coinis.com`).
- No personal contact info; use `support@coinis.com` if a contact is needed.

## Reviews

PRs are reviewed by the maintainer (`@jovan-kovacevic`). Changes that touch any of the following get extra scrutiny:

- Cost-gate tables.
- Endpoint shapes or required parameters in skill prose.
- Plugin manifests (`.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`).

Typo fixes, new scenarios, and doc updates are lighter-touch.
