# The 1.15.8 replacement map

Removals/replacements that third-party addons hit in the Classic Era 1.15.x modernization wave — most landed in the 1.15.8 refactor (clients 1.15.8/1.15.9 = Interface `11508`/`11509`, July 2026), a few earlier (marked). The client moved big chunks of FrameXML into `Blizzard_*` addons with mixins and removed legacy globals. Symbol presence/absence and replacements below were verified against the `Gethe/wow-ui-source` `classic_era` branch during real repairs (C-side removals additionally proven by the field crashes themselves); rows carrying their own hedge are exactly as certain as stated. Re-verify against the current branch before applying to a later client.

## Contents
- Diagnosis commands
- AddOn API family
- Unit frame globals → mixins
- Aura/buff system
- Compact raid frames and nameplates
- Events
- Options, templates, fonts
- Frame-shape changes
- Deprecation shims (the UnitAura trap)

## Diagnosis commands

```bash
# List the client UI source tree (find the file that owns a symbol):
gh api "repos/Gethe/wow-ui-source/git/trees/classic_era?recursive=1" --jq '.tree[].path' | grep -i <name>

# Fetch a file:
curl -sL "https://raw.githubusercontent.com/Gethe/wow-ui-source/classic_era/Interface/AddOns/<path>"

# Does an event still exist? (in-game): /dump C_EventUtils.IsEventValid("EVENT_NAME")
# Or grep the API docs dump: Blizzard_APIDocumentationGenerated/

# Syntax-check every edit:
luac -p <file>   # WoW's Lua 5.1 drops the backslash of unknown escapes ("\U" reads as "U");
                 # modern luac rejects them. Rewrite preserving the 5.1 runtime bytes —
                 # usually delete the stray backslash ("...\\\U..." -> "...\\U...");
                 # doubling it ("\U" -> "\\U") CHANGES the string.

# Find all embedded copies of a LibStub library (minor-version precedence!):
find <AddOns dir> -name "LibFoo-1.0.lua" | xargs grep -H "MINOR"
```

## AddOn API family

Flat globals removed; now only on `C_AddOns.*`:

| Removed global | Replacement | Trap |
|---|---|---|
| `GetAddOnMetadata` | `C_AddOns.GetAddOnMetadata` | — |
| `GetAddOnInfo` | `C_AddOns.GetAddOnInfo` | Same return positions (name/title/notes/loadable) |
| `IsAddOnLoaded` | `C_AddOns.IsAddOnLoaded` | — |
| `LoadAddOn` / `EnableAddOn` / `DisableAddOn` | `C_AddOns.*` | — |
| `GetAddOnEnableState(character, name)` | `C_AddOns.GetAddOnEnableState(name, character)` | **ARGUMENT ORDER SWAPPED** — a plain alias silently returns wrong values; write a wrapper preserving the legacy signature |

Alias pattern: `local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata` at the top of each affected file — the `or` fallback is deliberate: on current Era the left side is nil and the C_AddOns side is taken, while on older clients (multi-flavor addons) the surviving global wins.

Note: `getglobal(x)` did NOT break — 1.15.8 replaced the C function with a Lua shim (`Blizzard_UIParent/Shared/UIParent.lua`), so it still works; rewriting to `_G[x]` is cleanup, not repair.

## Unit frame globals → mixins

TargetFrame etc. are mixin-based; the free functions are gone. Hook the instance method (handler receives `self`):

| Removed global | Replacement |
|---|---|
| `TargetFrame_Update` | `hooksecurefunc(TargetFrame, "Update", ...)` (TargetFrameMixin:Update) |
| `TargetFrame_UpdateAuras` | `hooksecurefunc(TargetFrame, "UpdateAuras", ...)`; direct call: `TargetFrame:UpdateAuras()` |
| `TargetFrame_ShouldShowDebuffs(...)` | `TargetFrame:ShouldShowDebuffs(unit, caster, nameplateShowAll, casterIsAPlayer)` |
| `TargetFrame_UpdateAuraPositions(self, ...)` | `self:UpdateAuraPositions(auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX, mirrorAurasVertically)` with `self.UpdateBuffAnchor`/`self.UpdateDebuffAnchor` |
| `Target_Spellbar_AdjustPosition(spellbar)` | `spellbar:AdjustPosition()` (TargetSpellBarMixin) |
| `InterfaceOptionsFrame_OpenToCategory` *(removed ≤1.15.7, predates this refactor)* | `Settings.OpenToCategory(categoryIDOrName)` — keep the old call in an else-branch for older clients if the addon is multi-flavor |

`MAX_TARGET_BUFFS`/`MAX_TARGET_DEBUFFS` still global; `TargetFrameBuff1`-style global button names still exist; `PlayerPortrait`/`TargetFramePortrait` still exist.

## Aura/buff system

| Removed global | Replacement |
|---|---|
| `AuraButton_Update` / `AuraButton_UpdateDuration` | Modern BuffFrame: `BuffFrame.auraFrames` / `DebuffFrame.auraFrames` arrays (created at OnLoad, fixed count); hook button members: `hooksecurefunc(button, "OnUpdate", ...)`, `hooksecurefunc(button, "UpdateDuration", ...)` |
| Legacy aura data fields | Buttons carry `buttonInfo` `{index, auraType, auraInstanceID, expirationTime}` and a `Duration` fontstring; `C_UnitAuras.GetAuraDataByAuraInstanceID` exists on Era |

Feature-detect the branch, don't gate on project ID: `local useModern = type(AuraButton_Update) ~= "function"`.

Why `hooksecurefunc(button, "OnUpdate", ...)` is correct here despite the HookScript rule below: modern aura buttons dispatch these as mixin *methods* (XML `<OnUpdate method="OnUpdate"/>` — a table-member lookup), which member-hooks intercept. The HookScript-never-SetScript rule applies to actual script handlers installed with `SetScript`.

## Compact raid frames and nameplates

| Removed global | Replacement |
|---|---|
| `CompactRaidFrameContainer_GetUnitFrame` | `hooksecurefunc(CompactRaidFrameContainer, "GetUnitFrame", ...)` (same effective `self, unit, frameType` signature). New frameType `raidFake` exists — handle it in frame-type maps |
| `DefaultCompactNamePlateFrameSetup` | Gone (nameplates are mixin/pool-based). Hook `NamePlateDriverFrame` `"OnNamePlateAdded"` — fires after `namePlate.UnitFrame` is attached; guard for pooled re-adds |
| `CompactUnitFrame_UtilSetBuff` / `UtilSetDebuff` | **GONE, no Lua replacement** — compact frame auras render natively (attribute-driven). Feature that hooked them must be disabled behind an existence check with an explanatory comment |

Still present on Era: `DefaultCompactUnitFrameSetup`, `DefaultCompactMiniFrameSetup`, `CompactRaidFrameReservation_GetFrame`, the `CompactUnitFrame_*` update functions, `UnitFrame_SetUnit/Update`, `UnitFrameHealthBar_*`.

## Events

| Event | Status |
|---|---|
| `LEARNED_SPELL_IN_TAB` | Removed. `SPELLS_CHANGED` covers spell-learning for cache-invalidation purposes (note: it carries no args — if the addon needed the learned spell's identity, it must rescan the spellbook); upstream libraries guard with `C_EventUtils.IsEventValid("LEARNED_SPELL_IN_TAB")` |
| `CHARACTER_POINTS_CHANGED`, `SPELLS_CHANGED`, `CVAR_UPDATE`, `UNIT_INVENTORY_CHANGED`, `UNIT_AURA`, `GET_ITEM_INFO_RECEIVED` | Still valid (audited against the API docs dump) |
| `WEAPON_ENCHANT_CHANGED` | Documented in the Era dump but firing behavior unverified; the Classic-correct set is `UNIT_INVENTORY_CHANGED:player` + `PLAYER_EQUIPMENT_CHANGED` |

## Options, templates, fonts

| Broken | Fix |
|---|---|
| `SettingsCheckBoxTemplate` (XML inherits) | Renamed `SettingsCheckboxTemplate` (lowercase b) *(rename predates 1.15.8 — already lowercase in 1.15.7)* |
| `InterfaceOptionsCheckButtonTemplate`, `OptionsSmallCheckButtonTemplate`, `OptionsFrameTabButtonTemplate` | Still exist via `Blizzard_FrameXML/DeprecatedTemplates.xml` |
| `text:SetFont("GameFontNormal", size, flags)` | Old clients tolerated the FontObject NAME; now errors "Invalid font asset". Use `GameFontNormal:GetFont()` for the real file path |

## Frame-shape changes

- `MiniMapTracking` is created **parentless** on Era (MinimapTracking_Simple.xml top-level frame, `GetParent() == nil`) — code doing `frame:GetParent():GetCenter()` crashes. Fix: parent it (e.g. to `Minimap`) before geometry, or guard.
- `PetFrame` declares built-in heal-prediction elements under **global names** old addons also use (`PetFrameMyHealPredictionBar` etc.), but as StatusBarOverlaySegment *Frames*, not Textures — name-collision adoption code must type-check (`IsObjectType("Texture")`) and parent-check before reusing a global.
- Health bars' XML `OnSizeChanged` now drives native prediction segments — addons must `HookScript`, never `SetScript`, on Blizzard frame handlers.

## Deprecation shims (the UnitAura trap)

`UnitAura`/`UnitBuff`/`UnitDebuff` exist on 1.15.8+ only as `Blizzard_Deprecated/Deprecated_1_15_8.lua` shims, gated on the `loadDeprecationFallbacks` cvar (per warcraft.wiki.gg: default on in release builds, can default off on PTR, and the functions "will be removed in a future patch"). When repairing, treat them as already gone: port to `C_UnitAuras.GetBuffDataByIndex/GetDebuffDataByIndex/GetAuraDataBySpellName` (+ `AuraUtil.UnpackAuraData` for tuple form). Addons that captured the globals at file-load time break the moment the cvar is off — flag those to their authors.
