# Field study: the top 10 wago.io WeakAuras per class (Classic bucket)

Data-driven study of ~90 auras — the top 10 by lifetime views for each of the nine classic classes — with every aura's **decoded table and custom code** fetched via `data.wago.io/lookup/wago/code?id=<slug>` (snapshot 2026-07-27/28). Rankings are lifetime views in wago's classic bucket (Era/SoD/HC share one bucket); same-author flavor siblings were deduped into one entry. Search relevance on wago is unreliable, so per-class candidate pools merged multiple query variants + category tags — a top aura with unusual naming could still be missed.

## Contents
- Cross-class findings
- The one-snippet-per-class table
- Cross-class snippets (FSR mana tick, powershift counter, GUID-scoped CC tracker)
- Per-class: top 10 + patterns (Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid)

## Cross-class findings

1. **Built-ins carry ~90-96% of all triggers, everywhere.** Across ~90 decoded auras, `aura2` (buff/debuff) + Cooldown Progress are the spine of every pack; custom triggers are 0-13% (Warlock bucket: 37 of 838 triggers; the 13% outlier is one hyper-engineered Warrior HUD). At least one top-10 aura *per class* ships **zero custom Lua** — including 100+-child SoD suites. The "built-in triggers first" principle isn't advice, it's what the field's most successful auras actually do.
2. **Each class has one or two API-gap mechanics, and ONE community snippet per gap circulates verbatim.** Byte-identical copies (md5-confirmed for the mana TSU, complete with its `duration = 6.45 -- why?` comment) travel between packs by different authors. Top packs are largely different curations of the same half-dozen snippets — see the table below.
3. **"Custom code block" counts are misleading.** The most common block is a 1-3-line `customTriggerLogic` combiner (`return (t[1] or t[2]) and not t[3]`) folding an Era spell and its SoD rune replacement into one icon — packs carry 20-40 of these and only 1-2 real custom triggers.
4. **The addon-in-a-WeakAura pattern:** big packs embed entire engines in a hidden child's On Init and rebroadcast via `WeakAuras.ScanEvents` — the vendored ~23KB LibClassicSwingTimerAPI (Paladin twist school), the ~20-24KB nanShield absorb framework (Mage), 554-line swing engines (Warrior), Luxthos' 28.5KB options hub. Consumers are lightweight custom-event triggers. **Namespace your synthetic events** — the field's copies rename `ENERGYTICK` → `OVERLAYTICK` / `WA_ENERGY_TICK` precisely to avoid cross-pack collisions, and the tightest variant passes `aura_env.id` as an arg and checks it on receipt.
5. **Configuration has two schools.** Options-hub (roughly one pack per class, usually Luxthos: 24-31 authorOptions on hidden "Options" children, published via a global registry + `LWA_*` ScanEvents bus, "settings survive updates"). Everyone else ships 0-3 authorOptions and configures via: children parked at Load=Never as an opt-in menu, drag-reorder dynamic groups, edit-me constants at the top of a customGrow, or "delete the group you don't want."
6. **Flavor gating in the field ignores the load flags.** Across ~90 auras: `use_hardcore` appears **zero** times (all "Hardcore" support is marketing copy), `use_engraving` in only 2 packs (Comfy Rogue, nullgodx Paladin — it works, it's just not the convention). The dominant idioms: gate SoD runes with **Spell Known** triggers/loads (rune spells simply aren't known on Era), or ship **separate sibling imports per flavor** (the Cludes pattern: one Era + one SoD import per class).
7. **Rarities worth knowing exist:** `aura_env.saved` persistence (2 of ~90: Pet Happiness's per-pet state, one Windfury damage tally), SecureActionButton click-auras (2: druid `/cancelform` rebuff, Easy Poisons), OPTIONS-event fake states so clone auras preview correctly in `/wa` config (Quazii's Homunculi tracker, rams' pack).
8. **Staleness is the norm and built-ins are why it's survivable.** The most-viewed pack in nearly every class froze in 2023-2024 (toc 11500-11504, pre-1.15.8 refactor) yet still accrues views, because built-in-trigger packs age gracefully. Only ~2 packs per class were maintained into 2025+. When adopting an old aura, audit exactly its custom blocks — the mana TSUs and CLEU handlers are where age bites.
9. **Views ≫ installs as popularity signal** in the classic bucket (Companion installs run 1-3 orders of magnitude below views); star-to-view ratio flags current momentum better than lifetime views.
10. **Lineage is open:** forks are credited, snippets pool, and the newest strong packs are aggregations of the best community pieces (a Paladin pack embeds another author's swing bar AND a third author's Reckoning counter, byte-for-byte).

## The one-snippet-per-class table

| Class | API-gap mechanic | Canonical community solution |
|---|---|---|
| Rogue / Druid (energy) | 2s energy tick | Self-rescheduling ENERGYTICK TSU (8/10 rogue, 5/10 druid packs) — examples.md §2 |
| Priest / Paladin / Shaman / Mage / Warlock (mana) | Five-second rule + 2s mana tick | The shared FSR mana-tick TSU (below); Riv's phase-lock variant uses `(ts - ts % 2)` remainder math |
| Druid | Powershifts remaining | `floor(mana / GetSpellPowerCost(768))` counter (7/10 packs; below) |
| Hunter | Auto Shot castbar/timing | Bouk's CLEU castbar lineage (4+ packs): `CLEU:SPELL_CAST_START:...` + vanilla pushback ladder {1,.8,.6,.4,.2}s + quiver-haste bag scan |
| Hunter | Pet happiness value | Full client-side simulation (loyalty-scaled decay + CLEU SPELL_PERIODIC_ENERGIZE feed detection), persisted in aura_env.saved |
| Paladin | Seal-twist window | Two schools: vendored LibClassicSwingTimerAPI rebroadcast via ScanEvents, or built-in Swing Timer + bar-geometry (SetWidth cuts a fixed 0.4s zone) |
| Warrior | HS/Cleave queue, Overpower window | Actionbar-scan (`IsCurrentAction`) or built-in Queued Action trigger; per-GUID dodge snapshots from `CLEU:SWING_MISSED:SPELL_MISSED` (7/10 packs) |
| Mage | Absorb values (no Era API) | Ice Barrier CLEU estimator (seed capacity on cast, decrement from ABSORB miss amounts) or the nanShield framework |
| Shaman | Totem pulse cadence | `C_Timer.NewTicker(pulse, → ScanEvents("X_REFIRE_EVENT"))` per totem |
| Warlock | Own-CC (Banish/Fear) by GUID | GUID-scoped CLEU status trigger with SPELL_AURA_BROKEN early-break detection (below) |

## Cross-class snippets

### The FSR mana-tick TSU — improved variant
The most-copied custom trigger in the classic ecosystem. This is Sabimaru's cleaned-up version (adds the `lastCast` guard so Meditation-style mid-FSR ticks don't reset the bar; the older byte-identical Cludes/Quazii/Sheepi copy hardcodes `duration = 6.45 -- why?`). TSU; Event(s): `UNIT_SPELLCAST_SUCCEEDED:player UNIT_POWER_FREQUENT:player`

```lua
function(a, e, t)
    local currentMana = UnitPower("player", 0)
    local fsrDuration = 5
    if currentMana >= UnitPowerMax("player", 0) then
        return false
    end
    if e == "UNIT_POWER_FREQUENT" and currentMana > aura_env.lastMana then
        if GetTime() >= aura_env.lastCast + fsrDuration then
            a[""] = { show = true, changed = true, duration = 2,
                expirationTime = GetTime() + 2, progressType = "timed", autoHide = true }
        end
        aura_env.lastMana = currentMana
    elseif e == "UNIT_SPELLCAST_SUCCEEDED" and currentMana < aura_env.lastMana then
        a[""] = { show = true, changed = true, duration = fsrDuration,
            expirationTime = GetTime() + fsrDuration, progressType = "timed", autoHide = true }
        aura_env.lastMana = currentMana
        aura_env.lastCast = GetTime()
    end
    return true
end
-- On Init: aura_env.lastMana = UnitPower("player", 0); aura_env.lastCast = 0
```
Source: [wago.io/XejlH_0_F](https://wago.io/XejlH_0_F) (Sabimaru Warlock); ancestor in [wago.io/Y7SYk2ATp](https://wago.io/Y7SYk2ATp) et al.

### The druid powershift counter
Seed of a class-wide meme (7 of 10 druid packs). Custom Event trigger; Event(s): `UNIT_SPELLCAST_SUCCEEDED:player UNIT_POWER_FREQUENT:player` (note: the original leaks globals; use `aura_env`):

```lua
-- Trigger:
function()
    aura_env.mana = UnitPower("player", 0)
    aura_env.cost = GetSpellPowerCost(768)[1].cost   -- 768 = Cat Form
    return true
end
-- Duration Info (static): function() return aura_env.mana, aura_env.cost, true end
-- Stack Info:            function() return math.floor(aura_env.mana / aura_env.cost) end
```
Source: [wago.io/tEf7cR1dG](https://wago.io/tEf7cR1dG) ([Classic] Feral Powershifts).

### GUID-scoped own-CC tracker with early-break detection
Cludes' Banish timer — the pattern for "my CC on that specific mob": scope by `sourceGUID == you`, remember `destGUID`, catch `SPELL_AURA_BROKEN` for early breaks. Custom Status trigger on CLEU:

```lua
function(_, _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spell)
    local e = aura_env
    if (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH")
       and spell == e.spell and sourceGUID == e.playerGUID then
        e.target = destGUID
        e.startTime = GetTime()
        e.expirationTime = e.startTime + e.duration
        e.broken = false
        return true
    elseif (subEvent == "SPELL_AURA_REMOVED" or subEvent == "SPELL_AURA_BROKEN")
       and spell == e.spell and sourceGUID == e.playerGUID then
        if destGUID == (e.target or "") then e.broken = true end
    end
end
```
Source: [wago.io/Y8douZITb](https://wago.io/Y8douZITb) (Cludes Warlock, Banish Timer).

## Warrior

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Warrior 2.0](https://wago.io/z6xqQay0S) | 89.7k | 2024-03 | Era |
| 2 | [Classic - Warrior - Defcon](https://wago.io/pFY9Mig50) | 50.0k | 2025-03 | Era/Fresh |
| 3 | [Meeh - SoD Warrior UI](https://wago.io/5aXZWXpIb) | 25.7k | 2024-07 | SoD |
| 4 | [[SoM 1.15] Warrior debuffs on target](https://wago.io/qquldQqcX) | 24.8k | 2023-12 | Era |
| 5 | [Sabimaru - Warrior Classic](https://wago.io/HV-7izFl4) | 17.9k | 2024-04 | SoD+Era |
| 6 | [Eskaton Fury Warrior HUD](https://wago.io/2kcZgDv9x) | 14.4k | **2026-04** | Era |
| 7 | [Luxthos - Warrior (Classic Era)](https://wago.io/ZShYlugjn) | 11.3k | 2025-01 | Era |
| 8 | [Telos - Classic Era Warrior](https://wago.io/Pp5dNu2f-) | 10.8k | 2023-10 | Era |
| 9 | [Bicarb - Warrior UI Era/Fresh](https://wago.io/LT1BLL4GP) | 9.8k | 2025-03 | Era/Fresh |
| 10 | [Warrior UI by React](https://wago.io/MQMiIyG6R) | 9.8k | 2024-09 | SoD |

Patterns: custom Lua clusters on four mechanics — swing timers, the HS/Cleave on-next-swing queue (actionbar scan or built-in Queued Action), the Overpower/Revenge dodge window (`CLEU:SWING_MISSED:SPELL_MISSED`, per-GUID, in ≥7/10 packs), and nameplate AoE counting (Bicarb's fuses a CC-safety check: don't break Polymorph/Sap). Big packs run ScanEvents pub/sub buses (Eskaton: 19 call sites, 216 authorOptions, 13% custom ratio — the ceiling of WA engineering). The #4 aura is a 13-icon dynamicgroup with zero custom code. Eskaton is the only top-10 aura *anywhere in this study* verified current on toc 11508.

## Paladin

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Paladin 2.0](https://wago.io/Y7SYk2ATp) | 52.0k | 2024-03 | Era |
| 2 | [Seal Twist Swing Timer (Surveillant)](https://wago.io/0i19EUqcz) | 23.9k | 2025-03 | SoD(+Era) |
| 3 | [Sabimaru - Paladin Classic](https://wago.io/zLJ2R3Oua) | 17.9k | 2024-04 | SoD |
| 4 | [Holos - Classic Era Paladin](https://wago.io/mB3x5baVA) | 16.1k | 2024-11 | Era |
| 5 | [Luxthos - Paladin (Classic Era)](https://wago.io/LuxthosPaladinClassicEra) | 12.6k | 2025-01 | Era |
| 6 | [Paladin - SoD (Nullgodx)](https://wago.io/l0kBBfo6N) | 11.4k | 2025-12 | SoD |
| 7 | [SOD Twist swing timer](https://wago.io/U-6c-UWSf) | 9.5k | 2024-05 | SoD |
| 8 | [Matt's Classic Holy Paladin](https://wago.io/68rsrGbCO) | 8.9k | 2024-02 | Era |
| 9 | [Swing Timer with Seal Twist - Riv](https://wago.io/QTOmoal4B) | 8.6k | 2024-11 | any |
| 10 | [Extra Attack Tracker (Reckoning)](https://wago.io/woGV4kzIu) | 7.2k | 2024-11 | any |

Patterns: three custom-code magnets — seal twisting, FSR/mana tick, Reckoning stored attacks (`aura_env.stacks` capped at 4, reset on swing/swap/death; in 3/10). The twist family splits into the library school (vendored ~23KB LibClassicSwingTimerAPI → ScanEvents) and the geometry school (built-in Swing Timer + `SetWidth`/`SetPoint` to paint a fixed 0.4s zone). A full healer suite (#8) needs essentially zero Lua. #10's "ErrorFix" title literally refers to replacing bare CLEU with filtered `CLEU:SPELL_EXTRA_ATTACKS:...` — the ecosystem learning the mandatory-filter rule in public. nullgodx (#6) is one of only two packs in the study using `use_engraving` (123/147 children).

## Hunter

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Hunter 2.0](https://wago.io/pXkndXV5n) | 75.7k | 2024-03 | Era |
| 2 | [Hunter Castbar (TBC)](https://wago.io/92y4H96_t) | 46.0k | 2023-12 | Era/SoD |
| 3 | [Bouk's Hunter Castbar](https://wago.io/YSKP1xUe2) | 26.8k | 2023-12 | Era/SoD |
| 4 | [Sabimaru - Hunter Classic](https://wago.io/B2G4lZKVE) | 25.7k | 2024-04 | SoD |
| 5 | [LuckyoneUI Classic - Hunter](https://wago.io/LuckyoneUI-Classic-Hunter) | 18.2k | 2023-08 | Era |
| 6 | [Pet Happiness](https://wago.io/xkzc0BxaD) | 16.9k | 2024-12 | any |
| 7 | [Hunter - Pet Info](https://wago.io/WMhm-4RpX) | 16.4k | 2024-01 | any |
| 8 | [Hunter Auto Shot Timer](https://wago.io/iBJTPFuk4) | 15.1k | 2024-01 | any |
| 9 | [Luxthos - Hunter (Classic Era)](https://wago.io/LuxthosHunterClassicEra) | 14.5k | 2025-01 | Era |
| 10 | [Sarthe SoD - Hunter](https://wago.io/Mq1Yqf_74) | 10.4k | 2024-05 | SoD |

Patterns: uniquely utility-heavy top 10 (4 standalone single-region tools) because Auto Shot and pets are self-contained problems. One castbar lineage (Bouk's) circulates near-verbatim through ≥4 entries — CLEU cast events + vanilla pushback ladder + quiver-haste bag scan. Range bracketing via known-range item IDs (`IsItemInRange("item:9621"...)`) visualizes the dead zone (Sabimaru). Pet Happiness is 1 of only 2 auras in the whole study using `aura_env.saved`. Sarthe detects Feign Death resists via `UI_ERROR_MESSAGE` id 513 — an event no built-in covers.

## Rogue

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Rogue 2.0](https://wago.io/LPFM2RH-l) | 97.7k | 2024-03 | Era |
| 2 | [SOD - Simonize's Rogue Pack](https://wago.io/dTwWQJRhb) | 29.0k | 2025-05 | SoD |
| 3 | [Sabimaru - Rogue Classic](https://wago.io/YWmuM5cC9) | 22.6k | 2024-04 | SoD+Era |
| 4 | [Luxthos - Rogue (Classic Era)](https://wago.io/LuxthosRogueClassicEra) | 18.9k | 2025-01 | Era+HC |
| 5 | [Classic Combo Points, Energy Bar](https://wago.io/aLBkkUAdc) | 18.8k | 2023-07 | Era |
| 6 | [Abÿss - Rogue essentials SOD](https://wago.io/R__6CHk0r) | 10.2k | 2023-12 | SoD |
| 7 | [Quazii Rogue (mirror)](https://wago.io/kfLg9KGqm2) | 7.1k | 2024-01 | SoD+HC |
| 8 | [Comfy \| Rogue UI](https://wago.io/6dsez-sDj) | 6.8k | 2025-07 | SoD |
| 9 | [SoD Rogue (buff board)](https://wago.io/pvzilYr5C) | 5.9k | 2024-09 | SoD |
| 10 | [Rogue - Classic Hud 2.0](https://wago.io/S3g4jTxOz) | 4.9k | 2023-09 | Era+HC |

Patterns: the purest one-snippet class — 8/10 packs carry the ENERGYTICK TSU as their *only* real custom trigger (median: 75+ built-ins to 1 custom; total Lua <5KB in 9/10). The other two are 100% built-in, including the 75-child Simonize pack (CLEU proc detection done entirely through the built-in Combat Log trigger's fields). Comfy (#8) is 1 of 2 study-wide `use_engraving` users. Cludes smuggles glow control into `customTriggerLogic` via `aura_env.region:SetGlow()` side effects — clever, but the docs' clone-region warnings apply.

## Priest

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Priest 2.0](https://wago.io/R8xGfpcxa) | 68.1k | 2024-03 | Era |
| 2 | [Classic Priest MP5/Spirit Tap - Riv](https://wago.io/ixGev0rhd) | 32.4k | 2024-11 | Era |
| 3 | [Sabimaru - Priest Classic](https://wago.io/gFd6I4vVo) | 29.3k | 2024-04 | SoD+Era |
| 4 | [Luxthos - Priest (Classic Era)](https://wago.io/LuxthosPriestClassicEra) | 13.2k | 2025-01 | Era+HC |
| 5 | [Sheepi - Priest UI](https://wago.io/OdaqYrgUr) | 10.4k | 2024-10 | SoD |
| 6 | [SoD shadow multi-target dot timer](https://wago.io/sod-priest-multi-target-dot-timer) | 8.1k | 2023-12 | SoD(+Era) |
| 7 | [Quazii Priest (mirror)](https://wago.io/MbgozaAEl) | 6.2k | 2024-01 | SoD |
| 8 | [[SOD] Shadow bar - dots & CDs](https://wago.io/xMH-_bucg) | 4.2k | 2024-02 | SoD |
| 9 | [Priest SOD UI](https://wago.io/gMJK_wxCO) | 4.0k | 2023-12 | SoD |
| 10 | [SoD Shadow Priest (Cerebo)](https://wago.io/7gUcl3VuB) | 3.9k | 2025-02 | SoD |

Patterns: mana economy is the only scripting problem (FSR TSU in every large pack; Riv's variant phase-locks the tick bar with `(ts - ts % 2)` remainder math). **The killer finding: multi-target DoT tracking needs zero code** — #6 is four nodes total, one aura2 trigger per bar with unit=`multi` producing clones per dotted enemy. Quazii's Homunculi tracker is the study's cleanest GUID-keyed CLEU TSU and fabricates preview states on the OPTIONS event so the config screen looks populated. Group-buff coordination (who cast PI on whom) rides a stock combatlog clone trigger + custom text reading `aura_env.states[1].sourceName`.

## Shaman

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Shaman 2.0](https://wago.io/Cd0Kqh-jx) | 58.3k | 2024-03 | Era |
| 2 | [Sabimaru - Shaman Classic](https://wago.io/8MyJNekEa) | 13.2k | 2024-04 | SoD |
| 3 | [Stormbringer's S.H.O.C.K](https://wago.io/kTNdSGFyC) | 13.2k | 2024-07 | SoD |
| 4 | [Luxthos - Shaman (Classic Era)](https://wago.io/SJP_6WLhH) | 13.1k | 2025-01 | Era |
| 5 | [Shaman SoD WA (Premixed)](https://wago.io/T8riimj-0) | 10.5k | 2023-12 | SoD |
| 6 | [Rams SoD Enhancement](https://wago.io/Lo6i4ByJ3) | 9.9k | 2024-08 | SoD |
| 7 | [Mood Shaman](https://wago.io/271HrXPCZ) | 7.4k | 2024-08 | SoD |
| 8 | [Shaman Totem Alerts](https://wago.io/JF0z70slG) | 5.2k | 2024-02 | any |
| 9 | [Wolde - Windfury Tracker](https://wago.io/Sl86LZ3vp) | 4.3k | 2025-02 | Era |
| 10 | [Sephalo - Totem Menu](https://wago.io/LL-j6Ob7K) | 3.6k | 2024-01 | any |

Patterns: shaman signature mechanics are all built-ins (Totem, Weapon Enchant, Swing Timer triggers); custom Lua covers totem *pulse* cadence (NewTicker→ScanEvents refire), range-aware group scans (dispel-type scanning; "is a live shaman in MY subgroup" via `WA_IterateGroupMembers` + `GetRaidRosterInfo`), and rams' CLEU Windfury/Overload damage accounting (the study's other `aura_env.saved` user, plus a `hooksecurefunc` on the engraving UI). S.H.O.C.K proves a 114-child art showpiece can be 100% built-in triggers with Lua only for presentation. Wolde's auto-chat nag ships a real bug: its raid whitelist keys Zul'Gurub as 249 (Onyxia's ID) — decoded-code review catches what descriptions never show.

## Mage

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Mage 2.0](https://wago.io/8BtIrvz_E) | 66.6k | 2024-03 | Era |
| 2 | [Luxthos - Mage (Classic Era)](https://wago.io/LuxthosMageClassicEra) | 28.3k | 2025-01 | Era+HC |
| 3 | [Sabimaru - Mage Classic](https://wago.io/6vNSif5yK) | 18.0k | 2024-03 | SoD |
| 4 | [Sheepi - Mage UI](https://wago.io/9aJRJ7vil) | 16.2k | 2024-10 | SoD |
| 5 | [Classic Mage Buffs SoD RUI](https://wago.io/zy0XvHIz_) | 13.3k | 2024-02 | mixed |
| 6 | [Gryma \|\| Mage SoD](https://wago.io/UIYMnqnDG) | 11.1k | 2023-12 | SoD P1 |
| 7 | [Kalltorak's SOD Mage Pack](https://wago.io/ZVzZwtP9V) | 8.6k | 2024-02 | SoD |
| 8 | [Quazii Mage (mirror)](https://wago.io/Qfo-sZmuYv) | 7.6k | 2024-01 | SoD |
| 9 | [Not SoD - Mage](https://wago.io/zOZOE4nec) | 6.7k | 2024-04 | SoD |
| 10 | [Mynester: Mage](https://wago.io/EH_1GiKQQ) | 6.6k | 2024-08 | SoD |

Patterns: two custom-code magnets — mana (the shared FSR TSU, byte-identical across 3+ packs) and absorbs (no Era API): either the ~2.5KB Ice Barrier CLEU estimator (seed 826 base absorb on cast, decrement from ABSORB miss amounts) or the embedded nanShield framework (3 packs, ~20-24KB, `WA_NAN_SHIELD` ScanEvents). Sheepi carries 182 children on ~6 real custom functions. Living Flame AoE counting = the wiki's throttled nameplate scan with `WeakAuras.CheckRange(unit, 20, "<=")`, shared verbatim between two packs.

## Warlock

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Warlock 2.0](https://wago.io/Y8douZITb) | 39.9k | 2024-03 | Era |
| 2 | [Vim's Warlock Buffs](https://wago.io/YIvG-x90O) | 25.5k | 2024-09 | Era/SoD/TBC/Wrath |
| 3 | [Luxthos - Warlock (Classic Era)](https://wago.io/LuxthosWarlockClassicEra) | 14.5k | 2025-01 | Era+HC |
| 4 | [Sabimaru - Warlock Classic](https://wago.io/XejlH_0_F) | 14.5k | 2024-04 | SoD+Era |
| 5 | [Telos - Classic SoD Warlock](https://wago.io/LlGorxzdz) | 10.5k | 2024-11 | SoD |
| 6 | [Warlock UI - SoD (Staffman)](https://wago.io/RSPDkyAfE) | 8.0k | 2025-02 | SoD |
| 7 | [Warlock SOD UI (acallys)](https://wago.io/KEtu_iJCb) | 6.9k | 2024-04 | SoD |
| 8 | [Denon Warlock Classic - Spell](https://wago.io/3I-KQHW7G) | 5.6k | 2024-07 | Era |
| 9 | [Villpumps SOD Suite](https://wago.io/Hy7YemX6w) | 5.6k | 2024-03 | SoD |
| 10 | [Warlock Destro UI SoD P2](https://wago.io/u3L4Wbe9b) | 5.4k | 2024-03 | SoD P2 |

Patterns: the cleanest census — 37 custom of 838 triggers (4.4%). Soul shards/healthstones are *inventory*: 130 item-type triggers, more than any other mechanic. Vim's covers four game flavors with 94 children, 95 aura2 triggers, and zero event code. Villpumps' Lake of Fire tracker is the field's best nameplate-anchored ground-effect TSU (CLEU + `NAME_PLATE_UNIT_ADDED/REMOVED` re-attach, states keyed by destGUID with `unit = nameplateN`). A rune-adaptive SoD UI with zero custom code exists (#7: layout swaps purely via `use_spellknown` loads).

## Druid

| # | Aura | Views | Updated | Flavor |
|---|---|---|---|---|
| 1 | [Cludes \| Classic Druid 2.0](https://wago.io/HCaWT5tJa) | 60.1k | 2024-03 | Era |
| 2 | [[Classic] Feral Powershifts](https://wago.io/tEf7cR1dG) | 25.6k | 2024-01 | Era |
| 3 | [Sabimaru - Druid Classic](https://wago.io/bQynAWaKe) | 24.3k | 2024-04 | SoD |
| 4 | [Sheepi - Druid UI](https://wago.io/qmsAvpew0) | 12.1k | 2024-09 | SoD |
| 5 | [Luxthos - Druid (Classic Era)](https://wago.io/LuxthosDruidClassicEra) | 11.4k | 2025-01 | Era |
| 6 | [Drood UI - SoD](https://wago.io/sUhWdK19S) | 10.1k | 2024-11 | SoD |
| 7 | [Feral/Druid UI by Meatslab](https://wago.io/jHooVKdGs) | 9.1k | 2024-02 | SoD |
| 8 | [Feral Buff/Debuff/Shift Tracker](https://wago.io/Px63fSX6h) | 8.8k | 2025-04 | Era |
| 9 | [Druid FERAL - SOD](https://wago.io/529NgFDIa) | 7.7k | 2023-12 | SoD P1 |
| 10 | [Raid Consumables/Buff Tracker](https://wago.io/R0CRtYhCw) | 7.6k | 2025-04 | mixed |

Patterns: two verbatim memes own the class — the powershift counter (7/10, above) and the energy-tick TSU (5/10). Form-awareness is built-in-stackable (Drood UI: 41 Power triggers; Meatslab: 44 Stance/Form triggers). Meatslab is the study's other secure-button aura: click-to-rebuff overlays with `/dismount /cancelform /use` macrotext — druids must leave form to self-buff, so the click-aura pattern earns its keep. Duffdude's consumables tracker configures via 31 of 38 children shipped at Load=Never — the menu-of-disabled-children idiom at its purest.
