# Coinis on Windsurf

Windsurf's **Cascade** agent supports MCP servers via in-app settings or the `mcp_config.json` file.

## Connect (UI)

1. Open Windsurf → **Cascade → Settings → MCP Servers → Add server**.
2. Use:
   - **Name:** coinis
   - **URL:** `https://mcp.coinis.com`
3. Save and restart Cascade.

## Connect (config file)

Edit `~/.codeium/windsurf/mcp_config.json`:

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

In Cascade, ask: "What Coinis tools do you have?" — Cascade should surface the `mcp__coinis__*` tools and offer to call them.

## Notes

- Cascade has Write Mode (file edits) and Chat Mode (read-only). For creative generation via Coinis, either mode works — the MCP calls don't touch the local filesystem.
- For example prompts, see [`../README.md`](../README.md).
