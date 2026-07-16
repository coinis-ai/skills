---
name: New skill request
about: Propose a new Coinis skill or new endpoint coverage in an existing skill.
labels: enhancement
---

## What user task does this enable

<!-- Describe the prompt or workflow that this skill would handle. -->

## New skill, or an addition to an existing one?

<!-- Pick one. This is the anti-sprawl gate: if it can fit inside an existing coinis-* skill, it should be an addition, not a new top-level skill. -->

- [ ] New top-level skill (`coinis-<short-name>/`)
- [ ] New endpoint coverage / rule inside an existing skill: `coinis-<which>`

**Why a separate skill, not an addition to an existing `coinis-*` skill?**

<!-- Required if you picked "New top-level skill". Name the closest existing skill and say why this does NOT belong inside it. -->

## Routing — NOT for

<!-- Which sibling coinis-* skill owns the cases this one should NOT handle? Use the [[skill-name]] cross-link form; this becomes the description's "NOT for:" clause. -->

## Triggering condition

<!-- The single dense `Use when …` sentence that would go in the skill's frontmatter description (triggering conditions only, not the workflow). -->

**A few example user utterances that should route here** (these inform, but do NOT become, the single `Use when …` line):

<!-- e.g. "make a 9:16 version of #3703", "translate this creative to German" -->

## MCP endpoints involved

<!-- list_endpoints / list_skills entries and observed request shapes. Only real, verified endpoints — do not propose a skill for an endpoint you haven't confirmed exists. -->

## Rules / failure modes

<!-- Cost gate? Polling cadence? Does it override an upstream in-MCP skill? Known failure modes you've observed? -->

## Frontmatter

<!-- Don't paste a full stub here. The canonical frontmatter shape (name; description with "Use when …" + "NOT for:"; argument-hint; allowed-tools — and NO per-skill version field) lives in CONTRIBUTING.md → "Adding a new skill". Follow that. -->

## Public-safety check

- [ ] This skill can be public (no business strategy, customer pricing, internal infra, etc.).
- [ ] The backing MCP endpoint(s) actually exist (verified via `list_endpoints` / `list_skills`) — this is not a request to invent a capability.
