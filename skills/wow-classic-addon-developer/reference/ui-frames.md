# UI frame mechanics — scale, layering, input & models

How frames scale, stack, take mouse input, and render 3D models in Classic Era 1.15.x. (Frame creation, strata basics, backdrops, drag-to-move are in [minimal-addons.md](minimal-addons.md).)

## Pixel-perfect rendering

WoW measures the UI in **virtual units, not pixels**: at scale 1.0, one UI unit = 1/768 of the physical screen height, so `UIParent` is always 768 units tall. On a 1440p monitor each unit spans 1440/768 ≈ 1.875 physical pixels — a "1-unit" border lands on fractional pixels and the GPU smears it. That's the blur. Fix: make 1 unit map to whole pixels by scaling `UIParent` to `768 / physicalHeight`.

```lua
local _, physHeight = GetPhysicalScreenSize()    -- real render resolution (Era since 1.13.2)
UIParent:SetScale(768 / physHeight)              -- apply on PLAYER_LOGIN / after each loading screen
```

**Why Lua not the CVar:** the `uiScale` CVar clamps at **0.64**, so resolutions taller than ~1200px (where `768/h < 0.64`) can't go low enough via `/console uiScale`. `UIParent:SetScale()` bypasses the clamp. For a crisp 1px element, size it to one physical pixel:

```lua
local function PixelSize(frame)                  -- one physical pixel in `frame`'s coordinate units
    local _, ph = GetPhysicalScreenSize()
    return (768 / ph) / frame:GetEffectiveScale()
end
local line = frame:CreateTexture(nil, "OVERLAY"); line:SetColorTexture(0,0,0,1)
line:SetHeight(PixelSize(frame)); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
```

`PixelUtil` (e.g. `PixelUtil.SetWidth`, `PixelUtil.SetPoint`) ships in Era and does this rounding for you — the Blizzard-blessed alternative.

## UI scale

- `region:SetScale(s)` / `GetScale()` — the region's own multiplier (default 1.0).
- `region:GetEffectiveScale()` — **own × all parents' scale up to `UIParent`**. This is the number for any screen↔frame coordinate math.
- `region:SetIgnoreParentScale(true)` — breaks the multiply chain (a sharp child inside a scaled parent). Available in Era.
- CVars `useUiScale` (0/1 master) + `uiScale` (0.64–8.0); **can't change `uiScale` in combat**.

```lua
-- place `child` exactly over a point known in `other`'s space:
local s = other:GetEffectiveScale() / child:GetEffectiveScale()
child:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px * s, py * s)
```

## Mouse interaction

`EnableMouse(true)` is the umbrella toggle — it implies **both** click and motion. Wheel is separate (`EnableMouseWheel(true)`). Granular toggles (in Era): `SetMouseClickEnabled(bool)`, `SetMouseMotionEnabled(bool)`.

| Script | Fires | Notes |
|---|---|---|
| `OnEnter`/`OnLeave` | hover in/out | needs motion enabled |
| `OnMouseDown`/`OnMouseUp` | physical press/release | `(self, button)`; **not** gated by `RegisterForClicks` |
| `OnClick` | logical click on a Button | `(self, button, down)`; **gated** by `RegisterForClicks` |
| `OnDoubleClick` | double click | `(self, button)` |
| `OnMouseWheel` | wheel | `(self, delta)` ±1; needs `EnableMouseWheel(true)` |

`Button:RegisterForClicks("AnyUp","AnyDown","LeftButtonUp","RightButtonDown",…)` — default `"LeftButtonUp"`; governs `OnClick`/`PreClick`/`PostClick` only, not `OnMouseDown/Up` or drag.

**Click passthrough:** `SetPropagateMouseClicks`/`SetPropagateMouseMotion` don't exist in Era. Make a frame hover-only without eating clicks via `SetMouseClickEnabled(false)`, or carve the clickable area with **`SetHitRectInsets(l, r, t, b)`** (positive shrinks the hit rect inward).

```lua
local scale = UIParent:GetEffectiveScale()
local cx, cy = GetCursorPosition()               -- scale-independent pixels, screen bottom-left origin
cx, cy = cx / scale, cy / scale                  -- now in UIParent units
dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)   -- sits under the cursor
```

`frame:IsMouseOver([top, bottom, left, right])` returns a bool — handy in `OnUpdate` when OnEnter/OnLeave aren't reliable.

## Frame layering depth

Two tiers: **strata** (coarse bands) then **frame level** (fine, within a strata).

- `SetFrameStrata("HIGH")` — bands low→high: `BACKGROUND, LOW, MEDIUM, HIGH, DIALOG, FULLSCREEN, FULLSCREEN_DIALOG, TOOLTIP`. A higher strata always draws over a lower one, regardless of level.
- `SetFrameLevel(n)` — integer **0–10000**; within a strata, higher draws on top. Children default to parent level + 1.
- `SetToplevel(true)` — clicking the frame auto-raises it above siblings in its strata (good for draggable windows; Era since 1.10.1; combat-restricted on protected frames).
- `Raise()` / `Lower()` — bump above/below all siblings in the strata immediately.

**Texture sub-layers** within one frame: each draw layer (`BACKGROUND < BORDER < ARTWORK < OVERLAY < HIGHLIGHT`) has an integer sub-level **−8…7** to break ties:

```lua
local mid = f:CreateTexture(nil, "ARTWORK", nil, 0)   -- CreateTexture(name, layer, templates, subLevel)
local top = f:CreateTexture(nil, "ARTWORK", nil, 2)   -- same layer, drawn above `mid`
top:SetDrawLayer("ARTWORK", 5)                         -- change sublevel later
```

Full draw order, outermost first: **strata → frame level → draw layer → sub-level**. Sub-levels are scoped to one frame (a texture can't jump above a texture in a higher-level frame).

## 3D model frames

`CreateFrame("PlayerModel"/"Model"/"DressUpModel"/"CinematicModel", name, parent)` — all four exist in Era. `PlayerModel` is the workhorse (units, creatures by display ID).

```lua
local m = CreateFrame("PlayerModel", "MyMobView", UIParent)
m:SetSize(220, 280); m:SetPoint("CENTER")
m:SetDisplayInfo(448)        -- render ANY creature by display ID, without having encountered it
-- or: m:SetUnit("player") / m:SetCreature(creatureID) / m:SetModel(fileDataID)
m:SetPortraitZoom(0)         -- 0 = full body, 1 = head-only portrait
m:SetFacing(0.6)             -- yaw, radians (SetRotation is the older alias)
m:SetScript("OnShow", function(self) self:RefreshCamera() end)
```

**Caveats:** model frames are **timing-sensitive** — `SetModel`/`SetDisplayInfo` can silently no-op if called before the frame is shown; reapply in `OnShow` or after `C_Timer.After(0, ...)`. Use Era display IDs (don't copy IDs from other-flavor data). `ModelScene`/actor APIs and `SetItemAppearance` are partial/absent in Era — prefer `SetDisplayInfo`/`SetModel`/`SetCreature`. `SetPortraitZoom` is far more predictable than manual `SetPosition`/`SetCamera`.
