# Cookbook

Example prompts and the skills they trigger. Use this as a guide for what Coinis skills can do — and as a way to verify your install is working: if a prompt below routes to the named skill(s), the bundle is wired up correctly.

## Quick reference — prompt → skill(s)

The fastest way to find the right recipe. Each row is an example phrasing and the skill(s) it should trigger. All 9 skills are covered.

| Say something like… | Triggers |
|---|---|
| "Make a 1080×1080 ad image for `https://shop.example.com/earbuds`" | [`coinis-image-from-url`](coinis-image-from-url/SKILL.md) + [`coinis-polling`](coinis-polling/SKILL.md) |
| "Create a 9:16 UGC video for that product" | [`coinis-video-from-url`](coinis-video-from-url/SKILL.md) + polling |
| "Which model should we use for this?" / "use Seedance 2.0 for the hero clip" / "keep the same bottle across all 5 shots" | [`coinis-marketplace-models`](coinis-marketplace-models/SKILL.md) + polling |
| "Which image model should we use — Seedream 4.5 or 5.0 Lite?" / "generate this one on Seedream" | [`coinis-marketplace-models`](coinis-marketplace-models/SKILL.md) + polling |
| "Recreate this competitor's ad in our brand: `<url>`" | [`coinis-competitor-recreate`](coinis-competitor-recreate/SKILL.md) |
| "Give me 4 variations of #3703 / translate it to German / upscale it / resize it to 9:16" | [`coinis-revisions`](coinis-revisions/SKILL.md) |
| "4 squares + 2 stories for each of these 12 SKUs" | [`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md) |
| "Launch a Meta campaign for these creatives, $50/day" | [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md) |
| "What's my ROAS by ad set last week?" | [`coinis-reports-cli`](coinis-reports-cli/SKILL.md) |
| "Did the empty response charge me?" | [`coinis-polling`](coinis-polling/SKILL.md) |
| "It's been 3 minutes — is my video done yet?" | [`coinis-polling`](coinis-polling/SKILL.md) |

Slash-command entry points for the render/iteration skills: `/coinis:competitor-recreate`, `/coinis:revisions`.

Spend is gated by the live MCP itself: before any paid `generate/*` / `revise/*` fire, the agent POSTs the sibling `…/preview_cost/` to surface `tokenCost` + `currentBalance` and proceeds only on explicit consent and `sufficient: true`. This gate is owned by the in-MCP `creative-generation` playbook (`load_skill('creative-generation')`).

---

## 1. Generate an ad image from a product URL

> Make me a 1080×1080 ad image for https://shop.example.com/products/wireless-earbuds

**Skills involved:** [`coinis-image-from-url`](coinis-image-from-url/SKILL.md), [`coinis-polling`](coinis-polling/SKILL.md).

**Why this is powerful:** A raw product URL the workspace has never seen becomes a render-ready ad creative in one turn — the agent silently runs brand/product setup so you never touch the brand-builder UI.

**What happens:**
1. Agent checks if the product URL already exists in the workspace; if not, runs the brand/product setup flow.
2. Previews cost via `generate/image_templates/preview_cost/`, surfaces `tokenCost` + `currentBalance`, then fires `generate/image_templates` against the Coinis MCP on consent.
3. Polls first at ~60 s, then every 30 s. Surfaces the rendered URL when ready.

## 2. Generate a 9:16 UGC video

> Create a 9:16 UGC video for that same product

**Skills involved:** [`coinis-video-from-url`](coinis-video-from-url/SKILL.md), [`coinis-polling`](coinis-polling/SKILL.md).

**Why this is powerful:** A URL-driven UGC pipeline — no actor, no shoot, no editing timeline. The whole UGC creative comes out of one prompt.

**What happens:**
1. Agent confirms aspect ratio (`9:16` or `16:9` only — no 1:1 / 4:5 for UGC).
2. Previews cost via `generate/ugc_video/preview_cost/`, surfaces `tokenCost` + `currentBalance`, and proceeds only on explicit consent and `sufficient: true`. Agent picks sensible defaults for the rest.
3. Fires `generate/ugc_video`. Polls every 180 s — uses `ScheduleWakeup` to avoid burning context.
4. Surfaces the rendered URL when ready.

## 3. Batch creatives across multiple products

> Generate 4 square + 2 story images for each of these 12 SKUs

**Skills involved:** [`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md).

**Why this is powerful:** One sentence fans out into dozens of parallel renders with honest count math — you get the whole matrix without babysitting each POST, and the cost is previewed up front so there are no surprises.

**What happens:**
1. Agent previews cost via `preview_cost/`, surfaces the total `tokenCost` + `currentBalance`, and asks once if budget allows.
2. Fans out parallel POSTs (one per product × format).
3. Surfaces a per-batch summary, not per-creative — keeps the conversation skimmable.
4. Honest count math across format collapse (e.g. story + reel may collapse server-side; reports the actual unique creative count).

## 4. Launch a Meta campaign

> Launch a campaign for these three creatives, $50/day, US/UK audience, last 90 days lookback

**Skills involved:** [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md).

**Why this is powerful:** The in-product picker chain — objective, audience, placements, budget — collapses into a short prose Q&A, so you launch Meta ads from the terminal without ever opening Ads Manager.

**What happens:**
1. Agent pre-flights the workspace's `hasMetaConnection` flag.
2. Translates the in-product picker UX into sequenced prose questions: objective, audience, placements, budget.
3. Creates the Meta campaign / ad set / ad atomically. Surfaces preview + spend cap before fire.

## 5. Pull last week's performance report

> What's my ROAS by ad set for last week?

**Skills involved:** [`coinis-reports-cli`](coinis-reports-cli/SKILL.md).

**Why this is powerful:** Performance data drilled down by prose ("now show me ad-level for ad set X") instead of clicking through a dashboard tree — terminal-width tables, sensible date defaults, dollars normalized correctly.

**What happens:**
1. Agent picks a sensible default date range (last 7 days, account timezone).
2. Pulls ROAS / CPA / spend at the requested granularity.
3. Renders a 7-column table for terminal-width output. Drills down via prose ("show me ad-level for ad set X") rather than a UI tree.

## 6. Revise an existing creative

> Give me four variations of #3703, then translate it to German and upscale it

**Skills involved:** [`coinis-revisions`](coinis-revisions/SKILL.md) (`/coinis:revisions`).

**Why this is powerful:** Five iteration ops — `variate`, `resize`, `translate`, `upscale`, `ad_copy` — over a creative you already own. Localizing or A/B-fanning a winning creative is cheap, and `revise/ad_copy` is the one zero-cost endpoint.

**What happens:**
1. Agent confirms the source creative `id` exists and has rendered (you can't revise something still in flight).
2. For paid ops (`variate`, `resize`, `translate`, `upscale`), previews cost via the sibling `…/preview_cost/` and proceeds on consent; `ad_copy` is zero-cost and fires directly.
3. Fires the matching `revise/*` endpoint per request — `variate` for "more like this", `translate` with `languages`, `upscale` for resolution, `ad_copy` for text. Returns NEW creative ids — revise never mutates the source.
4. For body shapes beyond `revise/resize`, the agent reads accepted fields from `load_skill('creative-generation')` rather than inventing them.

## 7. Recover from a `{"error": ""}` response

> The UGC video call returned empty — did it bill me?

**Skills involved:** [`coinis-polling`](coinis-polling/SKILL.md).

**Why this is powerful:** An empty error body normally looks like a dead end. The agent knows this specific failure shape means "the record was created but the serializer choked" — so it recovers the real result instead of leaving you guessing whether you were charged.

**What happens:**
1. Agent recognises `{"error": ""}` as the "BE serializer failed on a record it already created" shape.
2. Verifies post-hoc with `GET /generated_creatives/?ordering=-id` (sort by `id` desc, NOT `createdAt`, NOT `tokenBalance`).
3. If a record exists with the correct URL → it billed; reads the balance delta to confirm the charge. Does not promise a refund.

## 8. Recreate a competitor's ad in your brand

> Here's a competitor's ad: https://example.com/their-ad.jpg — do our version of this for product #482

**Skills involved:** [`coinis-competitor-recreate`](coinis-competitor-recreate/SKILL.md) (`/coinis:competitor-recreate`).

**Why this is powerful:** A Coinis-unique capability with no competitor analog — ingest a rival's ad and re-render it in *your* brand palette, voice, and product. Competitive teardown-to-creative in one step.

**What happens:**
1. Agent takes the competitor reference (URL or uploaded image) plus the target brand/product to render it for (#482).
2. Loads the authoritative request shape via `load_skill('creative-generation')` before firing — the body is owned upstream, not hardcoded here.
3. Previews cost via `generate/competitor_recreate/preview_cost/`, surfaces `tokenCost` + `currentBalance`, and fires `generate/competitor_recreate` on consent — which recreates the source ad in the user's own brand style.
4. Polls and surfaces the rendered URL.

---

## Multi-skill chains — the full funnel

The recipes above are single moves. The real leverage is chaining them: a product URL becomes a creative, the creative launches a campaign, and the campaign's ROAS comes back to the same terminal — all without leaving the CLI.

### Chain A — URL → creative → Meta campaign → ROAS

**Goal:** Go from a bare product link to a live Meta campaign and its first performance read in one session.

**Chains:** [`coinis-image-from-url`](coinis-image-from-url/SKILL.md) → [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md) → [`coinis-reports-cli`](coinis-reports-cli/SKILL.md) (with [`coinis-polling`](coinis-polling/SKILL.md) along the way).

**Why this is powerful:** This is the entire acquisition funnel — make the asset, ship the ad, read the result — collapsed into a conversation. No hand-offs between a designer, a media buyer, and an analyst; one operator drives all three.

**What you say:**

> Make a 1080×1080 ad image for https://shop.example.com/sneakers, then launch a Meta campaign for it at $50/day to a US/UK audience. Once it's been live a few days, pull the ROAS.

**What the agent does:**
1. **Creative** ([`coinis-image-from-url`](coinis-image-from-url/SKILL.md)): silent brand/product setup for the new URL → previews cost via `preview_cost/` and fires `generate/image_templates` on consent → polls (~60 s, then 30 s) → surfaces the rendered creative **id** and URL. The creative id is the hand-off token for the next step.
2. **Campaign** ([`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md)): pre-flights `hasMetaConnection` → because the **creative id must exist first**, it uses the id from step 1 → walks objective / audience (US/UK) / placements / budget ($50/day) as prose → creates campaign + ad set + ad, surfacing preview + spend cap before fire.
3. **Report** ([`coinis-reports-cli`](coinis-reports-cli/SKILL.md)): later in the session (or on a fresh run), pulls ROAS / CPA / spend for that campaign, default last-7-days in account timezone, rendered as a terminal-width table.

**Tip:** The sequencing rule is load-bearing — the campaign step cannot reference a creative that hasn't rendered. Let polling finish in step 1 before launching.

### Chain B — Batch creatives → campaign → report (scaled funnel)

**Goal:** Stand up a whole catalog's worth of creatives, launch against them, and measure — without doing it 12 times by hand.

**Chains:** [`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md) → [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md) → [`coinis-reports-cli`](coinis-reports-cli/SKILL.md) (surfaced by [`coinis-polling`](coinis-polling/SKILL.md)).

**Why this is powerful:** The batch step turns one prompt into dozens of parallel renders; the campaign step consumes that whole set of creative ids at once; the report step reads them all back. It's the small-team way to run catalog-scale paid social.

**What you say:**

> Generate 4 square + 2 story images for each of these 12 SKUs, then launch a Meta campaign across all of them at $200/day, US audience. Show me ROAS by ad set after the weekend.

**What the agent does:**
1. **Batch** ([`coinis-batch-patterns`](coinis-batch-patterns/SKILL.md)): previews the total cost once via `preview_cost/`, asks if budget allows, then fans out parallel POSTs (product × format). Reports honest unique-creative count after server-side format collapse — the set of creative **ids** is the hand-off.
2. **Polling** ([`coinis-polling`](coinis-polling/SKILL.md)): waits for the batch to render, using `ScheduleWakeup` so a large set doesn't burn context in a tight loop. Surfaces a per-batch summary.
3. **Campaign** ([`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md)): with every creative id now rendered, launches one campaign across the set at $200/day, US audience — again honoring the creative-id-must-exist-first rule.
4. **Report** ([`coinis-reports-cli`](coinis-reports-cli/SKILL.md)): pulls ROAS **by ad set** so you can see which SKU/format combinations are winning, terminal-width table, drill down by prose.

### Chain C — Hero image → resize fan-out → campaign

**Goal:** One hero render, reframed cheaply into every placement, then shipped.

**Chains:** [`coinis-image-from-url`](coinis-image-from-url/SKILL.md) → [`coinis-revisions`](coinis-revisions/SKILL.md) → [`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md).

**Why this is powerful:** You render the hero asset once, then reframe it per placement with cheap `revise/resize` — the generation step is amortized across the whole campaign instead of repeated per format.

**What you say:**

> Make a hero image of product #482, then give me feed (1:1), story (9:16) and landscape (16:9) versions, and launch a Meta campaign with all three.

**What the agent does:**
1. **Hero** ([`coinis-image-from-url`](coinis-image-from-url/SKILL.md)): previews cost via `preview_cost/`, fires `generate/image_templates` on consent, surfaces the rendered hero creative id.
2. **Reframe** ([`coinis-revisions`](coinis-revisions/SKILL.md)): reframes each placement with `revise/resize` — previewing cost via the sibling `…/preview_cost/` before each paid fire — to crop / letterbox the hero into 1:1, 9:16 and 16:9. Each resize returns a NEW creative id and never mutates the hero.
3. **Campaign** ([`coinis-campaign-flow-cli`](coinis-campaign-flow-cli/SKILL.md)): launches with all three rendered placement creative ids.

## Patterns these recipes share

Four principles run through every recipe above — reach for them by default:

1. **Preview cost, then iterate on the cheap surface.** When a base creative already exists, prefer a `revise/*` over a fresh paid `generate/*` — `revise/ad_copy` is zero-cost (Recipe 6) and `revise/resize` reframes an existing hero for a fraction of a new render (Chain C). Always POST the sibling `…/preview_cost/` before any paid fire.
2. **Render the hero once, reframe per placement.** One paid `generate` amortized across 1:1 / 9:16 / 16:9 with `revise/resize` (Chain C) beats N full generations.
3. **The creative `id` is the hand-off token.** Every chain threads the rendered `id` from generate → campaign → report; the campaign step can't reference a creative that hasn't rendered, so let polling finish first (Chains A/B).
4. **Let the in-MCP playbook own prompts and costs.** Read request bodies and `tokenCost` from `load_skill('creative-generation')` / `preview_cost` at call time — never hardcode a body shape or a token number in the CLI overlay.

---

For more examples and the full triggering catalogue, see [`tests/marketer-scenarios.md`](tests/marketer-scenarios.md) (day-in-the-life personas) and [`tests/end-to-end-use-cases.md`](tests/end-to-end-use-cases.md) (API-shaped use cases).
