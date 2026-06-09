# Coinis on ChatGPT

ChatGPT (web, desktop, mobile) connects to MCP servers via **Connectors**. Once the Coinis MCP is connected, the Coinis skills become available inside any ChatGPT conversation.

## Connect

1. Open ChatGPT → **Settings → Connectors → Add custom connector**.
2. Pick **MCP server** as the type.
3. Use:
   - **Name:** Coinis
   - **URL:** `https://mcp.coinis.com`
   - **Authentication:** OAuth (the Coinis MCP handles the auth flow on first use).
4. Save. ChatGPT will surface the `coinis` MCP's tools in any conversation.

ChatGPT's connector system loads the upstream Coinis MCP playbooks (via `list_skills` / `load_skill`). The CLI-overlay skills in this repo are designed for terminal clients (Claude Code, Codex, Cursor) — on ChatGPT, the in-MCP playbooks are the primary surface.

## Verify

Ask: "What Coinis tools do you have?" — ChatGPT should list the `mcp__coinis__*` tools (`list_skills`, `list_endpoints`, etc.).

## Notes

- The Custom GPT format also supports MCP-via-Actions if your account doesn't have Connectors yet. See OpenAI's MCP documentation for the latest available path.
- For example prompts that drive the skills, see [`../README.md`](../README.md).
