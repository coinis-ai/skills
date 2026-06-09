# Coinis on Warp

Warp terminal's **Agent Mode** supports MCP servers via Warp settings or a config file.

## Connect

1. Open Warp → **Settings → AI → Agent Mode → MCP Servers → Add server**.
2. Use:
   - **Name:** coinis
   - **URL:** `https://mcp.coinis.com`
   - **Transport:** HTTP
3. Save. The Coinis tools become available to Warp's agent for any terminal task.

## Verify

In Warp, run an Agent Mode prompt: "Use Coinis to list my workspaces." The agent should call `mcp__coinis__list_my_workspaces` and surface the result inline in the terminal.

## Notes

- Warp's agent is terminal-native — useful for one-off creative generation as part of a build / deploy / asset-ship workflow ("generate a hero image for the new SKU, then `aws s3 cp` it to the CDN").
- For example prompts, see [`../README.md`](../README.md).
