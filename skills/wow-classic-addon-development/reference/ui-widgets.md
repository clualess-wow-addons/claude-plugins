# UI & widgets

Building real UI in Classic Era (1.15.x): XML layout, the widget cookbook, tooltip authoring, dropdowns, hyperlinks, sound/media, minimap buttons, key bindings. (Frame basics — backdrops, anchoring, strata, movable — are in [minimal-addons.md](minimal-addons.md).)

The UI family of references: **this file** (controls) · [ui-windows.md](ui-windows.md) (window chrome, dialogs, tabs, options panel) · [ui-graphics.md](ui-graphics.md) (textures, fonts, animations) · [ui-frames.md](ui-frames.md) (scale, layering, mouse, 3D models).

## XML layout

XML is parsed *before* your Lua, so it shines for **reusable templates** and declarative structure. Mix freely with Lua: define a `virtual="true"` template in XML, then `CreateFrame(type, name, parent, "MyTemplate")`. List the `.xml` in the `.toc` (it pulls in its own `<Script>`/`<Include>` files).

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
  <Script file="MyAddon.lua"/>

  <Button name="MyRowTemplate" virtual="true">         <!-- template, not instantiated -->
    <Size x="180" y="20"/>
    <Layers><Layer level="ARTWORK">
      <FontString parentKey="Label" inherits="GameFontNormal" justifyH="LEFT"/>  <!-- parent.Label -->
    </Layer></Layers>
    <Scripts><OnClick method="OnClick"/></Scripts>      <!-- self:OnClick(button,down) -->
  </Button>

  <Frame name="MyFrame" parent="UIParent" hidden="true" frameStrata="DIALOG">
    <Size x="300" y="200"/>
    <Anchors><Anchor point="CENTER"/></Anchors>
    <Frames>
      <Button parentKey="Close" inherits="UIPanelCloseButton">
        <Anchors><Anchor point="TOPRIGHT" x="-2" y="-2"/></Anchors>
      </Button>
    </Frames>
    <Scripts><OnLoad function="MyFrame_OnLoad"/></Scripts>  <!-- global func(self) -->
  </Frame>
</Ui>
```

- **`virtual="true"`** = template; reference via `inherits="A, B"` (later wins) in XML *or* `CreateFrame`. **`intrinsic="true"`** defines a new widget *type* (advanced).
- **`<Layers>`/`<Layer level=…>`** hold visuals (`<Texture>`, `<FontString>`); **`<Frames>`** hold interactive child frames.
- **`<Scripts>`**: inline body (`self`, `event`, `button`, `...` in scope) · `function="Global"` → `Global(self, ...)` · `method="Name"` → `self:Name(...)`. Add `inherit="prepend|append"` to run alongside a template's handler.
- **`parentKey="Foo"`** → `parent.Foo = self` (modern idiom, no global). `name="$parentFoo"` builds a global from the parent's name.
- **`mixin="MyMixin"`** → `Mixin(self, MyMixin)` at creation, before `OnLoad`.

**XML vs Lua:** XML for static structure/templates/early `OnLoad`; Lua for anything dynamic. Most authors do pure-Lua `CreateFrame` and reserve XML for repeated templates.

## Widget cookbook

```lua
-- Button (UIPanelButtonTemplate = standard gold button)
local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
b:SetSize(120, 24); b:SetText("Do It")              -- :Enable()/:Disable()/:GetText()
b:SetScript("OnClick", function(self, mouseBtn, down) end)
-- other templates: UIPanelCloseButton (the X), GameMenuButtonTemplate

-- StatusBar (health / cast / progress)
local sb = CreateFrame("StatusBar", nil, parent)
sb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
sb:SetStatusBarColor(0, 1, 0); sb:SetMinMaxValues(0, 100); sb:SetValue(65)
-- :SetOrientation("VERTICAL"), :SetReverseFill(true)

-- EditBox (InputBoxTemplate draws the border)
local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
e:SetSize(160, 20); e:SetAutoFocus(false); e:SetMaxLetters(64)  -- :SetNumeric(true)
e:SetScript("OnEnterPressed", function(self) print(self:GetText()); self:ClearFocus() end)
e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- CheckButton (UICheckButtonTemplate)
local c = CreateFrame("CheckButton", "MyCheck", parent, "UICheckButtonTemplate")
_G["MyCheckText"]:SetText("Enable"); c:SetChecked(true)        -- :GetChecked()
c:SetScript("OnClick", function(self) MyDB.on = self:GetChecked() end)

-- Slider (OptionsSliderTemplate; labels are $nameLow/High/Text)
local s = CreateFrame("Slider", "MySlider", parent, "OptionsSliderTemplate")
s:SetMinMaxValues(0,100); s:SetValueStep(5); s:SetObeyStepOnDrag(true); s:SetValue(50)
s:SetScript("OnValueChanged", function(self, v, userInput) MyDB.scale = v end)

-- Cooldown (radial sweep; OmniCC hooks it automatically → free countdown text)
local cd = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
cd:SetAllPoints()
local start, dur = GetSpellCooldown(spellID)
if start > 0 then cd:SetCooldown(start, dur) end    -- (startTime, durationSec); (0,0) clears

-- Texture & FontString
local t = parent:CreateTexture(nil, "ARTWORK")
t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); t:SetTexCoord(0.08,0.92,0.08,0.92)
t:SetVertexColor(1,0.5,0.5)                         -- tint; solid fill = SetColorTexture(r,g,b,a)
local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fs:SetFormattedText("Gold: |cffffff00%d|r", 1234)  -- printf-style; or :SetText / :SetFontObject
```

**ScrollFrame + FauxScrollFrame** — the canonical Era list. `FauxScrollFrameTemplate` draws only the scrollbar; *you* keep a fixed pool of row widgets and repaint by offset.

```lua
local ROWS, ROW_H = 12, 16
local scroll = CreateFrame("ScrollFrame", "MyScroll", parent, "FauxScrollFrameTemplate")
local rows = {}
for i = 1, ROWS do
    local r = CreateFrame("Button", nil, scroll); r:SetSize(260, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i-1)*ROW_H)
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormal"); r.text:SetPoint("LEFT")
    rows[i] = r
end
local function Update()
    local n = #data
    FauxScrollFrame_Update(scroll, n, ROWS, ROW_H)          -- (frame, numItems, numToShow, rowH)
    local offset = FauxScrollFrame_GetOffset(scroll)
    for i = 1, ROWS do
        local idx, r = i + offset, rows[i]
        if idx <= n then r.value = data[idx]; r.text:SetText(data[idx]); r:Show() else r:Hide() end
    end
end
scroll:SetScript("OnVerticalScroll", function(self, off) FauxScrollFrame_OnVerticalScroll(self, off, ROW_H, Update) end)
scroll:SetScript("OnShow", Update); Update()
```

## GameTooltip — authoring & hooking

Set owner/anchor, add lines, then **`Show()`** (`AddLine` doesn't auto-show):

```lua
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")       -- ANCHOR_CURSOR/LEFT/TOP/NONE...
    GameTooltip:SetText("Title", 1, 1, 1)
    GameTooltip:AddLine("Wraps.", nil,nil,nil, true) -- (text,r,g,b,wrap)
    GameTooltip:AddDoubleLine("Left", "Right", 1,1,1, 0,1,0)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", GameTooltip_Hide)           -- or function() GameTooltip:Hide() end
```

**Add lines to item tooltips (Classic):** `HookScript("OnTooltipSetItem")`, read with `:GetItem()`:

```lua
GameTooltip:HookScript("OnTooltipSetItem", function(tt)
    local _, link = tt:GetItem()
    if link then tt:AddLine("ItemID: "..link:match("item:(%d+)"), 0.6,0.6,1); tt:Show() end
end)
```

In Era, the `OnTooltipSetItem` HookScript is the standard way to add lines to item tooltips — retail removed it in 10.0.2, but Era keeps it wired. The retail replacement (`TooltipDataProcessor.AddTooltipPostCall` + `C_TooltipInfo`) is **not usable here**: Era declares `C_TooltipInfo` only as a stub with **no getter functions**. In multi-flavor code, guard on the function, not the namespace: `if C_TooltipInfo and C_TooltipInfo.GetItem then`.

## Dropdown menus — `UIDropDownMenu`

`UIDropDownMenu` (shown here) still ships in Era; the newer `MenuUtil`/`Blizzard_Menu` system **also** exists in 1.15.x if you prefer it. With `UIDropDownMenu` you bind an *initialize* function that rebuilds the menu each open, emitting one `info` table per item:

```lua
local dd = CreateFrame("Frame", "MyDD", UIParent, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(dd, 160); UIDropDownMenu_SetText(dd, "Pick")
UIDropDownMenu_Initialize(dd, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    info.text, info.checked = "Option A", (MyDB.choice == "A")
    info.func = function() MyDB.choice = "A"; UIDropDownMenu_SetText(dd, "A"); CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
end)
```

`info` fields: `text`, `value`, `func(self,arg1,arg2,checked)`, `arg1/2`, `checked`, `isNotRadio` (square check), `notCheckable`, `isTitle`, `disabled`, `hasArrow`+`menuList` (submenu), `icon`, `tooltipTitle`/`tooltipText`+`tooltipOnButton`. Context menu: `UIDropDownMenu_Initialize(menu, fn, "MENU")` then `ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)`.

Native **`EasyMenu`** is **gone from Era** (not in the 1.15.x UI source). Use **LibUIDropDownMenu**'s `L_EasyMenu` instead — its `L_`-prefixed clones (`L_UIDropDownMenu_Initialize`, `L_EasyMenu`) also insulate you from Blizzard changes + taint.

## Custom hyperlinks

Format `|cAARRGGBB|Htype:payload|h[text]|h|r`. Use the **`addon`** type — local-only, **cannot** be sent in chat (server filters unknown types); fine for your own frames/output.

```lua
print("|cff71d5ff|Haddon:MyAddon:show:1234|h[MyAddon: open]|h|r")
hooksecurefunc("SetItemRef", function(link)          -- clicking a printed chat link
    local kind, addon, data = strsplit(":", link)
    if kind == "addon" and addon == "MyAddon" then --[[ handle data ]] end
end)
-- Links inside YOUR frame: frame:SetHyperlinksEnabled(true) + OnHyperlinkClick/Enter/Leave scripts
```

## Sound & media

```lua
PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)            -- named constant
local ok, handle = PlaySoundFile("Interface\\AddOns\\MyAddon\\alert.ogg", "Master")
StopSound(handle)                                             -- channels: Master/SFX/Music/Ambience/Dialog
```

**LibSharedMedia-3.0** — shared registry so users pick your media in any addon's config:

```lua
local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register(LSM.MediaType.STATUSBAR, "MyBar", "Interface\\AddOns\\MyAddon\\bar.tga")
sb:SetStatusBarTexture(LSM:Fetch("statusbar", MyDB.bar))     -- types: FONT/SOUND/STATUSBAR/BORDER/BACKGROUND
-- LSM:List(type) / LSM:HashTable(type) for config dropdowns
```

## Minimap button — LibDBIcon-1.0 + LibDataBroker-1.1

Create an LDB data object, hand it to LibDBIcon with a saved-vars table (it persists `hide`/`minimapPos`):

```lua
local broker = LibStub("LibDataBroker-1.1"):NewDataObject("MyAddon", {
    type = "launcher", icon = "Interface\\Icons\\INV_Misc_Gear_01",
    OnClick = function(_, btn) if btn == "LeftButton" then MyAddon:Toggle() end end,
    OnTooltipShow = function(tt) tt:AddLine("MyAddon"); tt:AddLine("Left-click: toggle", 1,1,1) end,
})
-- after ADDON_LOADED, with MyAddonDB.minimap = MyAddonDB.minimap or {}:
LibStub("LibDBIcon-1.0"):Register("MyAddon", broker, MyAddonDB.minimap)
```

DataBroker displays (TitanPanel, ChocolateBar) show the same object automatically.

## Key bindings

**Static — `Bindings.xml`** at the addon root (**do NOT list it in the `.toc`** — auto-loaded). Labels come from `BINDING_HEADER_*`/`BINDING_NAME_*` globals set in Lua:

```xml
<Bindings>
  <Binding name="MYADDON_TOGGLE" header="MYADDON" default="SHIFT-M">MyAddon:Toggle()</Binding>
</Bindings>
```
```lua
BINDING_HEADER_MYADDON = "My Addon"; BINDING_NAME_MYADDON_TOGGLE = "Toggle window"
```

**Runtime, combat-safe — `SetOverrideBindingClick`** (temporary, not saved, wiped on reload) attaches a key to a secure button without touching the user's saved binds — the standard way to bind keys to runtime `SecureActionButtonTemplate`s:

```lua
SetOverrideBindingClick(myFrame, true, "G", "MyAddonKeyButton")   -- true = priority
ClearOverrideBindings(myFrame)                                    -- to remove
```

`SetBindingClick(key, buttonName)` is the saved variant (blocked in combat). `SetBinding(key, command)` binds to a named action.

## Unit-frame frameworks (brief)

**oUF** is the de-facto base for custom unit frames — it handles event/unit-attribute plumbing and secure group headers; a *layout* you write supplies the look (`oUF:RegisterStyle` → `oUF:SetActiveStyle` → `oUF:Spawn("player")`/`:SpawnHeader(...)`, with `[name]`/`[perhp]` tags). **Classic caveat:** mainline `oUF-wow/oUF` is developed against the modern client; Era generally needs a Classic-compatible fork (e.g. the one bundled with the RUF layout) — verify the embedded copy.
