# Minimal addon idioms (no framework)

Idiomatic zero-dependency Classic Era (1.15.x) addon patterns, mined from real addons in this workspace (`unitscan`, `TransmuteTimer`, `TradeSync`, `KillTrack`, `Coordinates`, `FasterLoot`, `HighLevelAlert`, `Postal`, `TomTom`).

## 1. Bootstrap & the `local ADDON, ns = ...` namespace

Every Lua file in an addon is called with two varargs: the addon's folder name (string) and a private table shared across *that addon's files only*. This is the zero-dependency replacement for a namespace.

```lua
local ADDON_NAME, ns = ...        -- ns is the SAME table object in every file of this addon
```

Variants seen in the wild:
- Name only — `TransmuteTimer.lua`: `local ADDON_NAME = ...` (single-file addon).
- Private table only — `Coordinates.lua`: `local addon = select(2, ...)`, then `function addon.foo() end`.
- Both — main file `local NAME = ...`; other files `local KT = select(2, ...)` to grab the shared object.
- Discard name — `HighLevelAlert/core.lua`: `local _, HLA = ...`.

There is no framework `OnInitialize`. You create one `Frame`, register events, and route them:

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then   -- note: gate on YOUR addon name
        MyAddonDB = MyAddonDB or {}                            -- SavedVariables now exist
        for k, v in pairs(DEFAULTS) do
            if MyAddonDB[k] == nil then MyAddonDB[k] = v end   -- merge defaults
        end
        BuildFrames()
    elseif event == "PLAYER_LOGIN" then                       -- all addons loaded, world data ready
        Refresh()
    end
end)
```

**Why SavedVariables are nil before `ADDON_LOADED`:** the client only deserializes your saved-variables file into the global *immediately before* firing `ADDON_LOADED` for that specific addon. File-scope code (run at load) sees `nil`. Always gate DB access on `event == "ADDON_LOADED" and arg1 == ADDON_NAME`.

**Which lifecycle event:** `ADDON_LOADED` (yours) → init DB + defaults; `PLAYER_LOGIN` → one-time setup with game state ready (fires **once**); **`PLAYER_ENTERING_WORLD`** → *every* loading screen (login, `/reload`, each zone/instance change) — use it for per-world state you must re-establish, and it's the reliable place to read your **starting** zone (which `ZONE_CHANGED_NEW_AREA` misses on login). Don't put one-time init in PEW — it repeats. To defer heavy work off the login stall, `C_Timer.After(0, fn)` runs it next frame (see [events-and-combat-log.md](events-and-combat-log.md) for `C_Timer`).

Terse dispatch variant (`Coordinates.lua`) — route each event to a same-named method, then unregister once done:

```lua
f:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
function f:ADDON_LOADED() ...; self:UnregisterEvent("ADDON_LOADED") end
```

## 2. SavedVariables idioms

`.toc` declares the globals; the names must match exactly what you read/write in Lua:
- `## SavedVariables: MyAddonDB` — one file shared by **all characters on the account**.
- `## SavedVariablesPerCharacter: MyAddonCharDB` — separate file **per character**.
- Multiple comma-separated globals allowed: `## SavedVariables: unitscan_targets, USHCMapSettings`.

**Defaults-merge** — shallow-merge only missing keys so user data survives updates. Use `== nil`, not `not`, so `false` defaults work:

```lua
MyAddonDB = MyAddonDB or {}
for k, v in pairs(DEFAULTS) do
    if MyAddonDB[k] == nil then MyAddonDB[k] = v end
end
```

**Footgun — shallow merge shares sub-table references.** If a `DEFAULTS` value is itself a table (`pos = { x = 0, y = 0 }`), `db[k] = v` stores the *same* table object, so a later `db.pos.x = 10` mutates `DEFAULTS.pos` too — poisoning whatever else gets default-assigned from it later that session. For nested defaults, deep-copy them on assign, or keep `DEFAULTS` values scalar and build sub-tables in code.

**Type-validated / self-repairing init** (defends against partial writes or old schemas) — `KillTrack` rebuilds any field of the wrong type:

```lua
if type(_G.KILLTRACK) ~= "table" then _G.KILLTRACK = {} end
local g = _G.KILLTRACK
if type(g.ACHIEV_THRESHOLD) ~= "number" then g.ACHIEV_THRESHOLD = 1000 end
if type(g.MOBS)            ~= "table"  then g.MOBS = {} end
```

**Versioned migration** — stamp a schema version and branch:

```lua
DB.version = DB.version or 0
if DB.version < 1 then ... DB.version = 1 end   -- migrate v0->v1
```

`TradeSync` goes furthest: realm-keyed substructure (`TradeSyncDB.servers[realm]`), full-name char keys (`name.."-"..realm`), every leaf type-checked.

## 3. Slash commands

Globals named `SLASH_<TOKEN><n>` register triggers; `SlashCmdList["<TOKEN>"]` is the handler. The TOKEN ties them together.

```lua
SLASH_TRANSMUTETIMER1 = "/tmt"
SLASH_TRANSMUTETIMER2 = "/transmutetimer"          -- more aliases: increment the suffix
SlashCmdList["TRANSMUTETIMER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")  -- trim + lowercase
    if msg == "reset" then ... return end
    -- bare command = toggle
end
```

**Sub-command dispatch table** (scales better than if/elseif) — `KillTrack` registers alias→handler and builds the slash globals in a loop:

```lua
local Commands = {}
local function Register(aliases, fn)
    for _, a in ipairs(aliases) do Commands[a:lower()] = fn end
end
Register({"tooltip", "tt"}, function(args) ... end)

for i, v in ipairs({"killtrack", "kt"}) do _G["SLASH_KILLTRACK"..i] = "/"..v end
SlashCmdList["KILLTRACK"] = function(msg)
    local args = {}
    for w in msg:gmatch("%S+") do args[#args+1] = w end
    local fn = Commands[(args[1] or ""):lower()]
    if fn then fn({select(2, unpack(args))}) end
end
```

## 4. Hooking Blizzard functions safely

**`hooksecurefunc(funcName, postHook)`** — the safe primitive: appends your function to run *after* the original, never replacing it, never tainting. Your hook gets the same args; its return is ignored.

```lua
hooksecurefunc("ContainerFrame_Update", function(frame) ... end)   -- global
hooksecurefunc(SomeTable, "Method", function(self, ...) ... end)   -- table method
```

**`frame:HookScript("OnX", fn)`** — chains onto an existing widget script instead of clobbering it via `SetScript`.

**Replacing vs hooking:** `SetScript` replaces; `HookScript` chains. For Blizzard/secure frames, replacing a handler can taint and break protected actions in combat — prefer `HookScript`/`hooksecurefunc`. For your *own* frames, `SetScript` is correct. **Never** assign over a Blizzard global (`SomeBlizzFunc = function() end`) — it taints everything downstream.

## 5. Chat output, color codes, print prefix

`print(...)` routes to the default chat frame; or call `DEFAULT_CHAT_FRAME:AddMessage(str)` directly.

Color codes: `|cffRRGGBB<text>|r` — `|c` + `ff` (alpha) + 6 hex, closed by `|r`. Inside a string literal you can escape `|` as `\124`. Blizzard provides constants like `LIGHTYELLOW_FONT_COLOR_CODE`, `RED_FONT_COLOR_CODE`.

Wrap output once so every message is branded:

```lua
local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MyAddon|r: " .. text)
end
```

## 6. Frames & widgets for simple UI

`CreateFrame(frameType, name, parent, template)`. Child regions: `:CreateTexture(name, layer)`, `:CreateFontString(name, layer, inheritsFont)`.

**Backdrops — the Classic gotcha.** Since the 8.2-era API (Classic Era included) `Frame` has **no** `SetBackdrop` unless created with the `"BackdropTemplate"` template. Guard for both:

```lua
local tmpl = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame = CreateFrame("Button", "MyAddonFrame", UIParent, tmpl)
if frame.SetBackdrop then
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
else
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 3, -3); bg:SetPoint("BOTTOMRIGHT", -3, 3)
    bg:SetColorTexture(0, 0, 0, 0.7)
end
```

- Texture layers, low→high: `BACKGROUND < BORDER < ARTWORK < OVERLAY < HIGHLIGHT`.
- `tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)` crops the built-in icon border.
- `tex:SetColorTexture(r,g,b,a)` = solid fill. (Old `SetTexture(r,g,b)` for color is removed — use `SetColorTexture`.)
- Fonts: inherit a font object via the 3rd `CreateFontString` arg (`"GameFontNormalLarge"`), or `:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")`. `FRIZQT__.TTF` lacks CJK glyphs — use `Fonts\\2002.TTF` for koKR/zhCN/zhTW.
- Anchoring: `:SetPoint(point, relativeTo, relativePoint, x, y)`; `:ClearAllPoints()` before re-anchoring; `:SetAllPoints(true)` to fill parent.
- **Frame strata / level** (distinct from the texture layers above) set draw order across the *whole* UI: `frame:SetFrameStrata("MEDIUM")` + `:SetFrameLevel(n)`. Strata low→high: `BACKGROUND, LOW, MEDIUM`(default)`, HIGH, DIALOG, FULLSCREEN, FULLSCREEN_DIALOG, TOOLTIP`. Wrong strata is why a frame hides behind — or floats over — the world map. Parent to `UIParent` (the root frame) so it hides with the UI and inherits scale.

**Movable frame**, persisting position:

```lua
frame:SetMovable(true); frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y   -- save these
end)
```

## 7. Localization mini-pattern

A base table plus a metatable that returns the key itself when a translation is missing — untranslated strings degrade to readable English, never `nil`:

```lua
local L = setmetatable({}, { __index = function(t, k) return k end })
L["Hello"] = "Hello"            -- enUS; other locale files overwrite only what they translate
print(L["Untranslated key"])    -- prints the key, never nil
```

Stable-ID variants key by `LID_WARNING` etc. so code is decoupled from English wording. List all locale files *before* the core file in the `.toc`.
