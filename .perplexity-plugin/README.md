# Coinis on Perplexity

Perplexity (web, desktop, Comet browser) supports MCP via **Connectors** in the Perplexity Hub. Once connected, the Coinis tools become callable inside any Perplexity thread or Comet agent task.

## Connect

1. Open Perplexity → **Settings → Connectors → Add connector → MCP**.
2. Use:
   - **Name:** Coinis
   - **URL:** `https://mcp.coinis.com`
3. Authorise — the Coinis MCP runs an OAuth flow on first use.
4. Save. Perplexity will surface `coinis` tools alongside web search.

## Verify

Ask in a Perplexity thread: "List my Coinis workspaces" — Perplexity should call `list_my_workspaces` and surface the workspace JSON. If it falls back to web search instead, the connector is not active for this thread (toggle it on under the **Sources** picker).

## Notes

- Perplexity's strength is information retrieval + reasoning; for heavy creative-generation flows (UGC video, batch image fan-out), a CLI client (Claude Code, Codex) is a better fit.
- Comet browser passes URLs directly to MCP tools — so "generate an ad image for THIS page" works on whatever tab the user is viewing.
- For example prompts, see [`../README.md`](../README.md).
