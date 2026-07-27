---
name: wow-classic-weakauras-development
description: Use when creating, debugging, reviewing, or publishing WeakAuras for WoW Classic Era — custom triggers (Event/Status/TSU), CLEU filters, allstates/clones, aura_env, custom text or duration functions, load conditions for Era/SoD/Hardcore, wago.io import strings and updates, or an aura that silently stopped firing after a WeakAuras update.
---

# WoW Classic Era WeakAuras Development

## Overview

Reference for authoring WeakAuras (custom auras) on the Classic Era flavor (client 1.15.x). Verified against WeakAuras 5.21.8 source, the official wiki, and decoded code from the top wago.io classic auras (July 2026).

**Core principles:**
1. **Built-in triggers first.** A decoded-code census of the top 10 wago auras for all nine classes (~90 auras) found built-ins carrying ~90-96% of all triggers, with at least one zero-custom-Lua aura in every class's top 10 — including 100+-child packs. Reach for custom code only when no built-in trigger covers it; built-in trigger configuration is UI-discoverable in `/wa` — this skill documents the custom-code layer.
2. **Verify for the Era flavor.** WA ships one codebase but gates features per flavor; retail answers (and retail wiki examples) are often wrong on Era. Same for the client API — see the `wow-classic-addon-development` skill for general Era API rules.
3. **Filter in the Event(s) box, not in Lua.** WA pre-filters CLEU subevents and unit events before your function runs — it's strictly cheaper, and for CLEU it's mandatory (see below).

## Quick reference — the gotchas that break auras

| Fact | Detail |
|---|---|
| Bare CLEU is dead | `COMBAT_LOG_EVENT_UNFILTERED` / `CLEU` without a subevent filter **registers nothing** — the trigger silently never fires. Use `CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REMOVED` (chain with `:`) |
| CLEU args | WA calls `CombatLogGetCurrentEventInfo()` for you and passes the payload as varargs — never call it yourself. Offsets after `event`: 2=subevent, 4=sourceGUID, 8=destGUID, 9=destName, 12=spellId |
| TSU helpers | `allstates:Update(cloneId, state)`, `:Remove`, `:RemoveAll`, `:Replace`, `:Get` — set `changed` for you, no `return true` needed (but an explicit `return false` suppresses even helper updates). There is **no** `allstates:Create`. Plain-table writes still need `changed = true` **and** `return true` |
| aura_env lifecycle | ONE table per aura, **shared by all clones**. Reset at logout/**reload** (PLAYER_LOGOUT fires on /reload too) or when the aura is edited — but NOT on plain load/unload. On Init runs once per session, re-running after /reload or edits. Only `aura_env.saved` persists across reload/sessions |
| Sandbox | Custom code cannot use `pcall`, `xpcall`, `loadstring`, `getfenv`/`setfenv`; `WeakAuras` is a read-only proxy. `DebugPrint(...)` writes to the aura's Debug Log |
| Era meta-units | Don't rely on `boss`/`arena` units on Era: the meta-unit tables are empty on the Vanilla flavor, and the client isn't known to fire unit events for those tokens; `nameplate`, `group`, `party`, `raid` work |
| Spell ranks | Era CLEU spellIds are real (since 1.15.0) but **rank-specific** — match `spellName` for rank-agnostic logic |
| UnitBuff/UnitAura | Deprecation shims on 1.15.8+ (cvar-gated, will be removed). Use `WA_GetUnitBuff/WA_GetUnitDebuff` (sandbox helpers with C_UnitAuras fallback) or `C_UnitAuras` directly |
| ScanEvents is async | `WeakAuras.ScanEvents("MY_EVENT", ...)` delivers on the **next frame**, not synchronously |
| Updates keep user config | The import/update dialog's `userconfig` and `anchor` categories default to OFF — users keep their option values and positions as long as you don't rename option keys |
| Read any wago aura's code without importing | `curl 'https://data.wago.io/lookup/wago/code?id=<slug>'` returns the decoded aura table, every custom-code block, and luacheck results (`<slug>` = the wago.io URL path segment; browser User-Agent required). Same data in-browser: the aura page's **Editor** tab. Full endpoint list in [references/publishing-wago.md](references/publishing-wago.md) |

## Reference files

- [references/custom-triggers-and-tsu.md](references/custom-triggers-and-tsu.md) — the three custom trigger types and their exact contracts, Event(s) box syntax, TSU state fields and clone keying, watched triggers, throttling and performance.
- [references/aura-environment.md](references/aura-environment.md) — every custom-code entry point, `aura_env` fields and lifecycle, sandbox limits, WA helper functions, custom text/duration/activation/animation/dynamic-group functions.
- [references/classic-era-specifics.md](references/classic-era-specifics.md) — flavor packaging, Load-tab options for Era/SoD/Hardcore, trigger types removed or exclusive on Era, era API differences inside aura code, the 2026 realm landscape.
- [references/examples.md](references/examples.md) — working patterns harvested from the top wago.io classic auras (swing timer, energy ticks, CLEU procs, multi-target clones, nameplate anchoring, clickable auras, absorb accounting…), each with source attribution.
- [references/publishing-wago.md](references/publishing-wago.md) — export-string format, wago.io publishing and versioning, the Companion update pipeline, settings-preserving update categories, pack architecture lessons from Luxthos/Fojji, and the data API for inspecting any aura's code.
- [references/top-auras-by-class.md](references/top-auras-by-class.md) — decoded-code field study of the top 10 wago auras per class (~90 auras): cross-class findings, the one-snippet-per-class table (energy tick, FSR mana tick, powershift counter, Bouk castbar, seal-twist schools…), and per-class top-10 tables with patterns.

## Common mistakes

| Mistake | Reality |
|---|---|
| Copying a retail wiki example onto Era | Check flavor gates first: e.g. `Enum.PowerType.Essence`, `boss1` filters, `WA_TALENT_UPDATE` are retail-only |
| `allstates[""] = {...}` without `changed=true`/`return true` | State silently ignored. Or use the helper methods |
| Doing per-clone bookkeeping in `aura_env` | aura_env is shared across clones — per-clone data belongs in the state table |
| Heavy work on FRAME_UPDATE | Every-frame auras cost ~0.1–0.4% CPU each; prefer events, or set the built-in "Custom trigger Update Throttle" |
| Expecting On Hide for cleanup | On Hide doesn't always run (e.g. when opening WA options); never mutate pooled clone regions in non-resettable ways |
| Testing only with WA options open | Options fire fake OPTIONS/STATUS events and auto-create fake states — behavior differs from live play |
