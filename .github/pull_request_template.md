## Summary

<!-- One or two sentences. What changed and why. -->

## Type of change

- [ ] New skill
- [ ] Skill rule clarification / new failure-mode note
- [ ] New endpoint coverage in an existing skill
- [ ] Plugin manifest update (Claude / Codex / Cursor)
- [ ] Doc / cookbook update
- [ ] Cost-gate change (requires product sign-off)
- [ ] Maintenance (CI, scripts, dependencies)

## Public-safety checklist

- [ ] No business strategy, customer-facing pricing, competitor analysis, or team-specific roadmap.
- [ ] No internal hostnames other than `https://mcp.coinis.com`.
- [ ] No credentials, customer data, or internal ticket references.
- [ ] Every `coinis` / `mcp__coinis__*` example in the docs is a real, current MCP command.

## Breaking changes

<!-- None / describe what breaks (a renamed/removed skill, a changed required parameter, a manifest schema change). If yes, add `!` to the commit type — `feat!:` or `fix!:` — and bump the major version. -->

## Version bump

- [ ] N/A — doc-only / non-shipping change
- [ ] Patch (1.0.x) — clarification, doc fix, new failure-mode note
- [ ] Minor (1.x.0) — new skill, new endpoint coverage
- [ ] Major (x.0.0) — breaking rename, removal, or manifest schema change

If you bumped the version: confirm `VERSION` and the three plugin manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`) all match.

## Testing

<!-- How you verified this works. Link to use cases / scenarios touched. -->
