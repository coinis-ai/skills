# Assets

Brand assets used by the Codex plugin manifest (`composerIcon`, `logo` fields) and by external marketplace listings.

## Files

| File | Purpose | Status |
|---|---|---|
| `icon.svg` | Small composer icon shown in Codex chat — renders legibly down to 24×24px. Square `512×512` viewBox, 1:1. | **Present (placeholder).** Backs `interface.composerIcon` → `"./assets/icon.svg"` in `.codex-plugin/plugin.json`. |
| `logo.png` | Larger logo for marketplace listing. `512×512px`, RGBA, transparent corners. | **Present (placeholder).** Backs `interface.logo` → `"./assets/logo.png"` in `.codex-plugin/plugin.json`. |

Both files are **placeholder marks pending official Coinis brand art** — a rounded-square amber tile (`#F9AE3B`) with a navy (`#21294A`) `C` monogram. Colors were derived from the public Coinis logo; replace both with the official primary mark when available (keep the same filenames, dimensions, and 1:1 aspect so the manifest fields keep resolving).

Both assets are public-safe (no internal-only marks, no customer logos, no team headshots).
