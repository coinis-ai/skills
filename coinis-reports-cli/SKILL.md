---
name: coinis-reports-cli
description: |
  Use when pulling Coinis performance reports (ROAS, CPA, spend, conversions) from the CLI surface — covers the drill-down-as-prose translation, sensible column defaults for terminal output, date/timezone defaults, the dollars-from-the-reports-endpoint currency rule, and the in-MCP `reports-flow` playbook reference.
  NOT for: creating / editing / launching campaigns, ad sets, or ads (use [[coinis-campaign-flow-cli]] — and note campaign endpoints use cents, the opposite of the reports rule here); credit-spend decisions on creative generation (load the in-MCP `creative-generation` playbook); generating image or video creatives (use [[coinis-image-from-url]] / [[coinis-video-from-url]]); polling render-status of generate/revise jobs (use [[coinis-polling]]).
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_endpoints, mcp__coinis__get_report_columns, mcp__coinis__get_overall_report, mcp__coinis__get_dashboard_report, mcp__coinis__get_assets_overview, mcp__coinis__call_api
argument-hint: '[campaign|ad-set|ad name or id] [date range e.g. "last 7 days"] [metric e.g. ROAS|CPA|spend]'
---

# coinis-reports-cli

## Overview

CLI overlay for navigating Coinis performance reports. The numeric heavy lifting — column discovery, query shape, date/timezone/pagination defaults, the dollars-from-the-reports-endpoint currency rule that overrides the campaign-side cents rule for spend / CPC / CPM / CPA — all lives in the in-MCP `reports-flow` skill. This overlay handles what `reports-flow` can't: the chat-and-table surface doesn't have a tree view, a column manager, inline editing, or a CSV download button, so the drill-down has to happen as prose and the rendering has to fit a terminal.

## When to Use

- User asks for performance numbers (ROAS, CPA, spend, conversions, revenue → the `purchase_value` column) via the CLI.
- User asks to "see how campaign X is doing" / "pull last week's report" / "which ad sets are losing money".
- Any path that touches `get_report_columns`, `get_overall_report`, `get_dashboard_report`, or `get_assets_overview`.

**Don't use:** For creating or editing campaigns — that's [[coinis-campaign-flow-cli]]. For credit-spend decisions on creative generation — load the in-MCP `creative-generation` playbook.

## Mandatory pre-flight

Load the canonical reports playbook from the MCP at the start of any reporting turn:

```python
mcp__coinis__load_skill(name="reports-flow")
```

Everything numeric — column discovery via `get_report_columns`, query body shape, date / timezone / pagination defaults, the dollars-from-the-reports-endpoint currency rule — lives there. This overlay does not duplicate any of that; if a number, field, or path doesn't appear in `reports-flow`, look it up via `list_endpoints(filter="reports")`. **Do not invent endpoint paths or column names.**

## Drill-down translation — tree view as prose

The in-product UI has a 3-level drill-down (campaign → ad set → ad) with a tree view: click a row to expand its children, click again to collapse. The CLI has no tree — just `call_api` calls and text output. Translate the tree into a prose drill-down:

1. **Entry question.** Ask the user which level to start at: "Campaign-level summary, or drill into a specific campaign?" If the user already named a campaign / ad set / ad in the prompt, skip the ask and start at that level.
2. **Initial pull.** Fire the relevant report at the chosen level (campaign / ad set / ad) per `reports-flow`'s query shape.
3. **Drill question.** After surfacing the rows, ask: "Which row to expand?" — name, id, or ordinal ("the third one"). On answer, pull the next level scoped to that parent only.
4. **Roll back up.** A user saying "back" / "show campaigns again" rewinds one level. Keep the prior result in context so you don't re-pull unchanged data.

Don't surface every level at once. The tree view collapses 3 levels into a single pane visually; in the CLI, three levels of nested rows is unreadable.

## Column defaults — terminal can't render 12+ columns

`get_report_columns` exposes the full column catalogue. A terminal table with 12+ columns wraps into illegible noise. Cut to a sensible default for the CLI surface, and only expand on explicit request.

**Default columns (CLI surface):**

| When user asks for | Columns to render |
|---|---|
| Default / "show me the report" / "performance" | Name, Spend, `purchase_value` (label "Revenue"), ROAS, CPA, Conversions, Status |
| Specific metric ("show me CPM") | Name, Status, the requested metric, ROAS (anchor) |
| "Everything" / "all columns" | Pass through to `get_report_columns`, render all — warn that it will wrap |
| User names a column set | Pass through to `get_report_columns`, render that set |

The 7-column default is opinionated, not authoritative — `reports-flow` is the source of truth for what columns exist and how they're shaped. If a default column isn't available at the level being queried (e.g. some columns only exist at ad-set level), fall back to what `get_report_columns` returns for that level and surface the substitution.

## Date defaults

- Default range: **last 30 days, workspace timezone.**
- Surface the date range explicitly in every response: `"Performance for the last 30 days (workspace TZ):"` — the user can't see a date picker, so the range has to be in the text.
- If the user names a range ("last 7 days", "April", "since Monday"), parse it and pass through per `reports-flow`'s date-shape rules.
- Set the range as a session default at the first report request; don't re-ask on every subsequent drill. If the user wants to change it, they'll say so.

## Currency rule — defer to the canonical skill

`reports-flow` carries the load-bearing rule: **reports endpoints return dollars** (not cents) for spend / CPC / CPM / CPA. This is the **opposite** of the campaign-creation endpoints, which use cents. The reports rule overrides the campaign-side cents rule for any number coming out of the reports endpoint.

CLI surface obligation: **quote the unit explicitly in every line** that surfaces a monetary value — `"Spend: $1,234 (USD)"`, not bare `"1234"`. The user can't hover a column header to check; the unit has to be in the text.

When in doubt, re-read `reports-flow`. Don't infer from field names.

## Output formatting

- **≤10 rows:** render as a markdown table with the default columns.
- **>10 rows:** paginate. Show top 10 sorted by ROAS desc (or by the metric the user named), then prompt: `"Show next 10?"`. Don't dump 200 rows into the terminal.
- **CSV-style export:** the FE has a CSV download button; the CLI doesn't. Surface the raw `call_api` response as a fenced code block the user can copy into a spreadsheet. Mention that there's no FE download from this surface so they know why they're getting JSON.
- **Aggregate footer:** when paginating, surface workspace-level totals (total spend, total `purchase_value` shown as "Revenue", blended ROAS) as a one-line footer so the user has the headline number without paging through.

## Common mistakes (CLI-specific)

| Mistake | Reality |
|---|---|
| Quoting spend in cents because "campaign endpoints use cents" | WRONG. Reports endpoints return **dollars**. The reports rule overrides the campaign cents rule for spend / CPC / CPM / CPA. See `reports-flow` for the canonical wording. |
| Rendering all 12+ columns in a terminal table | Unreadable — wraps into noise. Respect the 7-column CLI default unless the user explicitly asks for "everything" or names a column set. |
| Asking for the date range on every drill turn | Set the session default at the first report request. Don't re-ask. If the user wants a different range, they'll name it. |
| Fabricating endpoint paths or column names | Always go through `list_endpoints(filter="reports")` and `get_report_columns` first. Never type out a path from memory. |
| Surfacing all three levels (campaign + ad set + ad) at once | The CLI has no tree to collapse; nested 3-level rows are unreadable. Ask which level, render one level at a time. |
| Skipping the unit on monetary values ("Spend: 1234") | Quote the unit every time. The user can't hover a column header in the terminal. |
| Re-pulling the same parent rows after a drill-down | Keep the prior result in context; only fire a new call when the level or scope actually changes. |

## Quick reference — MCP tools

| Op | Tool | Notes |
|---|---|---|
| Discover available columns | `get_report_columns` | Per `reports-flow`. Levels may have different column sets. |
| Pull a report at a level | `get_overall_report` | Query shape, date/timezone/pagination defaults all in `reports-flow`. |
| Dashboard-shaped query | `get_dashboard_report` | Per `reports-flow`. |
| Assets overview | `get_assets_overview` | Per `reports-flow`. |

Don't quote paths from memory — resolve via `list_endpoints(filter="reports")` and let `reports-flow` carry the query shape.

## Cross-links

- [[coinis-image-from-url]] — image creative generation flow.
- [[coinis-video-from-url]] — video creative generation flow.
- [[coinis-campaign-flow-cli]] — CLI overlay for campaign creation / edits (where cents-not-dollars applies).
- in-MCP `creative-generation` playbook — credit-spend gate rules for generation endpoints (`load_skill('creative-generation')`).

## Why this skill exists

The in-MCP `reports-flow` skill assumes a multi-pane dashboard surface: a tree view to drill the campaign → ad set → ad hierarchy, a column manager to toggle 30+ fields, a date picker, an inline CSV download. Claude Code's surface is a chat-and-table affordance — no tree, no column manager, no CSV button. This overlay handles the rendering and the drill-down questions; everything numeric (column schema, query shape, the dollars-from-the-reports-endpoint currency rule) stays with the canonical skill. Keep the split clean: if a behavior is about how the agent talks to the user, it belongs here; if it's about what to send the API or how to interpret the response, defer to `reports-flow`.
