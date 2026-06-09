# Coinis MCP — Marketer Scenarios

End-to-end scenarios that simulate real marketing work: each scenario is a persona, a deadline, a small product portfolio, and the natural-language prompts that person would actually type. The goal is to test the MCP under **realistic multi-product workflows**, not isolated API calls.

Pairs with [`end-to-end-use-cases.md`](end-to-end-use-cases.md) — that doc enumerates the API surface; this doc walks through day-in-the-life sequences that exercise multiple endpoints in the order a marketer would hit them.

**How to read each scenario:**

- **Persona** — who's at the keyboard.
- **Context & goal** — what's happening this week, what gets shipped.
- **Portfolio** — the products in play (URLs anonymized).
- **Session script** — the natural prompts the marketer types, with the expected MCP behavior underneath.
- **Success criteria** — what "done" looks like for the marketer (not for the API).
- **Complications** — realistic things that go wrong and how the agent should handle them.

The scenarios reference use-case IDs from [`end-to-end-use-cases.md`](end-to-end-use-cases.md) as `UC-XX`.

---

## Index

| # | Persona | Portfolio | Primary tools used |
|---|---|---|---|
| [MS-1](#ms-1--shopify-boutique-owner-black-friday-prep) | Maya — Shopify boutique owner | 12 apparel SKUs | image_templates (×4 formats), revise_ad_copy, ugc_video |
| [MS-2](#ms-2--amazon-seller-multi-variant-launch) | Dev — Amazon kitchen-gadget seller | 5 variants of one product | image_templates, revise_resize, revise_translate |
| [MS-3](#ms-3--dtc-skincare-brand-weekly-content-calendar) | Priya — skincare DTC marketer | 8 hero products | image_templates (story), ugc_video, revise_variate |
| [MS-4](#ms-4--saas-founder-landing-page-rebuild) | Alex — solo SaaS founder | 1 product, multiple feature pages | avatar_video (with scripts), image_templates, revise_variate |
| [MS-5](#ms-5--agency-account-manager-three-clients-onboarding) | Sam — agency account manager | 3 clients × ~6 products each | parallel workspaces, brand setup ×3, bulk image batches |
| [MS-6](#ms-6--affiliate-marketer-competitor-clone-sprint) | Jordan — affiliate / arbitrage marketer | 4 unrelated trending products | image_templates, revise_variate, ugc_video |
| [MS-7](#ms-7--restaurant-chain-seasonal-menu-launch) | Lena — restaurant-chain social marketer | 4 seasonal menu items | image_templates (feed + story), revise_translate (regional), ugc_video |
| [MS-8](#ms-8--creator-partner-brand-week) | Kai — content creator, 4 brand partnerships | 4 partner products | ugc_video (per partner), avatar_video, organic publishing |

---

## MS-1 — Shopify boutique owner, Black Friday prep

### Persona

Maya runs an online boutique on Shopify, a small store. She's a one-person team, no design background, has launched ads before but always struggles with creative volume. Black Friday is in 10 days.

### Context & goal

By end of session, she needs ad creatives for her 12 best-sellers ready to launch as a BF campaign on Meta:
- 4 square creatives per product (for feed)
- 2 stories per product (for IG/FB stories)
- 1 UGC video for the top 3 bestsellers
- All with a "30% OFF BLACK FRIDAY" text overlay
- Brand voice: playful, casual

### Portfolio

12 SKUs on `https://mayasboutique.example`:
1. Linen wrap top — `/products/linen-wrap-top`
2. Velvet midi skirt — `/products/velvet-midi-skirt`
3. Crochet tote — `/products/crochet-tote`
4. … (9 more)

### Session script

> **Maya:** "Hey, I'm prepping Black Friday. Can you set up my brand from mayasboutique.example and pull in these 12 products? Here are the URLs: [pastes 12 URLs]"

**Expected flow:**
1. `list_my_workspaces` → pick highest-balance with Meta connection (UC-B1).
2. Brand lookup on `mayasboutique.example` → no match → silent brand create with full identity (UC-C1). Pull `voiceTags` from `analyze_brand_identity`; if "playful"/"casual" appears, default tone shifts (UC-E6).
3. For each URL, `analyze_product` → `POST /products/` (UC-D1). 12 products created in parallel where possible.
4. Surface one summary: brand `#X Maya's Boutique` created, 12 products imported with ids `[…]`.

> **Maya:** "Great. Now make 4 square ads for each one. Just nice product shots, nothing too crazy."

**Expected flow:**
1. For each `pid`, fire `generate_image_templates(outputFormats=["square"], quantity=4, tone="playful", style="bold")` (UC-E2).
2. 12 parallel POSTs → 48 creative records (4 per product), each with own `id`/`jobId`.
3. Surface as a single batch: "48 creatives firing across 12 products. Expect ~55s render per creative; I'll watch them."
4. `ScheduleWakeup(60)` → poll all 48 in parallel; surface as they land (UC-G4).

> **Maya:** "Also 2 stories per product. Vertical format."

**Expected flow:** 12 parallel POSTs with `outputFormats=["story"], quantity=2` → 24 more creatives. Single batch surface. Don't combine `["story","reel"]` — they collapse (UC-E4).

> **Maya:** "Can you slap a Black Friday offer line on all of them?"

**Expected flow:**
1. Wait until base creatives are `success` (ad-copy revision needs the `generatedCreativeId` to exist — bundling forbidden per UC-E9).
2. Fan out `revise_ad_copy(generatedCreativeId=<each>, landingPageUrl=<product page>)` across all 72 creatives — this AI-generates overlay copy from the landing page; it does NOT take a literal `text=`/`placement=` string.
3. Surface plan + result in one turn per batch (UC-H6 is revise/ad_copy).

> **Maya:** "Now make me a UGC video for the linen wrap top, velvet skirt, and crochet tote."

**Expected flow:**
1. Pre-flight `analyze_product` for each — confirm `imageUrls[]` has 2+ product photos (UC-F4 pre-flight).
2. Fire 3 × `generate_ugc_video(url=..., aspectRatio="9:16")` — ONLY `url` + `aspectRatio` in the body (UC-F10).
3. Surface plan + result; quote the previewed `tokenCost` from the `preview_cost` call; schedule wakeup at 180s (UC-G2).

### Success criteria

- 72 image creatives + 3 UGC videos created in one session.
- Maya never sees an "approve to fire" gate for the images or videos (rules: UC-J7, UC-J8).
- She sees ONE "what was created" surface per batch, not 72 turns.
- All creatives have BF text overlay on the polished versions.
- She can hand the creative ids to the campaign launcher (or in the future, UC-L1).

### Complications to handle

- **One product URL is on `instagram.com/p/...`** → not a product page; `analyze_product` returns no imageUrls. Agent flags the URL specifically, asks for the actual Shopify product URL.
- **Workspace runs low on tokens during the batch** → agent surfaces remaining budget vs. remaining work; doesn't silently truncate.
- **Maya says "make them landscape"** → agent surfaces no-landscape API constraint, offers `feed` as substitute (UC-E5).

---

## MS-2 — Amazon seller, multi-variant launch

### Persona

Dev sells kitchen gadgets on Amazon. New product line launches Friday: one product (a vegetable spiralizer) in 5 colorways. He needs A+ content imagery and ads for sponsored placements, plus EU listings in German and Spanish.

### Context & goal

- 5 product variants → each needs 6 lifestyle/A+ images.
- All variants share a parent listing URL; variant-specific URLs differ only by color.
- EU rollout: translate the ad copy + key callouts to DE and ES.

### Portfolio

- Parent: `https://amazon-listing.example/spiralizer`
- Variants: `?variant=green | red | navy | cream | charcoal`

### Session script

> **Dev:** "I'm launching a new spiralizer in 5 colors. Here's the parent: amazon-listing.example/spiralizer. Set up the brand 'KitchenForge' and create products for each of the 5 colorways."

**Expected flow:**
1. Brand lookup → if `amazon-listing.example` doesn't match any brand → silent create with brand name **as user provided** ("KitchenForge"), not whatever `analyze_brand_identity` returns from the Amazon parent page (Amazon pages confuse brand inference). Agent should ASK if the brand name from analysis conflicts with the user's stated name.
2. For each variant URL: `analyze_product` → `POST /products/`. If `analyze_product` returns identical content across variants (Amazon often does this), capture the user's distinguishing field ("color") into the product `description`.

> **Dev:** "Make me 6 photo-realistic lifestyle shots per color. Kitchen counter scene, morning light, fresh vegetables on the side."

**Expected flow:**
1. `additionalInformations="kitchen counter, morning light, fresh vegetables on the side"` — pass through verbatim (UC-E7).
2. `tone="professional"`, `style="photo-realistic"` (lifestyle category override, UC-E6).
3. 5 parallel POSTs, `outputFormats=["square"], quantity=6` → 30 creatives.

> **Dev:** "Resize the best one from each color to portrait too."

**Expected flow:**
1. Wait for renders to land.
2. Dev picks (or agent picks the first `success` per product). **URL-based revise endpoints (resize, translate, variate) cannot take a creative id directly — fetch `imageUrl` first via `GET /generated_creatives/{id}/`, then pass that as `sourceImageUrl`.** Fire 5 × `revise_resize(sourceImageUrl=<fetched imageUrl>, targetAspectRatio="portrait")` (UC-H2).

> **Dev:** "Now generate ad copy for all 5, then translate the copy to German and Spanish."

**Expected flow:**
1. Fan out `revise_ad_copy(generatedCreativeId=<each>, landingPageUrl=<product page>)` across 5 creatives (UC-H6).
2. After ad copy lands, fetch each creative's `imageUrl` via `GET /generated_creatives/{id}/`, then fan out `revise_translate(sourceImageUrl=<fetched>, languages=["de","es"])` — ONE call per creative covers both languages, so 5 translate calls total (the `languages` array, not one call per language).
3. Note: sequencing matters; ad_copy must `success` before translate fires (UC-E9 bundling rule).

### Success criteria

- 30 base creatives + 5 portrait resizes + 5 ad copies + 5 translations (each covering DE + ES).
- Dev gets a single table at the end: variant × format × language → creative id.
- No duplicate brand created from the parent vs. variant URL confusion.

### Complications to handle

- **`analyze_product` returns the same image set for all 5 variants** (Amazon parent URL behavior) → agent uses variant URL with explicit `?variant=` param; if BE still merges them, agent flags it and asks Dev to upload variant-specific photos to the product `image_urls`.
- **Dev asks for "Italian and French too"** mid-flow → agent extends the translate batch without re-running ad_copy.

---

## MS-3 — DTC skincare brand, weekly content calendar

### Persona

Priya is the in-house marketer for a mid-size skincare brand, a high-volume seller. She runs a content calendar — every Monday she ships next week's creative batch: 8 hero products, mix of static + UGC video, Instagram-first.

### Context & goal

Weekly cadence:
- Each of 8 hero products gets 1 IG story (9:16) + 1 IG feed creative (4:5).
- 4 of the 8 (rotating) get a UGC video.
- Variants of last week's top-performing creative for the bestseller.

### Portfolio

8 hero SKUs on `https://glowlab.example`:
- Vitamin C serum, retinol cream, hyaluronic mist, niacinamide toner, sunscreen, eye cream, cleansing balm, body lotion.

### Session script

> **Priya:** "Run this week's batch. Same 8 products as last week."

**Expected flow:**
1. Agent infers from prior session context (or `list_products`) the 8 hero `pid`s — does NOT re-create them.
2. If product list returned matches 8 → confirm one-liner: "Same products as last week, firing 8 stories + 8 feed creatives + 4 UGC videos. Going."

> **Priya:** "Wait, swap out the body lotion for the lip balm — it's been performing better."

**Expected flow:** Agent updates the product list in-flight (does NOT re-fire what was already POSTed).

**Image batch:**
- 8 × `generate_image_templates(outputFormats=["story"], quantity=1, tone="clean", style="clean-minimal")` → 8 stories.
- 8 × `generate_image_templates(outputFormats=["feed"], quantity=1)` → 8 feed creatives. **NOTE:** `feed` is 4:5 portrait crop per the API; do NOT collapse with `story` (different aspect ratios — UC-E4 only applies to story+reel).

**UGC batch:**
- 4 × `generate_ugc_video(url=<product page url>, aspectRatio="9:16")`. Pre-flight `analyze_product` on each to confirm imageUrls (UC-F4).

> **Priya:** "Make 5 variations of the retinol cream creative #4521 — that one popped last week."

**Expected flow:** fetch creative #4521's `imageUrl` via `GET /generated_creatives/4521/`, then make **5 separate `revise_variate(sourceImageUrl=<fetched>, prompt=<variation brief>)` calls** — there is no `quantity=` param; N variants means N calls (UC-H1).

### Success criteria

- 16 images + 4 UGC videos + 5 variations shipped before lunch.
- Priya can answer "what did we ship today?" with one screen.
- Weekly cadence becomes a 3-prompt workflow.

### Complications to handle

- **One product page redirects to `out of stock`** → `analyze_product` returns minimal content; agent flags the product, asks Priya whether to skip it or use last week's creative.
- **A UGC video lands with bad framing** → Priya says "re-fire with a different vibe." Agent re-runs UGC with the SAME url (no tone/script knob to change — UC-F3) and surfaces honestly that variation comes from the BE's stochastic provider, not from user-supplied direction.

---

## MS-4 — SaaS founder, landing page rebuild

### Persona

Alex is a solo founder of a B2B SaaS (analytics dashboard). One product, but it has 6 feature pages, each needing its own hero creative + a short avatar explainer for the landing page.

### Context & goal

- Single product, 6 feature pages → 6 hero images (feed format) + 6 avatar talking-head videos (one per feature).
- Avatar scripts are Alex's own copy — he writes them, the agent never invents.
- After feature creatives, generate 3 variants of the best one for paid social.

### Portfolio

- Product: `https://saas.example/dashboard`
- Feature pages: `/features/cohort-analysis`, `/features/funnels`, `/features/retention`, `/features/integrations`, `/features/api`, `/features/exports`

### Session script

> **Alex:** "Set up the brand from saas.example and create one product per feature page — there are 6."

**Expected flow:**
1. Brand setup from root domain (UC-C1) — SaaS landing pages are usable for brand identity even though they fail UGC pre-flight (UC-C4 / UC-F4).
2. 6 × `analyze_product` + create. Watch: feature pages often have only screenshots and abstract illustrations — `imageUrls` may be sparse. Agent flags this and proceeds; images can still generate (the BE composes from description + brand assets), but UGC video on these URLs WILL fail.

> **Alex:** "Make a feed-format hero image for each. Tech style, clean."

**Expected flow:** 6 × `generate_image_templates(outputFormats=["feed"], quantity=1, tone="professional", style="clean-minimal")`. Tech/SaaS keeps `clean-minimal` (UC-E6).

> **Alex:** "Now I want avatar talking-head videos for each feature. I'll give you the script for each one."

**Expected flow:**
1. Agent confirms: "Talking-head needs the script you want the avatar to speak — paste them and I'll fire 6 in parallel." This is a CONTENT gate, not a spend gate (UC-F6).
2. Alex pastes 6 scripts.
3. 6 × `generate_avatar_talking_head(productId=<each>, prompt=<verbatim script>)`. Agent NEVER paraphrases.
4. Quote the previewed `tokenCost` from the `preview_cost` call; avatar has no measured render time — budget like UGC (first poll ~180 s, observed up to ~9 min).

> **Alex:** "The cohort-analysis hero image is the winner. Make 3 variations."

**Expected flow:** fetch the winning creative's `imageUrl` via `GET /generated_creatives/{id}/`, then make **3 separate `revise_variate(sourceImageUrl=<fetched>, prompt=<variation brief>)` calls** — no `quantity=` param; N variants means N calls (UC-H1).

### Success criteria

- 6 hero images + 6 avatar videos + 3 variants.
- Every avatar speaks exactly Alex's words.
- Alex has copy-pasteable URLs to embed on each feature page.

### Complications to handle

- **Alex asks for UGC video instead of avatar** → agent pre-flights, finds no product photography on SaaS landing pages, and surfaces UC-F4 alternatives (avatar is the right tool here — confirm and proceed).
- **One script is too long for the avatar provider's limit** → BE rejects with a length error; agent surfaces the limit, asks Alex to trim.

---

## MS-5 — Agency account manager, three-clients onboarding

### Persona

Sam manages 3 mid-size ecom clients at a small agency. New month, three new clients to onboard simultaneously. Each has 5–7 products. Each gets a starter creative batch.

### Context & goal

- 3 clients × 1 workspace each (or 1 workspace with 3 brands — depends on how the agency licenses).
- Per client: brand setup, ~6 products, 3 square + 1 story per product.
- Total: ~21 products, ~84 creatives across 3 brand contexts.

### Portfolio

- Client A: `https://clienta.example` — 6 outdoor gear products
- Client B: `https://clientb.example` — 7 home decor products
- Client C: `https://clientc.example` — 5 pet supply products

### Session script

> **Sam:** "I'm onboarding 3 new clients today. Workspace strategy: I want them as 3 separate brands in my agency workspace so I can manage them together."

**Expected flow:**
1. Confirm `wid` of the agency workspace (UC-B2 — Sam named it implicitly).
2. For each client domain, brand lookup → no match → silent create (UC-C1, ×3).
3. **Important:** Run the 3 brand-creates in parallel safely — they're independent POSTs against distinct domains.

> **Sam:** "Pull in these products. Client A URLs: [...]. Client B: [...]. Client C: [...]"

**Expected flow:**
1. ~18 `analyze_product` + `POST /products/` operations. Parallelize within each brand; serialize the brand-id dependency per URL group.
2. Single batch surface at the end: "Imported 18 products across 3 brands."

> **Sam:** "Give each product 3 squares + 1 story. Match the brand voice for each — pull it from the brand profiles you just created."

**Expected flow:**
1. For each product, fire 1 × image_templates `outputFormats=["square"], quantity=3` AND 1 × `outputFormats=["story"], quantity=1` — 2 POSTs per product × 18 = **36 POSTs**, **72 creative records**.
2. `tone`/`style` resolve per-brand from `voiceTags` (UC-E6) — different defaults for Outdoor Gear (bold, photo-realistic), Home Decor (clean-minimal), Pet Supply (playful).
3. Surface as 3 batches grouped by brand, not 72 separate confirmations.

### Success criteria

- 72 creatives delivered with brand-specific tone/style per client.
- Sam has a per-client report he can forward as a Monday update.

### Complications to handle

- **Client B's domain is already a brand in the workspace** (Sam onboarded them before, forgot) → domain match triggers UC-C2; agent asks once: "Use existing #B Client B, or create parallel?" Sam says "use existing."
- **Token budget pacing** → at 72 creatives, agent surfaces estimated total cost up front (predictable for images) and asks once if budget allows, then fires.
- **One client URL list contains duplicates** (e.g., a product slug appears twice with different query strings) → agent dedupes by `url` field and notes the merge.

---

## MS-6 — Affiliate marketer, competitor clone sprint

### Persona

Jordan is an affiliate marketer running paid traffic to ecom offers. Spots winning ads in competitor's Meta Ad Library, clones the angle for the affiliate offer. 4 unrelated trending products across 4 verticals this week.

### Context & goal

- 4 products in: fitness, beauty, kitchen, pets.
- Per product: clone the top competitor angle, then variate to 3 angles, then UGC video for the winner per vertical.

### Portfolio

- Product 1: protein shaker — `https://verticalA.example/sku-1`
- Product 2: scalp serum — `https://verticalB.example/sku-2`
- Product 3: silicone egg molds — `https://verticalC.example/sku-3`
- Product 4: dog enrichment puzzle — `https://verticalD.example/sku-4`

### Session script

> **Jordan:** "Set up 4 new brands and products from these URLs. I'll clone competitor ads next."

**Expected flow:**
1. 4 brand setups (UC-C1, all unknown domains).
2. 4 product setups (UC-D1).

> **Jordan:** "For each product, I'll give you a competitor ad URL or screenshot. Generate the same vibe for my product. Here's the first: [competitor image url]"

**Expected flow:**
1. Per competitor reference, agent uses `revise_variate` if a competitor creative is already in the workspace, OR — more likely — uses `generate_image_templates` with `additionalInformations` describing the competitor scene/copy/composition explicitly. Ad-clone via the UI flow uses a stored ad-reference record; via MCP, the closest path is a richly-described `additionalInformations` line. Agent should ASK Jordan to describe the competitor scene in his own words if no stored ad-reference record exists.
2. Fire 1 image per product with the cloned style brief. Surface plan + result (UC-J7 — no approve gate for images).

> **Jordan:** "Now make 3 variations of each."

**Expected flow:** for each of the 4 base creatives, fetch its `imageUrl` via `GET /generated_creatives/{id}/`, then make **3 separate `revise_variate(sourceImageUrl=<fetched>, prompt=<variation brief>)` calls** (no `quantity=` param) → 12 variations total across the 4 products (UC-H1).

> **Jordan:** "Pick the best of each vertical and make a UGC video."

**Expected flow:**
1. Jordan picks (or agent surfaces the first to land per vertical).
2. 4 × `generate_ugc_video(url=<product page url>, aspectRatio="9:16")`. Note: UGC uses the product PAGE URL, not the creative — UC-F1.

### Success criteria

- 4 cloned base creatives + 12 variations + 4 UGC videos.
- Jordan can move directly to launch (in his own ad manager — Coinis Meta launch is a separate future flow, UC-L1).

### Complications to handle

- **Competitor reference is a video, not a static** → cloning a video angle via MCP doesn't have a direct path today (image_to_video is removed — UC-F9). Agent suggests: shoot/source a base video and use V2V style transfer (UC-F8). Note UGC itself can't be steered by text — it accepts only `url` + `aspectRatio` (script/angle text is silently dropped, UC-F3), so there's no "describe the angle" shortcut.
- **One product URL is a 404** → agent flags before `analyze_product` burns nothing; asks Jordan for the working URL.

---

## MS-7 — Restaurant chain, seasonal menu launch

### Persona

Lena is the social marketer for a 12-location restaurant chain. New seasonal menu launches in 2 weeks. 4 menu items, each needs feed + story creatives and a short UGC-style video for Reels/TikTok.

### Context & goal

- 4 menu items (pumpkin soup, apple cider donut, butternut risotto, maple latte).
- Each: 2 feed images + 2 story images + 1 UGC video.
- Brand voice: warm, seasonal, cozy.
- Plus: translate the in-image taglines to French (Quebec locations).

### Portfolio

- Brand: `https://cozyforks.example` (chain website with menu pages).
- Menu items: `/menu/pumpkin-soup`, `/menu/apple-cider-donut`, `/menu/butternut-risotto`, `/menu/maple-latte`.

### Session script

> **Lena:** "Seasonal menu launches in 2 weeks. Set up the brand and 4 menu items from cozyforks.example."

**Expected flow:**
1. Brand setup; `voiceTags` likely include "warm", "cozy", "seasonal" → tone override to "warm" (UC-E6).
2. 4 product setups.

> **Lena:** "2 feed creatives and 2 stories per item. Make them feel autumnal — warm lighting, cozy, no harsh white backgrounds. Put the tagline 'Fall is back at Cozyforks' on the feed ones."

**Expected flow:**
1. 4 × `generate_image_templates(outputFormats=["feed"], quantity=2, additionalInformations="autumnal warm lighting, cozy, no harsh white backgrounds, tagline 'Fall is back at Cozyforks'")` — the tagline is baked into `additionalInformations` at generation time, not added as a separate revise step (there is no `revise/text_composite` endpoint).
2. 4 × `generate_image_templates(outputFormats=["story"], quantity=2, additionalInformations="autumnal warm lighting, cozy, no harsh white backgrounds")`.
3. Total: 16 creatives.

> **Lena:** "Translate the tagline on the feed ones to French for our Quebec locations."

**Expected flow:** fetch each of the 8 feed creatives' `imageUrl` via `GET /generated_creatives/{id}/`, then 8 × `revise_translate(sourceImageUrl=<fetched>, languages=["fr-CA"])` (or `["fr"]`, depending on what the API supports — agent should check the enum on the first 422). One call per creative covers all requested languages.

> **Lena:** "And one short reel-style UGC video per item."

**Expected flow:**
1. Pre-flight `analyze_product` on each menu page → menu pages typically have one hero shot of the dish. If `imageUrls[]` length >= 1, UGC will likely work but is at risk of "No usable product images" on minimal pages (UC-F4).
2. 4 × `generate_ugc_video(url=<menu page>, aspectRatio="9:16")`.

### Success criteria

- 16 image creatives (with EN + FR text overlay variants on feed) + 4 UGC videos.
- Lena has 2 weeks of social content from one session.

### Complications to handle

- **One menu page has no hero image** (the maple latte page is just a description) → UGC pre-flight fails; agent suggests an alternative (food photographer-style image generation, or avatar with a script).
- **`fr-CA` isn't in the language enum** → agent retries with `fr`; if still 422, asks Lena which closest language to use.

---

## MS-8 — Creator, partner brand week

### Persona

Kai is an Instagram lifestyle creator (~80K followers). This week: 4 sponsored partnerships across different brands. Needs authentic-feeling UGC content per partner, plus one talking-head video where Kai introduces all 4 products together for a "favorites" reel.

### Context & goal

- 4 partner products from 4 different brands (Kai is licensed to use their assets).
- Per partner: 1 UGC video + 1 feed-format image.
- "Favorites" video: talking-head with a Kai-written script naming all 4.

### Portfolio

- Partner A: candle brand — `https://candleco.example/lavender-candle`
- Partner B: athleisure — `https://moveco.example/joggers`
- Partner C: snack brand — `https://snackco.example/granola-bars`
- Partner D: skincare — `https://skinco.example/face-mist`

### Session script

> **Kai:** "I'm running 4 brand partnerships this week. Set up brands and products from these 4 URLs."

**Expected flow:**
1. 4 brand setups (each unknown domain → silent create, UC-C1).
2. 4 product setups.

> **Kai:** "One UGC video per product, 9:16 for Reels."

**Expected flow:** 4 × `generate_ugc_video(url=<product page>, aspectRatio="9:16")`. Parallel fire; 180s wakeup (UC-G2).

> **Kai:** "Plus one feed image per product for my grid."

**Expected flow:** 4 × `generate_image_templates(outputFormats=["feed"], quantity=1)`.

> **Kai:** "Now make a talking-head video where the avatar lists all 4 products as my 'weekly favorites'. Script: 'My favorites this week — the [Lavender Candle] from Candleco for chilling, the [Joggers] from Moveco for runs, [Granola Bars] from Snackco for snacks, and [Face Mist] from Skinco for glow. Links in bio!'"

**Expected flow:**
1. Talking-head requires a `productId` — for a multi-product "favorites" video, agent uses the brand-of-attribution (Kai's own creator brand, if one exists, or asks Kai to designate one). This is a real edge case the avatar endpoint shape doesn't handle cleanly.
2. Fire `generate_avatar_talking_head(productId=<designated>, prompt=<Kai's script verbatim>)`. Script passes through unchanged (UC-F6 / F7).

### Success criteria

- 4 UGC videos + 4 feed images + 1 favorites talking-head.
- Posted across the week, one product per day, with the favorites reel as the wrap-up.

### Complications to handle

- **Kai's "creator brand" doesn't exist yet** → agent flags the multi-product avatar gap, suggests creating a "Kai Lifestyle" brand for attribution OR using the first partner's brand context (with disclosure).
- **One UGC video renders with the wrong product as hero** (BE's discovery picked the wrong image) → no scriptable control via UGC (UC-F3); agent re-fires once, then suggests pivoting to avatar with a script if it fails again.

---

## Cross-scenario contract checks

Beyond the individual scenarios, the agent should pass these meta-checks across all 8:

| Check | Description |
|---|---|
| **No spurious approve gates** | None of MS-1…MS-8 should produce a "here's the plan, reply `go`" turn for image or UGC video. Avatar/talking-head scripts ARE the user input — no second approve turn. |
| **Honest counts** | When a marketer says "make 4", they get 4 creative records (UC-E2). When formats collapse (story+reel), the count is honest (UC-E4). |
| **Brand reuse, not duplication** | In MS-3 and MS-5, returning marketers don't get duplicate brands or duplicate products created. |
| **Per-batch surface, not per-creative** | A batch of 72 creatives (MS-1, MS-5) is summarized as one batch turn, not 72 separate "creative #X firing" turns. |
| **No silent field drops** | When a marketer hands UGC a script or tone (MS-3 "different vibe", MS-7 "warm lighting"), agent doesn't pass dropped fields silently — surfaces UC-F3 or routes to the right tool (avatar). |
| **Cost transparency** | For videos, the previewed `tokenCost` is quoted; balance deltas are NOT used as the source of truth (UC-J2). |
| **Brand voice propagates** | Maya (playful), Priya (clean), Lena (warm) — `voiceTags` from the brand drive `tone` defaults (UC-E6) without re-asking per creative. |
| **Sequencing is enforced** | Revise tools wait for source creatives to land (MS-1 BF overlay, MS-2 ad copy, MS-7 translate). UC-E9 / UC-H rules. |
| **Failure mode honesty** | When UGC pre-flight fails (MS-4, MS-7 maple latte, MS-8 wrong-hero re-fire), agent surfaces the limit and offers a working alternative, not a retry loop. |

---

## Maintenance

When the campaign launch / reports / pixel skills (UC-L1…L6) land, extend each marketer scenario with a "and now launch the campaign" final act. Marketers who just generated 72 creatives want to launch them in the same session — that's the full loop the platform is built around.
