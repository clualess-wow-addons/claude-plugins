# Classic data API cookbook

"Which API do I call for X in **Classic Era 1.15.x**." Era **backported** some modern namespaces (`C_Container`, `C_Spell`, `C_QuestLog`, `C_Timer`, `C_Map`, `C_NamePlate`) while keeping the legacy globals, but did **NOT** backport the newer unit-aura, spellbook, auction-house, or talent systems. When unsure in Era, the **legacy global is the safe call**.

## API quick map (what to use in Era)

| Need | Use in Era | Don't reach for in Era |
|---|---|---|
| Bag slot info | `C_Container.GetContainerItemInfo` (returns a table) | — |
| Auras | **index** `UnitAura(unit, i, filter)`; `AuraUtil.FindAuraByName` for by-name | `C_UnitAuras` (retail aura system) |
| Spell info / cd | `GetSpellInfo` **and** `C_Spell.*` (both work) | — |
| Spellbook iteration | `GetSpellBookItemName/Info(i, "spell")` | `C_SpellBook` iterators (namespace exists but has only spell-known checks + `HasPetSpells` — no iterators) |
| Auction house | **legacy** `QueryAuctionItems` etc. | `C_AuctionHouse` (retail AH; doesn't drive the Era AH) |
| Talents | `GetTalentInfo(tab, idx)` 3-tab tree | `C_ClassTalents` |
| `focus`, `boss1-5`, `arena1-5` units | **not available** | — |

## Units

**Unit tokens available in Era:** `player`, `pet`, `target`, `targettarget`, `pettarget`, `party1-4`, `partypet1-4`, `raid1-40`, `raidpet1-40`, `mouseover` all exist. `nameplate1-N` exist but are **read-only** (not secure-targetable). **`focus` (TBC 2.0.1), `boss1-5` (WotLK 3.3), `arena1-5` are NOT in Era.** Suffix any token with `target` (e.g. `raid12target`).

```lua
UnitHealth(unit); UnitHealthMax(unit)      -- enemy PLAYERS scaled to 100 since 1.13.3; NPCs absolute
UnitPower(unit, powerType); UnitPowerMax(unit, powerType)   -- powerType nil = active; Enum.PowerType.Mana=0...
UnitPowerType(unit)                        -- -> num, token("MANA"/"RAGE"/"ENERGY"/"FOCUS")
UnitName(unit)                             -- -> name, realm (realm nil if same)
UnitClass(unit)                            -- -> localized, classFile("MAGE", locale-independent), classID
UnitLevel(unit); UnitGUID(unit); UnitExists(unit); UnitIsPlayer(unit)
UnitIsEnemy(u1,u2); UnitReaction(u1,u2)    -- reaction <=4 hostile/neutral, >=5 friendly
UnitAffectingCombat(unit); UnitIsDeadOrGhost(unit)
```

Key events: `UNIT_HEALTH` (now fires frequently; `UNIT_HEALTH_FREQUENT` was merged in), `UNIT_MAXHEALTH`, `UNIT_POWER_UPDATE`, `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED/REMOVED`, `PLAYER_REGEN_DISABLED/ENABLED`. Most `UNIT_*` events carry the unit token as `arg1` — filter on it (or use `RegisterUnitEvent`).

## Auras (buffs / debuffs) — index-based

Era uses the old positional `UnitAura`, not `C_UnitAuras`. Iterate the index until nil:

```lua
name, icon, count, dispelType, duration, expirationTime, source, isStealable,
  _, spellId = UnitAura(unit, index [, filter])   -- 16 returns total
-- filter: "HELPFUL" | "HARMFUL" | "PLAYER" (only yours) | "RAID" | "CANCELABLE"  (space/|-combinable)
-- UnitBuff(u,i,f) == UnitAura(u,i,"HELPFUL"); UnitDebuff == "HARMFUL"
for i = 1, 40 do
    local n, _, _, _, dur, exp, src, _, _, spell = UnitAura("target", i, "HARMFUL")
    if not n then break end
end
```

**THE Classic limitation:** for auras **not cast by you**, the server doesn't send timing — `duration`/`expirationTime` come back **0**, and enemy *buffs* are hidden entirely. Fix with **LibClassicDurations** (reconstructs from combat log):

```lua
local LCD = LibStub("LibClassicDurations"); LCD:Register("MyAddon")
local UnitAura = LCD.UnitAuraWrapper        -- drop-in; now returns real enemy-debuff durations
```

## Items & inventory

Item link: `|cQUALITY|Hitem:ID:ench:...|h[Name]|h|r`. Pull the id: `tonumber(link:match("item:(%d+)"))`. Quality colors: `9d9d9d/ffffff/1eff00/0070dd/a335ee/ff8000` (poor→legendary).

```lua
-- GetItemInfo: 17 returns, ASYNC (nil until cached → GET_ITEM_INFO_RECEIVED). Global works in Era.
name, link, quality, iLevel, minLevel, type, subType, stack, equipLoc, texture, sellPrice,
  classID, subClassID, bindType = GetItemInfo(idOrLinkOrName)

-- Bags — C_Container (canonical in Era; returns a TABLE)
C_Container.GetContainerNumSlots(bag)           -- bag 0=backpack,1-4 bags,-1 bank,5-11 bank bags
local info = C_Container.GetContainerItemInfo(bag, slot)   -- nil if empty, else:
--   info.itemID, info.stackCount, info.hyperlink, info.quality, info.iconFileID, info.isLocked
C_Container.GetContainerItemLink(bag, slot); C_Container.UseContainerItem(bag, slot)

GetInventoryItemLink("player", slot)            -- slot = INVSLOT_* number
GetItemCount(item [, includeBank])              -- total owned
```

`INVSLOT_*`: HEAD=1 NECK=2 SHOULDER=3 CHEST=5 WAIST=6 LEGS=7 FEET=8 WRIST=9 HAND=10 FINGER1=11 FINGER2=12 TRINKET1=13 TRINKET2=14 BACK=15 **MAINHAND=16 OFFHAND=17 RANGED=18** TABARD=19. Or `GetInventorySlotInfo("MainHandSlot")`.

## Spells & cooldowns

Era has **both** legacy globals and the backported `C_Spell` — pick one; legacy is simplest.

```lua
name, rank, icon, castTime, minRange, maxRange, spellID = GetSpellInfo(idOrName)  -- legacy
start, duration, enabled, modRate = GetSpellCooldown(spell)
IsUsableSpell(spell)        -- -> usable, noMana
IsSpellKnown(spellID); IsPlayerSpell(spellID)
local si = C_Spell.GetSpellInfo(spellID)        -- backported table form; also valid in Era
```

**Cooldown gotcha:** `start=0,duration=0` = ready; the GCD also reports as a short cooldown — filter `duration > 1.5`:

```lua
local function CDRemaining(spellID)
    local start, dur, en = GetSpellCooldown(spellID)
    if en == 1 and dur > 1.5 and start > 0 then return (start + dur) - GetTime() end
    return 0
end
```

Refresh on `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USABLE`. Spellbook uses legacy `GetSpellBookItemName/Info(index, "spell")` (`C_SpellBook` exists in Era but has **no item-iteration functions** — only `IsSpellKnown`, `IsSpellInSpellBook`, `IsSpellKnownOrInSpellBook`, `HasPetSpells`); spellbook `index` ≠ spellID.

## Quests

Era keeps the legacy log walk and adds some `C_QuestLog.*`:

```lua
for i = 1, GetNumQuestLogEntries() do
    local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
    if not isHeader then
        SelectQuestLogEntry(i)
        for o = 1, GetNumQuestLeaderBoards(i) do
            local text, objType, finished = GetQuestLogLeaderBoard(o, i)   -- "Boars slain: 3/8"
        end
    end
end
-- isComplete: 1 complete, -1 failed, nil in progress
C_QuestLog.IsQuestFlaggedCompleted(questID)     -- the big one: ever finished? (works in Era)
```

Events: `QUEST_LOG_UPDATE` (broad — debounce), `UNIT_QUEST_LOG_CHANGED`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_REMOVED`.

## Group / raid

```lua
IsInGroup(); IsInRaid(); IsInInstance()         -- IsInInstance -> bool, "none"/"party"/"raid"/"pvp"
GetNumGroupMembers(); GetNumSubgroupMembers()   -- subgroup = party1..N count (excl. you)
```

Canonical roster iteration (re-read on **`GROUP_ROSTER_UPDATE`** — the single composition-change event; never cache that `raid1` = a person):

```lua
local function ForEachGroupMember(fn)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do fn("raid"..i) end
    elseif IsInGroup() then
        fn("player"); for i = 1, GetNumSubgroupMembers() do fn("party"..i) end
    else fn("player") end
end
local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(raidIndex)
-- rank: 2 leader, 1 assist, 0 member; fileName = locale-independent class
```

## Money, vendor, mail, bank

```lua
GetMoney()                          -- copper (1g=10000, 1s=100); event PLAYER_MONEY
GetCoinTextureString(copper)        -- "12g 30s 05c" with icons (display)
-- Vendor (MERCHANT_SHOW): GetMerchantNumItems(); GetMerchantItemInfo(i); BuyMerchantItem(i, qty)
-- Mail (MAIL_SHOW): GetInboxNumItems(); GetInboxHeaderInfo(i); TakeInboxItem(i, attach); TakeInboxMoney(i)
-- Bank (BANKFRAME_OPENED): bank containers are -1 (main) and 5-11 for C_Container.*
```

(Vanilla has no currency/token system — `C_CurrencyInfo` is largely irrelevant; gold is the only currency.)

## The legacy Auction House — Classic-only

The big one. The retail `C_AuctionHouse` API doesn't drive the Era auction house — use the original 1.x API. Browse is asynchronous via `AUCTION_ITEM_LIST_UPDATE`:

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()   -- ALWAYS gate; queries are throttled (~0.3s; getAll ~15min)
if canQuery then
    QueryAuctionItems(name, minLvl, maxLvl, page, usable, rarity, getAll, exactMatch)  -- page is 0-BASED
end

local f = CreateFrame("Frame"); f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function()
    local shown, total = GetNumAuctionItems("list")   -- type: "list"/"bidder"/"owner"
    for i = 1, shown do
        local name, tex, count, quality, canUse, lvl, _, minBid, minInc, buyout, bidAmt,
              highBidder, _, owner, _, _, itemId = GetAuctionItemInfo("list", i)   -- prices in copper
        local link = GetAuctionItemLink("list", i)
    end
end)
```

Acting requires a **hardware event** (real user click, since 4.0 — cannot auto-fire): `PlaceAuctionBid("list", index, bidAmount)` (pass buyout to buy); posting = `ClickAuctionSellItemButton()` then `StartAuction(minBid, buyout, runTime, stackSize, numStacks)` (`runTime` 1/2/3 = 12/24/48h). Events: `AUCTION_HOUSE_SHOW/CLOSED`, `AUCTION_ITEM_LIST_UPDATE`, `AUCTION_OWNED_LIST_UPDATE`, `AUCTION_BIDDER_LIST_UPDATE`.

## Talents (Classic tree)

Era uses the old 3-tab point-spend tree (the retail `C_ClassTalents` system isn't here):

```lua
-- NB: GetTalentTabInfo was REMOVED in 1.15.8 — sum points per tab from GetTalentInfo instead.
local function TabPoints(tab)
    local spent = 0
    for i = 1, GetNumTalents(tab) do
        local _, _, _, _, rank = GetTalentInfo(tab, i)   -- name, icon, tier, column, RANK, maxRank, ...
        spent = spent + (rank or 0)
    end
    return spent
end
-- "spec" = the tab (1..GetNumTalentTabs(), 3 in Vanilla) with the most points spent
local bestTab, best = 1, -1
for tab = 1, GetNumTalentTabs() do
    local p = TabPoints(tab)
    if p > best then best, bestTab = p, tab end
end
-- refresh on CHARACTER_POINTS_CHANGED / PLAYER_TALENT_UPDATE
```

## Maps & coordinates

Raw `C_Map` works in Era (1.13.2+) but gives only **zone-local 0–1 coords** for one `uiMapID`, returns **nil inside instances**, and does no cross-zone math:

```lua
local uiMapID = C_Map.GetBestMapForUnit("player")          -- most specific map; nil in some instances
local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")  -- Vector2DMixin or nil (outdoors, player only)
if pos then local x, y = pos:GetXY() end                   -- 0..1 (NOT *100)
```

**HereBeDragons-2.0** adds **world coordinates** (continent-absolute, yard-scaled, keyed by `instanceID`) and the continent-stitching raw `C_Map` won't do — use it for distance/direction:

```lua
local HBD = LibStub("HereBeDragons-2.0")
local px, py, pInstance = HBD:GetPlayerWorldPosition()
local angle, distance = HBD:GetWorldVector(pInstance, px, py, destX, destY)  -- radians (0=N, CW), yards
arrow:SetRotation(angle - (GetPlayerFacing() or 0))        -- screen-relative arrow
-- also: GetPlayerZonePosition, GetWorldCoordinatesFromZone(x,y,uiMapID), GetWorldDistance(...)
```

**HBD-Pins-2.0** draws icons (ordinary frames it repositions) on map & minimap; `ref` is any token you own for batch-removal:

```lua
local pins = LibStub("HereBeDragons-Pins-2.0")
pins:AddMinimapIconMap(ref, icon, uiMapID, x, y, true, true)  -- (...,showInParentZone, floatOnEdge)
pins:AddWorldMapIconMap(ref, icon, uiMapID, x, y)
pins:RemoveAllMinimapIcons(ref); pins:RemoveAllWorldMapIcons(ref)
```

## Nameplates

Each visible plate gets a transient token `nameplate1..N` (recycled — key off GUID, never cache the token).

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED"); f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:SetScript("OnEvent", function(_, event, unit)            -- unit = "nameplateN"
    local plate = C_NamePlate.GetNamePlateForUnit(unit)    -- anchor frame, or nil
    if event == "NAME_PLATE_UNIT_ADDED" and plate then
        local uf = plate.UnitFrame                          -- Blizzard's default frame
        if uf and uf.healthBar then uf.healthBar:SetStatusBarColor(0, 0.8, 1) end
    end
end)
```

- `C_NamePlate.GetNamePlateForUnit(unit)`, `.GetNamePlates()`.
- **`C_NamePlate.SetNamePlateEnemySize(w, h)`** is available in Era (added 1.13.2) — you CAN size enemy plates in 1.15.x; call out of combat (plate sizing is combat-protected). Also `SetNamePlateFriendlySize`, `SetNamePlateSelfSize`.
- **Era lets you reskin/hide `plate.UnitFrame` freely** — the default nameplate `UnitFrame` isn't combat-protected here. Attach decorations to `plate`; don't reparent the secure anchor.
- CVars (mostly out of combat): `nameplateShowEnemies`, `nameplateShowFriends`, `nameplateMaxDistance` (Era default ~20), `nameplateMotion`.
