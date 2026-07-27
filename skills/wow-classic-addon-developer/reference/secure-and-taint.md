# Secure frames, combat lockdown & taint

The hardest part of Classic Era (1.15.x) addon dev. Mined from `Bartender4`, `PallyPower`, `HealBot`, `Decursive`, `TrinketMenu`, `EnchantClickables`.

**Governing rule:** only the secure (Blizzard-signed) execution path may call protected functions — cast a spell, use an item, target a unit, or show/hide/move a protected frame in combat. Addon Lua is *insecure*; it can only pre-configure secure templates **out of combat** and let the player's hardware click do the protected work.

## 1. Secure action buttons

A button inheriting `SecureActionButtonTemplate` reads *attributes* on click and performs the matching protected action inside Blizzard's secure handler. You set attributes from insecure code (allowed out of combat); the click is secure because it's a real key/mouse press.

```lua
-- cast a spell — the "spell" attribute takes a spellID (number) OR a name string
local b = CreateFrame("Button", "MyCastBtn", parent, "SecureActionButtonTemplate")
b:SetAttribute("type", "spell")
b:SetAttribute("spell", spellID)                  -- numeric ID works; "Name(Rank N)" pins a Classic downrank

-- use an item by name, or by equipment slot
b:SetAttribute("type", "item")
b:SetAttribute("item", itemName)                  -- or:
b:SetAttribute("slot", 13)                        -- 13/14 = trinket slots
```

`type` values: `"spell"`, `"item"`, `"macro"`, `"target"`, role types like `"maintank"`. Other attributes: `unit`/`unit1` (action target), `macrotext1` (run macro lines through the secure path), `target-slot`.

**Modifier- and button-prefixed attributes** are the core of "one button, several actions". Grammar: `[modifier-]<name><buttonindex>` — `type1`/`type2` (left/right), `spell1`/`spell2`, `unit1`/`unit2`, `ctrl-type1`, `shift-type2`, wildcard `*type1` (all modifiers):

```lua
b:SetAttribute("type1", "spell"); b:SetAttribute("unit1", unit); b:SetAttribute("spell1", greaterBlessing)
b:SetAttribute("type2", "spell"); b:SetAttribute("spell2", normalBlessing)         -- right-click
b:SetAttribute("ctrl-type1", "maintank")                                            -- ctrl+left = role
```

`RegisterForClicks` controls which physical clicks reach the secure handler. Cast-on-down vs up matters for queueing: `b:RegisterForClicks("LeftButtonDown")` or the full set `"LeftButtonDown","RightButtonDown","AnyUp","AnyDown"`.

## 2. State drivers & `SecureHandler*` templates (combat-safe reactions)

`RegisterStateDriver(frame, "stateid", macroConditional)` tells the **secure** environment to watch a macro-conditional and write `state-<stateid>` on the frame whenever the result changes — *including in combat*, because evaluation and the attribute write happen entirely inside Blizzard's restricted environment. Your insecure code only supplies the snippet once.

```lua
local bar = CreateFrame("Frame", "MyBar", UIParent, "SecureHandlerStateTemplate")
bar:SetAttribute("_onstate-vis", [[
    if newstate == "show" then self:Show() elseif newstate == "hide" then self:Hide() end
]])
RegisterStateDriver(bar, "vis", "[combat]hide;show")   -- first match wins; ';'-separated priority list
```

Classic-relevant conditions: `[combat]`, `[stance:n]`/`[bonusbar:n]`, `[stealth]`, `[mod:ctrl/alt/shift]`, `[group:raid]`, `[@unit,exists/help/harm]`, `[bar:n]`. **Never true in Vanilla/Era** (the underlying features postdate 1.x — vehicles=WotLK, pet battles=MoP, possess/override bars=TBC–MoP — so they're harmless no-ops here, though they *do* work in later Classic flavors like WotLK/MoP Classic): `[petbattle]`, `[vehicleui]`, `[possessbar]`, `[overridebar]`.

The secure sandbox has its own restricted Lua (`ipairs`, `newtable()` to build tables — not `table.new` — frame methods like `:Show()`) and **cannot** call your insecure functions or read arbitrary globals — that boundary is exactly what keeps it untainted. Pass frames in with `SecureHandlerSetFrameRef(frame, "child", other)` and run snippets with `SecureHandlerExecute(frame, "...")`. Page swapping uses `control:ChildUpdate("state", newstate)` from an `_onstate-page` handler.

## 3. Combat lockdown: detect, refuse, defer, replay

`InCombatLockdown()` returns true from `PLAYER_REGEN_DISABLED` (combat start) until `PLAYER_REGEN_ENABLED` (combat end). While true, any insecure attempt to set a security-sensitive attribute, re-parent/move/show/hide a protected frame, or call a protected function is **blocked** and raises `ADDON_ACTION_BLOCKED`. Bail at the top of any function that touches protected state:

```lua
function MyAddon:UpdateLayout()
    if InCombatLockdown() then return end
    ...
end
```

Three escalating "I need to do this but I'm in combat" strategies:

**(a) Flag + replay on regen** (cheapest, coalesces to one deferred call):

```lua
function f:OnEvent(event)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if InCombatLockdown() then self.dirty = true else self:UpdateStates() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.dirty then self.dirty = nil; self:UpdateStates() end
    end
end
```

**(b) Keyed deferred-call queue** (Decursive's canonical careful pattern) — callers that hit lockdown enqueue under a unique ID (so repeated requests collapse), and `PLAYER_REGEN_ENABLED` drains the queue. Subtlety Decursive documents: `PLAYER_REGEN_DISABLED` can fire slightly *before* lockdown engages — use `InCombatLockdown()` for the actual decision, the events only to schedule the replay.

**(c) Defer at the event source** — on `PLAYER_REGEN_DISABLED` stop touching attributes; on `PLAYER_REGEN_ENABLED` redo the protected setup.

## 4. The taint model

**What taint is.** Every value and execution context carries a secure/insecure bit. Blizzard's shipped code is secure; your addon's code and every value it produces are *tainted*. WoW Lua starts secure; the moment execution reads addon code or data, that execution becomes tainted ("addon code is sticky; anything it touches becomes sticky"). Taint persists until `/reload` or logout.

**How it spreads:**
1. *Execution taint* — if a tainted function is anywhere on the call stack when a protected function runs, the action is blocked.
2. *Value taint* — a tainted value written into a Blizzard-owned table/variable taints that variable; later secure code reading it becomes tainted (sticky — the classic cause of `ADDON_ACTION_BLOCKED` naming your addon for a bug that surfaces frames away).
3. *Hooks* — a plain hook running your code inside Blizzard's path spreads taint. Use `hooksecurefunc` (post-hook runs *after* the secure call and receives a copy of the call's **arguments** — not its return values; observing those args is taint-safe). Reading is fine; writing back into protected state is not.

**Primitives:** `issecure()` (is the current path fully secure?), `securecall(fn, ...)` (run `fn` so its taint doesn't leak back to the caller), `forceinsecure()` (deliberately drop to insecure).

**`ADDON_ACTION_BLOCKED`** = a protected action attempted from a tainted path (recoverable; action dropped). **`ADDON_ACTION_FORBIDDEN`** = a function never callable from addons (always fatal to that path). Don't suppress them — the discipline is to never trigger them via the lockdown guards and secure templates above.

### Finding a taint source (debugging a blocked action)

`ADDON_ACTION_BLOCKED` usually names the *symptom*, not the write. To trace the real source:
- **`issecurevariable([table,] "name")`** → `isSecure, taintingAddon` — the fastest "who tainted this value?" check; the block message itself often already names the tainting addon + variable.
- **`/console taintLog 2`**, reproduce, then read `Logs/taint.log` in your WoW folder. Level 1 logs blocked actions plus the taint chain that led to them; level 2 also logs tainted reads/writes of globals (slower, more complete). Set `taintLog 0` when done.
- Usual culprit: writing a value into a Blizzard-owned table/global, or replacing a Blizzard function by plain assignment instead of `hooksecurefunc`.

## 5. Click-casting (HealBot / Clique style)

A click-cast unit button is a `SecureActionButtonTemplate` whose `unit` attribute names *which* unit and whose `type1`/`spell1` (+ modifier variants) name the action. The player mouses over and clicks; the secure handler casts on that button's unit. Targeting is **attribute-driven**, never `TargetUnit()` from Lua.

```lua
local icon = CreateFrame("Button", "Cell_"..i, parent, "SecureActionButtonTemplate")
icon:RegisterForClicks("LeftButtonDown")
icon:SetAttribute("unit", unit)            -- "raid7" / "party2" / "player"
icon:SetAttribute("type1", "spell"); icon:SetAttribute("spell1", healSpell)
-- or macro form for conditionals: type1="macro", macrotext1="/cast [@"..unit.."] "..healSpell
```

Update *insecure visuals* (textures, health text) every frame freely; you only need to be **out of combat** to change the *bound unit or spell* (an attribute). The in-combat-safe equivalent of re-targeting is the `[@mouseover]` macro conditional, evaluated secure-side at click time.

## 6. Why `/cast` and `RunMacroText` are restricted from insecure Lua

`RunMacroText`, `CastSpellByName`, `UseAction`, `TargetUnit`, etc. are protected: from a tainted path they are no-ops that raise `ADDON_ACTION_BLOCKED`. There is no API to "cast a spell from a timer/event" — that would let an addon auto-play the character. The only sanctioned route is **hardware-event → secure-template**: a real key/mouse press whose secure handler reads attributes and performs exactly one action. Hence the **one-button-one-action rule** — each physical click resolves to a single (modifier, button)→action mapping; you cannot loop, branch on game state in arbitrary Lua, or fire multiple casts per click. Everything "smart" (which spell, which unit) must be precomputed into attributes *before* the click, out of combat.

**Tradeskill exception** (from project memory): transmutes/recipes **cannot** be cast via `/cast` or `SecureActionButton type=spell` — both silently fail. Use `DoTradeSkill(index, count)` from a normal (insecure) OnClick handler; opening a tradeskill recipe is not a protected combat action. Requires the tradeskill window to have opened once that session.

## 7. End-to-end: configure out of combat, execute on hardware click

```lua
-- ONCE at setup: create secure button, register clicks
local btn = CreateFrame("Button", "MyBtn", parent,
    "SecureHandlerStateTemplate, SecureActionButtonTemplate")
btn:RegisterForClicks("LeftButtonDown","RightButtonDown")

-- EACH UPDATE, guarded by lockdown: precompute the action onto attributes
function MyAddon:UpdateLayout()
    if InCombatLockdown() then return end
    btn:SetAttribute("type1", "spell"); btn:SetAttribute("unit1", unit); btn:SetAttribute("spell1", spell)
end
-- At click, NO addon Lua runs for the cast: Blizzard's SecureActionButton_OnClick reads the attributes.
-- PreClick/PostClick scripts may run insecurely AROUND the click (e.g. to set macrotext out of
-- combat) but must finish before the secure action and must not themselves attempt a protected call.
-- NB: an insecure PreClick that calls SetAttribute is BLOCKED in combat — see SecureHandlerWrapScript below.
```

**Changing the action *at click time* in combat.** An insecure `PreClick` that calls `SetAttribute` is itself **blocked in combat**, so it can't pick the spell/unit per-click while locked down. The combat-safe mechanism is a secure snippet wrapped around the click: `SecureHandlerWrapScript(button, "OnClick", header, [[ pre-body ]], [[ post-body ]])`. The pre-body runs in the restricted environment *before* the secure action and may rewrite the button's attributes from secure state (`self:SetAttribute("spell", ...)`), so "smart" buttons re-target in combat without taint.

## 8. Secure group/raid headers (`SecureGroupHeaderTemplate`)

How party/raid unit frames (Grid, HealBot, oUF layouts) are built so that **clicking a member's frame to target or cast works in combat**. The header auto-spawns one secure unit button per group member, assigns each a `unit` attribute, and handles show/hide/sort/re-layout entirely inside the secure environment — so roster changes mid-combat don't break it. Configure it **out of combat** via attributes:

```lua
local header = CreateFrame("Frame", "MyRaidHeader", UIParent, "SecureGroupHeaderTemplate")
header:SetAttribute("template", "MyUnitButtonTemplate")    -- XML template inheriting SecureUnitButtonTemplate
header:SetAttribute("showRaid", true)                       -- + showParty / showPlayer / showSolo as needed
header:SetAttribute("point", "TOP"); header:SetAttribute("yOffset", -4)
header:SetAttribute("maxColumns", 8); header:SetAttribute("unitsPerColumn", 5)
header:SetAttribute("columnSpacing", 4); header:SetAttribute("columnAnchorPoint", "LEFT")
header:SetAttribute("sortMethod", "INDEX"); header:SetAttribute("groupBy", "GROUP")
-- size each button AS IT IS CREATED — a SECURE SNIPPET STRING (runs with self = the new button), NOT a Lua function:
header:SetAttribute("initialConfigFunction", [[ self:SetWidth(80); self:SetHeight(40) ]])
header:SetPoint("TOPLEFT", 20, -20); header:Show()
```

Layout attributes: `showRaid`/`showParty`/`showPlayer`/`showSolo` (≥1 true), `groupFilter` (`"1,2,3"` raid groups, class names, or roles), `point`, `xOffset`/`yOffset`, `maxColumns`/`unitsPerColumn`/`columnSpacing`/`columnAnchorPoint`, `sortMethod` (`"INDEX"`/`"NAME"`), `groupBy`/`groupingOrder`, `nameList`.

**Two environments, kept apart:** the header and its buttons are *secure* — unit binding, targeting, and combat-safe show/hide live there, and `initialConfigFunction` runs as restricted-environment code (a **string**, not a Lua function). Your button's **visuals** (health bar, name text, event-driven coloring) are ordinary *insecure* code: build them in the template's `OnLoad`, or decorate `header:GetChildren()` out of combat. Never move/resize a button or change its `unit` from insecure code in combat — that's blocked.

**For production, use a framework.** Hand-rolling headers is fragile; **oUF** (`oUF:SpawnHeader(...)`, see [ui-widgets.md](ui-widgets.md)) and Grid wrap all of this. Reach for the raw template only when you need full control.
