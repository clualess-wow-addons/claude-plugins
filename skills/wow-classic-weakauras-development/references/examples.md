# Worked examples from top wago.io Classic auras

Patterns harvested July 2026 — several decoded verbatim from live wago.io auras (via `data.wago.io/lookup/wago/code?id=<slug>`), the rest from WeakAuras source/wiki. Attribution and provenance noted per pattern; "composed" = assembled from documented primitives, not field-tested in-game.

Style note: decoded patterns keep their original code style — including explicit `show = true`, which modern TSU style omits (states are shown by default; see custom-triggers-and-tsu.md). Don't "fix" verbatim code; do prefer modern style in new code.

## Contents
- Study list: top classic auras and what they teach
- 1. Melee swing timer
- 2. Energy tick tracker
- 3. CLEU proc tracker with autohide
- 4. Multi-target debuff clones (composed)
- 5. Weapon temp-enchant reminder
- 6. Totem tracker
- 7. Range check
- 8. Nameplate-anchored debuffs (from the #1 classic aura)
- 9. Hunter Auto Shot timer
- 10. Throttled CLEU absorb accounting
- 11. Clickable aura (secure macro button)
- 12. Cross-aura config bus
- 13. Data-as-aura (mob danger DB)

## Study list: top classic auras and what they teach

| Aura | Teaches |
|---|---|
| [Debuffs on nameplates](https://wago.io/4je3fCkT3) (#1: 213k views) | TSU + filtered CLEU + GUID→nameplate resolution + clone anchoring |
| [Jeyp's Boss Frames](https://wago.io/5Pz4pCOF5) (112k views) | Synthesized boss frames; 225-char addon-macrotext limit (late-2024 Blizzard change) constrains click-frames |
| [Cludes class packs](https://wago.io/z6xqQay0S) (9 classes, ~40-98k views each) | Big packs with ZERO custom code — built-in triggers + dynamic groups scale fine |
| [Luxthos packs](https://www.luxthos.com/hunter-weakauras-for-world-of-warcraft-classic-era-hardcore/) | Custom-options-driven configurability; see publishing-wago.md for the decoded architecture |
| [Fojji – Raid Pack Anchors](https://wago.io/Hwx_pYSPh) (8.5k installs) | Anchor-group architecture decoupling user layout from pack updates |
| [Classic – Warrior – Defcon](https://wago.io/pFY9Mig50) | Swing-timer-driven decision support (Heroic Strike cancel window spark) |
| [nanShield Classic Era](https://wago.io/QYAI_P7h1) | CLEU absorb reconstruction; fork lineage + min-WA-version documentation |
| [Classic Mob Abilities](https://wago.io/HJ5QPxCON) | Hardcore safety net; data-as-aura pattern |
| [Hunter Auto Shot Timer](https://wago.io/iBJTPFuk4) | Autorepeat-event state machine; era range-check idioms |
| [Easy Poisons – Classic ERA](https://wago.io/ohQoJB47-) | The canonical clickable-WA secure-button pattern |
| [Zippy's Raid Reset Timers](https://wago.io/mPnf_gBer) | Multi-aura suite coordination (config bus + ScanEvents) |
| [Kaedin's Classic Swing Timer](https://wago.io/02Mf5t9sZ), [5 Second Rule & Mana Ticks](https://wago.io/tKwhPGqCa), [Energy ticker](https://wago.io/MdQTg1sSp) | The tick/swing genre |
| [Classic World Buff Tracker](https://wago.io/5AJ5FOIk0) | Era world-buff/chronoboon bookkeeping |

Inspect any of them without importing: wago page → Editor tab (decoded table + custom code) / Code Review tab, or `curl 'https://data.wago.io/lookup/wago/code?id=<slug>'`.

For a per-class breakdown (top 10 auras per class with decoded-code analysis, plus the FSR mana-tick, powershift-counter, and GUID-scoped CC snippets), see [top-auras-by-class.md](top-auras-by-class.md).

## 1. Melee swing timer

**Prefer the built-in trigger**: Trigger → Status → "Swing Timer" (present on Era; handles extra attacks skipping resets, parry-haste — WA shortens the swing 40% clamped to a 20%-remaining floor — cast pauses, and the era on-next-hit reset spells: Slam, Heroic Strike, Cleave, Raptor Strike, Maul, shoots/wands). WA's own UI warns results are approximate on non-retail.

Custom access to the same machinery:

```lua
-- Actions > On Init:
WeakAuras.InitSwingTimer()
```
```lua
-- Custom > Trigger State Updater, Event(s): SWING_TIMER_UPDATE   [WA-internal event]
function(allstates, event)
    local duration, expirationTime, name, icon = WeakAuras.GetSwingTimerInfo("main") -- "main"|"off"|"ranged"
    if duration and duration > 0 and expirationTime ~= math.huge then
        allstates[""] = {
            show = true, changed = true, progressType = "timed",
            duration = duration, expirationTime = expirationTime,
            name = name, icon = icon,
        }
    else
        allstates[""] = nil
    end
    return true
end
```

Notes: `GetSwingTimerInfo` returns `0, math.huge` when no swing is tracked — check that, not nil. `InitSwingTimer` is inferred-public (the built-in trigger's own init calls it) — could change. Source: GenericTrigger.lua L2035/L2237.

## 2. Energy tick tracker

Decoded verbatim from [wago.io/1oyFuioYU](https://wago.io/1oyFuioYU) (same code in Era-tagged [ZlZNQylx3](https://wago.io/ZlZNQylx3)). TSU; Event(s): `UNIT_POWER_FREQUENT:player ENERGYTICK`

```lua
function(a, e, t)
    local currEnergy = UnitPower("player", 3)   -- 3 = Enum.PowerType.Energy
    local dur = 2
    if (e == "UNIT_POWER_FREQUENT" and currEnergy > (aura_env.lastEnergy or 0))
    or (e == "ENERGYTICK" and t and currEnergy == UnitPowerMax("player", 3))
    then
        if not a[""] then
            a[""] = { show = true, changed = true, duration = dur,
                expirationTime = GetTime() + dur, progressType = "timed" }
        else
            local s = a[""]
            s.changed = true; s.duration = dur
            s.expirationTime = GetTime() + dur; s.show = true
            C_Timer.After(2, function() WeakAuras.ScanEvents("ENERGYTICK", true) end)
        end
    end
    aura_env.lastEnergy = currEnergy
    return true
end
```

The self-scheduled `ENERGYTICK` re-entry IS the drift handling: at full energy no power event fires, so the aura re-arms itself. A refinement ([7DlodicT4](https://wago.io/7DlodicT4)) filters out non-tick gains by excluding known ability amounts (5/8/25/35/60/100 — a heuristic that breaks when a gain equals a tick amount). Mana-tick/five-second-rule auras use the same skeleton plus a 5s window started on mana spend ([tKwhPGqCa](https://wago.io/tKwhPGqCa), [MdQTg1sSp](https://wago.io/MdQTg1sSp)).

## 3. CLEU proc tracker with autohide

Structure from the wiki-endorsed [EkwFygCD-](https://wago.io/EkwFygCD-), with one mandatory modernization: the source aura used a bare-CLEU event box, which no longer registers — the filter below is required. TSU; Event(s): `CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH`

```lua
function(allstates, event, ...)
    local _, subevent, _, sourceGUID = ...
    local destGUID, destName = select(8, ...)
    local spellId, spellName = select(12, ...)

    if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH")
       and destGUID == aura_env.player
       and spellId == 12345
    then
        local duration = 10
        local _, _, icon = GetSpellInfo(spellId)  -- icon at select(3): Era signature
        allstates[""] = {
            show = true, changed = true, progressType = "timed",
            duration = duration, expirationTime = GetTime() + duration,
            autoHide = true, name = spellName, icon = icon, spellId = spellId,
        }
        return true
    end
end
```
```lua
-- Actions > On Init:
aura_env.player = UnitGUID("player")
```

`autoHide = true` drops the state when the timer expires — no untrigger/removal event needed. Era spellIds are rank-specific; match `spellName` to be rank-agnostic.

## 4. Multi-target debuff clones (composed — reviewed, not field-tested)

Composed from documented primitives (TSU helper methods + CLEU offsets + `CLEU:UNIT_DIED` filtering). Note: the decoded popular "debuff tracker" auras use built-in aura triggers with zero custom code — check built-ins first. TSU; Event(s): `CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED:UNIT_DIED`

```lua
function(allstates, event, ...)
    local _, subevent, _, sourceGUID = ...
    local destGUID, destName = select(8, ...)
    local spellId, spellName = select(12, ...)

    if subevent == "UNIT_DIED" then      -- UNIT_DIED has no source; branch first
        allstates:Remove(destGUID)
        return
    end
    if sourceGUID ~= aura_env.player or spellId ~= aura_env.spellId then
        return
    end
    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
        local _, _, icon = GetSpellInfo(spellId)
        allstates:Update(destGUID, {     -- destGUID key = one clone per enemy
            progressType = "timed",      -- modern style: no show needed via helpers
            duration = aura_env.duration,
            expirationTime = GetTime() + aura_env.duration,
            autoHide = true, name = destName, icon = icon,
        })
    elseif subevent == "SPELL_AURA_REMOVED" then
        allstates:Remove(destGUID)
    end
end
```
```lua
-- Actions > On Init:
aura_env.player   = UnitGUID("player")
aura_env.spellId  = 11597   -- Sunder Armor (rank 5)
aura_env.duration = 30
```

Put the aura in a Dynamic Group or clones stack. Out-of-combat-log-range targets linger until autoHide expires them.

## 5. Weapon temp-enchant reminder

Stack/Icon blocks decoded verbatim from Era/SoD-tagged [4LKhciPfE](https://wago.io/4LKhciPfE); enchantID→icon table in [6lkNDc0xP](https://wago.io/6lkNDc0xP). Custom → Status; Event(s): `UNIT_INVENTORY_CHANGED:player PLAYER_EQUIPMENT_CHANGED PLAYER_ENTERING_WORLD`

```lua
-- Trigger: true when main hand has NO temp enchant
function() return not (GetWeaponEnchantInfo()) end
```
```lua
-- Duration Info (timed): GetWeaponEnchantInfo returns MILLISECONDS
function()
    local has, expirationMs = GetWeaponEnchantInfo()
    if has and expirationMs then
        return expirationMs / 1000, GetTime() + expirationMs / 1000
    end
    return 0, math.huge
end
```
```lua
-- Stack Info: charges (poisons / sharpening stones)
function() return select(3, GetWeaponEnchantInfo()) end
-- Icon Info: map enchantID → icon, fall back to the weapon's own icon
function()
    local enchId = select(4, GetWeaponEnchantInfo())
    local icon = aura_env.enchantIcons[enchId]
    return icon and icon or GetItemIcon(GetInventoryItemID("player", 16))
end
```

Off-hand = offsets 5-8 of the same call (the Era aura proves enchantIDs work on Era). Ranged returns (9-12) are Cata-documented — don't rely on them. `WEAPON_ENCHANT_CHANGED` doesn't exist on Classic. If your aura flickers on re-imbue: the API is stale right after the event (WA re-reads after 0.1s). Alternative: `WeakAuras.GetMHTenchInfo()`. Slot 16=MH, 17=OH.

## 6. Totem tracker

**Prefer the built-in Totem trigger** (present on Era). Custom route (loop + liveness test from WA's own prototype): TSU; Event(s): `PLAYER_TOTEM_UPDATE PLAYER_ENTERING_WORLD`

```lua
function(allstates, event, slotId)
    for i = 1, 4 do    -- 1=Fire 2=Earth 3=Water 4=Air
        local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(i)
        if haveTotem and startTime and startTime ~= 0 then   -- haveTotem alone is NOT enough
            allstates:Update(i, {
                show = true, progressType = "timed",
                duration = duration, expirationTime = startTime + duration,
                name = totemName, icon = icon, index = i,
            })
        else
            allstates:Remove(i)
        end
    end
end
```

Don't filter by the 7th return (spellID) — retail-11.1.5-only. `PLAYER_TOTEM_UPDATE` passes the changed slotId as first arg. (GetTotemInfo Era availability inferred from WA keeping the prototype — not verified in-game.)

## 7. Range check

Verbatim from the [Useful-Snippets wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Useful-Snippets#range-checking). Custom → Status; the `aura_env.last` guard IS the throttle:

```lua
function()
  if not aura_env.last or aura_env.last < GetTime() - 0.3 then
    aura_env.last = GetTime()
    local count = 0
    for i = 1, 40 do
      local unit = "nameplate"..i
      if UnitCanAttack("player", unit) and WeakAuras.CheckRange(unit, 8, "<=") then
        count = count + 1
      end
    end
    aura_env.count = count
  end
  return aura_env.count and aura_env.count >= 3
end
```

Contracts: `WeakAuras.IsSpellInRange(spellIdOrName, unit)` → nil/0/1 (accepts spell ID, unlike Blizzard's name-only `IsSpellInRange`); `WeakAuras.CheckRange(unit, range, "<="|">=")` → boolean; `WeakAuras.GetRange(unit, checkVisible)` → min, max. For simple cases the built-in Status → Range Check trigger is less code. Era idiom for melee range: `IsSpellInRange("Wing Clip", unit) == 1`.

## 8. Nameplate-anchored debuffs (from the #1 classic aura)

Decoded verbatim from [Debuffs on nameplates](https://wago.io/4je3fCkT3) (excerpt). TSU; Events: `CLEU:SPELL_INTERRUPT:UNIT_DIED NAME_PLATE_UNIT_REMOVED NAME_PLATE_UNIT_ADDED`

```lua
function(states, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, message, _, srcGUID, srcName, srcFlags, srcRFlags,
              destGUID, destName, destFlags, destRFlags, spellid = ...
        if message == "SPELL_INTERRUPT" then
            if spellid and aura_env.interrupts[spellid] then
                local duration = aura_env.interrupts[spellid]
                table.insert(aura_env.stored, {
                    srcGUID = srcGUID, destGUID = destGUID,
                    duration = duration, expirationTime = GetTime() + duration,
                    icon = select(3, GetSpellInfo(spellid))
                })
                for i = 1, 40 do
                    local unit = "nameplate"..i
                    if UnitGUID(unit) == destGUID then
                        -- states[key] = { show=true, changed=true, ..., unit=unit }
                        -- state.unit anchors the clone to that nameplate
                    end
                end
            end
        end
    end
end
```

The technique trio: filtered CLEU + a persistent `aura_env.stored` ledger + resolving destGUID→`nameplateN` by scanning `UnitGUID("nameplate"..i)`, with `NAME_PLATE_UNIT_ADDED/REMOVED` re-syncing as plates recycle. Setting `state.unit` enables nameplate anchoring/Group-by-Frame.

## 9. Hunter Auto Shot timer

Decoded from [iBJTPFuk4](https://wago.io/iBJTPFuk4). Event trigger; Events: `START_AUTOREPEAT_SPELL, STOP_AUTOREPEAT_SPELL, UNIT_SPELLCAST_SUCCEEDED, UNIT_SPELLCAST_DELAYED, UNIT_SPELLCAST_FAILED, ...`

```lua
function(event, ...)
    local args = {...}
    if event == "START_AUTOREPEAT_SPELL" then
        aura_env.OnStartAutorepeatSpell()
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        aura_env.OnStopAutorepeatSpell()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        aura_env.OnUnitSpellCastSucceeded(args[1], args[3])   -- spellID 75 = Auto Shot
    end
end
```

Classic-only `START/STOP_AUTOREPEAT_SPELL` bracket the Auto Shot cycle; handler functions live on `aura_env` (defined in On Init). Same technique renders as a synthetic cast bar in [Hunter Castbar](https://wago.io/92y4H96_t).

## 10. Throttled CLEU absorb accounting

From [nanShield Classic Era](https://wago.io/6HHBMDHTD) (126 stars): Era has no absorb API, so remaining Power Word: Shield is reconstructed by summing `CLEU:SPELL_ABSORBED` against the applied shield's capacity. The display TSU rate-limits itself:

```lua
function(...)
    local theTime = GetTime()
    if not aura_env.last or aura_env.last < theTime - 0.05 then
        aura_env.last = theTime
        return aura_env:on_tsu(...)
    end
end
```

Max one state rebuild per 50ms — the standard defense against CLEU spam in raids.

## 11. Clickable aura (secure macro button)

Init-action pattern decoded verbatim from [Easy Poisons – Classic ERA](https://wago.io/ohQoJB47-):

```lua
-- Actions > On Init
local buttonName = aura_env.id
if not _G[buttonName] then
    aura_env.button = CreateFrame("Button", buttonName, aura_env.region, "SecureActionButtonTemplate")
else
    aura_env.button = _G[buttonName]
end
aura_env.button:SetAttribute("type", "macro")
aura_env.button:SetFrameStrata("HIGH")
aura_env.button:SetAllPoints()
-- pre-click: assemble and set macrotext like "/use Instant Poison\n/use 16"
```

Constraints: attribute changes are blocked in combat; item `/use` works via secure attributes where direct spell attributes fail on Era (see the tradeskill-casting note in the workspace memory); since late 2024 addon-set macrotext is capped at ~225 chars (reported by Jeyp's Boss Frames' author — limit value unverified).

## 12. Cross-aura config bus

Verbatim pattern from [Zippy's Raid Reset Timers](https://wago.io/mPnf_gBer):

```lua
-- Aura A (options owner), On Init:
_G.ZRT_SHARED = _G.ZRT_SHARED or { config = {} }
local bus = _G.ZRT_SHARED.config
for k, v in pairs(aura_env.config or {}) do bus[k] = v end
WeakAuras.ScanEvents("ZRT_CONFIG_UPDATED")

-- Aura B (consumer), On Init:
aura_env._local_config = aura_env.config or {}
aura_env.config = setmetatable({}, {
    __index = function(_, k)
        local bus = _G.ZRT_SHARED and _G.ZRT_SHARED.config
        return (bus and bus[k] ~= nil) and bus[k] or aura_env._local_config[k]
    end,
})
-- Aura B's trigger lists ZRT_CONFIG_UPDATED in its Event(s)
```

One aura owns the user-facing options; consumers read through a metatable proxy; ScanEvents broadcasts changes (remember: delivery is next-frame).

## 13. Data-as-aura (mob danger DB)

From [Classic Mob Abilities](https://wago.io/HJ5QPxCON) (Hardcore safety net): a Status trigger on `PLAYER_TARGET_CHANGED` does an O(1) lookup in a table shipped in On Init:

```lua
-- Status trigger, Events: PLAYER_TARGET_CHANGED
function()
    return not UnitIsDead("target") and aura_env.mobList[UnitName("target")] and true or false
end
-- On Init:
aura_env.mobList = {
    ["Crushridge Warmonger"] = true,  -- 40 elite - Alterac Mountains
    ["Dustbelcher Lord"] = true,      -- 44 - Badlands
    -- ...
}
```

Era mobs are uniquely named, so UnitName keys work (retail would parse npcID from the GUID). One child aura per warning category keeps the DB updateable without touching trigger code.
