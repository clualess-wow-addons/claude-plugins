# Worked example — a complete addon

A small but **real, runnable** addon that ties the whole stack together: TOC + lifecycle + SavedVariables, a movable window with **saved position**, **tabs**, a **scrolling list**, an **options-backed setting**, a slash command, and **event-driven** content. *MiniLog* logs the zones you visit. Each piece links to its deep-dive file. Drop these two files in `Interface/AddOns/MiniLog/`.

## `MiniLog.toc`

```
## Interface: 11508
## Title: MiniLog
## Notes: Logs the zones you visit.
## Author: you
## Version: 1.0.0
## SavedVariables: MiniLogDB

MiniLog.lua
```

## `MiniLog.lua`

```lua
local ADDON, ns = ...                         -- private namespace (see minimal-addons.md)

local DEFAULTS = {                            -- SavedVariables defaults
    announce   = false,
    maxEntries = 50,
    pos        = { point = "CENTER", x = 0, y = 0 },
    log        = {},                          -- { {t="14:03", zone="Durotar"}, ... }
}
local db                                      -- resolved on ADDON_LOADED

-- ── logging ──────────────────────────────────────────────────────────────
local function AddEntry(zone)
    if not zone or zone == "" then return end
    table.insert(db.log, 1, { t = date("%H:%M"), zone = zone })   -- `date` is available in WoW Lua
    while #db.log > db.maxEntries do table.remove(db.log) end
    if db.announce then print("|cff33ff99MiniLog|r: entered " .. zone) end
    if ns.Refresh then ns.Refresh() end
end

-- ── UI (see ui-windows.md / ui-widgets.md) ───────────────────────────────
local function BuildUI()
    local f = CreateFrame("Frame", "MiniLogFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(280, 320)
    f:SetPoint(db.pos.point, UIParent, db.pos.point, db.pos.x, db.pos.y)   -- restore saved position
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        db.pos.point, db.pos.x, db.pos.y = p, x, y                          -- save position
    end)
    if f.SetTitle then f:SetTitle("MiniLog") elseif f.TitleText then f.TitleText:SetText("MiniLog") end
    tinsert(UISpecialFrames, "MiniLogFrame")                                -- Esc closes it
    ns.frame = f

    -- two content panels + two tabs (PanelTemplates; tabs MUST be named $parentTabN)
    -- NB: BasicFrameTemplateWithInset draws the inset border ART but has NO `.Inset` child
    -- frame (that lives on ButtonFrameTemplate) — so parent to `f` and inset by hand.
    local logPanel = CreateFrame("Frame", nil, f)
    logPanel:SetPoint("TOPLEFT", 8, -28); logPanel:SetPoint("BOTTOMRIGHT", -6, 8)
    local optPanel = CreateFrame("Frame", nil, f)
    optPanel:SetPoint("TOPLEFT", 8, -28); optPanel:SetPoint("BOTTOMRIGHT", -6, 8)
    local panels = { logPanel, optPanel }

    local tab1 = CreateFrame("Button", "$parentTab1", f, "PanelTabButtonTemplate")
    tab1:SetID(1); tab1:SetText("Log"); tab1:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 5, 2)
    local tab2 = CreateFrame("Button", "$parentTab2", f, "PanelTabButtonTemplate")
    tab2:SetID(2); tab2:SetText("Options"); tab2:SetPoint("LEFT", tab1, "RIGHT", -14, 0)
    f.numTabs = 2
    local function OnTab(self)
        PanelTemplates_SetTab(f, self:GetID())
        for i, p in ipairs(panels) do p:SetShown(i == self:GetID()) end
    end
    tab1:SetScript("OnClick", OnTab); tab2:SetScript("OnClick", OnTab)

    -- Log tab: a recycled scrolling list (FauxScrollFrame; see ui-widgets.md)
    local ROWS, ROW_H = 14, 18
    local scroll = CreateFrame("ScrollFrame", "MiniLogScroll", logPanel, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6); scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local rows = {}
    for i = 1, ROWS do
        local r = logPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -(i - 1) * ROW_H - 2); r:SetJustifyH("LEFT")
        rows[i] = r
    end
    local function Refresh()
        local n = #db.log
        FauxScrollFrame_Update(scroll, n, ROWS, ROW_H)
        local off = FauxScrollFrame_GetOffset(scroll)
        for i = 1, ROWS do
            local e = db.log[i + off]
            rows[i]:SetText(e and ("|cff888888" .. e.t .. "|r  " .. e.zone) or "")
        end
    end
    scroll:SetScript("OnVerticalScroll", function(self, o) FauxScrollFrame_OnVerticalScroll(self, o, ROW_H, Refresh) end)
    ns.Refresh = Refresh

    -- Options tab: an options-backed setting that changes behavior
    local cb = CreateFrame("CheckButton", "MiniLogAnnounceCB", optPanel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, -12)
    _G["MiniLogAnnounceCBText"]:SetText("Announce zone changes to chat")
    cb:SetChecked(db.announce)
    cb:SetScript("OnClick", function(self) db.announce = self:GetChecked() end)

    PanelTemplates_SetTab(f, 1); OnTab(tab1)       -- start on the Log tab
    Refresh()
    f:Hide()
end

local function Toggle() if ns.frame then ns.frame:SetShown(not ns.frame:IsShown()) end end

-- ── lifecycle (see minimal-addons.md) ────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MiniLogDB = MiniLogDB or {}                                          -- SavedVariables now exist
        db = MiniLogDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end -- merge defaults
        ns.db = db
    elseif event == "PLAYER_LOGIN" then
        BuildUI()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if db then AddEntry(GetZoneText()) end
    end
end)

-- ── slash command (see minimal-addons.md) ────────────────────────────────
SLASH_MINILOG1 = "/minilog"
SlashCmdList.MINILOG = function(msg)
    if msg:lower():match("^%s*clear%s*$") then
        wipe(db.log); if ns.Refresh then ns.Refresh() end
        print("|cff33ff99MiniLog|r: log cleared.")
    else
        Toggle()
    end
end
```

## What it demonstrates

- **TOC + lifecycle:** `ADDON_LOADED` (gate on `arg1 == ADDON`) initializes SavedVariables + merges defaults; `PLAYER_LOGIN` builds the UI; a third event drives content. *(minimal-addons.md)*
- **SavedVariables:** account-wide `MiniLogDB` with a defaults-merge; persists settings, the log, and window position. *(saved-variables.md)*
- **Window chrome + saved position:** `BasicFrameTemplateWithInset`, drag-to-move that writes `GetPoint()` back to the DB, and `UISpecialFrames` for Esc-to-close. *(ui-windows.md)*
- **Tabs + scrolling list:** `PanelTemplates` tabs switching two panels; a recycled `FauxScrollFrame` list. *(ui-windows.md, ui-widgets.md)*
- **Options-backed setting:** a checkbox whose state lives in the DB and changes runtime behavior (the `announce` print).
- **Slash command** with a sub-command (`/minilog clear`).

**Extend it:** add a `maxEntries` slider (ui-widgets.md), register a Blizzard options panel via the Settings API (ui-windows.md), or wrap the announce in **ChatThrottleLib** if it ever broadcasts (best-practices.md). Before shipping, run the [pre-ship checklist](best-practices.md).
