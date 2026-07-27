# Publishing, import/export, and wago.io

Verified against WeakAuras 5.21.8 Transmission.lua/Types.lua and live data.wago.io probes, July 2026.

## Contents
- Export string format
- Import and the update flow (what survives an update)
- Custom Options merge rules
- wago.io publishing and versioning
- The Companion update pipeline (metadata you must ship)
- Inspecting any aura's code (wago data API)
- Pack architecture lessons from the top packs

## Export string format

`!WA:2!` strings are: `LibSerialize:SerializeEx({errorOnUnserializableType=false}, table)` → `LibDeflate:CompressDeflate(serialized, {level=9})` → `"!WA:2!" .. LibDeflate:EncodeForPrint(compressed)`. Envelope: `{m="d", d=<root data>, c={children…}, v=1421|2000, s=<WA version>}` — exporting a parent group always bundles the whole tree; `v=2000` only when nested subgroups exist. Legacy v0/v1 formats remain importable. Flavor marking is automatic via `tocversion` in the data — wago files Era imports as CLASSIC-WEAKAURA with a 1.15.x patch label; no manual game-version picker anywhere.

Chat can't carry export strings (255-char message cap): WA turns `[WeakAuras: Name]` chat links into requests streamed over AceComm; the sender must have linked the aura within the last 5 minutes.

In-game import: paste into the import box (it calls `WeakAuras.Import(pastedString)`); no meaningful size cap in code.

## Import and the update flow (what survives an update)

WA matches an incoming import to an installed aura **by `uid`** — same uid = update, not duplicate. The update dialog diffs per category (`Private.update_categories`):

| Category | Default | Contents |
|---|---|---|
| name, display, trigger, conditions, load, action, animation | **take new** | The aura's actual behavior |
| authoroptions | **take new** | The author's option definitions |
| arrangement, oldchildren ("Remove Obsolete Auras"), newchildren ("Add Missing Auras"), metadata (url/desc/version/semver/wagoID) | **take new** | Group structure |
| **userconfig** ("Custom Configuration") | **KEEP USER'S** | `config` — users' Custom Options values |
| **anchor** ("Size & Position") | **KEEP USER'S** | offsets/size/scale |

This is why packs are updatable without users losing settings — as long as the author does not rename option keys. Users can override any category per import.

## Custom Options merge rules

On load/update, `validateUserConfig` deletes corrupt entries, fills **only nil** config keys with author defaults (existing user values kept), and resizes array-group entries per limitType. `aura_env.config` is a CopyTable of the merged result, ready before On Init runs. Option types and config shapes: see aura-environment.md.

## wago.io publishing and versioning

- New import: wago.io home → paste string → Visibility (Public/Hidden/Private) → Submit. Signed-out "Anonymous Guest" imports expire after 3 months; account imports persist.
- Each page has an immutable `_id` (e.g. `U7Co5q7Az`) and a slug that can be a custom alias (`LuxthosHunterClassicEra`); both work in URLs.
- Pasting a new string onto your existing page increments an integer version with an author `versionString` + changelog; the page shows all versions and Code Diffs between them.
- Page tabs worth knowing: **Editor** (decoded table + extracted custom code — read anyone's aura without importing), **Code Review** (automated luacheck per code block, complexity metrics, detected library requirements).
- Forks are tracked (`forkOf`). Good citizenship, from nanShield's page: document the minimum WA version your aura needs.

## The Companion update pipeline (metadata you must ship)

The [WeakAuras Companion](https://weakauras.wtf) app scans SavedVariables for auras whose **url** points at wago.io, fetches updates, and writes them into a generated `WeakAurasCompanion` data addon; in-game WA shows update badges.

Update detection (WeakAuras.lua `CountWagoUpdates`):

```lua
local slug, version = aura.url:match("wago.io/([^/]+)/([0-9]+)")
-- bare "wago.io/<slug>" is treated as version 1
-- badge when CompanionData.slugs[slug].wagoVersion > version
-- per-aura opt-out: aura.ignoreWagoUpdate = true
```

So: fill the **URL field** (in-game Information tab) with the aura's wago URL. Wago's hosted strings carry version-stamped `url`/`version`/`semver`/`wagoID` (Luxthos v9 ships `url = ".../LuxthosHunterClassicEra/9"`, `version = 9`, `semver = "1.15.8"`, `wagoID = "U7Co5q7Az"`). Known limitation: auras a user moved into their own custom group stop getting update prompts.

Third-party updaters can deliver auras via `WeakAuras.AddCompanionData(data)` (don't name your table `WeakAurasCompanion`).

## Inspecting any aura's code (wago data API)

Probed working July 2026 (curl with a browser User-Agent; the older documented `/api/lookup/wago` 404s):

```bash
curl 'https://data.wago.io/lookup/wago?id=<slug>'                      # page metadata, versions+changelogs
curl 'https://data.wago.io/lookup/wago/code?id=<slug>&version=<vs>'    # decoded table JSON + all custom code + luacheck
curl 'https://data.wago.io/api/raw/encoded?id=<slug>'                  # raw !WA:2! string (follow the 302)
curl 'https://data.wago.io/api/check/weakauras?ids=<slug1>,<slug2>'    # Companion-style update check
curl 'https://data.wago.io/search?q=<terms>&expansion=classic&sort=views'  # search; sort=views|stars|installs|date
```

Popularity note: in the classic bucket, views/stars are the meaningful signal — Companion "installs" run 1-3 orders of magnitude lower. Offline decoders exist (Rust `weakauras-codec`, Python `python-weakauras-tool`) but wago's Editor/Code Review tabs are the most reliable readers.

## Pack architecture lessons from the top packs

Decoded from Luxthos – Hunter (Classic Era) and Fojji's anchor packs:

- **One plain-group root per class**; per-category dynamic groups (Core / Utilities / Maintenance / Left / Right); a static Resources subgroup for bars.
- **Options hubs:** two hidden icon auras carry ALL authorOptions as collapsible Option Groups, so users configure everything in two places instead of per-aura. Luxthos' hub init actions publish settings through a shared global (`LWA`), so display auras never read `aura_env.config` directly.
- **Anchor decoupling (Fojji):** one movable parent aura exposes named sub-group anchors that separately-imported packs attach to — user layout survives pack updates; 8.5k installs say it works.
- **Version like Luxthos:** semver-ish versionString (`1.15.8-9` = client patch + iteration) with per-version changelogs.
- **Update-safe by construction:** keep option keys stable across versions (the userconfig category preserves values by key); structure changes ride the arrangement/newchildren/oldchildren categories.
- Suites that need cross-aura settings use the config-bus pattern (examples.md #12).
