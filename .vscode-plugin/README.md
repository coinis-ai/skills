# Coinis on VS Code

VS Code supports MCP servers via **GitHub Copilot Chat** (Agent Mode) and via extensions like Continue.dev and Cline.

## Connect via GitHub Copilot Chat (recommended)

Create `.vscode/mcp.json` in your workspace (or add to user settings.json under `mcp.servers`):

```json
{
  "servers": {
    "coinis": {
      "url": "https://mcp.coinis.com",
      "type": "http"
    }
  }
}
```

Reload VS Code. Open Copilot Chat → switch to **Agent mode** — the Coinis tools appear in the tool picker.

## Connect via Continue.dev

In Continue's config (`~/.continue/config.json`), add:

```json
{
  "mcpServers": {
    "coinis": {
      "url": "https://mcp.coinis.com"
    }
  }
}
```

## Verify

In Copilot Chat (Agent mode), run: `#list-tools` (or just ask "what Coinis tools are available?"). You should see `mcp__coinis__*` tools.

## Notes

- The skill files (`SKILL.md`) at the repo root are NOT loaded by VS Code directly — they're authoring docs for the in-MCP playbooks. VS Code consumes the MCP tools (`load_skill`, `generate_*`, etc.), and the MCP server surfaces the playbooks.
- For example prompts, see [`../README.md`](../README.md).
