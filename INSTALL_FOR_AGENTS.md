# Installation instructions for AI agents

If you are an AI agent installing this plugin for a user, follow these steps. Do not improvise.

There are two halves: (1) configure the **Coinis MCP server**, (2) install the **skills**. Do them in that order, and run the verify command after each.

## Preconditions to verify

1. The user has an MCP-capable agent client running. First-class targets are **Claude Code, Codex, or Cursor**; **any other MCP-capable client** (VS Code/Copilot, Cline, Warp, Windsurf, ChatGPT, Manus, Perplexity) also works — the skills only require that the `coinis` MCP tools become reachable. If the client cannot register an MCP server at all, stop and tell the user.
2. The Coinis MCP server can be pointed at `https://mcp.coinis.com`. If it is not yet configured, **do not stop** — configure it in Step 1 below (with the user's consent). Only stop if the client has no way to add an MCP server.
3. The user has at least one Coinis workspace with a non-zero token balance. If you can query workspaces via the MCP, check before installing; if not, tell the user to verify at <https://coinis.com>.

## Step 1 — Configure the Coinis MCP

Confirm with the user before changing their MCP config. Register an **HTTP** server named `coinis` at `https://mcp.coinis.com`.

| Client | Add command / config |
|---|---|
| Claude Code | `claude mcp add --transport http coinis https://mcp.coinis.com` (or `/mcp` → add server `coinis`, url `https://mcp.coinis.com`, transport `http`) |
| Codex | Add to `~/.codex/config.toml`: `[mcp_servers.coinis]` with `url = "https://mcp.coinis.com"`, then restart Codex |
| Cursor | Add to `.cursor/mcp.json`: `{"mcpServers":{"coinis":{"url":"https://mcp.coinis.com"}}}`, then reload |
| Any other client | Register an HTTP MCP server named `coinis` at `https://mcp.coinis.com`. See the matching `.<client>-plugin/README.md` in this repo for exact UI/config steps. |

Auth: the server runs its own login/consent flow on first tool use — do **not** paste API keys into the config unless the user's org explicitly issued a static token (then add it as an `Authorization: Bearer` header, with consent).

**Verify Step 1:** trigger one read-only, zero-credit call — `mcp__coinis__list_my_workspaces`. Success = the call returns (after any one-time browser auth) at least one workspace. If the tool name is not even available, the MCP is not registered — recheck the config before proceeding.

## Step 2 — Install the skills

| Client | Command |
|---|---|
| Claude Code | `/plugin marketplace add coinis-ltd/skills` then `/plugin install coinis` |
| Codex | `/plugins install coinis-ltd/skills` |
| Cursor | `@plugins add coinis-ltd/skills` |
| Any other client | Skills are an overlay on the MCP playbooks; non-plugin clients consume the MCP tools directly and do not need a separate skill install. Point the user at `.<client>-plugin/README.md`. |

**Verify Step 2:** list installed plugins and confirm `coinis` appears (Claude Code: `/plugin list`). Then ask the agent "What Coinis skills are available?" — it should enumerate the **eight** `coinis-*` skills.

## After install

1. Confirm the plugin is registered: list installed plugins and verify `coinis` appears (skip for non-plugin clients).
2. Confirm the skill set: ask "What Coinis skills are available?" and verify all **eight** `coinis-*` skills are listed (image-from-url, video-from-url, competitor-recreate, revisions, batch-patterns, campaign-flow-cli, reports-cli, polling).
3. Run the combined verify: invoke `/coinis:reports-cli` (Claude Code) or ask "Use Coinis to list my workspaces." Success = `mcp__coinis__list_my_workspaces` returns a workspace with its name and token balance. This proves MCP + skills are both wired.
4. Tell the user: the skills auto-load when the user asks for image/video creative generation, competitor recreation, creative revisions, Meta campaign launch, or performance reports. The user does not need to invoke them by name.

## Do NOT

- Do NOT silently install or silently change MCP config. Always confirm with the user before running an install command or editing their MCP settings.
- Do NOT install a version other than the latest stable unless the user asked for a specific version.
- Do NOT modify the user's MCP configuration to point at a host other than `https://mcp.coinis.com` without explicit consent.
- Do NOT paste credentials/API keys into config; rely on the server's own auth flow unless the user explicitly provides a static token.
- Do NOT fire any paid `generate/*` or `revise/*` call without first calling its `…/preview_cost/` sibling and surfacing the returned `tokenCost` + `currentBalance` to the user for explicit confirmation (proceed only when `sufficient` is true). `revise/ad_copy` is the only zero-cost exception.

## Troubleshooting

| Symptom | First check |
|---|---|
| Plugin install succeeds but skills don't appear | Restart the client. |
| Skill triggers but says "MCP not configured" / no `mcp__coinis__*` tools | The Coinis MCP server is missing from client config — redo Step 1 for the user's client. |
| `list_my_workspaces` returns empty | MCP works but the account has no workspace — tell the user to finish onboarding at <https://coinis.com>. |
| Auth flow opens then fails | The user's Coinis account may not be linked to a Meta ad account; tell them to complete onboarding at <https://coinis.com>. |
