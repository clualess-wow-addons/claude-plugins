# Ace3 framework patterns

Ace3 is the dominant Classic Era (1.15.x) addon framework — fully compatible. Mined from `Questie`, `Bartender4`, `GatherMate2`, `Prat-3.0`, `BigWigs_Core`, and the embedded libs.

## 1. Bootstrap with AceAddon-3.0

`NewAddon` mixes the named libraries directly into the addon object (so `self:RegisterEvent`, `self.db`, `self:Print` become available):

```lua
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
-- or thread a private table in: local _, MyAddon = ...; LibStub(...):NewAddon(MyAddon, "MyAddon", ...)
```

Lifecycle callbacks:
- `:OnInitialize()` — after the addon's SavedVariables load (≈`ADDON_LOADED`). Set up `self.db`, slash commands, options.
- `:OnEnable()` — at `PLAYER_LOGIN`. Register events, create frames, read game data.
- `:OnDisable()` — when manually disabled. Unhook, unregister, hide frames.

## 2. AceDB-3.0 — SavedVariables with profiles

```lua
local defaults = {
    profile = { scale = 1.0, show = { ["*"] = "always" } },  -- ["*"] = per-key default via metatable
    char    = {},
    global  = {},
}
function MyAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)  -- 3rd arg true = use a default profile
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied",  "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset",   "RefreshConfig")
end
```

Namespaces (each a key in `defaults` and on `self.db`): `profile` (user-switchable), `char`, `realm`, `class`, `race`, `faction`, `factionrealm`, `locale`, `global` (account-wide). Access: `self.db.profile.scale`, `self.db.global.foo`, `self.db.char.bar`. The `["*"]` wildcard supplies a default for *any* key via metatable (nest them: `["*"] = { ["*"] = true }`). The `## SavedVariables:` name in the `.toc` must match the `:New()` name.

## 3. AceEvent-3.0 — events + message bus

```lua
self:RegisterEvent("PLAYER_LOGIN", "OnLogin")    -- calls self:OnLogin(event, ...)
self:RegisterEvent("PLAYER_LOGIN")               -- defaults to method named after the event
self:UnregisterEvent("PLAYER_LOGIN")
self:UnregisterAllEvents()                       -- in OnDisable

-- internal message bus between your modules (decouples them):
self:RegisterMessage("MyAddon_DataReady", "OnDataReady")
self:SendMessage("MyAddon_DataReady", payload)
```

## 4. AceConfig-3.0 — options table + Blizzard panel

```lua
local options = {
    type = "group", name = "MyAddon",
    args = {
        lock = {
            order = 1, type = "toggle", name = L["Lock"], desc = L["Lock the frame."],
            get = function(info) return MyAddon.db.profile.locked end,
            set = function(info, v) MyAddon.db.profile.locked = v; MyAddon:Update() end,
        },
        bars = { order = 2, type = "group", name = "Bars", args = { --[[ nested ]] } },
    },
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("MyAddon", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyAddon", "MyAddon")   -- into Interface > AddOns
-- standalone window: AceConfigDialog:Open("MyAddon")
```

Option `type`s: `group`, `toggle`, `input`, `execute` (button), `select` (dropdown), `range` (slider), `color`, `header`, `description`. A generic getter/setter keyed by `info[#info]` (the option's key) or `info.arg` avoids per-option closures:

```lua
local function get(info) return MyAddon.db.profile[info.arg or info[#info]] end
local function set(info, v) MyAddon.db.profile[info.arg or info[#info]] = v end
```

Tie it to a slash command via AceConsole (`AceConfigDialog:Open` from your handler).

## 5. LibStub & embedding

LibStub is the tiny versioned-library loader every Ace lib registers through:

```lua
local lib, oldminor = LibStub:NewLibrary("MyLib-1.0", 5)   -- nil if a newer copy already loaded
if not lib then return end
local got = LibStub("MyLib-1.0")        -- retrieve (errors if absent)
local got = LibStub("MyLib-1.0", true)  -- silent, nil if absent
```

Embed the libs via an `embeds.xml` (load order matters — `LibStub` then `CallbackHandler-1.0` then the Ace libs):

```xml
<Script file="Libs\LibStub\LibStub.lua"/>
<Include file="Libs\CallbackHandler-1.0\CallbackHandler-1.0.xml"/>
<Include file="Libs\AceAddon-3.0\AceAddon-3.0.xml"/>
<Include file="Libs\AceDB-3.0\AceDB-3.0.xml"/>
```

In the `.toc`, list `embeds.xml` before your own files, declare `## OptionalDeps: Ace3` (so a standalone Ace3 loads first if the user has it), and wrap embedded-lib lines in packager markers so release builds can strip them when Ace3 is an external dep:

```
#@no-lib-strip@
embeds.xml
#@end-no-lib-strip@
```

## 6. Modules — `:NewModule` / `:GetModule`

```lua
local Mod = MyAddon:NewModule("Display", "AceEvent-3.0")   -- gets its own OnInitialize/OnEnable/OnDisable
function Mod:OnEnable() self:RegisterEvent("PLAYER_TARGET_CHANGED") end

local m = MyAddon:GetModule("Display", true)   -- silent
MyAddon:EnableModule("Display"); MyAddon:DisableModule("Display")
for name, module in MyAddon:IterateModules() do ... end
```

Each module's enabled state can be persisted (e.g. `module.db.profile.on`) and applied in the parent's enable pass.

**Not every big addon uses `:NewModule`.** Some large addons build a *custom* module registry instead — e.g. Questie's `QuestieLoader:CreateModule`/`ImportModule` (bare `{ private = {} }` tables, only the root addon has Ace lifecycle methods), and TSM's `LibTSM` components. If you're reading such an addon, don't expect per-module `OnInitialize`/`OnEnable`; trace its loader instead.

## 7. CallbackHandler-1.0

The dispatch engine under AceEvent/AceDB. It builds the `Register*/Unregister*/Fire` method trio on a target and dispatches each fire through `securecallfunction` so one buggy handler can't break the others. You rarely call it directly — it's what makes `:RegisterEvent`/`:SendMessage` and the AceDB `OnProfileChanged` callbacks work.

## Classic compatibility notes

All of the above works in Classic Era. Absent in Era: `LibDualSpec-1.0` (no dual spec — use manual profiles), `EditModeManagerFrame`. AceConfig/AceGUI dialogs and the message bus work as documented.
