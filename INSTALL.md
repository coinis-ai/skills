# Installation

Coinis skills install into Claude Code, Codex, or Cursor — and run against any MCP-capable client. There are two halves to a working setup, in order:

1. **Configure the Coinis MCP server** so the `mcp__coinis__*` tools are reachable. This is the part most people miss — without it the skills load but have nothing to call.
2. **Install the skills** for your client.

Then run the **Verify it works** check at the bottom to prove both halves landed.

## Prerequisites

1. A working installation of one of:
   - [Claude Code](https://docs.claude.com/claude-code) (CLI, IDE extension, or desktop app)
   - [Codex](https://openai.com/codex)
   - [Cursor](https://cursor.com)
   - …or any other MCP-capable client (VS Code/Copilot, Cline, Warp, Windsurf, ChatGPT, Manus, Perplexity — see [Connect any other client](#connect-any-other-client)).
2. A Coinis account with workspace credits. Sign up at [coinis.com](https://coinis.com).

You do **not** need the MCP pre-configured — step 1 below sets it up.

## 1 — Configure the Coinis MCP

The skills are a thin overlay; the actual generation, campaign, and reporting work happens through the **Coinis MCP server** at `https://mcp.coinis.com` (HTTP transport). Register it once per client.

**Auth note:** the server handles auth on first use — when a skill fires a tool that needs your Coinis account, the MCP triggers an OAuth-style login/consent flow in your browser. You do not paste an API key into the client config. If your org issues a static token instead, add it as an `Authorization: Bearer <token>` header in the config shapes below (see each client's MCP docs for the exact header field).

### Claude Code

Add the server from the CLI:

```bash
claude mcp add --transport http coinis https://mcp.coinis.com
```

Or, inside a Claude Code session, run `/mcp` and add a server named `coinis` with URL `https://mcp.coinis.com` and transport `http`. Confirm it is connected:

```text
# inside Claude Code
/mcp
```

`coinis` should appear with a connected/ready status. Docs: <https://docs.claude.com/claude-code/mcp>.

### Codex

Add an HTTP MCP server to your Codex config (`~/.codex/config.toml`):

```toml
[mcp_servers.coinis]
url = "https://mcp.coinis.com"
```

Restart Codex so it picks up the new server. Docs: <https://github.com/openai/codex> (MCP / `config.toml` section).

### Cursor

Create or edit `.cursor/mcp.json` in your project (or `~/.cursor/mcp.json` for all projects):

```json
{
  "mcpServers": {
    "coinis": {
      "url": "https://mcp.coinis.com"
    }
  }
}
```

Reload Cursor → **Settings → MCP** should list `coinis` as connected. Docs: <https://docs.cursor.com/context/model-context-protocol>.

### Connect any other client

If you are not on Claude Code / Codex / Cursor, the canonical MCP-add pattern is the same everywhere: register an **HTTP** server named `coinis` pointing at `https://mcp.coinis.com`. Per-client step-by-step guides live in the plugin folders:

- [ChatGPT](.chatgpt-plugin/README.md)
- [Cline](.cline-plugin/README.md)
- [Manus](.manus-plugin/README.md)
- [Perplexity](.perplexity-plugin/README.md)
- [VS Code (Copilot Agent / Continue.dev)](.vscode-plugin/README.md)
- [Warp](.warp-plugin/README.md)
- [Windsurf](.windsurf-plugin/README.md)

## 2 — Install the skills

### Claude Code

#### Option A — Install from the marketplace (recommended)

```text
# inside Claude Code
/plugin marketplace add coinis-ltd/skills
/plugin install coinis
```

#### Option B — Local checkout

```text
# inside Claude Code
/plugin marketplace add /path/to/coinis-mcp-skills-prod
/plugin install coinis
```

#### Option C — Symlink for contributors

If you're iterating on the skills, symlink each one into `~/.claude/skills/` so changes are picked up live:

```bash
for skill in coinis-*/; do
  ln -s "$(pwd)/${skill%/}" ~/.claude/skills/"${skill%/}"
done
```

Remove the symlinks before switching back to Option A or B to avoid duplicate registration.

### Codex

```text
# inside Codex
/plugins install coinis-ltd/skills
```

The Codex plugin manifest is at `.codex-plugin/plugin.json` — Codex will discover and surface the skills with default prompts.

### Cursor

```text
# inside Cursor
@plugins add coinis-ltd/skills
```

The Cursor plugin manifest is at `.cursor-plugin/plugin.json`.

### One-shot install script

For first-time setup, the `setup` script bootstraps the most common path (clone + symlink for Claude Code):

```bash
curl -fsSL https://raw.githubusercontent.com/coinis-ltd/skills/main/setup | bash
```

Inspect the script before running it. It clones to `~/.coinis/skills/`, symlinks each skill into `~/.claude/skills/`, and prints next steps for Codex and Cursor. The script installs the **skills**, not the MCP — do step 1 first.

## Verify it works

Two checks. The first proves the **skills** loaded; the second proves the **MCP** is wired and authenticated.

### Check 1 — skills loaded

In any client, ask:

> What Coinis skills are available?

The agent should list the **eight** `coinis-*` skills (image-from-url, video-from-url, competitor-recreate, revisions, batch-patterns, campaign-flow-cli, reports-cli, polling) with their descriptions.

### Check 2 — MCP reachable (runnable first command)

Run a read-only command that hits the MCP but spends **no** credits. Either invoke the reports skill directly (Claude Code):

```text
/coinis:reports-cli
```

…or, in any client, ask in plain language:

> Use Coinis to list my workspaces.

**Success looks like:** the agent calls `mcp__coinis__list_my_workspaces` (you may see a one-time browser auth/consent prompt the first time) and prints back at least one workspace with its name and token balance. That round-trip confirms the MCP is registered, reachable at `https://mcp.coinis.com`, and authenticated.

If `list_my_workspaces` returns an empty list, the MCP is working but the account has no workspace yet — finish onboarding at <https://coinis.com>.

### If verification fails

| Symptom | Fix |
|---|---|
| "What Coinis skills are available?" lists nothing | Skills not installed. For the marketplace install (Options A/B), run `/plugin list` in Claude Code — `coinis` should appear. For the symlink path (Option C) or the `setup` script, the skills are loose symlinks under `~/.claude/skills/` that `/plugin list` does not enumerate — re-ask "What Coinis skills are available?" instead. |
| Skill triggers but says "MCP not configured" / no `mcp__coinis__*` tools | The Coinis MCP server is missing — redo step 1 for your client. |
| `list_my_workspaces` errors with an auth failure | Complete the browser login/consent flow, or check the `Authorization` header if your org uses a static token. |
| Everything registers but tools don't appear | Restart the client since installation. |

## Uninstalling

```text
# Claude Code
/plugin uninstall coinis

# Codex
/plugins uninstall coinis

# Cursor
@plugins remove coinis
```

If you used the symlink option, remove the symlinks from `~/.claude/skills/coinis-*` manually. To remove the MCP server, delete the `coinis` entry from your client's MCP config (for Claude Code: `claude mcp remove coinis`).
