---
name: wow-classic-addon-repair
description: Use when a WoW Classic Era addon throws Lua errors after a client patch or stops working — "attempt to call a nil value", "hooksecurefunc(): X is not a function", "Attempt to register unknown event", XML "Unknown function" warnings, BugSack/BugGrabber error dumps, or a third-party addon broken by removed/renamed APIs that needs a local fix.
---

# WoW Classic Addon Repair

## Overview

Repairing third-party addons broken by client patches. Core principle: **verify every symbol against the live client source before patching — never patch from memory, and never suppress.** A modern replacement always exists or the feature is genuinely gone; both outcomes beat a pcall wrapper.

For writing your own addons use `wow-classic-addon-development`; for taint/`ADDON_ACTION_BLOCKED` problems (a different discipline) see that skill's secure-and-taint reference.

## The triage workflow

Copy this checklist and track progress per broken addon:

```
Repair Progress:
- [ ] 1. Collect the FIRST error per file (cascade rule)
- [ ] 2. Classify each root error by signature
- [ ] 3. Verify the symbol against live client source
- [ ] 4. Patch minimally with the verified replacement
- [ ] 5. luac -p every edited file
- [ ] 6. Trace the rest of the load path
- [ ] 7. Check embedded-library copies
- [ ] 8. Note the lifecycle caveat
```

**Step 1 — Collect errors; apply the cascade rule.** From BugSack/BugGrabber or the default error frame. A Lua file is one chunk: when it aborts at line N, everything it would have defined after N doesn't exist — so later errors like `attempt to index global 'X' (a nil value)` from XML OnLoad handlers, `table index is nil` in data files, and "Unknown function Y in element OnLoad" warnings are usually **cascades, not bugs**. Fix the first error per file; re-test (`/reload`, clear the error log, re-exercise the addon); only then treat survivors as real. Caveat: dumps can mix load-time chunk errors with *deferred* errors from inside functions (event handlers, clicks) that ran later or in a previous session — the cascade rule applies to the load-time ones; a later-line error from the same file may simply be code that only runs post-login.

**Step 2 — Classify by signature.** Use the quick-reference table below. The three big families: removed global *function* (call/hook sites), removed *event*, renamed *XML template*.

**Step 3 — Verify before patching.** The authoritative source is Blizzard's client UI dump: `github.com/Gethe/wow-ui-source`, branch `classic_era`. Fetch raw files (`raw.githubusercontent.com/Gethe/wow-ui-source/classic_era/Interface/AddOns/...`) or list the tree via `gh api "repos/Gethe/wow-ui-source/git/trees/classic_era?recursive=1"`. Event validity: `C_EventUtils.IsEventValid("NAME")` in-game, or grep `Blizzard_APIDocumentationGenerated/`. **A plausible replacement from memory is the enemy** — signatures change (see the swapped-argument trap in the replacement map).

**Step 4 — Patch minimally.** Match the addon's existing style. Preferred patterns: a local alias at the top of the file (`local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata`), an instance-method hook replacing a global hook (`hooksecurefunc(TargetFrame, "Update", ...)` — mind that method hooks receive `self`), or a feature-detect branch (`if C_EventUtils.IsEventValid(...)`). When the old and new API differ in argument order or the handler's signature, write a 3-line wrapper preserving the legacy call shape rather than touching every call site. If functionality has NO modern equivalent (it happens — see the map), disable that one feature behind an existence check **with a comment saying why**; that's honest degradation, not suppression.

**Step 5 — Syntax-check.** `luac -p <file>` after every edit. Note: WoW's Lua (5.1) accepts invalid string escapes that modern luac rejects — 5.1 drops the backslash of an unknown escape, so `"\U"` reads as `"U"`. Rewrite to produce the SAME runtime bytes: usually delete the stray backslash (`"Images\\\UI-..."` → `"Images\\UI-..."`); never blindly double it (`"\U"` → `"\\U"` *changes* the string to backslash+U).

**Step 6 — Trace the rest of the load path.** Fixing the reported line just lets the file run further. Grep the whole file (and other files in the .toc load order) for every other reference to removed-API families before declaring victory — otherwise the error moves to the next line and you'll be back tomorrow. Also scan functions called from `ADDON_LOADED`/`PLAYER_LOGIN` handlers and the addon's slash-command/options paths (the next click can be the next error).

**Step 7 — Embedded libraries.** If the broken code is a LibStub library inside the addon: `find` ALL copies of it across the AddOns folder and compare `MINOR_VERSION`s. The hazard runs in BOTH directions: *runtime* API calls resolve to the **highest** minor (a fix to a lower copy is silently defeated by an unfixed higher copy), but *load-time* side effects in the file body — `RegisterEvent`, frame creation — run from **every** copy as it loads, so the first/lowest copy can throw even when all higher copies are already fixed. Audit all copies: patch any with broken load-time code, and confirm the highest minor carries the fix for runtime behavior. Check whether the library's upstream repo already fixed it and mirror that fix verbatim (so the next addon release ships it identically).

**Step 8 — Lifecycle.** Local patches to unversioned third-party addons are **overwritten by every CurseForge/Wago update**. Prefer the author's updated release when one exists; report genuine bugs upstream; keep a note of what you patched so it can be re-applied or checked after updates.

## Quick reference — error signature → diagnosis

| Signature | Likely cause | Fix pattern |
|---|---|---|
| `attempt to call a nil value` at file load | Removed global API (e.g. the flat AddOn functions) | Local alias to the `C_*` namespace equivalent; check arg order |
| `hooksecurefunc(): X is not a function` | Global function became a mixin method | `hooksecurefunc(FrameInstance, "Method", ...)`; handler now receives `self` |
| `Attempt to register unknown event "X"` | Event removed/renamed | Feature-detect with `C_EventUtils.IsEventValid`; often an already-registered sibling event covers it |
| XML `Unknown function Y in element OnLoad` | Usually a CASCADE — the Lua file defining Y aborted earlier | Fix the file's first error; re-check |
| `table index is nil` in a data file | Usually a CASCADE — globals it indexes with were never defined | Fix the defining file's first error |
| `Unknown frame template: X` / inherits failure | XML template renamed (case changes happen) | grep the live client dump for the current template name |
| `SetFont(): Invalid font asset` | A FontObject NAME passed where a font FILE path is required (old clients tolerated it) | `FontObject:GetFont()` to resolve the real path |
| `attempt to index local 'x' (a nil value)` in frame code | A frame the addon assumes exists changed shape (nil parent, renamed child, Frame where Texture expected) | Read the error's Locals block; verify the frame's current XML in the client dump; adopt/create defensively with type + parent checks |
| Script ran too long (`LUA_WARNING`, execution time limit) | Performance watchdog, NOT a crash — and the stack often points at an innocent bystander, not the spender | Usually ignore if Count:1; investigate only if recurring |

## Red flags — stop and return to the workflow

- "I'll just wrap it in pcall" — suppression leaves the feature broken and hides the next regression. (In WeakAuras custom code pcall is blocked anyway.)
- "The replacement is probably C_Foo.Bar" — *probably* is not verified; signatures and argument orders change.
- "Fixed the reported line, done" — you fixed the first domino. Run step 6.
- "These five errors are five bugs" — count the files, not the errors. Run step 1.
- "The library fix works" — did you check for higher-minor embedded copies? Run step 7.

## References

- [references/era-1158-replacement-map.md](references/era-1158-replacement-map.md) — the verified removed→replacement map from the 1.15.8 client refactor (the biggest breakage event to date), plus diagnosis commands.
- [references/case-studies.md](references/case-studies.md) — seven real repairs as generalized patterns: what the error looked like, what the root cause was, what the fix pattern generalizes to.
