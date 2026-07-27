# aura_env, the sandbox, and every custom-code entry point

Verified against WeakAuras 5.21.8 source (AuraEnvironment.lua) and the official wiki, July 2026.

## Contents
- Where custom Lua can live
- aura_env fields and lifecycle
- aura_env.saved (persistence)
- aura_env.config (Custom Options)
- The sandbox: what's blocked
- Helper functions available to custom code
- Cross-aura communication: WeakAuras.ScanEvents
- Custom Text functions
- Actions: On Init / On Show / On Hide
- Custom Activation, Conditions, Animations
- Dynamic groups: Custom Sort / Grow / Anchor / Group-by-Frame

## Where custom Lua can live

Trigger tab: Custom Trigger (Event/Status/TSU), Custom Untrigger, Duration/Name/Icon/Texture/Stack/Overlay Info, Custom Variables (TSU).
Activation: Custom Function. Display: Custom Text (%c), Custom Anchor. Actions: On Init / On Show / On Hide + chat-message %c. Conditions: Custom Check, Run Custom Code action. Animations: custom Alpha/Translate/Scale/Rotate/Color functions. Dynamic groups: Custom Sort, Custom Grow, Group by Frame. All present on Classic Era. ([Custom-Code-Blocks wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Code-Blocks))

## aura_env fields and lifecycle

| Field | What | Lifecycle |
|---|---|---|
| `aura_env.id` | Aura name | pointer swapped per activation |
| `aura_env.cloneId` | Current clone key (`""` for non-clones) | per activation |
| `aura_env.state` | Current clone's state table | per activation |
| `aura_env.states` | Per-trigger states (`aura_env.states[2]`); wiki: not accessible from trigger functions | per activation |
| `aura_env.region` | The aura's region frame (base region during init) | per activation |
| `aura_env.config` | User's Custom Options values | snapshot at env init |
| `aura_env.saved` | Author storage that survives sessions | serialized at logout |
| *your own fields* | Anything you assign | live until logout or aura edit |

**The critical mental model (verified in source):** there is ONE `aura_env` table per aura, shared by ALL clones — WA only swaps the `id`/`cloneId`/`state`/`states`/`region` pointers when activating the environment for a region. Your own `aura_env.*` variables persist for the whole session and are NOT per-clone. Per-clone data belongs in the state table.

The environment is destroyed only at PLAYER_LOGOUT — **which also fires on /reload** — or when the aura (or its group parent) is edited in Options. Plain load/unload does NOT reset it. **On Init therefore runs once per session**, not on every load — and again after a /reload or an edit resets the env. Only `aura_env.saved` carries data across that reset.

## aura_env.saved (persistence)

The only thing that survives reload/logout. Serialized (LibSerialize + LibDeflate) into WeakAurasSaved at logout; unserializable values (functions, frames) are silently dropped. Initialize defensively:

```lua
-- Actions > On Init (code BLOCK — no function() wrapper, no args, no return)
aura_env.saved = aura_env.saved or {}
aura_env.saved.killCount = aura_env.saved.killCount or 0
```

Keep it small — WA warns when an aura saves too much.

## aura_env.config (Custom Options)

A CopyTable snapshot of the user's Custom Options, keyed by Option Key; guaranteed initialized before On Init runs. Shapes:

```lua
local cfg = aura_env.config
cfg.showIcon          -- toggle → boolean
cfg.labelText         -- input → string
unpack(cfg.barColor)  -- color → {r,g,b,a} normalized
cfg.sortMode          -- select → integer (1-based)
cfg.categories[3]     -- multiselect → booleans by index
cfg.style.scale       -- Option Group (simple)
cfg.spells[i].name    -- Option Group (array)
```

Option types: toggle, input, number, range, color, select, multiselect, media (+ noninteractive description/space/header, and group simple|array). On updates, only nil keys receive author defaults — existing user values are kept (see publishing-wago.md for the full update semantics).

## The sandbox: what's blocked

Custom code runs in a restricted environment (AuraEnvironment.lua). Blocked (error "Forbidden function or table"): `getfenv`, `setfenv`, `loadstring`, **`pcall`, `xpcall`**, `SendMail`-family, `EnumerateFrames`, `RunScript`, `CreateMacro`/`EditMacro`, `ChatEdit_*`, frame-metatable getters; blocked tables: `SlashCmdList`, `DEFAULT_CHAT_FRAME`, `ChatFrame1`, `WeakAurasSaved`. The `WeakAuras` table is a read-only proxy that additionally blocks `WeakAuras.Add/Delete/Rename/Import` etc. `DebugPrint(...)` is injected (writes to the aura's Debug Log).

Design consequence: you cannot pcall-guard risky calls — structure code to avoid errors instead.

## Helper functions available to custom code

From the [Useful-variables-and-functions wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Useful-variables-and-functions-within-WeakAuras), all on Era:

```lua
WA_GetUnitBuff(unit, spellNameOrId[, filter])   -- UnitAura-style returns; falls back to
WA_GetUnitDebuff(unit, spellNameOrId[, filter]) -- C_UnitAuras when the globals are gone,
WA_GetUnitAura(unit, spell, filter)             -- so they survive the 1.15.8 deprecations
WA_IterateGroupMembers(reversed, forceParty)
WA_ClassColorName(unit)
WA_Utf8Sub(str, n)
WeakAuras.IsOptionsOpen()
WeakAuras.GetActiveConditions(aura_env.id, aura_env.cloneId)
WeakAuras.CurrentEncounter   -- {id, zone_id, boss_guids}
WeakAuras.GetAuraTooltipInfo(unit, index, filter)
LibStub("LibCustomGlow-1.0") -- PixelGlow/AutoCastGlow/ButtonGlow Start/Stop
WeakAuras.IsClassicEra(), WeakAuras.IsRetail(), ... -- flavor checks; WeakAuras.BuildInfo
WeakAuras.GetSwingTimerInfo(hand), WeakAuras.InitSwingTimer()  -- see examples.md
WeakAuras.GetMHTenchInfo(), GetOHTenchInfo()    -- -> exp, dur, name, shortenedName, icon, charges, enchantID
                                                --    (expiration FIRST — different order than GetWeaponEnchantInfo)
WeakAuras.WatchSpellCooldown(id, ignoreRunes, useExact, followoverride)  -- wiki shows only (id)
WeakAuras.IsSpellInRange(spellIdOrName, unit)   -- nil/0/1; accepts spell ID (Blizzard's needs a name)
WeakAuras.CheckRange(unit, range, "<=" | ">=")  -- boolean, via LibRangeCheck
WeakAuras.GetRange(unit, checkVisible)          -- min, max
```

## Cross-aura communication: WeakAuras.ScanEvents

```lua
-- sender (any custom code):
WeakAuras.ScanEvents("MYADDON_PHASE_CHANGED", 2, GetTime())
-- receiver: Custom > Event trigger, Event(s): MYADDON_PHASE_CHANGED
function(event, phase, when) return phase == 2 end
```

- Delivery is **asynchronous** (queued, processed next frame) in current builds — do not rely on synchronous effects.
- Use unique event-name prefixes to avoid collisions. `WeakAuras.ScanEventsByID("EV", id, ...)` additionally fires `EV:id` for filtered listeners.
- Suites coordinate through a `_G` shared config table plus a ScanEvents "config updated" broadcast — see the Zippy's pattern in examples.md.

## Custom Text functions

Text field `%c` (or `%c1`…`%cN` for multiple returns); code in the Custom Text box.

- Timed-progress args: `(expirationTime, duration, progress, formatedDuration, name, icon, stacks)`; static: `(total, value, value, total, name, icon, stacks)`.
- **`progress` is a formatted STRING** — recompute from `aura_env.state.expirationTime` for math.
- Returning nil renders empty. Set "Update Custom Text On… Every Frame" only for live countdowns.
- Standard tokens need no code: `%p` progress/remaining time, `%n` name, `%s` stacks, `%i` icon. Any state field is printable directly as `%fieldName`; `%2.p` reaches trigger 2's progress; brace before adjacent text: `%{p}sec`.

```lua
function()
  if aura_env.state and aura_env.state.duration and aura_env.state.duration > 0 then
    local remaining = aura_env.state.expirationTime - GetTime()
    return remaining > 3600 and ceil(remaining/3600).."h"
        or remaining > 60 and ceil(remaining/60).."m"
        or floor(remaining)
  end
end
```

## Actions: On Init / On Show / On Hide

Code BLOCKS (no `function()` wrapper, no args/returns). Init: once per session per aura (see lifecycle above) — cache expensive lookups here (`aura_env.player = UnitGUID("player")`). On Show/On Hide run per clone with `aura_env.state`/`aura_env.region` pointing at that clone — but On Hide is not guaranteed in all paths (options opening); don't rely on it for critical cleanup.

## Custom Activation, Conditions, Animations

```lua
-- Activation (Required for Activation > Custom Function): receives per-trigger booleans
function(triggers) return triggers[1] and (triggers[2] or triggers[3]) end

-- Conditions > Custom Check: receives array of current states; extra re-eval events
-- can be listed in the text field above it
function(states)
  if states[1].expirationTime and states[2].expirationTime then
    return states[1].expirationTime < states[2].expirationTime
  end
end

-- Animations (called every frame; progress 0→1 Main/Finish, 1→0 Start):
-- Translate: function(progress, startX, startY, deltaX, deltaY) -> x, y
-- Alpha:  function(progress, start, delta) -> alpha
-- Scale:  function(progress, startX, startY, scaleX, scaleY) -> sx, sy
-- Rotate: function(progress, start, delta) -> degrees
-- Color:  function(progress, r1,g1,b1,a1, r2,g2,b2,a2) -> r,g,b,a
-- Always nil-check aura_env.state inside animation functions.
```

## Dynamic groups: Custom Sort / Grow / Anchor / Group-by-Frame

`regionData` objects: `{id, cloneId, dataIndex, data, region, xOffset, yOffset, show}`; state at `regionData.region.state`. Treat as read-only.

```lua
-- Custom Sort: true if a precedes b
function(a, b)
    return (a.region.state.expirationTime or 0) > (b.region.state.expirationTime or 0)
end

-- Custom Grow: fill newPositions[i] = {x, y, show}; returns nothing
function(newPositions, activeRegions)
    local mid = #activeRegions / 2
    for i = 1, #activeRegions do
        newPositions[i] = { 40 * (i - mid), 0.5 * (i - mid)^2 }
    end
end
-- frame-anchored form: newPositions[frame][regionData] = {x, y, show} (forms can't be mixed)

-- Display > Anchored To = Custom: no args, return a frame
function()
    if aura_env.state.destUnit then
        return C_NamePlate.GetNamePlateForUnit(aura_env.state.destUnit)
    end
end

-- Dynamic Group > Group By Frame = Custom Frames:
function(frames, activeRegions)
    for _, regionData in ipairs(activeRegions) do
        local unit = regionData.region.state and regionData.region.state.destUnit
        local frame = unit and C_NamePlate.GetNamePlateForUnit(unit)
        if frame then
            frames[frame] = frames[frame] or {}
            tinsert(frames[frame], regionData)
        end
    end
end
```

## Deprecations to recognize in old imports

WA 2.14 removed Sticky Duration/`SetDurationInfo`, `region.border`, `region.text`/`region.text2` — replaced by `region.subRegions` (check `subRegions[i].type == "subborder"` / `"subtext"`). Also `region:Rotate` was renamed `region:SetRotation` (WA 5.3.5+).
