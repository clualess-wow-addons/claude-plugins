# Custom triggers and the Trigger State Updater (TSU)

Verified against WeakAuras 5.21.8 (the shipped Classic Era build) and the official wiki, July 2026.

## Contents
- The three custom trigger types
- Trigger/untrigger contract (Event and Status)
- Event(s) box syntax
- CLEU: filters are mandatory, args are passed to you
- TSU: contract, state fields, clone keys, helper methods
- Watched triggers (TRIGGER:n)
- Custom dynamic-info functions (non-TSU)
- Custom Variables block (TSU)
- Performance and throttling
- Debugging

## The three custom trigger types

Trigger → Type "Custom" → Custom Trigger:
- **Event** (`custom_type=event`) — fires on the listed events; hides via "Hide: Timed" (auto after N seconds, no untrigger function) or "Hide: Custom" (custom untrigger).
- **Status** (`custom_type=status`) — represents an ongoing condition; Check On "Event(s)" or "Every Frame (High CPU usage)". Receives a dummy no-arg `STATUS` event on login/reload/options-close to establish initial state.
- **Trigger State Updater (Advanced)** (`custom_type=stateupdate`) — full control via `allstates`; effectively a Status trigger (gets `STATUS` too). Has NO untrigger and NO custom duration/name/icon/texture/stacks functions — all dynamic info comes from state fields.

While an aura is open in WA options it also receives fake `OPTIONS` events, and fake states are auto-created if the trigger provides none — live behavior differs from options-open behavior.

## Trigger/untrigger contract (Event and Status)

```lua
--Event(s): ENCOUNTER_START, ENCOUNTER_END
--Trigger
function(event, arg1, arg2, ...)
    if event == "ENCOUNTER_START" then
        return true
    end
end
--Untrigger
function(event, arg1, arg2, ...)
    if event == "ENCOUNTER_END" then
        return true
    end
end
```

- The event name is always the first argument (except TSU, where `allstates` comes first).
- Trigger returning `true` activates. Returning false/nil does **not** deactivate — it routes the same args into the untrigger, which must itself return `true` to deactivate.
- Source: [Custom-Triggers wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Triggers).

## Event(s) box syntax

Whitespace/comma separated. Exact forms (wiki + parsing loop in GenericTrigger.lua):

```
UNIT_SPELLCAST_SUCCEEDED:player          -- unit filter (RegisterUnitEvent — only fires for that unit)
UNIT_HEALTH:grouppets                    -- 'pets'/'petsonly' suffix on group units
CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REMOVED   -- CLEU subevent filter; chain with ':'
COMBAT_LOG_EVENT_UNFILTERED:SPELL_CAST_START -- same thing, long form
TRIGGER:1:2                              -- watched triggers (see below)
FRAME_UPDATE                             -- WA-synthesized every-frame event (mixable with real events; elapsed time arrives as the first arg after the event name)
```

`STATUS` (the dummy init event) is NOT an Event(s)-box form — it is auto-delivered to Status/TSU triggers on login/reload/options-close whether or not you list it; listing it is a no-op, and Event-type triggers never receive it.

**Classic Era caveat:** the `boss` and `arena` meta-unit tables are empty on the Vanilla flavor (Types.lua gate), so built-in unit triggers and state expansion skip them; explicitly-typed tokens like `boss1` do get registered by WA, but the Era client is not known to fire unit events for boss/arena tokens (unverified in-game). Either way: don't rely on boss/arena units on Era. `nameplate1-40`, `group`, `party`, `raid` work.

Other WA-synthesized events you can list: `WA_DELAYED_PLAYER_ENTERING_WORLD` (0.8s after PLAYER_ENTERING_WORLD, same args), `TENCH_UPDATE` (weapon-enchant rescan). `WA_TALENT_UPDATE` is retail-only.

## CLEU: filters are mandatory, args are passed to you

- **Unfiltered CLEU is disabled.** A bare `CLEU`/`COMBAT_LOG_EVENT_UNFILTERED` entry registers nothing — the trigger silently never fires and the aura shows a red warning. This killed many old imports ([Deprecated-CLEU wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Deprecated-CLEU)). Fix: append subevent filters.
- WA itself calls `CombatLogGetCurrentEventInfo()` and passes the **full payload as arguments**. Never call it yourself. The `event` argument stays `"COMBAT_LOG_EVENT_UNFILTERED"` even if you typed `CLEU`.

```lua
-- Event(s): CLEU:SPELL_CAST_SUCCESS
function(event, timestamp, subEvent, hideCaster,
         sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
         destGUID, destName, destFlags, destRaidFlags,
         spellId, spellName, spellSchool, ...)
    if subEvent == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("player") then
        return true
    end
end
```

Era note: CLEU spellIds are real since 1.15.0 but **rank-specific** — match on `spellName` for rank-agnostic logic, or list every rank's ID.

## TSU: contract, state fields, clone keys, helper methods

Signature: `function(allstates, event, ...)` — allstates first, then the event name, then that event's args (for CLEU: the full payload).

**Return semantics:** with plain-table writes you must set `changed = true` on every touched state AND `return true`. The `allstates` helper methods set changed themselves and make the return unnecessary; explicitly returning `false` suppresses even helper-based updates (GenericTrigger.lua L664).

**Helper methods** (TSUHelpers.lua; there is **no** `allstates:Create`):

```lua
allstates:Update(cloneId, newState)   -- create or update; ignores nil fields
allstates:Replace(cloneId, newState)  -- full replace; CAN nil-out fields
allstates:Remove(cloneId)
allstates:RemoveAll()
allstates:Get(cloneId[, stateKey])
```

The helpers have existed for years; only WA 5.21.3 shipped them broken (fixed in [5.21.4](https://github.com/WeakAuras/WeakAuras2/releases/tag/5.21.4)).

**Clone keys:** the allstates table key IS the cloneId. Constant key (`""`) = one region; semantic key (destGUID, sourceName, spellId) = one clone per unique key; `#allstates+1` = always new. Each TSU trigger has its own private allstates — triggers never share states (use watched triggers to bridge).

**State fields** ([TSU wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Trigger-State-Updater-(TSU))):

| Field | Meaning |
|---|---|
| `changed` | REQUIRED true on every modified state (plain-table style) |
| `show` | Legacy; modern style is: remove the state (or `show=false`, which auto-removes). Old imports may run a compatibility mode requiring explicit show |
| `progressType` | `"timed"` (+ `duration`, `expirationTime` relative to GetTime()) or `"static"` (+ `value`, `total`) |
| `autoHide` | true = drop the state when a timed progress expires (no removal event needed) |
| `paused`, `remaining` | Pause a timed state; resume with `paused=false` + recomputed `expirationTime` |
| `name`, `icon`, `texture`, `stacks`, `index` | Display info; `index` orders dynamic groups (don't mix key types) |
| `unit` | A valid unitID — enables anchor-to-nameplate/unitframe, Group By Frame, glows |
| `additionalProgress` | Overlay segments: array of `{min, max}` or `{direction = "forward"\|"backward", width[, offset]}` subtables |
| `spellId`, `itemId`, `link`, `tooltip`, … | Tooltip sources |
| *anything else* | Custom fields — readable per-clone as `aura_env.state.<field>` and printable as `%fieldName` |

Canonical example (adapted from the wiki's TSU example — overlay `additionalProgress` block omitted; group cast bars with per-caster clones):

```lua
-- Event(s): COMBAT_LOG_EVENT_UNFILTERED:SPELL_CAST_START
function(allstates, event, _, subEvent, _, _, sourceName, _, _, _, _, _, _, spellID)
    if subEvent == "SPELL_CAST_START" and UnitExists(sourceName) and spellID == 123456 then
        local name, _, icon, startMS, endMS = UnitCastingInfo(sourceName)
        if name then
            allstates[sourceName] = {
                changed = true,
                progressType = "timed",
                duration = (endMS - startMS) / 1000,
                expirationTime = endMS / 1000,
                name = name,
                icon = icon,
                caster = sourceName,   -- custom field → %caster
                autoHide = true,
            }
            return true
        end
    end
end
```

**Clone-region pool warning (official):** clone regions are pooled and reused across auras. Never add FontStrings, SetScript handlers, or SetPoint re-anchors to clone regions — WA can't reset them and On Hide is not a reliable cleanup point (it doesn't run when opening WA options). For anchoring use `region:SetAnchor(point, frame, framePoint)` and `region:SetOffset(x, y)`.

## Watched triggers (TRIGGER:n)

`TRIGGER:5` or `TRIGGER:1:2` in the Event(s) box fires your custom trigger whenever those triggers update, as `(event, updatedTriggerNumber, updatedTriggerStates)` — `updatedTriggerStates` keyed by cloneId (`""` for non-cloning triggers). Reciprocal watching is blocked; delivery is deferred. Official example: [WatchedTriggerExample](https://wago.io/WatchedTriggerExample).

## Custom dynamic-info functions (Event/Status triggers only — NOT TSU)

- Duration Info: timed → `return duration, expirationTime`; static → `return value, total, true` (a 4th return sets `state.inverse`).
- Name/Stack/Icon/Texture Info: return the value (stacks must be a number). Icon Info feeds icons + progress bars; Texture Info feeds texture regions.
- Overlay funcs: return `(min, max)` or `("forward"|"backward", width[, offset])`.

## Custom Variables block (TSU)

The box below a TSU function is a plain **table** (not a function) declaring state fields for Conditions and Progress Sources:

```lua
{
    additionalProgress = 1,          -- N overlay pickers
    expirationTime = true, stacks = true,   -- enable standard conditions
    unit = "string",
    spellUsable = {
        display = "Spell Usable",
        type = "bool",               -- bool needles arrive as 1/0, not true/false
        test = function(state, needle)
            return state and (IsUsableSpell(state.spellname) == (needle == 1))
        end,
        events = { "SPELL_UPDATE_USABLE", "PLAYER_TARGET_CHANGED" },
    },
}
```

Types: `bool`, `number` (test gets value+comparator), `string`, `timer` (compares remaining time vs GetTime()-relative value), `elapsedTimer`, `select` (with `values` map). number/timer/elapsedTimer fields become selectable Progress Sources.

## Performance and throttling

- Filters in the Event(s) box beat filtering in Lua — WA pre-filters by CLEU subevent and unitID before your function runs (PR #1325).
- Every-frame auras cost real CPU (~0.1–0.4% each, per WA-contributor measurement in PR #2487). Prefer events.
- For FRAME_UPDATE work, use the built-in **"Custom trigger Update Throttle"** spinbox (`trigger.onUpdateThrottle` — shown only on Status/TSU custom triggers when Check On = Every Frame or FRAME_UPDATE is listed; Event-type triggers listing FRAME_UPDATE get every-frame calls with no throttle option). It throttles ONLY the FRAME_UPDATE branch — real events are never throttled by it.
- For CLEU-storms (40-man raids), hand-roll a guard, as the #1 absorb tracker does: `if not aura_env.last or aura_env.last < GetTime() - 0.05 then aura_env.last = GetTime() ... end`.
- The "delay" option belongs to built-in event prototypes only; custom triggers can't use it.

## Debugging

- `DebugPrint(...)` (injected into the sandbox) writes to the aura's Debug Log (right-click the aura in the options list).
- Inspect state tables with the DevTool addon: `DevTool:AddData(updatedTriggerStates, "states")`.
- An aura that "never fires" after an update: check for the bare-CLEU red warning first.
