# Coinis Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](VERSION)
[![Skills](https://img.shields.io/badge/skills-8-blueviolet.svg)](#skills)

Skills for the **Coinis** advertising platform — generate image and video ad creatives, recreate competitor ads, launch and manage Meta campaigns, and pull ROAS/CPA/spend reports, all from your AI agent. Works with **Claude Code**, **Codex**, **Cursor**, and any MCP-capable client.

Each skill sits in front of the MCP's own playbooks (the ones loaded via `list_skills` / `load_skill`) and encodes client-specific behavior — auth checkpoints, brand/product setup flows, spend-preview confirmation, and the standing rules that override upstream defaults on the CLI surface. Batches and chains span skills: generate a creative, launch it as a campaign, then report on it — all in one session.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/coinis-ltd/skills/main/setup | bash
```

Or follow the per-client instructions in [INSTALL.md](INSTALL.md).

### Claude Code

```text
/plugin marketplace add coinis-ltd/skills
/plugin install coinis
```

### Codex

```text
/plugins install coinis-ltd/skills
```

### Cursor

```text
@plugins add coinis-ltd/skills
```

## What do I want → which skill

| What you want | Skill |
|---|---|
| Generate an image creative from a product URL | [`coinis-image-from-url`](coinis-image-from-url/SKILL.md) |
| Generate a video creative (UGC, avatar, talking-head) | [`coinis-video-from-url`](coinis-video-from-url/SKILL.md) |
| Recreate a competitor's ad as my own creative | [`coinis-competitor-recreate`](coinis-competitor-recreate/SKILL.md) |
| Revise, resize, or iterate on a creative I already generated | [`coinis-revisions`](coinis-revisions/SKILL.md) |
| Make creatives for many products / formats at once | [`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md) |
| Launch or manage a Meta campaign | [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md) |
| Pull ROAS / CPA / spend reports | [`coinis-reports-cli`](coinis-reports-cli/SKILL.md) |
| Wait on a long async render without burning context | [`coinis-polling`](coinis-polling/SKILL.md) |

## Skills

| Skill | Invoke | Purpose |
|---|---|---|
| [`coinis-image-from-url`](coinis-image-from-url/SKILL.md) | `/coinis:image-from-url` | End-to-end recipe for creating an image creative when the workspace doesn't yet have the product. Covers auto-mode auth checkpoint, brand/product setup, and the preview-cost approve gate. |
| [`coinis-video-from-url`](coinis-video-from-url/SKILL.md) | `/coinis:video-from-url` | Same shape, for video creatives (UGC, image-to-video, video-to-video, avatar, talking-head). Distinguishes spend gates from content gates. |
| [`coinis-marketplace-models`](coinis-marketplace-models/SKILL.md) | `/coinis:marketplace-models` | The model-keyed `generate/marketplace_proxy` family — the one surface where you pick the model and author the prompt verbatim. Model discovery from the validator, cost-shopping across candidate models before choosing, keeping generated text out of the render, and locking one subject across a series with reference images. |
| [`coinis-competitor-recreate`](coinis-competitor-recreate/SKILL.md) | `/coinis:competitor-recreate` | Recreate a competitor's ad as your own original creative for your brand and product, without copying protected assets. |
| [`coinis-revisions`](coinis-revisions/SKILL.md) | `/coinis:revisions` | Revise, resize, translate, upscale, or iterate on a creative you already generated. Owns the revise-call shapes and the preview-cost spend gate (with `revise/ad_copy` as the one zero-cost exception). |
| [`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md) | `/coinis:batch-patterns` | Multi-product / multi-format fan-out: parallel POST shape, honest count math across format collapse, one-surface-per-batch convention, preview-cost pre-flight. |
| [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md) | `/coinis:campaign-flow-cli` | CLI overlay for Meta campaign creation. Translates the in-product picker/approve UX into sequenced prose questions; defers all validation to the in-MCP `campaign-flow` skill. |
| [`coinis-reports-cli`](coinis-reports-cli/SKILL.md) | `/coinis:reports-cli` | CLI overlay for performance reports. Tree-view-as-prose drill-down, 7-column default for terminal output, dollars-from-the-reports-endpoint currency rule; defers all numeric handling to the in-MCP `reports-flow` skill. |
| [`coinis-polling`](coinis-polling/SKILL.md) | `/coinis:polling` | Polling cadences per creative type for the CLI surface (which has no live progress cards). Owns the `aiResults[]` child-job shape, sort-by-id rule, and `{"error":""}` post-hoc verification. |

## Requirements

- An MCP-capable client. First-class plugins ship for [Claude Code](https://docs.claude.com/claude-code), [Codex](https://openai.com/codex), and [Cursor](https://cursor.com); any other MCP-capable client works too — see [Connect any agent](#connect-any-agent) below for per-platform guides (ChatGPT, Cline, Manus, Perplexity, VS Code, Warp, Windsurf).
- The **Coinis MCP server** (`coinis`) configured in your client. The skills assume the `mcp__coinis__*` tools are reachable at `https://mcp.coinis.com`.
- A Coinis account with workspace credits. Sign up at [coinis.com](https://coinis.com).

## Connect any agent

These skills drive the live Coinis MCP, so any MCP-capable client works. Per-platform connection notes:

- [ChatGPT](.chatgpt-plugin/README.md)
- [Cline](.cline-plugin/README.md)
- [Manus](.manus-plugin/README.md)
- [Perplexity](.perplexity-plugin/README.md)
- [VS Code](.vscode-plugin/README.md)
- [Warp](.warp-plugin/README.md)
- [Windsurf](.windsurf-plugin/README.md)

## Repository layout

```
coinis-mcp-skills-prod/
├── .claude-plugin/          # Claude Code plugin manifest + marketplace listing
├── .codex-plugin/           # Codex plugin manifest
├── .cursor-plugin/          # Cursor plugin manifest
├── .{chatgpt,cline,manus,perplexity,vscode,warp,windsurf}-plugin/  # Per-platform 'connect any agent' guides (README each)
├── .github/                 # CODEOWNERS, PR template, issue templates
├── CLAUDE.md                # Agent guide for working in this repo
├── CONTRIBUTING.md          # Contribution rules
├── COOKBOOK.md              # Example prompts → skills they trigger
├── INSTALL.md               # Install instructions for users
├── INSTALL_FOR_AGENTS.md    # Install instructions for AI agents
├── LICENSE
├── README.md
├── VERSION
├── assets/                  # Brand-asset placeholders (icon/logo planned — see assets/README.md)
├── coinis-*/                # One directory per skill (SKILL.md)
├── evals/                   # Triggering + correctness scenarios
├── scripts/                 # Maintenance scripts
├── setup                    # One-shot installer
└── tests/                   # End-to-end use cases + day-in-the-life scenarios
```

## Tests

Two complementary catalogues:

- [`tests/end-to-end-use-cases.md`](tests/end-to-end-use-cases.md) — API-shaped use cases: every documented MCP path (auth, workspace, brand, product, image, video, revise, polling) with the expected flow, success criteria, and the negative cases the skills warn against.
- [`tests/marketer-scenarios.md`](tests/marketer-scenarios.md) — Day-in-the-life scenarios: 8 marketer personas working across several products each (Shopify SMB, Amazon seller, DTC brand, SaaS founder, agency, affiliate, restaurant, creator). Tests the agent under realistic multi-product workflows with natural-language prompts, not isolated API calls.

Eval scenarios (triggering + correctness, per skill) live in [`evals/scenarios.md`](evals/scenarios.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All contributions must be public-safe — no business strategy, customer-facing pricing, competitor analysis, internal infrastructure paths, credentials, customer data, or team-specific roadmap.

## Examples

See [COOKBOOK.md](COOKBOOK.md) for example prompts and the skills they trigger.

## Related

- **Upstream MCP playbooks:** load via `list_skills` → `load_skill(name)` in the `coinis` MCP. Those cover the validation matrices and safe-default combos at the API level. The skills in this repo wrap them with CLI-specific behavior.

## License

[MIT](LICENSE) © [Coinis](https://coinis.com)
