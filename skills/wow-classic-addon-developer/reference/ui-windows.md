# UI windows, templates & config panels

Assembling real windows in Classic Era 1.15.x: standard chrome templates, tabs, dialogs, scrolling, the options panel, and the color picker. Everything here is confirmed used by installed Classic addons.

## Standard window chrome templates

Inherit a Blizzard template to get a bordered, titled, closable window for free instead of hand-building borders. Set the title with `frame:SetTitle("...")` (modern mixin) or `frame.TitleText:SetText("...")` (older); the close button is `frame.CloseButton`. Inspect a template's exact child keys live with `/fstack`.

```lua
-- A proper window: portrait + title + close + sunken inset, draggable, Esc-closable
local f = CreateFrame("Frame", "MyAddonWindow", UIParent, "PortraitFrameTemplate")
f:SetSize(360, 260); f:SetPoint("CENTER")
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetTitle("My Addon")                              -- or f.TitleText:SetText("My Addon")
SetPortraitToAsset(f.PortraitContainer.portrait, "Interface\\Icons\\INV_Misc_Gear_01")
-- f.CloseButton already wired to hide the frame
tinsert(UISpecialFrames, "MyAddonWindow")           -- Esc closes it (see below)

local inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate")   -- content area
inset:SetPoint("TOPLEFT", 8, -28); inset:SetPoint("BOTTOMRIGHT", -8, 8)
```

| Template | Gives you | Key children |
|---|---|---|
| `BasicFrameTemplate` | border, title bar, close button, bg | `.CloseButton`, `.TitleText`, `.Bg`, `.TitleBg` |
| `BasicFrameTemplateWithInset` | the above + sunken inset **artwork** | *no `.Inset` child frame* — parent content to the frame itself with manual insets, or use `ButtonFrameTemplate` |
| `PortraitFrameTemplate` | circular portrait + title + close | `.portrait`/`.PortraitContainer.portrait`, `.TitleText`, `.CloseButton` |
| `ButtonFrameTemplate` | portrait window with a large inset (bag/profession style) | `.Inset`, `.CloseButton`, portrait; `ButtonFrameTemplate_HidePortrait(f)` |
| `UIPanelDialogTemplate` | simple dialog frame + close | `.Title`/`.TitleText`, close button |
| `InsetFrameTemplate` | just a sunken bordered content area | — (use as a child) |

Portrait helpers: `SetPortraitToAsset(tex, "Interface\\Icons\\...")` (a file), `SetPortraitTexture(tex, "player")` (a unit's model).

## Tabs

`PanelTemplates_*` drive a row of tab buttons (template `PanelTabButtonTemplate` / `CharacterFrameTabButtonTemplate`), one content panel each:

```lua
local tabs = { tab1Panel, tab2Panel }
PanelTemplates_SetNumTabs(f, #tabs)
PanelTemplates_SetTab(f, 1)                          -- highlight tab 1
for i, btn in ipairs({ f.Tab1, f.Tab2 }) do
    btn:SetScript("OnClick", function()
        PanelTemplates_SetTab(f, i)
        for j, panel in ipairs(tabs) do panel:SetShown(j == i) end
    end)
end
-- PanelTemplates_GetSelectedTab(f), PanelTemplates_TabResize(tabButton, padding) to size to label
```

## StaticPopup dialogs

The standard confirm/prompt dialog. Register once, show by key:

```lua
StaticPopupDialogs["MYADDON_RESET"] = {
    text = "Reset %s to defaults?",                  -- %s filled by StaticPopup_Show args
    button1 = YES, button2 = NO,                     -- YES/NO/OKAY/CANCEL are localized globals
    OnAccept = function(self, data) data.Reset() end,
    hasEditBox = false, timeout = 0, whileDead = true, hideOnEscape = true,
    preferredIndex = 3,                              -- GOTCHA: avoids a taint bug from other addons' popups
}
StaticPopup_Show("MYADDON_RESET", "MyAddon", nil, { Reset = MyAddon.Reset })   -- (key, text_arg1, arg2, data)
```

Always set `preferredIndex = 3` (`STATICPOPUP_NUMDIALOGS`) — without it, a tainted addon popup occupying an earlier slot can taint yours. Other useful fields: `OnCancel`/`OnShow`/`OnHide`; for text input `hasEditBox` + `editBoxWidth` + `maxLetters` + `EditBoxOnEnterPressed`; `exclusive` (only one popup at a time), `enterClicksFirstButton`, `hasMoneyFrame`/`hasItemFrame`, and `cancels = "OTHER_KEY"` to auto-dismiss another popup.

## Esc-to-close & the UIPanel system

`tinsert(UISpecialFrames, "MyFrameName")` makes **Escape** hide the (globally-named) frame — the simplest "closable window." Just don't leave a stale name in the list after the frame is gone.

The managed **UIPanel system** (`UIPanelWindows[name] = {area=..., pushable=...}` + `ShowUIPanel(f)`/`HideUIPanel(f)`) auto-positions frames so the character/bag panels tile and don't overlap. Most addons **avoid** it (it fights you over position and can taint) and use a plain movable frame + `UISpecialFrames` instead.

## ScrollFrame with `SetScrollChild`

For content *larger than the viewport* (vs `FauxScrollFrameTemplate`, which recycles fixed rows — see [ui-widgets.md](ui-widgets.md)). The scroll child is one big frame you scroll within a window:

```lua
local sf = CreateFrame("ScrollFrame", "MyScroll", parent, "UIPanelScrollFrameTemplate")  -- includes the scrollbar
sf:SetPoint("TOPLEFT", 8, -8); sf:SetPoint("BOTTOMRIGHT", -30, 8)
local content = CreateFrame("Frame", nil, sf)
content:SetSize(1, 1)                                 -- width tracks sf; height set to total content
sf:SetScrollChild(content)
-- build child widgets onto `content`, then set its height:
content:SetHeight(totalRows * ROW_H)
-- mouse wheel is wired by the template; for a bare ScrollFrame: sf:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel)
```

## Config / options panel — use the Settings API in Era

**Current Classic Era 1.15.x uses the Settings API** — the old `InterfaceOptions_AddCategory` was **removed** from 1.15.x. Build a canvas frame with a `.name`, register it, and it appears under **Game Menu → Options → AddOns**:

```lua
local panel = CreateFrame("Frame")
panel.name = "MyAddon"
-- ... add your checkboxes/sliders onto `panel` ...
local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
-- open it from a slash command: Settings.OpenToCategory(category:GetID())
-- subpanel: Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
```

To also support pre-Settings clients, feature-detect (the pattern real addons use):

```lua
if InterfaceOptions_AddCategory then                  -- legacy, gone in current Era
    InterfaceOptions_AddCategory(panel)
else
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
end
```

(If you use Ace3, `AceConfigDialog:AddToBlizOptions("MyAddon")` wraps all of this — see [ace3.md](ace3.md).)

## ColorPickerFrame

The shared color picker. Modern call (used in Era by Pawn, MoveAny, etc.):

```lua
local function open(r, g, b, a)
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame:GetColorAlpha()      -- 1 - OpacitySliderFrame:GetValue() on older clients
        MyAddon:SetColor(nr, ng, nb, na)
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, opacity = a, hasOpacity = true,
        swatchFunc = apply, opacityFunc = apply,
        cancelFunc = function() MyAddon:SetColor(r, g, b, a) end,   -- restore on cancel
    })
end
```

## Anchoring & sizing depth

(Basic `SetPoint` is in [minimal-addons.md](minimal-addons.md).)

- **Stretch by anchoring two+ points** instead of `SetSize`: anchoring `TOPLEFT` and `BOTTOMRIGHT` makes a frame track its parent's size. `SetPoint("LEFT")` + `SetPoint("RIGHT")` fixes width to the gap.
- `frame:GetPoint(i)` → `point, relativeTo, relativePoint, x, y` (persist these to save position); `GetNumPoints()`.
- `frame:SetClampedToScreen(true)` keeps a dragged window on-screen; `SetClampRectInsets(l, r, t, b)` lets part go past the edge (negative extends the clamp boundary).
- **Circular-anchor pitfall:** a frame's size can't depend on a child whose size depends on the frame — you get a "couldn't compute" layout. Give one side an explicit size.
- Content-size a window to its widgets by measuring (`fontString:GetStringWidth()`, summing row heights) and calling `SetSize`.
