# Case studies: seven repair patterns

Seven real repairs from the 1.15.8 breakage wave, written as reusable patterns. Each shows the signature, the diagnosis that mattered, and what the fix generalizes to.

## Contents
- 1. The cascade avalanche (Atlas)
- 2. The swapped-argument alias trap (Atlas)
- 3. Global hook → mixin method (Spy, ClassicAuraDurations)
- 4. The next error you prevent (ClassicHealPrediction)
- 5. Feature-detect, don't version-gate (BuffTimers)
- 6. Embedded-library minor precedence (LibRangeCheck)
- 7. Frame-shape collision (SexyMap, ClassicHealPrediction round 2)

## 1. The cascade avalanche

**Signature:** six errors across one addon — `attempt to call a nil value` in three Lua files, `attempt to index global 'Atlas' (a nil value)` in three XML OnLoad handlers, `table index is nil` in two data files.

**Diagnosis that mattered:** count files, not errors. The three call-a-nil errors were the same root cause (removed `GetAddOnMetadata`/`GetAddOnInfo`) in three files; every other error was a cascade — the XML handlers indexed a global the aborted main file never got to assign (`_G.Atlas = addon` was below the failing line), and the data files indexed `ATLAS_DDL_*` constants defined *after* the failing line of another aborted file.

**Generalizes to:** always locate each cascade's *defining* file and check whether the definition site is above or below that file's first error. Six errors became two aliases.

## 2. The swapped-argument alias trap

**Signature:** none — this one produces **no error**, just silently wrong behavior after a naive fix.

**Diagnosis that mattered:** reading the new API's documentation instead of assuming symmetry: legacy `GetAddOnEnableState(character, name)` vs `C_AddOns.GetAddOnEnableState(name, character)`. A plain `local GetAddOnEnableState = C_AddOns.GetAddOnEnableState` alias type-checks, runs, and returns enable-state for the wrong query.

**Fix pattern:** a wrapper preserving the legacy signature:

```lua
local GetAddOnEnableState = _G.GetAddOnEnableState or function(character, name)
    return C_AddOns.GetAddOnEnableState(name, character)
end
```

**Generalizes to:** for every alias, compare the two signatures in the client source — not just the names.

## 3. Global hook → mixin method

**Signature:** `hooksecurefunc(): TargetFrame_Update is not a function` (same family: `TargetFrame_UpdateAuras`, `CompactRaidFrameContainer_GetUnitFrame`).

**Diagnosis that mattered:** the function didn't vanish — it moved onto a mixin applied to a named frame instance. Verify in the client XML that the frame declares `mixin="TargetFrameMixin"`, then hook the instance: `hooksecurefunc(TargetFrame, "Update", handler)`.

**Two traps:** (a) method hooks receive `self` as the first argument — a handler written for the old global signature may misread its args (harmless if it declared no params, wrong if it used them); (b) direct calls change shape too: `TargetFrame_UpdateAuras(TargetFrame)` → `TargetFrame:UpdateAuras()`.

**Generalizes to:** any `X_Verb is not a function` where X is a frame name — look for `XMixin:Verb` in the client dump.

## 4. The next error you prevent

**Signature:** the reported error is at line 989; the file is 2000 lines and hooks a dozen more globals below.

**Diagnosis that mattered:** after fixing the reported hook, *every subsequent hook target in the same code path was verified against the client dump before re-testing*. Two more were already dead (`DefaultCompactNamePlateFrameSetup`, and later in another addon `CompactUnitFrame_UtilSetBuff`) — they'd have been the next login's error report, one at a time.

**Generalizes to:** step 6 of the triage workflow. Also the honest-degradation case: `CompactUnitFrame_UtilSetBuff` has NO modern replacement (native rendering) — the right fix was an existence check disabling that one feature with a comment, not a fake shim.

## 5. Feature-detect, don't version-gate

**Signature:** `hooksecurefunc(): AuraButton_Update is not a function` — in an addon that already contained a working modern code path, gated by `WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC`.

**Diagnosis that mattered:** the addon's author assumed "Classic = legacy API". The client refactor broke that equation. The fix flipped the gate to a feature-detect on the API itself: `local useModern = type(AuraButton_Update) ~= "function"` — and then *every other site* that branched on the same project-ID flag had to flip too (duration-field names, argument handling), or the addon would load clean but render nothing.

**Generalizes to:** detect capabilities, not client flavors; and when changing a gate, grep for every consumer of that gate.

## 6. Embedded-library minor precedence

**Signature:** `Attempt to register unknown event "LEARNED_SPELL_IN_TAB"` from `RangeDisplay/libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua`.

**Diagnosis that mattered:** three addons embedded the same LibStub library at minors 32/34/35. The error came from the minor-32 copy (loaded first, registered its frame before higher minors loaded); minors 34/35 already contained the upstream fix (`if C_EventUtils and C_EventUtils.IsEventValid("LEARNED_SPELL_IN_TAB") then ...`). The repair mirrored the exact upstream guard into the old copy — matching what the addon's next release ships — after confirming no *unfixed higher-minor* copy existed that would win LibStub precedence and resurrect the bug.

**Generalizes to:** for any library error — `find` all copies, compare minors, read the upstream repo's current code, mirror it verbatim.

## 7. Frame-shape collision

**Signature A:** `attempt to index local 'parent' (a nil value)` — code did `frame:GetParent():GetCenter()` on a Blizzard button that the new client creates parentless (`MiniMapTracking`).
**Signature B:** `attempt to call a nil value` calling `SetTexture` — an addon's create-or-adopt helper grabbed a global by name (`PetFrameMyHealPredictionBar`) that the new client now defines itself, as a *Frame*, not the Texture the addon expected.

**Diagnosis that mattered:** the error's **Locals block** — it showed the object's real type and creation site (`<PetFrame.xml:107>` vs `<Addon.lua:239>`), turning a mystery nil into a name collision in one read.

**Fix patterns:** for A, restore the invariant the code relies on (parent the orphan) rather than nil-guarding every use; for B, make adoption defensive — only reuse a same-named global if `IsObjectType("Texture")` AND `GetParent() == expected` — leaving Blizzard's objects untouched. Bonus rule from the same repair: `HookScript`, never `SetScript`, on Blizzard frames' handlers (SetScript clobbers native behavior silently).

**Generalizes to:** read Locals before theorizing; when a client update ships same-named UI elements, collision-proof the addon's creation path instead of renaming Blizzard's world.
