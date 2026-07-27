# Classic Era specifics

What differs on the Era flavor (client 1.15.x). Verified against WeakAuras 5.21.8 source and the classic_era client dump, July 2026.

## Contents
- Flavor packaging and detection
- Load tab: targeting Era vs SoD vs Hardcore
- The 2026 realm landscape
- Trigger types removed / exclusive on Era
- Aura scanning: the UnitBuff problem
- CLEU on Era
- Spell ranks
- Mechanics with no API (and their workarounds)
- Load-tab differences vs retail

## Flavor packaging and detection

WA ships one codebase, packaged per flavor via `## X-Flavor:` (Vanilla=1 … Mainline=10); Classic Era loads `WeakAuras_Vanilla.toc`. Imports carry `tocversion` in their data — wago.io files them into the classic bucket automatically; there is no manual game-version picker on either side.

In code: `WeakAuras.IsClassicEra()` (alias `IsClassic`), `IsTBC()`, `IsWrathClassic()`, `IsCataClassic()`, `IsMists()`, `IsRetail()`, plus combined helpers (`IsClassicOrWrath()`, …) and `WeakAuras.BuildInfo`.

## Load tab: targeting Era vs SoD vs Hardcore

There is NO "game version" load selector — flavor targeting happens by which client the aura is imported into. Within the Era client, two era-only tristates exist (Prototypes.lua load_prototype):

| Load option | Field | Computed via |
|---|---|---|
| Hardcore | `hardcore` | `C_GameRules.IsHardcoreActive()` |
| Season of Discovery | `engraving` | `C_Engraving.IsEngravingEnabled()` |

- Plain-Era-only: set BOTH tristates to the crossed-out (false) state.
- SoD-only: tick Season of Discovery.
- In custom code:

```lua
local isEra      = WeakAuras.IsClassicEra()          -- any 1.15.x client (Era, HC, SoD)
local isHardcore = isEra and C_GameRules.IsHardcoreActive()
local isSoD      = isEra and C_Engraving.IsEngravingEnabled()
local plainEra   = isEra and not isHardcore and not isSoD
-- SoD season check WA uses elsewhere:
local isSoDSeason = C_Seasons and C_Seasons.GetActiveSeason and C_Seasons.GetActiveSeason() == 2
```

## The 2026 realm landscape

- 20th-Anniversary progression realms moved to the **TBC client** (2.5.5) in Jan 2026 → they are the TBC WA flavor now, not Era.
- Anniversary **Hardcore** realms did not progress — still Era flavor.
- Era flavor therefore covers: legacy Era realms, all Hardcore realms, SoD realms. Distinguish Anniversary-HC from legacy realms only by `GetRealmName()` (no load option).

## Trigger types removed / exclusive on Era

Removed on Era: Alternate Power, Currency, Death Knight Rune, Spell Activation Overlay (+ all-classic removals: Class/Spec, Equipment Set, Evoker Essence, Loot Specialization, PvP Talent).
Present on Era: **Swing Timer** (removed only on Cata/Mists), **Totem**, **Weapon Enchant**, **Threat Situation**.
Classic-exclusive: **Queued Action** (on-next-swing abilities like Heroic Strike, via IsCurrentSpell) — removed on retail.

## Aura scanning: the UnitBuff problem

On 1.15.8+ the globals `UnitAura`/`UnitBuff`/`UnitDebuff` are deprecation shims (Blizzard_Deprecated, gated on the `loadDeprecationFallbacks` cvar — default on in release builds, "will be removed in a future patch"). Author custom code as if they're already gone:

```lua
-- Preferred inside WA custom code (rank-agnostic by name; survives shim removal):
local name, icon, count, _, dur, expirationTime = WA_GetUnitBuff("player", "Arcane Intellect")

-- Or C_UnitAuras directly (full modern API exists on Era):
for i = 1, 40 do
    local aura = C_UnitAuras.GetBuffDataByIndex("player", i, "HELPFUL")
    if not aura then break end
    if aura.name == "Arcane Intellect" then
        -- aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId
        break
    end
end
-- Also: C_UnitAuras.GetAuraDataBySpellName(unit, name, filter), GetDebuffDataByIndex(unit, i, "HARMFUL")
```

Note: WA's own built-in Aura trigger still runs the legacy scan path on Era (`newAPI = WeakAuras.IsRetail()` in BuffTrigger2.lua) — that's WA's problem, not yours; built-in Aura triggers keep working.

## CLEU on Era

- spellIds are REAL since 1.15.0 (they were 0 in 1.13-era classic) — and rank-specific.
- Subevent filters are mandatory (see custom-triggers-and-tsu.md).
- Era-relevant payload quirk: for off-hand detection, SWING_DAMAGE carries isOffHand at `select(10, ...)` of the suffix but SWING_MISSED at `select(2, ...)` — payload layouts differ per subevent.
- No absorb API on Era (`UNIT_ABSORB_AMOUNT_CHANGED`/`GetTotalAbsorbs` don't exist) — absorb trackers reconstruct values from `CLEU:SPELL_ABSORBED` accounting (see examples.md).

## GCD tracking

Track the global cooldown via spellID **29515** on Era/BCC — retail's 61304 does not work here ([Useful-Snippets wiki](https://github.com/WeakAuras/WeakAuras2/wiki/Useful-Snippets#gcd-lookup)). For cooldown watching from custom code, the real signature is `WeakAuras.WatchSpellCooldown(id, ignoreRunes, useExact, followoverride)` — the wiki shows only `(id)`.

## Spell ranks

Every rank has its own spellId. Built-in spell triggers resolve names via `GetSpellInfo(spellName)` → the player's currently-known (highest) rank, so name-based triggers follow rank-ups automatically; "Exact Spell ID" toggles rank-exact matching. In custom CLEU code: match `spellName` for rank-agnostic behavior or enumerate every rank ID.

## Mechanics with no API (and their workarounds)

| Mechanic | API? | Workaround (details in examples.md) |
|---|---|---|
| Melee swing timer | None from Blizzard | Use WA's built-in Swing Timer trigger (CLEU-driven; handles extra attacks, parry-haste, era on-next-hit resets like Slam/Heroic Strike); custom access via `WeakAuras.GetSwingTimerInfo()` |
| Auto Shot timing | None | `START_AUTOREPEAT_SPELL`/`STOP_AUTOREPEAT_SPELL` + `UNIT_SPELLCAST_SUCCEEDED` state machine |
| Energy ticks | None | Predict the fixed 2s/20-energy server heartbeat from observed `UNIT_POWER_UPDATE`/`UNIT_POWER_FREQUENT` gains |
| Mana ticks / five-second rule | None | Track mana spend (cast events) to start the 5s window, then 2s tick cadence |
| Absorb amounts | None | CLEU `SPELL_ABSORBED` accounting against known shield capacity |
| Weapon temp enchants | `GetWeaponEnchantInfo()` (12 returns, times in **milliseconds**) | Built-in Weapon Enchant trigger is event-driven: `UNIT_INVENTORY_CHANGED:player` + `PLAYER_EQUIPMENT_CHANGED`, re-read after a 0.1s debounce, raising `TENCH_UPDATE`. No name API (WA scrapes tooltips). `WEAPON_ENCHANT_CHANGED` exists in the Era client's API docs, but WA registers it only on retail — don't rely on it firing on Era (unverified) |
| Totems | `GetTotemInfo(slot)` 1-4 | Built-in Totem trigger; don't use the 7th return (spellID) — retail-only; liveness test is `startTime ~= 0` |
| Enemy cooldowns (PvP) | None | CLEU `SPELL_CAST_SUCCESS` inference per enemy GUID with clones |

## Load-tab differences vs retail

No Class-and-Spec (era has plain Player Class); Talent load is a flat-index multiselect over the classic trees (`GetTalentInfo(tab, index)`, re-checked on CHARACTER_POINTS_CHANGED) with only Selected/Not-Selected options; War Mode / Pet Battle / Skyriding / Vehicle-UI hidden; "In Vehicle" is relabeled "On Taxi".

## 1.15.8+ client refactor trap

The same client modernization that broke many addons also breaks aura code that touches legacy UI globals (`GetAddOnMetadata` → `C_AddOns.*`, removed events like `LEARNED_SPELL_IN_TAB`, mixin-ified unit frames). Verify symbols against the classic_era client dump (github.com/Gethe/wow-ui-source, branch `classic_era`) and events via `C_EventUtils.IsEventValid`. General Era API rules: see the `wow-classic-addon-development` skill.
