# Coinis on Manus

Manus is an autonomous AI agent platform. Manus connects to MCP servers via its **Connectors** / **Tools** settings.

## Connect

1. Open Manus → **Workspace → Tools → Add MCP server**.
2. Use:
   - **Name:** coinis
   - **URL:** `https://mcp.coinis.com`
   - **Authentication:** OAuth (the Coinis MCP runs the auth flow on first use)
3. Save. Manus's planner will now consider Coinis tools when decomposing tasks that involve ad creative generation, campaign launch, or performance reporting.

## Verify

Give Manus a task like: "Generate 4 image variations for https://shop.example.com/products/wireless-earbuds and report which one is highest-CTR after 24h." Manus should:

1. Call Coinis to generate the variations.
2. Pull performance data via Coinis after the wait window.
3. Report back.

## Notes

- Manus's autonomy makes the MCP's `preview_cost` gate matter more, not less — before any paid `generate/*` / `revise/*` fire, Manus should call the `…/preview_cost/` sibling and confirm the returned `tokenCost` with a human. Set Manus's spend cap accordingly.
- For example prompts, see [`../README.md`](../README.md).
