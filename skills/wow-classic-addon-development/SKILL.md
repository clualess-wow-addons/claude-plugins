---
name: wow-classic-addon-development
description: Use when creating, debugging, reviewing, or optimizing World of Warcraft Classic Era / Vanilla (1.15.x) Lua addons — Lua errors, taint or combat-lockdown ("action blocked") issues, frame and event handling, combat-log parsing, SavedVariables, slash commands, secure action buttons, TOC files, Ace3/LibStub, cast tracking, or any question about Classic Era API availability.
---

# WoW Classic Era Addon Developer

## Overview

Expert reference for building, debugging, and optimizing addons on the WoW **Classic Era** client (**1.15.x**, interface `11507`/`11508`). Distilled from the real installed addon corpus (Questie, Bartender4, DBM, ClassicCastbars, DataStore, Decursive, unitscan, …) and warcraft.wiki.gg.

**Core principle: verify every API against Classic Era.** Many modern WoW APIs are absent or behave differently here — confirm an API exists in Era before using it, and respect the taint / combat-lockdown system that governs what addons may do. Apply this skill's guidance inline; for a full structured audit of an existing addon, the `/luanalyze` command runs this same knowledge end-to-end via a subagent.

## When to use

- Creating a new Classic Era addon (TOC, entry Lua, SavedVariables, slash commands, UI)
- Debugging Lua errors, nil API calls, `ADDON_ACTION_BLOCKED` / taint, combat-lockdown failures
- Reviewing an addon for bugs, performance, or API-compatibility issues
- Event/combat-log handling, cast tracking, secure click-casting, data layers

**Not for:** modern (post-Classic) WoW APIs, private-server emulation, or non-addon Lua.

## Three architecture archetypes — identify which one you're in

1. **Minimal / no-framework** — single file(s), `local ADDON, ns = ...`, one event frame, raw SavedVariables. Best for small/solo addons. *e.g. TransmuteTimer, Coordinates, unitscan.* → `reference/minimal-addons.md`
2. **Ace3-native** — `AceAddon` + `AceDB` + `AceEvent` + `AceConfig`, fully embraced. The default for most feature-rich addons. *e.g. Questie, Bartender4, RXPGuides.* → `reference/ace3.md`
3. **Custom framework** — the addon rolls its own module loader / class system and embeds only the Ace *libraries* it needs (often just `AceComm` + `AceSerializer`), not `AceAddon`. Only worth it at large/multi-team scale. *e.g. TradeSkillMaster (LibTSM + LibTSMClass), WeakAuras, Details!.*

Ace3 is **modular** — you can `LibStub` any single Ace library without adopting the whole framework. Don't assume a big addon uses `AceAddon` just because it embeds an Ace lib.

## Deep-reference map — read the file that matches the task

| File | Covers |
|---|---|
| [reference/lua-primer.md](reference/lua-primer.md) | Lua 5.1 language itself — types/truthiness, operators, control flow, functions + varargs, tables, string patterns (not regex), metatables, gotchas. Start here if Lua itself is unfamiliar |
| [reference/example-addon.md](reference/example-addon.md) | **A complete runnable addon (TOC + Lua) end-to-end** — lifecycle, SavedVariables, a movable saved-position window with tabs, a scrolling list, an options-backed setting, slash command. The on-ramp |
| [reference/minimal-addons.md](reference/minimal-addons.md) | No-framework bootstrap, `local ADDON, ns = ...`, SavedVariables merge/migration, slash commands, hooks, color/print, frames + backdrops, localization |
| [reference/ace3.md](reference/ace3.md) | AceAddon/AceDB/AceEvent/AceConfig, modules, LibStub, embedding, CallbackHandler |
| [reference/events-and-combat-log.md](reference/events-and-combat-log.md) | Event dispatch forms, `COMBAT_LOG_EVENT_UNFILTERED`, throttling, `C_Timer`, Classic cast-tracking reality, chat parsing, register/unregister |
| [reference/secure-and-taint.md](reference/secure-and-taint.md) | `SecureActionButtonTemplate`, attributes, state drivers, `InCombatLockdown`, defer/replay, the taint model, click-casting, one-button-one-action |
| [reference/ui-widgets.md](reference/ui-widgets.md) | Building UI — XML layout, widget cookbook (Button/StatusBar/EditBox/FauxScrollFrame/Slider/Cooldown), GameTooltip authoring, dropdowns, hyperlinks, sound/LibSharedMedia, minimap buttons, key bindings |
| [reference/ui-windows.md](reference/ui-windows.md) | Assembling windows — chrome templates (BasicFrame/Portrait/ButtonFrame), tabs, StaticPopup dialogs, Esc-to-close, real ScrollFrame, the **Settings** options panel (Era dropped `InterfaceOptions_AddCategory`), color picker, anchoring depth |
| [reference/ui-graphics.md](reference/ui-graphics.md) | Drawing — texture atlases, mask textures, nine-slice/backdrops, gradients/blend, fonts & FontObjects, animations in depth (types, looping, the snap-back gotcha) |
| [reference/ui-frames.md](reference/ui-frames.md) | Frame mechanics — pixel-perfect rendering & UI scale, full mouse interaction (+ Classic passthrough), frame strata/level/draw sublevels, 3D model frames |
| [reference/classic-api.md](reference/classic-api.md) | Game-data APIs — units, auras (LibClassicDurations), items/bags, spells/cooldowns, quests, group/raid, money/vendor/mail, the legacy Auction House, talents, maps (HereBeDragons), nameplates |
| [reference/saved-variables.md](reference/saved-variables.md) | Cross-character schema, DataStore pub/sub, big-table performance, item caching, serialization libs |
| [reference/recipes.md](reference/recipes.md) | Cookbook of common tasks — track an aura→icon, movable saved-position frame, options checkbox, react-to-event, throttling, defer-in-combat, count bag items, expose a public API |
| [reference/best-practices.md](reference/best-practices.md) | Profiling, error handling (`geterrorhandler`/`safecall`), hot-path micro-perf, animations, luacheck, `.pkgmeta`/externals, lint + release CI, comms/tooltips/localization, and the **pre-ship checklist** |
| [reference/testing.md](reference/testing.md) | **Testing your addon offline** — the ladder: static luacheck/LuaLS → **busted** unit tests (logic + mocked API) → **wowless** headless full-addon load (runs against the real Era API) → in-client (WoWUnit/BugSack); the tool matrix + abandoned tools to avoid |
| [reference/compatibility.md](reference/compatibility.md) | Coexisting with other addons (name collisions, polite hooking, load order), LibStub version skew, detecting/handshaking another addon, and **ruleset differences** — Era vs Hardcore vs Season of Discovery on the shared 1.15.x build |

**Building UI — which file:** widgets (buttons, sliders, scroll lists, tooltips, dropdowns) → [ui-widgets](reference/ui-widgets.md) · window chrome, tabs, dialogs, the options panel → [ui-windows](reference/ui-windows.md) · textures, atlases, fonts, animations → [ui-graphics](reference/ui-graphics.md) · scale, layering, mouse, strata → [ui-frames](reference/ui-frames.md).

## Classic-specific rules (verify first, every time)

| Concern | Rule |
|---|---|
| API availability | Feature-detect (`if C_Foo and C_Foo.Bar then`) rather than assuming. Many modern `C_*` APIs are absent/partial in Era. |
| Protected actions | Casting, targeting, using items, moving/showing protected frames in combat require **secure** templates + a hardware click. Never from a timer/event. |
| Taint | Insecure code touching Blizzard tables/frames spreads taint → `ADDON_ACTION_BLOCKED`. Keep state in your own namespace; use `hooksecurefunc`, never overwrite Blizzard globals. |
| Combat lockdown | `InCombatLockdown()` guards protected changes. Defer to `PLAYER_REGEN_ENABLED`. |
| Spell ranks | Vanilla spells have multiple ranks — identify spells by **spellID**, not name. `GetSpellInfo`/`C_Spell.GetSpellInfo` take a spellID; the old `"Frostbolt(Rank 11)"` name-string lookup is unreliable (name lookup needs the spell in your book and modern Era no longer returns rank). Use `GetSpellSubtext(spellID)` for the rank text. |
| Enemy casts | `UnitCastingInfo` works for any unit, but `UnitChannelInfo` returns nothing for non-player units (engine bug). Use LibClassicCasterino / CLEU reconstruction for enemy channels and missed cast starts. |
| Macros | 255-char limit; one-button-one-action. No automation that picks the action for the player. |
| Tradeskills | Transmutes/recipes **cannot** be cast via `/cast` or `SecureActionButton type=spell` (silent fail). Use `DoTradeSkill(index, count)` from a normal OnClick (tradeskill window must have opened once that session). |

## Addon load lifecycle

| Event | Use for |
|---|---|
| `ADDON_LOADED` (arg1 == your addon) | **Earliest safe SavedVariables access.** Init DB + defaults, create frames. Gate on `arg1`. |
| `PLAYER_LOGIN` | Fires once after all addons load. One-time init, frame placement, reading game state. |
| `PLAYER_ENTERING_WORLD` | Fires every login/reload/zone. Recurring/instance setup — *not* one-time init. |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | Combat start / end. Finish secure-frame setup before combat; replay deferred work after. |

Avoid `VARIABLES_LOADED` (tracks Blizzard CVars, not your vars; can fire late). SavedVariables globals are **nil** before your `ADDON_LOADED`.

## TOC essentials (Classic Era)

```
## Interface: 11508          # 1.15.x build; comma-list multiple to silence "out of date". Verify in-game: /dump (select(4, GetBuildInfo()))
## Title: MyAddon
## Notes: Short description.
## Author: yourname
## Version: @project-version@   # packager replaces with the git tag
## SavedVariables: MyAddonDB             # account-wide
## SavedVariablesPerCharacter: MyAddonCD # per character
## OptionalDeps: Ace3                    # load after these if present
## X-Curse-Project-ID: 123456            # BigWigs packager upload target

MyAddon.lua                  # files load top-to-bottom, in order; deps before dependents
```

Other directives: `## Dependencies:` (hard, blocks load if missing), `## LoadOnDemand: 1` (+ `C_AddOns.LoadAddOn("Name")`), `## LoadWith:`, `## DefaultState:`, `## IconTexture:`, `## Category:`, `## X-*` custom metadata (read via `C_AddOns.GetAddOnMetadata`). The current Era build is `11508`.

## WoW Lua 5.1 environment

Stock **Lua 5.1** with security edits. Available: `string` (+ `strsplit`/`strtrim`/`format`), `table` (+ `wipe`), `math`, `bit` (`bit.band/bor/bxor/lshift`), `coroutine`, `pcall`/`xpcall`/`select`/`setmetatable`/`unpack`, plus WoW extras (`hooksecurefunc`, `securecall`, `C_Timer`, `fastrandom`). **Removed for security:** the `os` and `io` libraries, `package` (incl. `require`), `dofile`/`loadfile`. The only OS facilities are the bare globals `time`/`date`/`difftime` (no `clock` — use `GetTime()`/`debugprofilestop()`). `loadstring` exists but its output runs *tainted*. New to the language itself (1-based tables, `~=`, truthiness, patterns-not-regex, metatables)? See [lua-primer.md](reference/lua-primer.md).

## Code quality standards

- `local` everything; expose at most one global table. Cache globals as upvalues in hot paths (`local GetTime, band = GetTime, bit.band`).
- Throttle `OnUpdate` (fires every frame); stop it (`SetScript("OnUpdate", nil)`) when idle. Prefer events over polling; `UnregisterEvent` when done.
- Recycle frames (`CreateFramePool`) — frames can't be destroyed. `wipe()` and reuse tables to cut GC churn.
- `pcall` risky calls; check nil returns from API. Naming: PascalCase frames, camelCase functions/locals.
- Guard combat: `if InCombatLockdown() then return/defer end` in anything touching protected state.
- WoW has **no compile step** — lint with **luacheck** (`std="lua51"`) and the **Lua Language Server** + WoW API types (editor autocomplete + live diagnostics) to catch leaked globals, typos, and undefined/misused APIs before they ship. A leaked global (missing `local`) doesn't error; it taints and collides. See [best-practices.md](reference/best-practices.md).
- **Test offline before launching the game:** luacheck/LuaLS (static) → **busted** (unit tests, incl. mocked API) → **wowless** (headless full-addon load against the real Era API) → in-client (**WoWUnit** / **BugSack**). See [testing.md](reference/testing.md).

## Debugging

`/console scriptErrors 1` (enable error popups) · `/run <lua>` (execute a snippet inline) · `/dump <expr>` · `/tinspect <table>` · `/etrace` (live event log + args) · `/fstack` (frame under cursor) · `/api` (in-game API browser — **ships in Era**; `Blizzard_APIDocumentation` is in the classic_era UI source) · **BugSack + !BugGrabber** (capture all errors incl. startup) · **DevTool** (`/dev` — GUI table/value inspector, Era-current) · **`/console taintLog 2`** (trace a taint / "action blocked" source to `Logs/taint.log`). Browse the default UI's own Lua at warcraft.wiki.gg or **wago.tools**. Profile with `/console scriptProfile 1` + `GetAddOnCPUUsage` (or `C_AddOnProfiler`), or `debugprofilestop()` for a hot path — see [best-practices.md](reference/best-practices.md).

**Symptom → first check:**

| Symptom | Likely cause → fix |
|---|---|
| `attempt to call a nil value` | API absent in Era, or load-order — feature-detect; confirm it exists ([classic-api.md](reference/classic-api.md)) |
| `attempt to index a nil value` | unguarded API return (e.g. async `GetItemInfo` nil) — nil-check before use |
| `ADDON_ACTION_BLOCKED` | insecure code touched protected state — `/console taintLog 2` → `Logs/taint.log`; use secure templates ([secure-and-taint.md](reference/secure-and-taint.md)) |
| SavedVariables empty / reset | read before your `ADDON_LOADED`, or `.toc` name mismatch |
| Frame invisible / behind the world | wrong strata/level, or missing size/anchor/`Show()` |

## Common mistakes

- Calling a protected function (cast/target/move) from a normal OnClick or timer → blocked in combat. Use a secure button + hardware click.
- Reading SavedVariables at file scope (they're nil until your `ADDON_LOADED`).
- Assuming a modern API exists in Era; using `SetTexture(r,g,b)` for color (use `SetColorTexture`); calling `SetBackdrop` without the `BackdropTemplate`.
- Overwriting a Blizzard global by plain assignment instead of `hooksecurefunc` → taints everything downstream. (Leaked globals: see Code-quality above.)
- Unthrottled `OnUpdate`/CLEU handlers → raid frame-rate drops. Blocking on `GetItemInfo` instead of waiting for `GET_ITEM_INFO_RECEIVED`.

## Useful Classic-ecosystem libraries

**Ace3** suite (AceAddon/DB/Event/Config/Comm/Console/Timer/Hook/Serializer, plus **AceBucket** — coalesce bursty events into time-windowed batches: `RegisterBucketEvent("BAG_UPDATE", 0.5, handler)`) · **LibStub** (versioned lib loader) · **HereBeDragons-2.0** (+ **-Pins-2.0**) — map/minimap coordinate translation and pin management; **essential** for any waypoint/arrow/map-overlay addon (Questie, RXPGuides, TomTom) · **LibDataBroker-1.1** + **LibDBIcon-1.0** (data broker objects + minimap buttons) · **LibSharedMedia-3.0** (fonts/sounds/textures) · **LibClassicDurations** (other-unit buff/debuff durations) · **LibClassicCasterino** (enemy cast bars from CLEU) · **LibSerialize** + **LibDeflate** (serialize + compress import/export strings & addon comms).

## Reference: major addon architectures

WeakAuras (trigger→display auras) · Details!/Recount (combat-log parsing) · DBM/BigWigs (encounter timers, short-term event registration, ref-counted dispatch) · Questie (Ace3 + map overlays) · TSM/Auctionator (AH automation, throttled big-table scanning) · DataStore/Altoholic (cross-character pub/sub DB) · Decursive (taint-careful secure casting). Use these as living examples of the patterns in the reference files.
