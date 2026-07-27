# Best practices, tooling & performance discipline

Project hygiene and measured-performance practices for Classic Era (1.15.x), from warcraft.wiki.gg and the WoWAce/BigWigs/WeakAuras toolchain. Complements the pattern files; this one is about *how to build well*, not which API to call.

## Profiling — measure before you optimize

Two independent profilers; know which needs the CVar.

```lua
-- CPU: requires the CVar + reload (it has overhead, off by default). Persists across sessions.
/console scriptProfile 1
/reload
```
```lua
UpdateAddOnCPUUsage()                          -- refresh the cache FIRST
print("CPU:", GetAddOnCPUUsage("MyAddon"), "ms")     -- per addon
local ms, calls = GetFunctionCPUUsage(MyAddon.OnUpdate, true)   -- per function (+subroutines)

-- Memory needs NO CVar:
UpdateAddOnMemoryUsage()                        -- refresh (expensive — see warning)
print("mem:", GetAddOnMemoryUsage("MyAddon"), "KB")
print("total Lua:", collectgarbage("count"), "KB")   -- cheap, no Update, no CVar

-- Micro-time a hot path (ms, sub-ms precision, no CVar). Loop the code ~10k× for signal:
local t0 = debugprofilestop(); for i=1,1e5 do hot() end; print(debugprofilestop()-t0, "ms")
```

- **Never call `UpdateAddOnMemoryUsage()` or `collectgarbage("collect")` per-frame** — each can stall the client >0.5 s. For "how much garbage did I make", diff `collectgarbage("count")`, don't force a collect.
- For CPU profiling use `scriptProfile` + `GetAddOnCPUUsage`. The newer **`C_AddOnProfiler`** (per-addon millisecond metrics — `GetAddOnMetric`, `GetApplicationMetric`, `GetOverallMetric`, `GetTopKAddOnsForMetric`) **is present in Era** — it's defined in the `classic_era` UI source (`Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua`). It's a recent backport, so sanity-check it on your live build before depending on it.

## Error handling — report, don't swallow or crash

- **`pcall` hides the error silently.** If you catch and ignore, you've buried a bug. Re-surface it so BugSack/Blizzard still report it while the UI keeps running:

```lua
local ok, err = pcall(risky)
if not ok then geterrorhandler()(err) end
```

- **`safecall` via WoW's arg-passing `xpcall`** (a non-standard 5.1 extension — args after the handler) wraps a call with no allocating closure:

```lua
local function safecall(f, ...) return xpcall(f, geterrorhandler(), ...) end
safecall(MyAddon.Refresh, MyAddon, unit)   -- one bad call won't abort the rest
```

- **Wrap the boundaries, let logic errors propagate inside.** Protect edges where an exception would break *unrelated* code — event dispatchers, timer/callback fires, SavedVariables migration, third-party callbacks (this is why Ace3/FrameXML dispatch user callbacks through `xpcall`). Inside your own logic, prefer a visible error over a blanket `pcall` that masks it.
- **`securecall` is for taint, not try/catch** — it runs a possibly-tainted function without leaking taint back to you.

## Hot-path micro-performance (Lua 5.1)

In `OnUpdate` and `COMBAT_LOG_EVENT_UNFILTERED` handlers, allocations are the enemy (GC churn = frame hitches). Make the hot path **zero-garbage**.

- **`..` in a loop is O(n²) garbage** (each builds a new immutable string). Build a table, concat once:
  ```lua
  local buf = {}; for i=1,#lines do buf[i]=lines[i] end
  local s = table.concat(buf, "\n")
  ```
  For a small fixed number of pieces, one `format`/`..` is fine — the rule is about repetition.
- **`select("#", ...)` / `select(i, ...)` instead of `{...}`** in vararg hot paths — `{...}` allocates a table every call:
  ```lua
  for i = 1, select("#", ...) do local v = select(i, ...) ... end
  ```
- **Numeric `for i=1,#t` over `pairs`** in hot loops; never `pairs` a table every frame. Use array-style tables for hot data, cache the index instead of recomputing `#t`.
- **Zero-garbage rule, concrete:** no `{...}`, no `..`, no `pairs`, no per-fire closures, no temp tables — reuse one scratch table with `wipe()`. String *literals* are interned (free); *constructed* strings are not.

## Animation groups over `OnUpdate` tweens

**Myth correction:** the native animation system **is** present in Classic Era 1.15.x (confirmed in Blizzard's `classic_era` UI source). Prefer it over a Lua fade/slide loop — it runs in C with zero per-frame Lua or GC:

```lua
local ag   = frame:CreateAnimationGroup()
local fade = ag:CreateAnimation("Alpha")
fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.5)
ag:Play()
```
If you genuinely must tween in Lua, route *all* animations through one shared driver `OnUpdate`, not one per frame.

## Coding-standards gotchas

- **Zero-global shared namespace** — every file gets `...` = `addonName, privateTable`. Share state across files with no global at all:
  ```lua
  local addonName, ns = ...
  ns.Foo = function() ... end
  ```
- **`:` vs `.`** — a method defined with `:` (implicit `self`) must be *called* with `:`. `MyAddon.Update()` on a `:`-defined method passes no `self` → `attempt to index local 'self' (a nil value)`.
- **A leaked global doesn't error** — a missing `local` silently creates a global that (a) collides with other addons, (b) can **taint** the execution path → "action blocked" in combat, (c) hides typos. You won't catch it at runtime — catch it statically with luacheck (below).
- **Use named API constants, not raw magic numbers** — `INVSLOT_HEAD`/`INVSLOT_MAINHAND` over inventory slot `1`/`16`, `Enum.*` over its integer value. Raw IDs (equipment slots, item classes, etc.) can shift between patches; the named constant always maps correctly.

## Static analysis: luacheck

WoW Lua has **no compile step**; luacheck is the only pre-ship safety net. It catches the exact failure mode that bites every addon — a missing `local`, a typo'd global, an undefined API, an unused local.

```lua
-- .luacheckrc
std = "lua51"               -- WoW is a Lua 5.1 VM; never the default std
max_line_length = false
codes = true                -- show warning codes so you can target ignores
exclude_files = { "Libs/" } -- never lint embedded libraries
files["Locales/*.lua"].ignore = { "211/L" }   -- locale tables set unused locals

globals = { "MyAddonDB", "SLASH_MYADDON1", "SlashCmdList" }   -- globals YOU create
read_globals = {            -- WoW APIs you USE (subset; or use a full-API config)
    "CreateFrame", "C_Timer", "C_ChatInfo", "hooksecurefunc",
    "UnitName", "UnitGUID", "GetTime", "GameTooltip", "UIParent",
    "strsplit", "tinsert", "wipe", "LibStub", "WOW_PROJECT_ID",
}
```

- The ~5,000 WoW API globals aren't in any std. Either list them in `read_globals`, or drop in a ready-made per-flavor config (**`Jayrgo/wow-luacheckrc`**, generated from Blizzard's interface resources — has a Classic variant) so you don't hand-maintain it.
- Silence the *legitimate* globals with ignore codes: `11./SLASH_.*` and `11./BINDING_.*` (these MUST be global), `212/self`, `212/event` (unavoidable handler args).
- Run `luacheck .` locally (it walks up to find `.luacheckrc`); run it in CI on every push/PR.
- **Source the right luacheck.** The maintained home is **`lunarmodules/luacheck`** (the original `mpeterv/luacheck` is effectively abandoned); LuaRocks, the Docker image, and the GitHub Actions all point there.

### Second linter + formatter: selene & StyLua

Two Rust tools that complement luacheck (both actively maintained, both Lua 5.1):

- **[selene](https://github.com/Kampfkarren/selene)** — a fast linter with a *different* rule set, so it flags a few things luacheck doesn't (and vice-versa). Its `lua51` std is built in; WoW globals need a custom std YAML — a community `wow.toml` gist exists, but it's not a maintained package, so selene is less turnkey than Jayrgo's `.luacheckrc`. Run it *in addition* to luacheck, not instead.
- **[StyLua](https://github.com/JohnnyMorganz/StyLua)** — the de-facto Lua auto-formatter; fills the one gap none of luacheck/selene/LuaLS cover. Set `syntax = "Lua51"` in `stylua.toml`; gate CI with `stylua --check .` (exit 1 on unformatted code); official pre-commit hooks ship in the repo.

## Editor diagnostics: Lua Language Server + WoW API types

The biggest day-to-day win after luacheck: the **Lua Language Server** (LuaLS / sumneko — the "Lua" VS Code extension) pointed at a set of **WoW API type annotations**. You get autocomplete, hover docs, and live flagging of misspelled API names, undefined globals, and wrong argument counts *as you type*. The same check runs headless in CI via `lua-language-server --check <dir>`.

**Use a current-engine annotation set, not a 1.12 one.** Classic Era runs the *modern* client engine (`C_Timer`, `C_Container`, `C_Spell` all exist), so a Vanilla-1.12 def set would wrongly flag the modern APIs you actually use. **`Ketho/vscode-wow-api`** (annotations generated from live Blizzard interface resources) is the right pick — its `Annotations/` define `CreateFrame`, `C_Timer`, `UnitName`, … Clone it and point `.luarc.json` at it:

```json
// .luarc.json at your addon root
{
  "runtime.version": "Lua 5.1",
  "workspace.library": [ "path/to/vscode-wow-api/Annotations" ]
}
```

luacheck and LuaLS are **complementary, not redundant**: luacheck owns leaked/undefined *globals*, unused locals, and style; LuaLS adds type awareness — `undefined-global` on a typo, wrong-arg-count, and editor autocomplete/hover. Run both. (Verified: against a file with a leaked global, a typo'd variable, and `CreateFrame`/`UnitName` calls, luacheck flagged the leak + typo + unused local and ignored the WoW APIs; `lua-language-server --check` flagged the typo as `undefined-global` and recognized the WoW APIs from the annotations.)

- **Ketho now ships a `vanilla-1.15.8` flavor** — it's first-class Classic Era, not retail-only, and stays the right pick. For Blizzard *frame* methods and XML-defined globals the API-doc generator misses, also add **NumyAddon/FramexmlAnnotations** (`classic_era` branch), or point `workspace.library` at **Gethe/wow-ui-source** (`classic_era`) for the real UI source. **DeadlyBossMods/LuaLS-Config** is a good real-world multi-flavor template (Classic defines + a CI `action.yml`, layered on top of Ketho).
- **Annotate the shared namespace** — LuaLS can't infer `local addonName, ns = ...` across files. Declare `---@class MyAddon` once, tag the vararg `local _, ns = ... ---@type MyAddon`, and `ns.Foo` then autocompletes in every file.

## Packaging: `.pkgmeta`, externals, multi-flavor

**For a Classic-only addon, a single `MyAddon.toc` with `## Interface: 11508` is enough** — the rest matters once you ship libraries or multiple flavors.

`.pkgmeta` (YAML, repo root, **spaces not tabs**) drives the BigWigs packager:

```yaml
package-as: MyAddon
externals:                              # fetch libs at BUILD time — keep them out of git
  Libs/LibStub:   https://repos.wowace.com/wow/libstub/trunk
  Libs/AceDB-3.0: https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0
ignore:
  - "*.md"
enable-nolib-creation: yes              # also emit a -nolib zip (GitHub releases only)
```

- **Externals over committed libs** — clean diffs, no stale-library drift, and luacheck `exclude_files` keeps them out of lint. Wrap loader lines in `--@no-lib-strip@ … --@end-no-lib-strip@` so the loader survives nolib stripping.
- **LibStub dedups** — across all addons, only the highest `MAJOR.MINOR` of each library actually loads. Bump a lib's `MINOR` when you embed a newer copy; never edit a lib's API in place.
- **Classic-only addon:** a single `## Interface: 11508` TOC is all you need — no per-flavor TOC machinery.

## CI: lint + release

Two GitHub Actions workflows is the norm — **lint on push/PR**, **release on tag**.

```yaml
# .github/workflows/lint.yml
on: [push, pull_request]
jobs:
  luacheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nebularg/actions-luacheck@v1
        with: { args: "--no-color -q", annotate: warning }
```

```yaml
# .github/workflows/release.yml
on: { push: { tags: ["**"] } }   # annotated tags — changelog needs annotation
permissions: { contents: write } # default token is read-only since Feb 2023
jobs:
  release:
    runs-on: ubuntu-latest
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}   # the name mismatch IS the gotcha
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }   # full history — required for auto-changelog
      - uses: BigWigsMods/packager@v2
```

Three release gotchas (all silent failures): **`GITHUB_OAUTH`, not `GITHUB_TOKEN`** (the packager only reads `GITHUB_OAUTH`); **`permissions: contents: write`** (else the release — and the CurseForge upload — is skipped); **`fetch-depth: 0`** (shallow clones break the changelog). Only `CF_API_KEY` is needed for Classic CurseForge publishing.

Keep dev files out of the shipped zip with `.gitattributes` (`export-ignore`), in addition to `.pkgmeta: ignore`:

```gitattributes
.github        export-ignore
.luacheckrc    export-ignore
README.md      export-ignore
```

## Testing outside the game

Moved to its own file: **[reference/testing.md](testing.md)** — the offline ladder (static luacheck/LuaLS → **busted** unit tests → **wowless** full-addon load → in-client), the tool matrix, and the abandoned-tools list. (Static linting — luacheck, LuaLS, selene, StyLua — is covered above; testing.md is execution.)

## Addon comms — register, throttle, chunk

- **Register the prefix first.** `C_ChatInfo.RegisterAddonMessagePrefix("MyAddon")` (≤16 chars; the client allows only a limited number of prefixes). Messages to an unregistered prefix are silently dropped on receive.
- **Send:** `C_ChatInfo.SendAddonMessage(prefix, text, channel[, target])`. Era channels: `"PARTY"`, `"RAID"`, `"INSTANCE_CHAT"`, `"GUILD"`, `"OFFICER"`, `"WHISPER"` (needs target). **Gotcha:** `"CHANNEL"` (custom channels) is **disabled** since 1.13.3, and `"SAY"`/`"YELL"` are heavily throttled (proximity pings only). Use PARTY/RAID/GUILD/WHISPER/INSTANCE_CHAT for anything real.
- **255-byte cap** per message (prefix + body). Longer payloads must be chunked and reassembled.
- **The engine throttle drops, it doesn't queue:** each prefix gets ~10 messages, regaining 1/sec; over-budget sends return `Enum.SendAddonMessageResult.AddonMessageThrottle` and are **lost**. Sustained raw output can also disconnect you. So don't hand-roll volume — use **ChatThrottleLib** (queues + paces; embedded by DBM, DataStore, Details) or **AceComm-3.0**, which bundles prefix registration, chunking, throttling, and pairs with AceSerializer. Prefer AceComm unless you have a specific reason not to.

## Tooltip scanning — read data off a tooltip

- **`C_TooltipInfo` is a stub in Era** — the namespace is declared in the `classic_era` API docs but with **no getter functions**, so the structured-table tooltip path never runs here. Use the hidden-`GameTooltip` scanner below. (Multi-flavor addons: guard on the *function*, not the namespace — `if C_TooltipInfo and C_TooltipInfo.GetItem then`.)
- **In Classic Era you must scan a hidden `GameTooltip`** — create it once owned with `ANCHOR_NONE` (off-screen but populatable), `ClearLines()` before each scan, then read the left/right font strings by global name:
  ```lua
  local tip = CreateFrame("GameTooltip", "MyScanTip", nil, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetHyperlink(itemLink)                       -- or :SetBagItem(bag, slot) / :SetUnit("player")
  for i = 1, tip:NumLines() do
      local text = _G["MyScanTipTextLeft"..i]:GetText()   -- right side: ...TextRight<i>
  end
  ```
- **Cache results by itemID/link** — scanning is comparatively expensive; never rescan every frame. Item data can arrive async, so re-scan on `GET_ITEM_INFO_RECEIVED` if a needed line is missing.

## Mixins & templates

- **`Mixin(target, ...)`** copies methods from one or more mixin tables onto `target`; **`CreateFromMixins(...)`** builds a fresh object from them (used widely — Auctionator, HereBeDragons-Pins). They're how Blizzard composes frame behavior.
- **Prefer XML templates / `inherits` + the `template` arg** over per-frame Lua setup — defined once, reused, far less per-instance work and GC. `BackdropTemplateMixin` is exactly why `SetBackdrop` needs the `BackdropTemplate` (see [minimal-addons.md](minimal-addons.md)).

## Localization

- **AceLocale-3.0**: `local L = LibStub("AceLocale-3.0"):GetLocale("MyAddon")`; locale files register with `:NewLocale("MyAddon", "deDE")`. enUS is the base; a missing key falls through to the key text (don't let it be `nil`).
- **Never concatenate translated fragments** — word order differs per language. Use **one full format string** per message: store `L.LEVEL_UP = "%s reached level %d"` and call `L.LEVEL_UP:format(name, lvl)`. `L["reached level"] .. lvl` is untranslatable. When a language must reorder the substitutions, use **positional specifiers** (`"Level %2$d reached by %1$s"`) so the translation controls order.
- `GetLocale()` returns the client locale: `enUS deDE frFR esES esMX ptBR ruRU koKR zhCN zhTW itIT`.

## Etiquette & anti-patterns

- Don't taint Blizzard frames; **never `SetScript` over a Blizzard handler** — `hooksecurefunc`/`HookScript` instead.
- Always register comm prefixes; keep one global namespace table to avoid collisions.
- Prefer events over polling; on disable, `UnregisterEvent`/unhook and stop `OnUpdate` (`SetScript("OnUpdate", nil)`).
- Strip debug `print`s before release (luacheck flags stragglers); never spam chat or comm channels.

## Pre-ship checklist

Before you tag a release, confirm:

- [ ] **luacheck passes** — no leaked globals (missing `local`), undefined APIs, or unused locals (CI runs it).
- [ ] **Offline checks green** — busted specs + a wowless load-test pass ([testing.md](testing.md)).
- [ ] **Fresh install works** — delete your `WTF/.../SavedVariables/<Addon>.lua`, `/reload`, verify defaults apply with no errors.
- [ ] **Upgrade path works** — load a PREVIOUS-version SavedVariables file; migration runs with no data loss ([saved-variables.md](saved-variables.md)).
- [ ] **Clean error log** — `/console scriptErrors 1` through a full login → use → `/reload` → logout cycle, no errors.
- [ ] **No combat taint** — exercise every secure / frame-moving feature *in combat*; watch for "action blocked". Protected changes deferred to `PLAYER_REGEN_ENABLED`.
- [ ] **Throttled** — no unthrottled `OnUpdate`/CLEU; no raw `SendAddonMessage` floods (ChatThrottleLib/AceComm).
- [ ] **Cleans up** — disable/feature-off unregisters events, cancels tickers, stops `OnUpdate`.
- [ ] **Localized** — user-facing strings via your locale table (no concatenated translated fragments); falls back to enUS.
- [ ] **No debug spam** — `print`/dumps gated behind a debug flag or removed.
- [ ] **TOC correct** — `## Interface: 11508`, `## SavedVariables` declared, `## Version` uses `@project-version@` if packaged.
- [ ] **Profiled** — if performance-sensitive, a hot path checked with `scriptProfile` + `GetAddOnCPUUsage` or `debugprofilestop()`.
- [ ] **Releases cleanly** — tag → BigWigs packager; `.pkgmeta` externals resolve; CI lint + release green.
