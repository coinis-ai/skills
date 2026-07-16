---
name: coinis-polling
description: |
  Use when waiting for a Coinis MCP `generate_*` or `revise_*` job to finish in the CLI surface — covers per-creative-type polling cadences, the `aiResults[]` job-status shape, sort-by-id rule, `{"error":""}` post-hoc verification, and `ScheduleWakeup` integration.
  NOT for: the brand/product setup or fire sequence for images ([[coinis-image-from-url]]) or videos ([[coinis-video-from-url]]); or multi-creative fan-out math ([[coinis-batch-patterns]]). This skill starts AFTER a creative id exists and ends when its URL resolves.
allowed-tools: mcp__coinis__call_api, ScheduleWakeup
argument-hint: <creative-id> [workspace-id] (or the job you just fired)
---

# coinis-polling

## Overview

Coinis MCP (`coinis`) creative generation is async. The in-product agent surfaces live progress cards in the FE — the upstream `creative-generation` skill explicitly says "agent does NOT poll" because the FE owns that loop. The MCP-client / Claude Code surface has no such cards, so **that rule is wrong for the CLI** and this skill overrides it: the CLI agent MUST poll to surface the rendered URL. Use `ScheduleWakeup` for long-running jobs to avoid burning context on tight loops.

## Per-creative-type polling cadence

Cadences below are derived from live-run measurements of each endpoint.

| Endpoint family | First poll | Typical render | Notes |
|---|---|---|---|
| `generate/image_templates` | 60 s | 60–80 s (measured 58 / 59 / 83 s) | Re-poll every 30 s after first if still processing. |
| `generate/competitor_recreate` | 60 s | similar to image_templates | Same renderer class. |
| `revise/variate`, `revise/resize`, `revise/translate`, `revise/upscale` | 30 s | 20–60 s | Creates a NEW creative id. |
| `revise/ad_copy` | 30 s | 20–60 s | No new creative id — result lands on source's `aiResults[]`. See child-job shape below. |
| `generate/ugc_video` | 180 s | observed ~9 min (past the original 2–5 min envelope) | Long. Use `ScheduleWakeup(delaySeconds=180)`. |
| `generate/cinematic_video` | 180 s | no live data — match UGC heuristic | Long video renderer; match UGC cadence and keep waking up past the 2–5 min envelope. |
| `generate/video_to_video` | 180 s | unverified (processing at report time in run logs) | Match UGC cadence. |
| `generate/avatar/generate`, `generate/avatar/talking_head` | 180 s | no live data — match UGC heuristic | Avatar discovery blocked on `avatarId` in catalogue. |

## The GET shape

```
GET /api/workspaces/{wid}/generated_creatives/{cid}/
```

Watch `actionStatus`:

- `processing` → keep polling.
- `success` → `imageUrl` (or `videoUrl`) is now populated and authoritative. Quote that URL.
- `failed` → read `errorMessage`. Stop polling. Surface to user.

Rendered assets land on the workspace's configured CDN; the GET response is the only authoritative source for the final URL.

## `aiResults[]` — the child-job shape

For most creatives the top-level `actionStatus` is the source of truth. **One exception:** `revise/ad_copy` doesn't create a new creative — it appends a child job to the SOURCE creative's `aiResults[]` array under `result_data`.

Field shape on the source creative after `revise/ad_copy` resolves:

```json
{
  "aiResults": [
    {
      "job_id": "...",
      "status": "success",
      "action": "ad_copy",
      "started_at": "...",
      "completed_at": "...",
      "result_data": {
        "headlines": [... 5 ...],
        "primaryTexts": [... 5 ...],
        "descriptions": [... 5 ...],
        "ctaLabel": "...",
        "displayLink": "..."
      }
    }
  ]
}
```

To poll: `GET /generated_creatives/{source_id}/`, then find the entry in `aiResults[]` with the matching `action: "ad_copy"` and `job_id` returned by the POST. Wait for that entry's `status: "success"`. Do NOT look for a new creative id — there isn't one.

## Sort / listing rules

- **Sort by `id` desc, NOT `createdAt`.** Bulk image fans-out write the same `createdAt` timestamp across N records (e.g. `quantity=4` returns 4 creatives with identical timestamps). `id` is monotonic and unambiguous:

  ```
  GET /api/workspaces/{wid}/generated_creatives/?ordering=-id
  ```

- **Don't use the list endpoint to find a single creative you already have the id for.** It's verbose and pages over the whole workspace. Hit `GET /generated_creatives/{id}/` directly.
- For post-hoc recovery (see next section), `?ordering=-id&limit=5` is the right shape.

## `{"error": ""}` — post-hoc verification

Some endpoints return `{"error": ""}` while still creating a billed record. Verified for `generate_ugc_video`. Distinct from the `analyze_product` `{"error":""}` bot-block, which is scrape-only and does NOT bill.

Recovery shape when the response is empty but you suspect a record was created:

```
GET /api/workspaces/{wid}/generated_creatives/?ordering=-id&limit=5
```

Find the latest record whose `requestJson.url` (or `productId` / `brandId`) matches the call you just made. That's the creative — poll it normally.

**Don't verify a job by reading a balance delta** — balance lags reservations, doesn't reflect refunds synchronously, and can move up mid-session from top-ups. The creative's `id` existing is the authoritative "did it create a record"; for cost, read the `preview_cost/` flow before firing — see `load_skill('creative-generation')`.

## `ScheduleWakeup` integration

For long-running jobs (UGC, video-to-video, avatar, talking-head), use `ScheduleWakeup` rather than tight polling loops:

```python
ScheduleWakeup(delaySeconds=180)
# On wakeup:
GET /api/workspaces/{wid}/generated_creatives/{cid}/
# If still processing, ScheduleWakeup again at 60–120 s.
```

For images / revises, a single 60-s or 30-s wakeup is usually enough; re-poll inline if the first hit returns `processing`.

## Common mistakes

| Mistake | Reality |
|---|---|
| Polling UGC at 60 s | Wasteful — UGC renders in minutes, not seconds. First poll at 180 s. |
| Polling once for video and giving up before 5 min | Premature. Observed renders past the 2–5 min envelope; one run still processing at ~9 min with no `errorMessage`. Keep waking up. |
| Sorting `GET /generated_creatives/` by `createdAt` desc to find "the latest" | Unreliable — batched creatives share `createdAt`. Sort by `id` desc. |
| Listing the whole workspace to find a known creative id | Don't. Hit `GET /{id}/` directly. |
| Looking for a new creative id after `revise/ad_copy` | There isn't one. The result is on the source's `aiResults[]`. |
| Treating `{"error": ""}` as "didn't fire" | For `generate_ugc_video` it bills and creates a record. Verify via `?ordering=-id&limit=5`. |
| Polling forever on `failed` | `actionStatus: failed` is terminal — read `errorMessage` and stop. |

## CLI-surface UX rules

The CLI surface has no front-end progress cards, so the agent owns how the wait and its result reach the user. Bundle-wide defaults:

1. **Reply in the user's language** — MCP field names, endpoint paths, and `actionStatus` values (`processing`/`success`/`failed`) stay English.
2. **No raw JSON dumps** (no `aiResults[]` arrays, no `call_api` transcripts). Lead with the rendered URL + a one-line summary — but **do** keep the creative `id`/`jobId` as clearly-labeled trace handles; recovery (sort-by-`id`-desc, direct `GET /{id}/`) depends on them.
3. **Never narrate plumbing** — don't say "polling the job", "scheduling a wakeup", or name MCP tools; say "still generating — I'll share the link the moment it lands".
4. **One question at a time** — never batch-ask.

A `failed` `actionStatus` is terminal: surface `errorMessage` and stop; don't retry silently.

## Cross-links

- [[coinis-image-from-url]] — image generation flow (calls into this skill at step 8).
- [[coinis-video-from-url]] — video generation flow (calls into this skill at step 6).
- [[coinis-batch-patterns]] — multi-creative batches share `createdAt` and force the sort-by-id rule.

## Why this skill exists

The upstream `creative-generation` skill assumes the FE owns polling. In the MCP-client surface, the FE doesn't exist, so the agent has to. Cadences here are the ones traceable to the 2026-05-28 live runs — not invented defaults. The `aiResults[]` shape and the sort-by-id rule are the two patterns that consistently bite agents that copy in-product assumptions into the CLI.
