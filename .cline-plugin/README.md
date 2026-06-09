# Coinis on Cline

Cline (a VS Code extension) supports MCP servers via its **MCP Servers** panel and the `cline_mcp_settings.json` file.

## Connect (UI)

1. Open VS Code → Cline panel → **MCP Servers → Configure**.
2. Add a new server:
   - **Name:** coinis
   - **URL:** `https://mcp.coinis.com`
   - **Transport:** HTTP (or SSE, depending on what your Cline version supports)
3. Save. Cline will surface `coinis` tools in the tool picker.

## Connect (config file)

Edit `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` (macOS) — paths differ per OS:

```json
{
  "mcpServers": {
    "coinis": {
      "url": "https://mcp.coinis.com",
      "alwaysAllow": []
    }
  }
}
```

`alwaysAllow` lets you whitelist specific tools to skip the per-call approval modal — leave empty until you trust the flow.

## Verify

In Cline, ask: "List my Coinis workspaces" — Cline should prompt to approve the `mcp__coinis__list_my_workspaces` call.

## Notes

- Cline's per-tool approval modal is useful when first using the Coinis MCP — it surfaces the exact request body before the call fires. Once familiar, add the safe read-only tools (`list_*`, `get_*`) to `alwaysAllow`.
- For example prompts, see [`../README.md`](../README.md).
