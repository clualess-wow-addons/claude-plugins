# Events, combat log & timing

Classic Era (1.15.x) event handling, combat-log parsing, throttling, and cast tracking. Mined from `KillTrack`, `ClassicCastbars`, `ThreatClassic2`, `Spy`, `Details`, `DBM-Core`, `NovaWorldBuffs`.

## 1. Frame + event dispatch patterns

Frames are the only objects that receive game events. Three idiomatic forms:

**Form A — dispatch table with a guard** (`KillTrack`). Handlers live in a table; bootstrap by iterating it so you never maintain a separate event list:

```lua
function KT:OnEvent(_, event, ...)
    if self.Events[event] then self.Events[event](self, ...) end
end
function KT.Events.COMBAT_LOG_EVENT_UNFILTERED(self) ... end
function KT.Events.ADDON_LOADED(self, name) ... end

KT.Frame = CreateFrame("Frame")
for k in pairs(KT.Events) do KT.Frame:RegisterEvent(k) end   -- register exactly what has a handler
KT.Frame:SetScript("OnEvent", function(_, e, ...) KT:OnEvent(_, e, ...) end)
```

**Form B — `self[event](self, ...)`** ("the frame IS the addon", `ClassicCastbars`). No dispatch table; each event name is a method. Only register events you define (an unhandled registered event errors):

```lua
local CC = CreateFrame("Frame", "ClassicCastbars")
CC:RegisterEvent("PLAYER_LOGIN")
CC:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)
function CC:PLAYER_LOGIN() ... end
function CC:UNIT_SPELLCAST_START(unitID) ... end
```

**Form B with nil-guard** (safest, `ThreatClassic2`): `return TC2[event] and TC2[event](TC2, event, ...)`.

**Event aliasing** — point several events at one handler: `TC2.UNIT_TARGET = TC2.PLAYER_TARGET_CHANGED`.

**`RegisterUnitEvent`** is a perf refinement: the frame only fires for the named units (up to four), skipping a per-call `if unit == ...` filter:

```lua
self:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", "focus")
```

## 2. Combat log: `COMBAT_LOG_EVENT_UNFILTERED` + `CombatLogGetCurrentEventInfo()`

The payload is **not** passed as event args (since 7.0, Classic included). Register the event, then call `CombatLogGetCurrentEventInfo()` inside the handler. The first 11 returns are the fixed prefix; everything after is subevent-specific.

```lua
local timestamp, subevent, hideCaster,
      srcGUID, srcName, srcFlags, srcRaidFlags,
      dstGUID, dstName, dstFlags, dstRaidFlags,
      arg12, arg13, arg14, arg15 = CombatLogGetCurrentEventInfo()
```

Grab only what you use (minimal): `local _, sub, _, sguid, _, _, _, dguid, dname = CombatLogGetCurrentEventInfo()`.

Subevent dispatch — prefer a **set/table lookup** over an if/elseif chain when you have many subevents:

```lua
local DAMAGE = { SWING_DAMAGE=true, SPELL_DAMAGE=true, RANGE_DAMAGE=true }
if DAMAGE[subevent] then ... end
if subevent == "UNIT_DIED" then ... end
```

**Subevent payload = prefix + suffix (the #1 CLEU bug).** The values after the 11-field header depend on the subevent's *prefix*: `SWING_*` has **no** spell args (payload starts at arg 12); `SPELL_*`/`SPELL_PERIODIC_*`/`RANGE_*` insert `spellId, spellName, spellSchool` at args **12/13/14** (payload starts at **15**); `ENVIRONMENTAL_*` puts `environmentalType` at 12. Read the payload off the right base or a parser "works for melee but breaks on spells":

```lua
-- SWING_DAMAGE:        amount = select(12, CombatLogGetCurrentEventInfo())
-- SPELL_DAMAGE:        spellId, _, _, amount = select(12, CombatLogGetCurrentEventInfo())
-- SPELL_AURA_APPLIED:  spellId, _, _, auraType = select(12, ...)   -- auraType "BUFF"/"DEBUFF"
```

**Flag testing** uses `bit.band` against `COMBATLOG_OBJECT_*` globals (Classic exposes the `bit` lib and these constants). Lead with `~= 0`, not `== CONSTANT`: many useful masks are **multi-bit** (e.g. `COMBATLOG_OBJECT_AFFILIATION_MASK`, the `0x3000` pet mask), and `== CONSTANT` silently fails for those — it only works for a single-bit flag.

```lua
if bit.band(srcFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then ... end   -- robust for any mask
if bit.band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER)      ~= 0 then ... end
```

**GUID classification:** cheap prefix `strsub(guid, 1, 6)` ("Player"/"Creatu"/"Pet"), or `select(6, strsplit("-", guid))` for the NPC ID.

**Perf — CLEU is a hot path** (hundreds/sec in raids). Upvalue every API/global used inside it at file scope:

```lua
local CombatLogGetCurrentEventInfo, UnitGUID, bit_band = CombatLogGetCurrentEventInfo, UnitGUID, bit.band
```

Classic note: patch 1.15.0 restored real `spellId` values in the Era combat log (previously `0`).

## 3. Throttling

**`OnUpdate` fires every rendered frame** (60–200×/sec). Never do real work every frame — gate with a time accumulator:

```lua
local acc = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.2 then return end   -- run ~5×/sec
    acc = 0
    DoWork()
end)
```

The legitimate every-frame case is smooth animation (advancing a bar by `elapsed` with no API calls in the loop). Stop the handler entirely when idle: `frame:SetScript("OnUpdate", nil)`.

**`C_Timer`** (all available in Classic Era):
- `C_Timer.After(delay, fn)` — one-shot deferred call.
- `C_Timer.NewTimer(delay, fn)` — cancelable one-shot; keep handle, `:Cancel()`.
- `C_Timer.NewTicker(interval, fn[, iterations])` — repeating.

`C_Timer.After(0, fn)` defers work to the next frame — the standard trick to spread expensive startup off the login stall, or to wait one frame for state to settle.

**Debounce a bursty event** — coalesce many rapid fires into one deferred action (e.g. recompute roster once on `GROUP_ROSTER_UPDATE` via a flag + `C_Timer.After`). If you're on Ace3, **AceBucket** does exactly this declaratively: `self:RegisterBucketEvent("BAG_UPDATE", 0.5, "Rescan")` fires `Rescan` at most once per 0.5s no matter how many `BAG_UPDATE`s land (Questie uses this for `CHAT_MSG_SKILL`). DBM uses its own scheduler rather than a `C_Timer` per call for its many boss-timer schedules.

## 4. Classic cast-tracking reality

`UNIT_SPELLCAST_*` events that fire in Classic Era: `START`, `STOP`, `DELAYED`, `FAILED`, `INTERRUPTED`, `SUCCEEDED`, `CHANNEL_START`, `CHANNEL_UPDATE`, `CHANNEL_STOP`, `INTERRUPTIBLE`, `NOT_INTERRUPTIBLE`. The `UNIT_SPELLCAST_EMPOWER_*` events never fire in Era (empowered casts are a later-expansion feature) — don't rely on them.

Guard events whose existence is uncertain across flavors before registering:

```lua
for _, e in ipairs(castEvents) do
    if C_EventUtils.IsEventValid(e) then self:RegisterEvent(e) end
end
```

**The core limitation:** `UnitChannelInfo()` returns nothing for **non-player** units in Era (an open engine bug), so *channeled* enemy casts can't be read directly. `UnitCastingInfo(unit)` **does** work for any unit — you can read a normal cast already in progress on a target/nameplate; it's channels and precise pushback timing that need reconstruction. Workarounds:
- Reconstruct enemy/channel bars manually from a stored cast-time DB + `GetTime()`.
- On `NAME_PLATE_UNIT_ADDED`, probe `UnitCastingInfo(token)`/`UnitChannelInfo(token)` to seed a bar for a cast already in progress (you missed START).
- Model **pushback** (cast slowed when hit) yourself from CLEU damage subevents — no event reports it for enemies.
- The library **LibClassicCasterino** reconstructs enemy cast state entirely from CLEU (`SPELL_CAST_START`/`SUCCESS`/`INTERRUPTED`) + a cast-time DB; it's the reference for combat-log-only cast tracking.

Guard against stale STOP/FAILED for a cast you already replaced via cast-ID matching: `if castbar.castID ~= castID then return end`.

## 5. Chat / message parsing

Register `CHAT_MSG_*`; message text is `arg1`, sender `arg2`. Lua has **patterns, not regex**:

```lua
local text = string.match(msg, "^!wb (%S+)")        -- capture
msg = string.gsub(msg, "(%d+)g", "%1 gold")          -- substitute with capture %1
if string.find(msg, ERR_CHAT_THROTTLED) then ... end -- substring test vs localized global
```

**`ChatFrame_AddMessageEventFilter`** suppresses or rewrites chat lines (vs just observing). Return `true` to swallow, or `false, newMsg, author, ...` to replace:

```lua
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if string.find(msg, "messages that can be sent is limited") then return true end  -- hide throttle spam
end)
```

Match against localized global string constants (`ERR_CHAT_THROTTLED`) rather than hardcoded English for locale resilience.

## 6. Slash commands

Raw form (`SLASH_<NAME>n` + `SlashCmdList`) — see minimal-addons.md. Via AceConsole — see ace3.md.

## 7. Register-then-unregister for performance

Drop an event once its job is done, and toggle heavy events with state:

```lua
function CC:PLAYER_LOGIN()
    ...                          -- one-time init
    self:UnregisterEvent("PLAYER_LOGIN")
    self.PLAYER_LOGIN = nil      -- also drop the method so dispatch can't hit it
end
```

`Spy` unregisters the firehose `COMBAT_LOG_EVENT_UNFILTERED` when leaving a PvP zone and re-registers on entry. DBM has two distinct mechanisms here, easy to confuse: **`RegisterEventsInCombat`** populates an `inCombatOnlyEvents` set that is auto-registered on boss pull and auto-dropped at combat end (the real "only while fighting" system), while **`RegisterShortTermEvents`/`UnregisterShortTermEvents`** is a separate *manual* toggle (in live Era code it registers world mouseover/nameplate scans out in the open world and drops them on instance entry). DBM fans a single `mainFrame` out to all mods via a `registeredEvents[event] = {mods}` index; dropping a consumer clears that dispatch entry, but the `mainFrame` stays subscribed — only **UNIT_ events** are *truly* unregistered from the frame, via a real per-unit refcount that hits zero.

## Era availability guards

Gate flavor-specific code on `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC`. Guard uncertain events with `C_EventUtils.IsEventValid`. **Not available in Era:** `UNIT_SPELLCAST_EMPOWER_*`, reliable non-player `UnitChannelInfo`, the newer castbar `SetLook` API. **Era-available** and used throughout: `CombatLogGetCurrentEventInfo`, `C_Timer.*`, `bit.band` + `COMBATLOG_OBJECT_*`, `C_Spell.GetSpellInfo`, `RegisterUnitEvent`, `ChatFrame_AddMessageEventFilter`.
