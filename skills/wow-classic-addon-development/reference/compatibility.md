# Addon compatibility & interoperability

Your addon never runs alone — the player has dozens loaded, on one of several 1.15.x rulesets. Most "works on my machine" bugs are conflicts or wrong-ruleset assumptions, not logic errors. **Test with your real addon list enabled, not a clean profile** — load-order and shared-frame conflicts only surface in a full environment.

## Coexisting with other addons

- **Prefix every global you create** — `MyAddonDB`, `SLASH_MYADDON1`, and frame names (`"MyAddonFrame"`, never `"Button1"`). Unprefixed names collide; a *leaked* global (missing `local`) collides silently **and** taints — luacheck catches it.
- **Chain, don't clobber, anything you don't own.** `hooksecurefunc`/`HookScript` append to Blizzard's or another addon's handler; `SetScript`/plain assignment **replace** it — dropping their behavior and often tainting. Only `SetScript` your *own* frames. (See [secure-and-taint.md](secure-and-taint.md), [minimal-addons.md](minimal-addons.md).)
- **Don't assume load order.** Anything you need from another addon may not be loaded when your file runs — gate on `ADDON_LOADED`/`PLAYER_LOGIN`, or declare `## OptionalDeps:` to load after it.

## LibStub version skew

Embedded libraries are shared process-wide: across **all** addons, only the highest `MAJOR.MINOR` of each library actually loads. So:
- **Embed a current copy** and bump its `MINOR` when you update it — an addon shipping a newer copy of a lib you also embed will win, and your code then runs against *its* version.
- **Never edit a library's API in place.** Another addon may load your modified copy and break. Fork under a new MAJOR if you must diverge.
- Guard optional libs: `local LSM = LibStub("LibSharedMedia-3.0", true)` — the `true` returns `nil` instead of erroring when the lib is absent.

## Detecting / talking to another addon

```lua
if C_AddOns.IsAddOnLoaded("Questie") then ... end            -- loaded this session?
local ver = C_AddOns.GetAddOnMetadata("Questie", "Version")  -- from its .toc, even if not loaded
```

For live interop (share data, avoid double work), agree an **addon-comms** prefix and exchange a version in the handshake (see [best-practices.md](best-practices.md)). Prefer feature-detecting a shared library/global over trusting an addon name.

## Know your ruleset — Era vs Hardcore vs Season of Discovery

All three run the **same 1.15.x client** (interface `11507`/`11508`), so an addon tagged "Classic Era" may load on any of them. They differ in ways that break assumptions:

- **Season of Discovery (SoD):** adds the **rune-engraving** system, and some abilities carry **new/altered spell IDs**. The `C_Engraving` namespace ships on **every** 1.15 realm (same client), so detect SoD by whether the system is *active*: `if C_Engraving and C_Engraving.IsEngravingEnabled() then ... end`.
- **Hardcore (HC):** death is permanent (no resurrection); the official Hardcore addon and stricter anti-automation norms apply — anything resembling play-for-the-user is especially unwelcome here.
- **Era (vanilla ruleset):** the baseline this skill assumes.

**Don't branch on a guessed flavor — feature-detect** (`C_Engraving.IsEngravingEnabled()`, a specific spell ID) instead. When you genuinely must branch, `C_Seasons.HasActiveSeason()` / `C_Seasons.GetActiveSeason()` identify a seasonal realm. `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` identifies the **vanilla 1.x client** (the progression Classics have their own constants, e.g. `WOW_PROJECT_WRATH_CLASSIC`) — but Era, HC, SoD, and Anniversary realms all share it, so it can't tell rulesets apart.
