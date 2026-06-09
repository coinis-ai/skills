# Coinis MCP — End-to-End Use Cases

Catalogue of user-driven scenarios the Coinis MCP (`coinis`, http at `https://mcp.coinis.com`) must support end-to-end. Each case captures the user-facing prompt, the expected MCP flow, success criteria, and the failure modes the skills explicitly warn about.

These are scenarios, not pytest fixtures — they're the ground truth the skills in this repo wrap and the contract regressions should be checked against.

**Source of truth:** [`coinis-image-from-url/SKILL.md`](../coinis-image-from-url/SKILL.md), [`coinis-video-from-url/SKILL.md`](../coinis-video-from-url/SKILL.md), and the upstream MCP skills loaded via `mcp__coinis__load_skill`.

**Notation used below:**

- `wid` = workspace id
- `bid` = brand id
- `pid` = product id
- `cid` = creative id
- `MCP.<tool>` = a Coinis MCP tool call
- `POST /api/...` = the underlying REST endpoint the MCP fronts

---

## Index

| Category | Cases |
|---|---|
| [A. Authentication & session](#a-authentication--session) | UC-A1 … UC-A3 |
| [B. Workspace selection](#b-workspace-selection) | UC-B1 … UC-B3 |
| [C. Brand setup](#c-brand-setup) | UC-C1 … UC-C4 |
| [D. Product setup](#d-product-setup) | UC-D1 … UC-D4 |
| [E. Image creative generation](#e-image-creative-generation) | UC-E1 … UC-E9 |
| [F. Video creative generation](#f-video-creative-generation) | UC-F1 … UC-F10 |
| [G. Polling & retrieval](#g-polling--retrieval) | UC-G1 … UC-G4 |
| [H. Creative revision](#h-creative-revision) | UC-H1 … UC-H7 |
| [I. Skill discovery & playbooks](#i-skill-discovery--playbooks) | UC-I1 … UC-I2 |
| [J. Errors & edge cases](#j-errors--edge-cases) | UC-J1 … UC-J9 |
| [K. End-to-end happy paths](#k-end-to-end-happy-paths) | UC-K1 … UC-K4 |
| [L. Future surface (not yet covered by skills)](#l-future-surface-not-yet-covered-by-skills) | UC-L1 … UC-L6 |

---

## A. Authentication & session

### UC-A1 — First-time OAuth flow
**Precondition:** No Coinis MCP session in this Claude Code instance.
**Prompt:** "Make me an image from https://example.com/product/42"
**Expected flow:**
1. `MCP.mcp__coinis__authenticate()` → returns authorization URL.
2. Agent shares URL with user; user opens in browser, completes auth.
3. Browser redirects to `http://localhost:<port>/callback?code=...&state=...`.
4. Agent calls `MCP.mcp__coinis__complete_authentication(callback_url=...)`.
5. Real MCP tool surface becomes available.
**Success:** Subsequent `list_my_workspaces` succeeds without 401.
**Failure modes:** User pastes only the code instead of the full URL → `complete_authentication` rejects; agent re-asks for the full address-bar URL.

### UC-A2 — Remote / headless session OAuth
**Precondition:** Claude Code running over SSH / remote; browser localhost callback fails to render.
**Prompt:** Same as UC-A1.
**Expected flow:** Same as A1, but the user's browser shows a "can't connect" error on the callback page — the URL in the address bar is still valid and is what gets pasted back.
**Success:** Session created despite the localhost connection error.
**Failure modes:** Agent treats the "can't connect" page as a hard failure and re-runs `authenticate` → loses the original auth code.

### UC-A3 — Expired session mid-task
**Precondition:** Valid session at start; token expires while a long task runs.
**Prompt:** Mid-task, agent fires `generate_image_templates` and gets 401.
**Expected flow:** Agent surfaces the auth requirement; re-enters UC-A1; resumes from the failed step (no double-billing, no orphan creatives).
**Success:** Task completes from where it left off.

---

## B. Workspace selection

### UC-B1 — Auto-pick by balance + Meta connection
**Precondition:** User has 2+ workspaces.
**Prompt:** "Generate a square ad for https://shop.example.com/sku-1."
**Expected flow:**
1. `list_my_workspaces` → array of workspaces with `tokenBalance` and `hasMetaConnection`.
2. Agent picks the highest-balance workspace where `hasMetaConnection: true`.
3. `wid` cached for the rest of the session.
**Success:** Subsequent calls reuse the same `wid` without re-querying.
**Failure modes:** Agent picks the first workspace returned (insertion order) → may be low-balance or unconnected.

### UC-B2 — User names a specific workspace
**Prompt:** "Use my 'Coinis Pro' workspace for this."
**Expected flow:** Agent matches by `name` field; if no match, asks to disambiguate; never auto-overrides a named choice.
**Success:** Named workspace is used regardless of balance.

### UC-B3 — No workspace with Meta connection
**Precondition:** All workspaces have `hasMetaConnection: false`.
**Prompt:** "Launch a campaign for SKU-1."
**Expected flow:** Agent surfaces the Meta-connection gap *before* burning credits on creatives; suggests connecting Meta in the app, or generating creatives without launching.
**Success:** No campaign-launch attempt is made on an unconnected workspace.

---

## C. Brand setup

### UC-C1 — Unknown domain → silent brand creation
**Precondition:** `GET /api/workspaces/{wid}/brands/` returns no brand whose `website` matches the URL's eTLD+1.
**Prompt:** "Make an image for https://newbrand.example/coffee-grinder"
**Expected flow:**
1. `analyze_product` (free, sync) on the URL — capture identity/imageUrls.
2. `analyze_brand_identity` (or equivalent) for colors/voice/categories.
3. `POST /api/workspaces/{wid}/brands/` with full identity payload (no "ask"). Capture `bid`.
**Success:** Brand created silently; no approve-then-go turn fired.
**Failure modes (must NOT happen):**
- Asking the user "create a new brand?" on unknown domain.
- Falling back to a minimal `{name}`-only POST when full identity is available.
- Treating an auto-mode safety classifier flag as a reason to default back to the gate (cite the rule and retry/ask permission instead).

### UC-C2 — Matching domain → ask use-existing-vs-parallel
**Precondition:** A brand with `website` matching the URL's eTLD+1 already exists (e.g. `#Y CoffeeBrand`).
**Prompt:** Same as UC-C1 but on `https://coffeebrand.example/...`.
**Expected flow:** Agent presents one-line choice: "Use existing `#Y CoffeeBrand`, or create a parallel entry?"
**Success:**
- Bare "yes" / "use existing" → reuse `#Y`.
- "new" / "parallel" → create a new brand row anyway.
**Failure modes:** Three-option `No Brand / existing / new` gate (retired). Auto-creating a parallel brand without asking.

### UC-C3 — Brand exists but lacks full identity
**Prompt:** "Refresh the brand profile for #Y from https://coffeebrand.example"
**Expected flow:** Agent runs `analyze_brand_identity`, then `PATCH` the existing brand with the analyzed fields rather than creating a duplicate.
**Success:** Brand `id` unchanged; missing fields filled in.

### UC-C4 — User-supplied URL is a homepage with no product schema
**Prompt:** "Use https://brandhomepage.example to generate ads."
**Expected flow:** Agent runs `analyze_product`; if `imageUrls: []` or only logos, brand creation still proceeds (homepage is fine for brand identity), but the user is warned that **product creation may fail** and UGC video pre-flight will reject this URL (see UC-F4).

---

## D. Product setup

### UC-D1 — Create product from analyzed URL
**Precondition:** Brand exists (`bid` known); product doesn't (`list_products` returns 0 matching).
**Prompt:** "Add this product: https://shop.example.com/blue-mug"
**Expected flow:**
1. `analyze_product(url=...)` → name, description, imageUrls, productAiSummary, productCategory.
2. `POST /api/workspaces/{wid}/brands/{bid}/products/` with name + description + category + url + `image_urls` (NOT both `image_urls` and `image_keys`).
3. Drop image URLs containing `<!--` or with non-`jpg|png|webp` tails.
**Success:** Product created with `id` returned.
**Failure modes:** Sending both `image_urls` and `image_keys` → 422.

### UC-D2 — Bulk catalogue import
**Prompt:** "Import every product from https://shop.example.com/all-products"
**Expected flow:** `import_from_url` (catalogue endpoint), NOT `analyze_product`. `analyze_product` is for a single product page.
**Success:** Multiple products created in one call.
**Failure modes:** Retrying `import_from_url` on a homepage that returns 0 SKUs → wrong endpoint. Falls back to `analyze_product` per specific product page.

### UC-D3 — Product already exists in the workspace
**Prompt:** Same URL as a product already created.
**Expected flow:** Agent matches by `url` field, reuses the existing `pid`. No duplicate POST.
**Success:** Generation jumps straight to the creative step.

### UC-D4 — Product URL has no scrapeable images
**Precondition:** `analyze_product` returns `imageUrls: []`.
**Expected flow:** Agent still allows brand+product creation but warns the user that downstream image generation may be lower quality and UGC video will fail at the discovery stage.

---

## E. Image creative generation

### UC-E1 — Default single square image
**Precondition:** Brand + product set up.
**Prompt:** "Make an ad image for this product."
**Expected flow:** Fire `generate_image_templates` immediately with:
```json
{
  "productId": <pid>,
  "outputFormats": ["square"],
  "quantity": 1,
  "tone": "professional",
  "style": "clean-minimal",
  "additionalInformations": "<concrete scene line>"
}
```
**Success:** Returns one creative with `id`, `jobId`, `actionStatus: processing`. Plan + result surfaced in ONE follow-up turn (no separate approve-then-go turn).

### UC-E2 — Multiple images, single format
**Prompt:** "Make me 4 ad images."
**Expected flow:** `outputFormats: ["square"], quantity: 4`. The single POST returns a JSON ARRAY of 4 creative records, each with its own `id` and `jobId`.
**Success:** All 4 ids tracked as a batch in the surface line.
**Failure modes:** Surfacing as "1 creative with 4 images" — wrong shape.

### UC-E3 — Mixed non-collapsing formats
**Prompt:** "I want 4 square + 3 portrait + 3 feed."
**Expected flow:** Fire 3 POSTs in parallel (one per format), each with its own `quantity`. `additionalInformations` is global per call — per-variation scene lines need per-call POSTs.
**Success:** 10 creative records total, tracked as a multi-batch.

### UC-E4 — Format collapse trap (story + reel)
**Prompt:** "Make 3 stories and 3 reels."
**Expected flow:** Agent recognizes both formats are 9:16 — they collapse server-side. Either:
- Pick one format × quantity 3 and warn the user, OR
- Issue them as 2 separate single-format calls.
**Success:** Honest creative count reported. Never promises "6 creatives" for a collapsing pair.

### UC-E5 — Unsupported format request (landscape / 16:9)
**Prompt:** "Make a 16:9 banner."
**Expected flow:** Agent surfaces that the API enum is `square | feed | portrait | story | reel` — no landscape. Offers `feed` (4:5 portrait crop) as closest substitute and asks the user to confirm before substituting.
**Success:** No 422 round-trip; substitute is explicit, not silent.

### UC-E6 — Tone/style override from brand voiceTags
**Precondition:** Brand `voiceTags: ["playful", "youthful"]`.
**Expected flow:** Agent overrides default `tone: professional` → `playful` based on `voiceTags`. Style override only when product category clearly implies it (lifestyle/consumer → `bold` or `photo-realistic`).

### UC-E7 — User-supplied scene line
**Prompt:** "Generate with the line: 'morning light on a marble counter'."
**Expected flow:** Pass user line through verbatim as `additionalInformations`; do not paraphrase or merge with brand defaults.

### UC-E8 — Insufficient balance pre-flight
**Precondition:** Workspace `tokenBalance` < image generation cost.
**Expected flow:** Agent surfaces the gap BEFORE firing (cost is predictable for images) and offers: top up, switch workspace, or reduce quantity.
**Success:** No billed-then-failed creative.

### UC-E9 — Bundling forbidden
**Prompt:** "Set up the brand, the product, and generate the image in one go."
**Expected flow:** Agent runs the steps sequentially (`source_creative_id` / `productId` don't exist until earlier steps land), surfacing each step's result. Does NOT bundle a single mega-approve covering all three.

---

## F. Video creative generation

### UC-F1 — UGC video from product URL, default aspect
**Prompt:** "Make a UGC video for https://shop.example.com/blue-mug"
**Expected flow:**
1. `analyze_product(url=...)` as pre-flight to confirm product imagery exists.
2. Brand-target rule (UC-C1/C2).
3. **Do NOT create a placeholder product** — UGC drops `productId`.
4. Fire `POST /api/workspaces/{wid}/generated_creatives/generate/ugc_video/` with body `{"url": "...", "aspectRatio": "9:16"}` only.
5. Capture `id`, `jobId` (cost was previewed via `preview_cost` before firing).
6. Surface plan + result in one turn.
**Success:** One video creative in `processing`; first poll at 180 s; observed renders up to ~9 min on 2026-05-28 — don't give up before ~10 min unless `actionStatus` is `failed`.

### UC-F2 — UGC video, 16:9
**Prompt:** "Make a landscape UGC video."
**Expected flow:** Same as F1 with `aspectRatio: "16:9"`. Valid enum is **only** `9:16` and `16:9` — anything else 422s.

### UC-F3 — User adds dropped fields (script / tone / language)
**Prompt:** "Make a UGC video with this script: 'Tired of cold coffee? ...'"
**Expected flow:** Agent explains that `generate_ugc_video` silently drops `script`/`tone`/`language`/`quantity`/`videoProvider` and offers `generate_avatar_video` (which honors the spoken script) as the right tool. Does NOT fire UGC with the script as a false sense of steering.

### UC-F4 — UGC on brand homepage / SaaS landing page
**Prompt:** "Make a UGC video for https://saaslandingpage.example"
**Expected flow:** Pre-flight `analyze_product` returns `imageUrls: []` or only logos. Agent surfaces three alternatives:
(a) paste a specific product/feature page URL,
(b) `generate_avatar_video` with a user-authored script,
(c) `generate_image_to_video` from an existing image creative (currently NOT in catalogue — surface honestly).
**Success:** No discovery-stage failure on the user's tab. No silent burn.

### UC-F5 — UGC with direct image URL (jpg/png/webp)
**Prompt:** "Animate this image: https://cdn.example.com/photo.jpg"
**Expected flow:** Agent surfaces that the BE scraper rejects binary content types (`500: The URL returned a file type that <scraper> cannot process: image/jpeg`) and there is **no working stills-to-video endpoint** at this time. Alternatives: publish on an HTML page first, or use `generate_avatar_video`.
**Success:** No POST is fired; no credits at risk.

### UC-F6 — Avatar video (content gate)
**Prompt:** "Make a talking avatar video for this product."
**Expected flow:**
1. Brand + product setup (avatar REQUIRES `productId`).
2. Agent asks: **"What should the avatar say?"** — this is a CONTENT gate, not a spend gate.
3. User supplies script.
4. Fire `POST /api/workspaces/{wid}/generated_creatives/avatar/generate/` with `{productId, prompt: <user script verbatim>}`.
5. Surface plan + result in ONE turn (the user input WAS the gate; no second approve turn).
**Success:** Script passed through verbatim; agent never invents the spoken words.

### UC-F7 — Talking-head video
**Prompt:** "Make a talking-head video for this product with a male voice."
**Expected flow:** Same as F6 but on `/api/workspaces/{wid}/generated_creatives/avatar/talking_head/`. Provider-specific avatar + voice params. Script gate still applies.

### UC-F8 — Video-to-video style transfer
**Prompt:** "Re-animate this video in cinematic style: https://cdn.example.com/clip.mp4"
**Expected flow:**
1. Agent asks once for motion/style direction if not given.
2. Fire `POST /api/workspaces/{wid}/generated_creatives/generate/video_to_video/` with the source video URL + prompt.
3. Surface plan + result.
**Success:** One creative in `processing`; cost via the `preview_cost` `tokenCost` quoted before firing.

### UC-F9 — Image-to-video (currently unsupported)
**Prompt:** "Turn this image into a video."
**Expected flow:** Agent confirms via `list_endpoints(filter="image_to_video")` that the endpoint is not in the catalogue. Surfaces alternatives (avatar, UGC on a hosted HTML page, wait for restoration). Does NOT loop-retry.

### UC-F10 — UGC `{"error": ""}` response — NOT credit-safe
**Precondition:** A prior fire with `productId`+`brandId` alongside `url` returned `{"error": ""}` (verified 2026-05-27).
**Expected flow:**
1. Agent recognises `{"error": ""}` as the "BE serializer failed on a record it already created" shape.
2. Verifies post-hoc with `GET /generated_creatives/?ordering=-id` (sort by `id` desc — NOT `createdAt`, NOT `tokenBalance`).
3. If a record exists with the correct URL → it billed; quote the previewed `tokenCost` from the `preview_cost` call. Don't promise a refund.
4. Future calls send ONLY `url` + `aspectRatio` to UGC (let BE auto-discover product/brand).
**Success:** No false "no charge" claim; behaviour matches the standing rule that `{"error": ""}` from `generate_ugc_video` MUST be verified post-hoc by listing creatives.

---

## G. Polling & retrieval

### UC-G1 — Image creative completion polling
**Precondition:** `generate_image_templates` returned `id`, `jobId`, `actionStatus: processing`.
**Expected flow:**
1. `ScheduleWakeup(delaySeconds=60)` (typical image render ~55s).
2. Wake → `GET /api/workspaces/{wid}/generated_creatives/{cid}/`.
3. If `actionStatus: success` → quote `imageUrl` (authoritative for final CDN URL).
4. If still `processing` → reschedule same cadence.
**Success:** Final URL surfaced once `success` lands.

### UC-G2 — Video creative completion polling
**Precondition:** Video fire (UGC / avatar / V2V) returned `id`, `jobId`.
**Expected flow:** `ScheduleWakeup(delaySeconds=180)` minimum — first poll at 180 s; observed renders up to ~9 min on 2026-05-28, so don't give up before ~10 min unless `actionStatus` is `failed`. Same GET loop.
**Failure modes:** Polling at 60s for video → wasteful and risks rate-limiting.

### UC-G3 — Creative `actionStatus: failed`
**Expected flow:** Agent reads `errorMessage` and surfaces it verbatim. If `"No usable product images on the page"` → suggest UC-F4 alternatives. If discovery-stage failure → check balance delta for refund (best-effort; don't promise).

### UC-G4 — Batch polling (multi-creative fan-out)
**Precondition:** UC-E2 / UC-E3 created N creative ids.
**Expected flow:** Poll all N in parallel; surface each as it lands rather than waiting for the slowest.
**Success:** Partial completion is visible to the user as it happens.

---

## H. Creative revision

The MCP exposes the following `revise_*` endpoints. Note: schemas are NOT uniform — each takes a different identifying field. **Verified via 2026-05-28 live run.**

### UC-H1 — `revise/variate/`
**Schema:** `{sourceImageUrl, prompt}` — takes the rendered image URL of the source, NOT the creative id.
**Prompt:** "Make a variation of creative #3637."
**Expected flow:** Fetch `imageUrl` from `GET /generated_creatives/3637/`, fire `POST /revise/variate/` with that URL + prompt. Returns a NEW creative record. Cost: ~3 tokens.

### UC-H2 — `revise/resize/`
**Schema:** `{sourceImageUrl, targetAspectRatio}` — pattern matches variate (uses URL not id).
**Prompt:** "Resize creative #123 to portrait."

### UC-H3 — `revise/translate/`
**Schema:** `{sourceImageUrl, languages: [...]}` — note `languages` is **plural and array-typed**, not `targetLanguage` (string).
**Prompt:** "Translate the copy in creative #3635 to German."
**Expected flow:** Fetch image URL, fire `POST /revise/translate/` with `{sourceImageUrl: "...", languages: ["de"]}`. Returns a new creative. Cost: ~3 tokens.

### UC-H4 — `revise/upscale/`
**Schema:** `{sourceImageUrl, ...}` — same URL-based identification.

### UC-H5 — `revise/text_regions/`
**Schema:** `{sourceImageUrl}` — READ-ONLY extraction. Returns the overlay text regions on a creative. Free / cheap.

### UC-H6 — `revise/ad_copy/`
**Schema (DIFFERENT):** `{generatedCreativeId, landingPageUrl}` — this is the ONLY revise endpoint that takes a creative id by reference, because the BE needs the source product/brand context to write copy. Also needs the landing page URL the copy will route to.
**Result shape (DIFFERENT):** No new creative id. Appends a job to the source creative's `aiResults[]` array; the generated headline/primaryText/description land on the source creative itself.

### UC-H7 — `revise/brand/colors/` and `revise/brand/logo/`
**Purpose:** Apply brand colors / logo to an existing creative.

### Endpoint NOT present
- `revise/text_composite` — **does not exist** in the catalogue. The earlier-doc reference was wrong. To add overlay text to a creative, the only path today is `revise/ad_copy` (generates copy + applies it) or pre-baking text into the original `additionalInformations` scene line.

**Cross-cutting rule:** `generate_*` and `revise_*` are NEVER bundled in a single approve — the source creative's id and image URL don't exist until the prior step lands `actionStatus: success`.

---

## I. Skill discovery & playbooks

### UC-I1 — Load upstream playbooks at session start
**Expected flow:** Before any image/video work:
```python
mcp__coinis__load_skill(name="creative-generation")
mcp__coinis__load_skill(name="brand-product-setup")
```
**Success:** Validation matrices + cross-cutting rules in context. The Claude-Code-specific overlays (`coinis-image-from-url`, `coinis-video-from-url`) override the upstream image/video approve gates.

### UC-I2 — Discover available endpoints
**Prompt:** "Does the MCP have an image-to-video endpoint?"
**Expected flow:** `list_endpoints(filter="image_to_video")` → empty → surface honestly. Catalogue is the single source of truth, not memory.

---

## J. Errors & edge cases

### UC-J1 — Auto-mode classifier flags a silent brand mutation
**Expected flow:** When the auto-mode safety classifier blocks the first `POST /brands/` on an unknown domain, the agent cites the UC-C1 rule on retry rather than defaulting back to a "create new brand?" gate.

### UC-J2 — Verifying spend via `tokenBalance` immediately
**Don't do this:** Balance lags reservations on some workspaces. Quote the `tokenCost` from the `preview_cost` call; don't infer spend from balance deltas.

### UC-J3 — Sorting `/generated_creatives/` by `createdAt` desc
**Don't do this:** Default sort is unreliable when multiple creatives share `createdAt` (bulk fans-out write the same timestamp). Sort by `id` desc — monotonic.

### UC-J4 — Probe firing real generators
**Don't do this:** A POST that satisfies validation FIRES. The only credit-safe probes are empty `{}` bodies or bodies missing required fields (422 without burning).

### UC-J5 — Diagnostic probes against off-target URLs/IDs
**Expected flow:** When diagnosing, the agent names the off-target URL/ID and the theory it tests BEFORE firing. Silent foreign probes break trust even when credit-safe.

### UC-J6 — Empty `{"error": ""}` UGC response
See UC-F10. Not credit-safe. Verify with `id`-desc list.

### UC-J7 — Asking before firing image generation
**Don't do this:** The image-skip-gate rule overrides the upstream "NEVER fire `generate_*` without confirm" rule. Fire on sensible defaults; surface plan inline with result.

### UC-J8 — Asking before firing UGC / V2V video
**Don't do this:** Same fire-then-surface rule applies. The avatar/talking-head ask is a CONTENT gate (script), not a spend gate.

### UC-J9 — Guilt theatre over a user-requested video burn
**Don't do this:** If the user asked for the video, the spend was authorized. Acknowledge wrong params if any, fix and re-fire — don't perform "unauthorized burn" apology theatre.

---

## K. End-to-end happy paths

### UC-K1 — Cold start → image creative → revision
1. UC-A1 (auth) → UC-B1 (workspace) → UC-C1 (brand) → UC-D1 (product) → UC-E1 (image) → UC-G1 (poll) → UC-H1 (variate). 7 calls, ~2 min wall clock.

### UC-K2 — Cold start → UGC video → polish via avatar
1. UC-A1 → UC-B1 → UC-C1 → UC-F1 (UGC, NO product step) → UC-G2 (poll, up to ~9 min).
2. If UGC fails at discovery (UC-G3 / F4), pivot to UC-F6 (avatar with user script).

### UC-K3 — Existing brand & product, multi-format image batch
**Precondition:** Brand and product already in workspace.
1. `list_products` → match by `url` → reuse `pid`.
2. UC-E3 (4 square + 3 portrait + 3 feed = 10 creatives, 3 parallel POSTs).
3. UC-G4 (parallel polling, surface as they land).

### UC-K4 — Insufficient balance recovery
1. UC-E8 surfaces the gap.
2. User tops up in the app.
3. Agent re-fires the original `generate_image_templates` without re-running brand/product setup.

---

## L. Future surface (not yet covered by skills)

Tracked here so test cases land alongside the skills that wrap them. Follow-up skills are planned for these areas.

### UC-L1 — Campaign launch flow (`coinis-campaign-flow`)
Skeleton: pick workspace with `hasMetaConnection: true` → choose creative ids → create Meta campaign / ad set / ad via MCP → surface preview + spend cap → fire.

### UC-L2 — Bulk campaign launch
Skeleton: N creatives × M audience segments → fan out into multiple Meta ad sets atomically.

### UC-L3 — Reporting (`coinis-reports`)
Skeleton: pull ROAS / CPA / spend by campaign / ad set / ad; respect 3-level drill-down. Real-time data sync.

### UC-L4 — Pixel & tracking setup (`coinis-pixel-tracking`)
Skeleton: read pixel status on workspace; surface install snippet; verify fire events.

### UC-L5 — Ads audit (`coinis-ads-audit`)
Skeleton: scan active ads for compliance flags (Meta policy, creative quality, CTA hygiene). Read-only.

### UC-L6 — Domain glossary (`coinis-domain-glossary`)
Skeleton: resolve user-facing terms (CPA, ROAS, audience overlap) to the platform's specific definitions. Read-only.

These cases will be fleshed out as the corresponding skills land.

---

## Maintenance

- When a new MCP tool surfaces in `list_endpoints` or `list_skills`, add a category to this document.
- When a skill in `skills/<name>/SKILL.md` adds a "Common mistake" or "Red flag", add the corresponding negative case here (the UC-J series and the "Failure modes" subsections).
- When adding a new UC, anchor it to a verified MCP shape (endpoint, body, observed response). Speculative cases belong under "Future surface."
