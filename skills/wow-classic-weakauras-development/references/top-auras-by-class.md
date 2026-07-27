# Field study: the top 10 wago.io WeakAuras per class (Classic bucket)

Data-driven study of the top wago.io auras for each of the nine classic classes, with every aura's **decoded table and custom code** fetched via `data.wago.io/lookup/wago/code?id=<slug>`. Two ranking passes were run (snapshots 2026-07-27/28): first by lifetime **views**, then by **stars** (`sort=stars`; star counts verified per-slug against the authoritative `lookup` `favoriteCount`). ~120 auras decoded in total. **Tables below rank by stars** — wago's bookmark/favorite signal — with views alongside; ties broken by views. The Era/SoD/HC flavors share one "classic" bucket; same-author flavor siblings are deduped into the stronger entry. wago search relevance is blended (a #1 aura can be invisible to its own class-name query), so candidate pools merged many query variants — an oddly-named high-star aura could still be missed. Below ~6 stars the tail is tie-heavy and volatile.

## Contents
- Cross-class findings
- Stars vs views: what each metric rewards
- The one-snippet-per-class table
- Cross-class snippets (FSR mana tick, powershift counter, GUID-scoped CC tracker)
- Per-class: top 10 + patterns (Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid)

## Cross-class findings

1. **Built-ins carry ~90-96% of all triggers, everywhere, under both rankings.** Across ~120 decoded auras, `aura2` (buff/debuff) + Cooldown Progress are the spine of every pack; custom triggers run 0-13% per pack (e.g. Warlock views-cohort: 37 of 838). Every class's top 10 contains at least one **zero-custom-Lua** aura — including 100+-child suites and a ★36 warrior tracker. "Built-in triggers first" isn't advice, it's what the field's best-loved auras actually are.
2. **Each class has one or two API-gap mechanics, and ONE community snippet per gap circulates verbatim.** Byte-identical copies (md5-confirmed for the mana TSU, complete with its `duration = 6.45 -- why?` comment) travel between packs by *different authors* — e.g. `ScanEvents('WA_WARRIOR_CLEAVE_AOE_COUNT_UPDATE')` verbatim in two unrelated warrior packs. Top packs are largely different curations of the same half-dozen snippets — see the table below.
3. **"Custom code block" counts are misleading.** The most common block is a 1-3-line `customTriggerLogic` combiner (`return (t[1] or t[2]) and not t[3]`) folding an Era spell and its SoD rune replacement into one icon — packs carry 20-40 of these and only 1-2 real custom triggers. A full next-best-action rotation engine (FuryProt, ★52) is built from nothing but built-in triggers ANDed in combiners.
4. **The addon-in-a-WeakAura pattern:** big packs embed entire engines in a hidden child's On Init and rebroadcast via `WeakAuras.ScanEvents` — the vendored ~23KB LibClassicSwingTimerAPI (two unrelated Paladin authors + two Warrior packs), the ~20-24KB nanShield absorb framework (Mage/Priest), Luxthos' 28.5KB options hub. Consumers are lightweight custom-event triggers. **Namespace your synthetic events** — field copies rename `ENERGYTICK` → `OVERLAYTICK` / `WA_ENERGY_TICK` precisely to avoid cross-pack collisions; the tightest variant passes `aura_env.id` as an arg and checks it on receipt.
5. **Configuration has two schools.** Options-hub (usually Luxthos: 24-31 authorOptions on hidden "Options" children, published via a global registry + `LWA_*` ScanEvents bus). Everyone else ships 0-3 authorOptions and configures via: children parked at Load=Never as an opt-in menu, drag-reorder dynamic groups, edit-me constants atop a customGrow, or "delete the group."
6. **Flavor gating in the field ignores the load flags.** Across the study: `use_hardcore` appears **zero** times (all "Hardcore" support is marketing copy); `use_engraving` in only 2-3 packs (it works — it's just not the convention). Dominant idioms: gate SoD runes with **Spell Known** triggers/loads, or ship **separate sibling imports per flavor** (the Cludes pattern).
7. **WA-as-interaction-tool is a real, star-rewarded niche** the views ranking under-surfaced: an invisible `SecureActionButtonTemplate` overlay that makes an aura genuinely clickable (Feed Pet Button ★11; druid `/cancelform` rebuff; Easy Poisons), camera-CVar automation for melee weaving (★12), an ItemRack gear-hotswap dispatcher (WA as addon glue, ★11), a mouse-interactive uptime meter (CreateFrame overlay firing ScanEvents on click/hover), and a raid summon-queue driven by chat commands + CLEU + a ScanEvents comm bus (with fake preview allstates when `WeakAuras.IsOptionsOpen()`).
8. **Rarities worth knowing:** `aura_env.saved` persistence (2 of ~120), OPTIONS-event fake states for WYSIWYG config previews (3), `WeakAuras.ComposeSorts` for clustering multi-unit clones under per-target headers with zero CLEU (Zimble's DoT timer).
9. **Staleness is the norm and built-ins are why it's survivable.** Most top entries froze in 2023-2024 (toc 11500-11504, pre-1.15.8); they age gracefully because they're built-in-heavy. When adopting one, audit exactly its custom blocks — mana TSUs and CLEU handlers are where age bites. Only a handful per class were maintained into 2025+; the study found exactly three top-10 auras current on toc 11508 (Eskaton warrior, zHUD mage, Totem Uptime Tracker).
10. **Lineage is open:** forks credited, snippets pooled, aggregation-as-authorship normal — and in one case (Priest multi-DoT) a maintained fork now out-stars the abandoned original it forked.

## Stars vs views: what each metric rewards

- **Stars reward keep-this value; views reward search placement.** Low-view craft utilities enter only under stars (Tankadin II ★4 on 2.7k views; Smelly HUD ★7 on 2.0k; Shirati's AoE meter ★7 on 1.6k), while high-view/low-star brand ports collapse (Luxthos ports: 11-28k views but ★1-5 — out of most stars top-10s; Quazii mirrors likewise).
- **favoriteCount never decays**, so stars also preserve legacy: stale-but-beloved packs keep their crowns (Cludes is #1 or #2 in eight of nine classes on both metrics; users' stars stayed on his deprecated Era originals rather than moving to his own SoD successors, by 10-20x).
- **Star-per-view ratio is the best quality/momentum signal** in the bucket — it surfaces both actively-used tools (FuryProt ★52/20k) and maintained current-client utilities (Totem Uptime ★8/2.4k, toc 11508).
- **The biggest single upset:** nanShield Classic Era (★126 — the highest star count in the entire study) never appeared in the views-based Priest list at all; it matches no "priest" search query and was found via "power word". Star voters visibly reward the hardest custom-code niche (absorb reconstruction) — the three Priest absorb trackers hold ranks 1, 7, and 9 by stars.

## The one-snippet-per-class table

| Class | API-gap mechanic | Canonical community solution |
|---|---|---|
| Rogue / Druid (energy) | 2s energy tick | Self-rescheduling ENERGYTICK TSU (in 7-8/10 packs both rankings) — examples.md §2; the standalone tracker itself charts (★6) with a delta-band heuristic distinguishing normal/Adrenaline-Rush/cap ticks |
| Priest / Paladin / Shaman / Mage / Warlock (mana) | Five-second rule + 2s mana tick | The shared FSR mana-tick TSU (below); Riv's phase-lock variant uses `(ts - ts % 2)` remainder math |
| Druid | Powershifts remaining | `floor(mana / GetSpellPowerCost(768))` counter (6-7/10 packs; below) |
| Hunter | Auto Shot castbar/timing | Bouk's CLEU castbar lineage (top-6 by both metrics): `CLEU:SPELL_CAST_START:...` + vanilla pushback ladder {1,.8,.6,.4,.2}s + quiver-haste bag scan |
| Hunter | Pet happiness/feeding | Happiness simulation (loyalty-scaled decay + CLEU feed detection, aura_env.saved); Feed Pet secure-button overlay |
| Paladin | Seal-twist window | Two schools: vendored LibClassicSwingTimerAPI rebroadcast via ScanEvents (two unrelated authors), or built-in Swing Timer + bar-geometry (SetWidth cuts a fixed 0.4s zone) |
| Warrior | HS/Cleave queue, Overpower window | Actionbar-scan (`IsCurrentAction`) or built-in Queued Action trigger; per-GUID dodge snapshots from `CLEU:SWING_MISSED:SPELL_MISSED` (both cross-author memes) |
| Mage / Priest | Absorb values (no Era API) | Ice Barrier CLEU estimator (seed capacity on cast, decrement from ABSORB miss amounts) or the nanShield framework (★126 as a standalone) |
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
Seed of a class-wide meme. Custom Event trigger; Event(s): `UNIT_SPELLCAST_SUCCEEDED:player UNIT_POWER_FREQUENT:player` (note: the original leaks globals; use `aura_env`):

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
Source: [wago.io/tEf7cR1dG](https://wago.io/tEf7cR1dG) ([Classic] Feral Powershifts, ★22).

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

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Warrior 2.0](https://wago.io/z6xqQay0S) | 57 | 89.7k | 2024-03 | Era |
| 2 | [FuryProt Next Best Action](https://wago.io/3a-_2_WGN) | 52 | 20.3k | 2024-05 | SoD/classic |
| 3 | [Classic - Warrior - Defcon](https://wago.io/pFY9Mig50) | 48 | 50.0k | 2025-03 | Era/Fresh |
| 4 | [[SoM 1.15] Warrior debuffs on target](https://wago.io/qquldQqcX) | 36 | 24.8k | 2023-12 | Era |
| 5 | [Meeh - SoD Warrior UI](https://wago.io/5aXZWXpIb) | 35 | 25.7k | 2024-07 | SoD |
| 6 | [Sabimaru - Warrior Classic](https://wago.io/HV-7izFl4) | 25 | 17.9k | 2024-04 | SoD+Era |
| 7 | [Warrior UI by React](https://wago.io/MQMiIyG6R) | 13 | 9.8k | 2024-09 | SoD |
| 8 | [Bicarb - Warrior UI Era/Fresh](https://wago.io/LT1BLL4GP) | 12 | 9.8k | 2025-03 | Era/Fresh |
| 9 | [Aeon's Warrior Classic SoD](https://wago.io/WQvZkYOS2) | 12 | 6.7k | 2024-03 | SoD |
| 10 | [Warrior Hotswap (Diamond Flask)](https://wago.io/djN0VftGP) | 11 | 8.2k | 2023-09 | Era/SoM |

Patterns: custom Lua clusters on four mechanics — swing timers, the HS/Cleave on-next-swing queue (actionbar scan or built-in Queued Action), the Overpower/Revenge dodge window (`CLEU:SWING_MISSED:SPELL_MISSED`, per-GUID, a cross-author meme), and nameplate AoE counting (Bicarb fuses a CC-safety check: don't break Polymorph/Sap). Stars promote the rotation helper: FuryProt (#2, best star-per-view in class) is a full priority engine built purely from built-in triggers + boolean combiners. #4 is 13 aura2 icons with literally zero code. Views-cohort entries Eskaton (★5, the only study aura verified on toc 11508), Luxthos (★4), and Telos (★10) drop out under stars. #10 is the study's "WA as addon glue" specimen — an ItemRack hotswap dispatcher that no-ops without the addon.

## Paladin

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Paladin 2.0](https://wago.io/Y7SYk2ATp) | 56 | 52.0k | 2024-03 | Era |
| 2 | [Sabimaru - Paladin Classic](https://wago.io/zLJ2R3Oua) | 20 | 17.9k | 2024-04 | SoD |
| 3 | [Seal Twist Swing Timer (Surveillant)](https://wago.io/0i19EUqcz) | 13 | 23.9k | 2025-03 | SoD(+Era) |
| 4 | [Holos - Classic Era Paladin](https://wago.io/mB3x5baVA) | 12 | 16.1k | 2024-11 | Era |
| 5 | [Paladin - SoD (Nullgodx)](https://wago.io/l0kBBfo6N) | 6 | 11.4k | 2025-12 | SoD |
| 6 | [Matt's Classic Holy Paladin](https://wago.io/68rsrGbCO) | 6 | 8.9k | 2024-02 | Era |
| 7 | [Luxthos - Paladin (Classic Era)](https://wago.io/LuxthosPaladinClassicEra) | 5 | 12.6k | 2025-01 | Era |
| 8 | [Quazii Paladin (mirror)](https://wago.io/XznZkjF2z) | 4 | 5.9k | 2024-01 | mixed |
| 9 | [Tankadin II (SoD)](https://wago.io/w-WF98f90) | 4 | 2.7k | 2024-08 | SoD |
| 10 | [SOD Twist swing timer](https://wago.io/U-6c-UWSf) | 3 | 9.5k | 2024-05 | SoD |

Patterns: three custom-code magnets — seal twisting (library school: vendored ~23KB LibClassicSwingTimerAPI → ScanEvents, now confirmed in *two unrelated authors'* timers; geometry school: built-in Swing Timer + `SetWidth`/`SetPoint` painting a fixed 0.4s zone), FSR/mana tick, and Reckoning stored attacks (`aura_env.stacks` capped at 4; the "ErrorFix" aura's title literally refers to replacing bare CLEU with filtered subevents). Below rank 4 stars stop discriminating (3-6★ tail). Newcomer Tankadin II earns stars on 2.7k views with a defense→avoidance/crush-cap calculator including a libram item-ID check. A full healer suite (#6) needs essentially zero Lua. Quazii's pack abuses a Custom Grow child as an expandable settings tab and stacks 12 built-in Swing Timer triggers for per-ability swing alignment.

## Hunter

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Hunter 2.0](https://wago.io/pXkndXV5n) | 76 | 75.7k | 2024-03 | Era |
| 2 | [Hunter Castbar (TBC)](https://wago.io/92y4H96_t) | 58 | 46.0k | 2023-12 | Era/SoD |
| 3 | [Sabimaru - Hunter Classic](https://wago.io/B2G4lZKVE) | 46 | 25.7k | 2024-04 | SoD |
| 4 | [Hunter - Pet Info](https://wago.io/WMhm-4RpX) | 26 | 16.4k | 2024-01 | any |
| 5 | [Pet Happiness](https://wago.io/xkzc0BxaD) | 22 | 16.9k | 2024-12 | any |
| 6 | [Bouk's Hunter Castbar](https://wago.io/YSKP1xUe2) | 18 | 26.8k | 2023-12 | Era/SoD |
| 7 | [LuckyoneUI Classic - Hunter](https://wago.io/gaLjRhKbK) | 17 | 18.2k | 2023-08 | Era |
| 8 | [Melee Weave Smart Camera Flip](https://wago.io/tYbtnSVt4) | 12 | 5.2k | 2024-01 | SoD(+Era) |
| 9 | [Feed Pet Button That Actually Works](https://wago.io/gJU1OA4Ra) | 11 | 5.8k | 2024-01 | SoD(+Era) |
| 10 | [Silents Trueshot & Hawk Buffs Missing](https://wago.io/BJ8Z7HM9q) | 10 | 8.5k | 2025-12 | Era 11508 |

Patterns: uniquely utility-heavy — the mid-tier is majority-custom because pet happiness/feeding/weaving have no built-in trigger types. One castbar lineage (Bouk's: CLEU cast events + vanilla pushback ladder + quiver-haste bag scan) fills the top 6 by both metrics. Stars surface two "WA as interaction tool" gems views buried: the camera-CVar automation aura (SetCVar camera flips for melee weaving, with a `camera_busy` latch) and the Feed Pet secure-button overlay (invisible `ActionButtonTemplate,SecureActionButtonTemplate` frame over the icon — clicking genuinely casts Feed Pet). #10 is the tell for where new stars flow: a two-icon, zero-code missing-buff glow, current on toc 11508 (Dec 2025). Sarthe (views #10) detects Feign Death resists via `UI_ERROR_MESSAGE` id 513.

## Rogue

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Rogue 2.0](https://wago.io/LPFM2RH-l) | 71 | 97.7k | 2024-03 | Era |
| 2 | [Sabimaru - Rogue Classic](https://wago.io/YWmuM5cC9) | 19 | 22.6k | 2024-04 | SoD+Era |
| 3 | [Personal Resource Display CLASSIC ERA](https://wago.io/u2ZEIZTrf) | 13 | 9.0k | 2025-07 | Era 11507 |
| 4 | [Classic Combo Points, Energy Bar](https://wago.io/aLBkkUAdc) | 11 | 18.8k | 2023-07 | Era |
| 5 | [Abÿss - Rogue essentials SOD](https://wago.io/R__6CHk0r) | 11 | 10.2k | 2023-12 | SoD |
| 6 | [Rogue - Classic Hud 2.0](https://wago.io/S3g4jTxOz) | 10 | 4.9k | 2023-09 | Era+HC |
| 7 | [SOD - Simonize's Rogue Pack](https://wago.io/dTwWQJRhb) | 9 | 29.0k | 2025-05 | SoD |
| 8 | [SoD Rogue (buff board)](https://wago.io/pvzilYr5C) | 9 | 5.9k | 2024-09 | SoD |
| 9 | [Energy Tick Tracker (Nug Inspired)](https://wago.io/TywXQKxob) | 6 | 7.5k | 2023-04 | any |
| 10 | [Rogue SoD (Luxthos TLK port)](https://wago.io/Uia8MTmtL) | 6 | 5.0k | 2024-02 | SoD |

Patterns: the purest one-snippet class — the ENERGYTICK TSU is the *only* real custom trigger in 7-8/10 packs under both rankings, and the standalone tracker itself charts at #9 (its delta-band heuristic distinguishes normal ~20 / Adrenaline Rush ~40 / cap ticks, re-arming via `C_Timer.After(1.995)`). Zero-code packs chart high (Simonize: 75 children, CLEU proc detection entirely via the built-in Combat Log trigger's fields). Stars promote current-client utilities (the all-class PRD at #3, toc 11507 — a relevance judgment call, flagged as such) and drop stale brand mirrors (Quazii ★2, Comfy ★3, Luxthos ★1 all out). Note #3/#10 caveat: if the PRD is excluded as class-generic, Legion Style Combo Points (★6, single procedurally-drawn texture region) takes #10.

## Priest

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [nanShield Classic Era](https://wago.io/6HHBMDHTD) | **126** | 31.9k | 2024-07 | Era/SoD |
| 2 | [Cludes \| Classic Priest 2.0](https://wago.io/R8xGfpcxa) | 78 | 68.1k | 2024-03 | Era |
| 3 | [Sabimaru - Priest Classic](https://wago.io/gFd6I4vVo) | 34 | 29.3k | 2024-04 | SoD+Era |
| 4 | [Classic Priest MP5/Spirit Tap - Riv](https://wago.io/ixGev0rhd) | 27 | 32.4k | 2024-11 | Era |
| 5 | [Sheepi - Priest UI](https://wago.io/OdaqYrgUr) | 22 | 10.4k | 2024-10 | SoD |
| 6 | [Multi-target dot timer (Zimble fork)](https://wago.io/Q-E-sFxKF) | 4 | 4.6k | 2025-04 | SoD 11507 |
| 7 | [Absorb Shields](https://wago.io/LJva4V4Yw) | 4 | 4.0k | 2024-04 | SoD |
| 8 | [Multi-target dot timer (Muricas original)](https://wago.io/sod-priest-multi-target-dot-timer) | 3 | 8.1k | 2023-12 | SoD(+Era) |
| 9 | [PW:S Remaining Absorb [SoD]](https://wago.io/hwuZxg2xw) | 3 | 7.3k | 2025-02 | SoD |
| 10 | [WarCrow - Priest Self Buffs](https://wago.io/KYe4i1Q_r) | 3 | 2.7k | 2023-09 | Era/SoM |

Patterns: **the study's biggest stars upset** — nanShield (★126, highest in the entire study) dethrones Cludes; it never surfaces in any "priest" search (found via "power word"). Star voters reward the hardest custom-code niche: the three absorb trackers hold ranks 1/7/9, all reconstructing shield values from `CLEU:SPELL_ABSORBED` deltas (no Era absorb API); nanShield fans state from one worker child to four renderers over a `WA_NAN_SHIELD` ScanEvents bus with a curved custom-grow layout. The fork-beats-parent case: Zimble's maintained fork (#6, toc 11507, `WeakAuras.ComposeSorts` clustering per-target bars under unit headers — **zero CLEU**) out-stars the abandoned original (#8). Multi-target DoT tracking still needs zero code (built-in aura2 `multi` unit clones). Mana economy is the only other scripting problem (FSR TSU in every large pack; Riv's `(ts - ts % 2)` phase-lock). Quazii's Homunculi tracker (views cohort) remains the cleanest GUID-keyed CLEU TSU with OPTIONS-event preview states.

## Shaman

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Shaman 2.0](https://wago.io/Cd0Kqh-jx) | 52 | 58.3k | 2024-03 | Era |
| 2 | [Sabimaru - Shaman Classic](https://wago.io/8MyJNekEa) | 17 | 13.2k | 2024-04 | SoD |
| 3 | [Stormbringer's S.H.O.C.K](https://wago.io/kTNdSGFyC) | 12 | 13.2k | 2024-07 | SoD |
| 4 | [Shaman SoD WA (Premixed)](https://wago.io/T8riimj-0) | 12 | 10.5k | 2023-12 | SoD |
| 5 | [Mood Shaman](https://wago.io/271HrXPCZ) | 11 | 7.4k | 2024-08 | SoD |
| 6 | [Maelstrom Weapon (art piece)](https://wago.io/ZLbzRNWVq) | 8 | 7.8k | 2024-02 | SoD |
| 7 | [Totem Uptime Tracker](https://wago.io/MoDL_K8hs) | 8 | 2.4k | 2025-10 | Era 11508 |
| 8 | [Shaman Totem Alerts](https://wago.io/JF0z70slG) | 7 | 5.2k | 2024-02 | any |
| 9 | [Rams SoD Enhancement](https://wago.io/Lo6i4ByJ3) | 6 | 9.9k | 2024-08 | SoD |
| 10 | [Sephalo - Totem Menu](https://wago.io/LL-j6Ob7K) | 5 | 3.6k | 2024-01 | any |

Patterns: signature mechanics are all built-ins (Totem, Weapon Enchant, Swing Timer triggers); custom Lua covers totem *pulse* cadence (NewTicker→ScanEvents refire), range-aware group scans, and rams' CLEU Windfury/Overload accounting (one of the study's two `aura_env.saved` users, plus a `hooksecurefunc` on the engraving UI). S.H.O.C.K proves a 114-child art showpiece can be 100% built-in triggers. The stars-only newcomer is the study's most interesting sociologically: Totem Uptime Tracker (#7, toc 11508) is starred by *melee who benefit from totems*, not shamans — a "measure your shaman" meter with a mouse-interactive CreateFrame overlay. Engineering earns proportionally fewer stars than polish: custom-heavy rams sits at ★6 while zero-code Premixed ties #4. Wolde's Windfury nag (views cohort) still ships its ZG-instanceID bug — decoded-code review catches what descriptions never show.

## Mage

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Mage 2.0](https://wago.io/8BtIrvz_E) | 83 | 66.6k | 2024-03 | Era |
| 2 | [Sheepi - Mage UI](https://wago.io/9aJRJ7vil) | 22 | 16.2k | 2024-10 | SoD |
| 3 | [[zHUD] Zippy's Mage HUD](https://wago.io/GfNFG3Qqh) | 15 | 6.3k | 2025-11 | Era/SoD 11508 |
| 4 | [Sabimaru - Mage Classic](https://wago.io/6vNSif5yK) | 14 | 18.0k | 2024-03 | SoD |
| 5 | [Luxthos - Mage (Classic Era)](https://wago.io/LuxthosMageClassicEra) | 13 | 28.3k | 2025-01 | Era+HC |
| 6 | [Gryma \|\| Mage SoD](https://wago.io/UIYMnqnDG) | 13 | 11.1k | 2023-12 | SoD P1 |
| 7 | [Kalltorak's SOD Mage Pack](https://wago.io/ZVzZwtP9V) | 11 | 8.6k | 2024-02 | SoD |
| 8 | [Classic Mage Buffs SoD RUI](https://wago.io/zy0XvHIz_) | 8 | 13.3k | 2024-02 | mixed |
| 9 | [FireMageEra](https://wago.io/sBqotaQGN) | 7 | 4.9k | 2025-06 | Era 11507 |
| 10 | [Shirati's: Total AoE (Hunter/Mage)](https://wago.io/JFDpzVq-7) | 7 | 1.6k | 2024-07 | mixed |

Patterns: two custom-code magnets — mana (the shared FSR TSU, byte-identical across 3+ packs) and absorbs (Ice Barrier CLEU estimator seeding 826 base absorb, or embedded nanShield, 3 packs). Stars promote maintenance: zHUD (#3, toc 11508, concentric progresstexture rings) would be ~#9 by views, while Luxthos drops from #2 to #5. FireMageEra (#9) shows the middle path — CLEU consumed through the *built-in* combatlog trigger type, custom code confined to conditions/presentation. Shirati's AoE meter (#10) is the inversion specimen: 100% custom TSU, zero built-in triggers, a rolling damage-window aggregator. Living Flame AoE counting = the wiki's throttled nameplate scan, shared verbatim between two packs.

## Warlock

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Vim's Warlock Buffs](https://wago.io/YIvG-x90O) | 35 | 25.5k | 2024-09 | Era/SoD/TBC/Wrath |
| 2 | [Sabimaru - Warlock Classic](https://wago.io/XejlH_0_F) | 21 | 14.5k | 2024-04 | SoD+Era |
| 3 | [Warlock Destro UI SoD P2](https://wago.io/u3L4Wbe9b) | 15 | 5.4k | 2024-03 | SoD P2 |
| 4 | [Villpumps SOD Suite](https://wago.io/Hy7YemX6w) | 9 | 5.6k | 2024-03 | SoD |
| 5 | [Warlock SOD UI (acallys)](https://wago.io/KEtu_iJCb) | 7 | 6.9k | 2024-04 | SoD |
| 6 | [Swift Summon - Curse](https://wago.io/SwiftSummon) | 6 | 3.1k | 2024-11 | any |
| 7 | [Warlock SOD - Rotation Assistant](https://wago.io/4XMkd1KUs) | 5 | 3.2k | 2024-01 | SoD P1 |
| 8 | [Alk's Warlock Compendium {CORE}](https://wago.io/VaQv57tih) | 5 | 2.3k | 2024-03 | SoD |
| 9 | [Luxthos - Warlock (Classic Era)](https://wago.io/LuxthosWarlockClassicEra) | 4 | 14.5k | 2025-01 | Era+HC |
| 10 | [Warlock UI - SoD (Staffman)](https://wago.io/RSPDkyAfE) | 4 | 8.0k | 2025-02 | SoD |

Patterns: the only class where stars and views crown the same #1 — and it's the 94-icon, zero-event-code buff board (95 built-in aura2 triggers covering four game flavors). Soul shards/healthstones are *inventory* (130 item-type triggers in the views cohort). Cludes drops out of the stars top 10 entirely (★30 wasn't enough — Warlock is his weakest brand showing). Stars surface specialist tools: Swift Summon (#6) is the study's social-coordination pattern — a raid summon queue driven by chat commands + CLEU Ritual-of-Summoning events + a three-channel ScanEvents comm bus, with fake class-colored preview states when the options window is open; the Rotation Assistant's "pet not attacking" nag polls `UnitExists('pettarget')` with a grace window — a warlock-only concern nothing built-in covers. Villpumps' Lake of Fire tracker remains the field's best nameplate-anchored ground-effect TSU.

## Druid

| # | Aura | ★ | Views | Updated | Flavor |
|---|---|---|---|---|---|
| 1 | [Cludes \| Classic Druid 2.0](https://wago.io/HCaWT5tJa) | 58 | 60.1k | 2024-03 | Era |
| 2 | [Sabimaru - Druid Classic](https://wago.io/bQynAWaKe) | 38 | 24.3k | 2024-04 | SoD |
| 3 | [[Classic] Feral Powershifts](https://wago.io/tEf7cR1dG) | 22 | 25.6k | 2024-01 | Era |
| 4 | [Sheepi - Druid UI](https://wago.io/qmsAvpew0) | 22 | 12.1k | 2024-09 | SoD |
| 5 | [Incoming heal](https://wago.io/Q7QDDTcKk) | 17 | 10.4k | 2025-10 | Era 11507 |
| 6 | [Feral/Druid UI by Meatslab](https://wago.io/jHooVKdGs) | 11 | 9.1k | 2024-02 | SoD |
| 7 | [Drood UI - SoD](https://wago.io/sUhWdK19S) | 10 | 10.1k | 2024-11 | SoD |
| 8 | [Druid HUD (classic/hc)](https://wago.io/ftVQvXC8a) | 8 | 4.5k | 2023-09 | Era+HC |
| 9 | [Smelly HUD: Druid](https://wago.io/uwVp9xAXh) | 7 | 2.0k | 2024-04 | SoD |
| 10 | [Pike's Pack Druid](https://wago.io/1v5aGg7X6) | 5 | 6.0k | 2025-01 | SoD |

Patterns: two verbatim memes own the class — the powershift counter (6+/10 both rankings) and the energy-tick TSU. Form-awareness stays built-in-stackable (40+ Power or Stance/Form triggers per pack). The stars-only star is Incoming heal (#5, toc 11507, updated 2025-10): a healer-coordination TSU keyed `healerGUID-targetGUID` that fuses `UnitGetIncomingHeals` with LibHealComm addon-message events — the most sophisticated healer tooling in the study. Druid HUD (#8) is a living fossil: pre-TSU "status"-type custom triggers still doing clone duty on 1.15 clients. Meatslab keeps the class's secure-button niche (`/dismount /cancelform /use` click-to-rebuff — druids must leave form to self-buff). Duffdude's views-cohort trackers (toc 11507) exemplify menu-of-disabled-children config (31/38 children at Load=Never).
