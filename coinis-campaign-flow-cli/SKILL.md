---
name: coinis-campaign-flow-cli
description: |
  Use when creating, updating, or launching a Meta campaign / ad set / ad on the Coinis MCP from the CLI surface — covers the picker-chain-as-prose translation, the `hasMetaConnection` pre-flight, the creative-id-must-exist-first sequencing rule, and the in-MCP `campaign-flow` playbook reference.
  NOT for: creative generation itself — route image creatives to [[coinis-image-from-url]] and video creatives to [[coinis-video-from-url]]; the render-status wait loop to [[coinis-polling]]; performance reporting to [[coinis-reports-cli]]; and the credit-spend gating on `generate/*` / `revise/*` fires to the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`). This skill only sequences and launches campaigns around creatives that already exist.
allowed-tools: mcp__coinis__load_skill, mcp__coinis__list_my_workspaces, mcp__coinis__list_endpoints
argument-hint: '[workspace] launch|update meta campaign with creative <creative-id> [objective] [budget$] [audience]'
---

# coinis-campaign-flow-cli

## Overview

CLI overlay for Meta campaign creation against the Coinis MCP. The heavy lifting — validation matrices, goal/event/CTA mapping, bid strategy × optimization goal table, the cents-vs-dollars budget rule — lives in the MCP's own `campaign-flow` skill. This file translates the picker-driven and approve-driven UX the in-product agent uses into a sequenced-questions UX the CLI agent can actually emit. Nothing here duplicates the canonical playbook; load that first, then apply this overlay.

## Mandatory pre-flight — load the canonical skill

```python
mcp__coinis__load_skill(name="campaign-flow")
```

That body owns:

- The validation matrices (objective × optimization goal × billing event × bid strategy).
- The goal / event / CTA mapping table.
- The budget conversion rule (the API takes cents; the user thinks in dollars).
- The required vs optional field lists per endpoint.
- The error-recovery patterns for the campaign / ad-set / ad endpoints.

If you have not loaded it, you are guessing. Load it.

## CLI pre-flight checks (unique to this overlay)

### 1. Workspace must have a live Meta connection

`list_my_workspaces` and inspect the chosen workspace's `hasMetaConnection` field.

- `true` → proceed.
- `false` / missing → STOP. Surface to the user: "This workspace isn't connected to Meta yet — campaigns can't be launched from here until you connect a Meta ad account in the Coinis app (Settings → Integrations → Meta). Once that's done, I can resume." Do not attempt any `POST /api/workspaces/{wid}/campaigns/…` call against a workspace without the connection — the BE rejects them and the failure is unhelpful from the CLI.

### 2. Every creative `id` you plan to attach to an ad must already exist with `actionStatus: success`

If the user says "launch a campaign with the UGC video you just generated", that creative's render must be finished first. Cross-ref `[[coinis-polling]]` for the wait pattern. Do NOT bundle a `generate_*` call with the campaign-launch flow in a single approve — the creative `id` doesn't exist until the render lands, the same way `[[coinis-image-from-url]]` forbids bundling generate with anything downstream. Sequencing is: render → poll to `success` → attach to ad.

### 3. Endpoint discovery, not endpoint invention

Before composing any campaign body, run `list_endpoints(filter="campaigns")` to see the routes the MCP actually exposes today (campaigns, ad sets, ads, plus their read / update / delete variants — shapes live in the catalogue, not in memory). The canonical `campaign-flow` skill covers required body fields; the catalogue confirms paths and query params. Don't fabricate either.

## Picker-chain-as-prose translation

The in-product agent emits `request_user_selection` blocks — pill rows of options above the composer. The CLI agent has no such tool. Translate every picker into ONE numbered question with options inline:

> "Which Meta ad account should this campaign run under? (a) Acme Retail – act_123, (b) Acme Wholesale – act_456, (c) other — paste the act_ id."

Rules for the prose translation:

- One picker = one question. Don't pre-emit the next picker's options until the current one is answered.
- For multi-step picker chains (ad account → Facebook page → pixel → audience), enact them as **sequential questions**, not a single multi-part dump. The in-product chain works that way because each pick filters the next picker's options; the CLI flow has to honour the same dependency order.
- When the user has already named one upfront ("use the Acme Retail account, pixel 789"), skip those pickers and only ask about what's missing.
- If the catalogue returns 0 options for a slot (no pages, no pixels), surface the gap — don't fabricate a placeholder id.

## Approve-gate translation — campaign launch IS a high-impact action

The canonical skill specifies a `request_user_approve` block with `tone="warning"` (or `"danger"` for high spend) before any campaign goes live. The CLI agent has no approve block. Replace it with a **prose summary table + one explicit confirm question**, and treat the response strictly.

The summary table must cover:

| Field | Value |
|---|---|
| Workspace | … |
| Ad account | … |
| Facebook page | … |
| Pixel | … |
| Objective | … |
| Daily / lifetime budget | quote in **dollars** — convert from cents per the canonical skill's rule |
| Schedule | start / end (or "ongoing") |
| Audience | … |
| Ad set count | … |
| Creative ids attached | each id + its `actionStatus` |

After the table, ONE explicit question: "Launch this campaign as shown, or adjust something first?"

Response handling — be strict, not loose:

- Explicit "launch" / "go" / "yes, launch" → fire.
- "Looks good" alone → ambiguous; treat as not-yet-approved and ask once more.
- "Wait" / "hold on" / silence / "change the budget to X" / "swap the creative" → re-emit the table with the adjustment, ask again. Do NOT fire on partial signals.
- Any change to budget / creative / audience / schedule mid-flow → the table is now stale, re-emit it before firing.

## Sequencing rules (mirror the canonical skill)

- Campaign before ad set before ad. The child can't reference the parent's `id` until the parent's POST returns.
- Creative `id` from any `generate_*` must be `actionStatus: success` before being attached to an ad. Reference `[[coinis-polling]]` for the wait loop.
- Edits to a live campaign (budget bump, audience swap, status flip) are mutations that affect real spend — emit a **second** approve table for the diff (old → new) before firing the PATCH.

## Common mistakes (CLI-specific)

| Mistake | Reality |
|---|---|
| Bundling "create campaign + create ad set + create ad" into one approve table | Child ids don't exist yet — same no-bundling rule as `[[coinis-image-from-url]]`. Approve once per parent, then chain. |
| Firing on a workspace without `hasMetaConnection: true` | The BE rejects it and the failure surface is unhelpful. Pre-flight `list_my_workspaces` and stop early if the flag is false. |
| Quoting budget to the user in cents | The API takes cents; the user thinks in dollars. Convert per the canonical skill's rule before putting numbers in the approve table. |
| Inventing endpoint paths or body shapes | Run `list_endpoints(filter="campaigns")` and let `mcp__coinis__load_skill(name="campaign-flow")` own the body schemas. |
| Attaching a creative whose render is still `processing` | Wait for `actionStatus: success` first (`[[coinis-polling]]`). Attaching a processing id either 422s or attaches a creative that may end up `failed` after the campaign is already live. |
| Treating "looks good" as a launch confirm | Ambiguous. The CLI has no approve button — require an explicit launch word, or re-ask. |
| Re-emitting the original table after a mid-flow change | Stale. Always re-emit with the diff applied so the user confirms the *current* plan, not the old one. |

## Cross-links

- `[[coinis-image-from-url]]` — bundling rule for `generate_*` + downstream steps.
- `[[coinis-video-from-url]]` — same rule, video flavour; UGC renders take longer, plan the wait.
- `[[coinis-polling]]` — the wait-loop pattern between `generate_*` and campaign-launch.
- `[[coinis-reports-cli]]` — post-launch performance pulls.

## Why this skill exists

The MCP's own `campaign-flow` skill assumes the agent has `request_user_selection` (picker UI) and `request_user_approve` (gate UI) available — the in-product agent has both; the CLI surface has neither. Without this overlay, the CLI agent either invents a picker affordance the user can't interact with, or skips the gate entirely and fires a live campaign on prose ambiguity. This file encodes the affordance translation and the CLI-specific pre-flight checks; the validation logic, goal / event / CTA matrices, and budget conversion rule are NOT duplicated here — load the canonical skill for those.
