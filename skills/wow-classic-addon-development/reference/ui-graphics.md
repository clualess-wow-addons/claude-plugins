# UI graphics — textures, fonts & animations

Classic Era runs the modern client binary, so engine-level texture/font/animation methods exist in Era — what differs is *data* (atlas names, art) and a couple of removed Lua APIs. (Texture-layer basics, `SetColorTexture`, `SetTexCoord` cropping, `SetFont` basics are in [minimal-addons.md](minimal-addons.md).)

## Texture atlases

An atlas is a named sub-rectangle of a shared sheet; `SetAtlas` looks up the file, tex-coords, native size, and slice margins for you — no hardcoded `SetTexCoord` fractions, art stays sharp.

```lua
tex:SetAtlas("ColorPicker-HueBar", true)   -- (atlas [, useAtlasSize [, filterMode]]); useAtlasSize sizes the region
local info = C_Texture.GetAtlasInfo("ColorPicker-HueBar")   -- table, or nil if the atlas isn't in this client
if info then tex:SetAtlas("ColorPicker-HueBar") end
```

**Era caveat:** the atlas *API* works (`SetAtlas`, `C_Texture.GetAtlasInfo`, both in 1.15.x), but Era ships a **much smaller atlas set** — many atlas *names* from newer content don't resolve. Always gate on `GetAtlasInfo(name) ~= nil`, or take names from a known-Era frame. Browse names in `UiTextureAtlasMember.db2` on **wago.tools**.

## Mask textures

A `MaskTexture`'s alpha carves out the textures it's attached to — the basis of circular minimap/portrait clips.

```lua
local mask = frame:CreateMaskTexture()           -- positioned/sized like a texture (max 3 masks per texture)
mask:SetAllPoints(tex)
mask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
tex:AddMaskTexture(mask)                          -- now `tex` shows only where the mask is bright
-- shortcut for a single-file mask, no object: tex:SetMask("path")
```

The trailing wrap-mode args matter: `"CLAMPTOBLACKADDITIVE"` clamps everything outside the mask image to black (fully clipped), giving a clean circle with no edge bleed.

## Nine-slice — scalable bordered panels

Nine-slice = 4 fixed corners + 4 stretched/tiled edges + a center fill, so a panel scales without distorting corners. Easiest route in Era is **`BackdropTemplate`** (itself nine-slice). **Gotcha:** `SetBackdrop` was removed from the base `Frame` in 9.0 — you must inherit `"BackdropTemplate"`:

```lua
local p = CreateFrame("Frame", "MyPanel", UIParent, "BackdropTemplate")
p:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
p:SetBackdropColor(0,0,0,0.85); p:SetBackdropBorderColor(0.6,0.6,0.6)
```

Or the explicit system: `NineSliceUtil.ApplyLayout(container, NineSliceLayouts.Dialog)` with the `NineSlicePanelTemplate` (Era layouts include `Dialog`, `InsetFrameTemplate`, `TooltipDefaultLayout`…). Single-texture nine-slice (no child regions): `tex:SetTextureSliceMargins(l,t,r,b)` + `tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)`.

## Gradients, blend, desaturation, rotation, pixel-snap

```lua
tex:SetGradient("VERTICAL", CreateColor(1,1,0,1), CreateColor(0,0,1,1))  -- min→max color (multiply filter)
tex:SetBlendMode("ADD")        -- BLEND(default)/ADD(glows)/MOD/DISABLE(opaque)/ALPHAKEY(cutout)
tex:SetDesaturated(true)       -- or SetDesaturation(0..1)
tex:SetRotation(-math.pi/4)    -- radians, +CCW, pivots about center
tex:SetTexCoord(1,0, 0,1)      -- 4-arg crop, or this = horizontal flip; 8-arg = per-corner affine (rotate/shear)
tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0)   -- DO THIS when rotating/animating a texture (no jitter)
```

**Removed (not in Era):** `Texture:SetGradientAlpha(...)` was merged into `SetGradient` in 10.0 and is gone — use `SetGradient` + `CreateColor` as above.

## Fonts & FontObjects

A `Font` object is a reusable, named bundle of (file, height, flags, color, justify, shadow). Point many FontStrings at one object; restyle the object and **every** FontString updates — this is how user "font" addons work.

```lua
local myFont = CreateFont("MyAddonHeader")       -- global _G["MyAddonHeader"], starts empty
myFont:SetFont("Fonts/FRIZQT__.TTF", 16, "OUTLINE")   -- flags non-optional since 10.0: ""/OUTLINE/THICKOUTLINE/MONOCHROME
myFont:SetTextColor(1, 0.82, 0)                  -- WoW gold
-- or clone Blizzard's then tweak (don't mutate the shared object): myFont:CopyFontObject(GameFontNormalLarge)

local fs = panel:CreateFontString(nil, "OVERLAY")
fs:SetFontObject(myFont)                         -- accepts an object OR a name string
fs:SetText("Inventory")
local w, h = fs:GetStringWidth(), fs:GetStringHeight()   -- measure (valid right after SetText)
panel:SetWidth(w + 20)                           -- size a frame to its text
```

**Standard font objects** (mix by family + role + size): `GameFontNormal`/`*Small`/`*Large`/`*Huge` (gold), `GameFontHighlight*` (white), `GameFontDisable*` (gray), color variants (`GameFontRed`/`Green`/`White`); `NumberFontNormal*` (bold figures); `SystemFont_*` (UI chrome); plus `QuestFont*`, `GameTooltipText`, `ChatFontNormal`. Other methods: `SetFormattedText`, `SetJustifyH/V`, `SetWordWrap`, `SetMaxLines`, `SetSpacing`, `SetTextColor`, `SetShadowColor/Offset`.

## Animations

`region:CreateAnimationGroup()` works on any frame/texture/fontstring. **All animation types ship in Era** (incl. `Path` and `FlipBook`): `Alpha`, `Scale`, `Translation`, `Rotation`, `Path`, `LineScale`, `LineTranslation`, `FlipBook`, `VertexColor`.

Per-animation: `SetDuration(s)`, `SetOrder(n)`, `SetStartDelay/SetEndDelay`, `SetSmoothing("IN"/"OUT"/"IN_OUT"/"NONE")`. Type setters — Alpha: `SetFromAlpha`/`SetToAlpha`; Scale: `SetScaleFrom`/`SetScaleTo` + `SetOrigin`; Translation: `SetOffset`; Rotation: `SetDegrees`/`SetRadians` + `SetOrigin`. Group: `Play`/`Stop`/`Pause`/`Restart`/`Finish`, `SetLooping("NONE"/"REPEAT"/"BOUNCE")`, `SetToFinalAlpha(true)`, `IsPlaying`. Scripts: `OnPlay`/`OnFinished`/`OnLoop`/`OnStop`.

```lua
-- Pulsing glow (BOUNCE auto-reverses → one anim each)
local glow = button:CreateTexture(nil, "OVERLAY"); glow:SetAllPoints(button)
glow:SetTexture("Interface/Buttons/ButtonHilight-Square"); glow:SetBlendMode("ADD")
glow:SetSnapToPixelGrid(false); glow:SetTexelSnappingBias(0)
local ag = glow:CreateAnimationGroup()
local fade = ag:CreateAnimation("Alpha"); fade:SetFromAlpha(0.25); fade:SetToAlpha(1); fade:SetDuration(0.6); fade:SetSmoothing("IN_OUT")
local grow = ag:CreateAnimation("Scale"); grow:SetScaleFrom(1,1); grow:SetScaleTo(1.15,1.15); grow:SetOrigin("CENTER",0,0); grow:SetDuration(0.6); grow:SetSmoothing("IN_OUT")
ag:SetLooping("BOUNCE"); ag:Play()
```

**The snap-back gotcha:** an animation is a *non-destructive visual transform* — when it finishes the region snaps back to its real anchor. To slide a panel in *and keep it*, anchor it at the off-screen **start**, translate it on, and re-pin to the final spot in `OnFinished`:

```lua
panel:ClearAllPoints(); panel:SetPoint("RIGHT", UIParent, "LEFT", 0, 0)   -- off the left edge
local intro = panel:CreateAnimationGroup()
local slide = intro:CreateAnimation("Translation"); slide:SetOffset(272, 0); slide:SetDuration(0.35); slide:SetSmoothing("OUT")
intro:SetToFinalAlpha(true)
intro:SetScript("OnFinished", function()
    panel:ClearAllPoints(); panel:SetPoint("RIGHT", UIParent, "LEFT", 272, 0)   -- pin at final spot
end)
panel:Show(); intro:Play()
```
