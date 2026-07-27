# SavedVariables & data layer

Cross-character data, big-table performance, and item caching for Classic Era (1.15.x). Mined from `DataStore`, `Altoholic`, `Auctionator`, `Baganator`, `WeakAuras`.

## 1. Cross-character DB schema

The standard key is hierarchical `Account.Realm.Character`, built at login:

```lua
local key = format("%s.%s.%s", "Default", GetRealmName(), UnitName("player"))
DB.Characters[key] = DB.Characters[key] or {}
```

Iterate/filter by decomposing the key: `local account, realm, name = strsplit(".", key)`. Connected-realm groups are stored separately so cross-realm guilds resolve. With AceDB, the `["*"]` wildcard supplies per-character defaults so any new key inherits a full default table.

## 2. DataStore-style publish/subscribe (sharing data between addons)

DataStore registers modules and exposes their methods through a metatable dispatcher, transparently converting a character *key* (string) into that character's *table*:

```lua
function addon:RegisterModule(name, module, publicMethods)
    registeredModules[name] = module
    for methodName, fn in pairs(publicMethods) do
        registeredMethods[methodName] = { func = fn, owner = module }
    end
end
setmetatable(addon, { __index = function(self, key)
    return function(self, arg1, ...)
        local m = registeredMethods[key]
        if m.isCharBased then arg1 = m.owner.Characters[arg1] end  -- string key -> table
        return m.func(arg1, ...)
    end
end})
```

Modules announce updates over the **AceComm/Ace message bus** (`addon:SendMessage("DATASTORE_..._RECEIVED", ...)`), which any subscriber picks up with `addon:RegisterMessage`. For guild sync: register a prefix with `C_ChatInfo.RegisterAddonMessagePrefix`, `addon:RegisterComm(prefix, handler)`, serialize with AceSerializer, and `addon:SendCommMessage(prefix, data, "GUILD")`.

## 3. Defaults, versioning, migration

Stamp a schema version and migrate step-by-step; clear deprecated fields early to prevent bloat:

```lua
local CURRENT = 8
DB.__dbversion = DB.__dbversion or CURRENT
if DB.__dbversion < 7 then ...; DB.__dbversion = 7 end
if DB.__dbversion < 8 then ...; DB.__dbversion = 8 end
DB.iconCache = nil   -- drop a field that's no longer used
```

Guard against *downgrades* (a newer DB opened by an older addon) — refuse to load/migrate and prompt the user to repair (rather than silently corrupting): `if DB.version > CURRENT then skip-load + prompt-repair end` (WeakAuras shows a `CONFIRM_REPAIR` popup advising a WTF backup). Do schema validation at `ADDON_LOADED`, lazy migration at `PLAYER_LOGIN`/`PLAYER_ALIVE`. Note real migration ladders are often *per-record* (e.g. WeakAuras steps each aura's own `internalVersion`), with the account-level `dbVersion` acting only as a coarse one-shot gate.

## 4. Performance with large tables

The real bottleneck is **serializing huge tables to disk at logout** (it stalls the UI) and deserializing at login. Techniques:

- **Keep only the hot slice live.** Auctionator keeps only the *current realm's* price DB deserialized; every other realm stays a serialized string until needed.
- **Defer the cold work off the login stall** with `C_Timer.After(0, ...)`, processing one chunk per frame:

```lua
C_Timer.After(0, function()
    for key, data in pairs(BigDB) do
        if type(data) == "table" then
            BigDB[key] = Serialize(data)   -- one realm per frame
            break                          -- yield; next tick continues
        end
    end
end)
```

- **`wipe(t)` to reuse a table** instead of `t = {}` — avoids GC churn:

```lua
wipe(guild.Members)   -- reuse the existing table object
```

- **Split init** across `OnInitialize` (lightweight) → deferred `InitializeLate` (expensive deserialize, after the UI is responsive) → `PLAYER_LOGIN`.
- **For the largest DBs, a time-budgeted coroutine beats fixed chunks.** WeakAuras runs its whole load as a coroutine and yields when the frame's time budget is spent — `if debugprofilestop() + estimate > finish then coroutine.yield() end` (≈15 ms/frame budget), and `Hide()`s the worker on `PLAYER_REGEN_DISABLED` so migration never steals frame time in combat. It also offloads cold data to a **LoadOnDemand** companion addon (`C_AddOns.LoadAddOn("WeakAurasArchive")`, then `db.history = nil`) to shrink the main SavedVariables file.

## 5. Item caching in Classic

`GetItemInfo(itemLinkOrID)` returns **nil until the server has cached the item**. Never block waiting — check the return, set a flag, and finish on `GET_ITEM_INFO_RECEIVED`:

```lua
local pending = false
local function Scan()
    for i = 1, n do
        local link = GetInventoryItemLink("player", i)
        if link and not GetItemInfo(link) then pending = true; return end  -- bail, retry later
        -- ... use GetItemInfo(link) results
    end
end
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function() if pending then pending = false; Scan() end end)
```

Bag API: prefer the namespaced **`C_Container`** (`C_Container.GetContainerItemInfo`, `.GetContainerNumSlots`) — backported and available in Era. **Return-shape gotcha:** `C_Container.GetContainerItemInfo(bag, slot)` returns a **single table** (`{ iconFileID, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, isFiltered, hasNoValue, itemID, isBound }`), **not** the old multi-return tuple — `local info = C_Container.GetContainerItemInfo(b, s); local link = info and info.hyperlink`. The legacy global `GetContainerItemInfo` still works in Era, so it's a safe fallback if you need it.

## 6. Serialization / compression libraries

- **AceSerializer-3.0** — turns Lua tables into a transmittable/storable string; bundled with Ace3. `addon:Serialize(...)` / `addon:Deserialize(str)`.
- **LibSerialize** — modern table serializer; what current WeakAuras uses for export (`LibSerialize:SerializeEx(...)`), with AceSerializer kept only as a legacy-decode fallback. Pair with LibDeflate.
- **LibDeflate** — pure-Lua DEFLATE compress/decompress + print-safe/base64 encoding. Used to shrink data for SavedVariables or addon-channel transmission (e.g. WeakAuras import/export strings: `LibDeflate:CompressDeflate(LibSerialize:SerializeEx(t))` → `EncodeForPrint`). Available in Classic Era.
- **`C_EncodingUtil`** (`SerializeCBOR`/`DeserializeCBOR`) — native compact binary encoding, **added to Classic Era in patch 1.15.8**, so it IS present on the current Era client; it's only absent on pre-1.15.8 builds. **LibCBOR** is the bundled pure-Lua fallback. Feature-detect only if you must support older clients: `if C_EncodingUtil then ... else LibCBOR ... end`.

## 7. When is data safe to read?

| Event | Safe to read |
|---|---|
| `ADDON_LOADED` (your addon) | Your SavedVariables. Init defaults here. |
| `PLAYER_LOGIN` | Character name/level/class, most world data. One-time init + migration. |
| `PLAYER_ALIVE` | Full world interaction; initial stat/inventory scans. |
| `PLAYER_ENTERING_WORLD` | Fires every login/reload/zone — expensive recurring setup, not one-time init. |
| `GET_ITEM_INFO_RECEIVED` | A previously-uncached item is now available. |

Avoid `VARIABLES_LOADED` (tracks Blizzard CVars; since its 3.0.1 ordering change it can fire after `PLAYER_ENTERING_WORLD`, and it never tracked your addon's vars).
