# Recipes — common addon tasks

Copy-paste solutions for frequent Classic Era tasks, composed from the primitives in the other files. Each is minimal; adapt names and link to the deep-dive for options.

## Track a buff/debuff → show an icon

Scan auras by spellID, show a texture while it's up, update on `UNIT_AURA`. *([classic-api.md](classic-api.md) — auras)*

```lua
local WATCH = 1459                                  -- the spellID to track
local icon = CreateFrame("Frame", nil, UIParent); icon:SetSize(36, 36); icon:SetPoint("CENTER")
icon.tex = icon:CreateTexture(nil, "ARTWORK"); icon.tex:SetAllPoints(); icon.tex:SetTexCoord(.08,.92,.08,.92)

local function Update()
    for i = 1, 40 do
        local name, tex, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellId == WATCH then icon.tex:SetTexture(tex); icon:Show(); return end
    end
    icon:Hide()
end
local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_AURA", "player"); f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", Update)
```

## A movable frame that saves its position

Reusable helper — pass a `save` callback that writes to your SavedVariable. (**EditMode is retail-only**; in Era you make frames movable by hand, like this.) *([ui-windows.md](ui-windows.md) — anchoring)*

```lua
local function MakeMovable(frame, save)
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if save then local p, _, rp, x, y = self:GetPoint(); save(p, rp, x, y) end
    end)
end
-- MakeMovable(myFrame, function(p, rp, x, y) DB.pos = { p, rp, x, y } end)
-- restore: local q = DB.pos; if q then myFrame:ClearAllPoints(); myFrame:SetPoint(q[1], UIParent, q[2], q[3], q[4]) end
```

## Recycle widgets with a frame pool

Frames can't be destroyed — pool and reuse them for dynamic lists instead of leaking one per update. *([best-practices.md](best-practices.md) — perf)*

```lua
local pool = CreateFramePool("Button", parent, "MyRowTemplate")   -- also CreateFontStringPool / CreateTexturePool
local function Rebuild(items)
    pool:ReleaseAll()                                -- hide + reclaim every active frame
    local prev
    for _, item in ipairs(items) do
        local row = pool:Acquire()                   -- reuse a hidden one, or create one if none free
        row:SetText(item.name); row:Show()
        row:SetPoint("TOPLEFT", prev or parent, prev and "BOTTOMLEFT" or "TOPLEFT", 0, prev and 0 or -4)
        prev = row
    end
end
```

## An options checkbox bound to a SavedVariable

```lua
local function Checkbox(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")   -- own label (robust on unnamed buttons)
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0); fs:SetText(label)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return cb
end
-- Checkbox(panel, "Enable", function() return DB.enabled end, function(v) DB.enabled = v end)
```

## React to an event (and announce)

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, _, level)
    print(("|cff33ff99Ding!|r Level %d"):format(level))
    -- visible chat: SendChatMessage("...", "GUILD")
    -- ADDON-to-addon volume: route through ChatThrottleLib / AceComm (best-practices.md), never raw
end)
```

## Throttle work (repeating vs per-frame)

```lua
-- cheap repeating update: a ticker (best for clocks/polls)
C_Timer.NewTicker(1, function() label:SetText(("FPS %d"):format(GetFramerate())) end)

-- smooth per-frame, but gated so it isn't every frame (events-and-combat-log.md)
local acc = 0
bar:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed; if acc < 0.1 then return end; acc = 0
    UpdateBar()
end)
```

## Defer a protected action out of combat

```lua
local pending
local function SafeApply(fn)
    if InCombatLockdown() then pending = fn else fn() end           -- secure-and-taint.md
end
local g = CreateFrame("Frame"); g:RegisterEvent("PLAYER_REGEN_ENABLED")
g:SetScript("OnEvent", function() if pending then pending(); pending = nil end end)
```

## Count / find an item in bags

```lua
local total = GetItemCount(itemID, true)            -- includeBank=true; simplest for "how many do I have"

for bag = 0, 4 do                                    -- manual scan when you need WHERE it is
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)   -- returns a table (classic-api.md)
        if info and info.itemID == itemID then --[[ bag, slot ]] end
    end
end
```

## Receive an item dropped onto a frame

The player picks an item up onto the cursor (from a bag); your frame catches it. *([classic-api.md](classic-api.md) — items)*

```lua
local slot = CreateFrame("Button", nil, UIParent)   -- receiving drops needs no RegisterForDrag (that's for STARTING drags)
slot:SetSize(37, 37); slot:SetPoint("CENTER")
local function OnDrop(self)
    local kind, id = GetCursorInfo()                 -- "item", itemID, itemLink while an item is on the cursor
    if kind == "item" then
        self.itemID = id
        local icon = select(10, GetItemInfo(id))     -- texture (10th return; cached — it was just on the cursor)
        self.tex = self.tex or self:CreateTexture(nil, "ARTWORK"); self.tex:SetAllPoints()
        self.tex:SetTexture(icon)
        ClearCursor()                                -- release the cursor
    end
end
slot:SetScript("OnReceiveDrag", OnDrop)              -- drag-and-drop
slot:SetScript("OnMouseUp", OnDrop)                  -- also accept a plain click while holding an item
```

## Expose a public API for other addons

One global namespace table is your API; add a tiny callback registry so others can react. *([ace3.md](ace3.md) — AceComm for cross-client; this is same-client.)*

```lua
MyAddon = MyAddon or {}                              -- the only global you expose
function MyAddon.GetData() return ns.data end        -- others call MyAddon.GetData()

local listeners = {}
function MyAddon.Register(fn) listeners[#listeners + 1] = fn end
local function Fire(...)                              -- call when your data changes
    for _, fn in ipairs(listeners) do securecall(fn, ...) end   -- taint-safe dispatch: one bad/tainted listener can't taint or abort the rest (best-practices.md)
end
```

## Iterate party/raid members

See the `ForEachGroupMember` idiom in [classic-api.md](classic-api.md) (raid → `raid1..N`; party → `player` + `party1..N`); re-read on `GROUP_ROSTER_UPDATE`, never cache that `raid1` is a fixed person.
