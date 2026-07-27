# Testing & running your addon offline

**100% offline is impossible** — secure/taint, the render loop, real event timing, and live game state only exist in the client. But you can verify most of your code on three offline layers and reserve the client for the thin part that genuinely can't be faked.

**Layer 0 is static** — before any of this, lint with **luacheck** and the **Lua Language Server** (+ **selene** / **StyLua**); those live in [best-practices.md](best-practices.md). This file is *execution*: running your code without the game. Most authors get **80–90% of bugs offline** (syntax, typos, undefined globals, wrong arg counts, logic) this way.

**The ceiling — what still needs the client:** secure-frame/taint/combat-lockdown behavior, real event firing/timing, the frame/render system (`OnUpdate`, layout, textures), and live game state (real `CombatLogGetCurrentEventInfo`, casting, unit/aura queries). Iterate those in-game with `/reload` + **BugSack** + **!BugGrabber**, or the in-client runner **WoWUnit** (Classic-current; the older **QhunUnitTest** was never updated past Legion). One partial exception for taint: **Meorawr/elune** is a Lua 5.1 VM that implements WoW's taint model, so it can reproduce taint / "action blocked" logic offline — it has no frames or `C_*` API, you still stub those.

## Layer 1 — pure logic (no mocks)

Push parsers, math, state machines, and formatting into plain modules that `return` a table, then test directly with **busted** (the standard Lua test runner):

```lua
-- spec/parse_spec.lua — stub the globals the module touches, THEN require it
_G.CombatLogGetCurrentEventInfo = function()
    return 1000, "SPELL_DAMAGE", false, "Player-1-AAA", "Caster", 0,0, "Creature-0-BBB", "Boar", 0,0, 133, "Fireball"
end
local parse = require("MyAddon.parse")
describe("parse", function()
    it("reads the subevent", function()
        assert.are.equal("SPELL_DAMAGE", parse.ReadCurrentEvent().subevent)
    end)
end)
```

## Layer 2 — API-touching code (mock the WoW API)

You're **not** limited to pure logic. Stub `CreateFrame` as a *recording* table and fire events into the captured handler yourself — this tests wiring + event behavior with no game running:

```lua
-- spec/frame_spec.lua  (verified: 5/5 under busted)
local registered, scripts = {}, {}
_G.CreateFrame = function() return {
    RegisterEvent = function(_, e) registered[e] = true end,
    SetScript     = function(_, s, fn) scripts[s] = fn end,
} end
_G.UnitName = function() return "Tester" end
require("addon")                              -- your file: CreateFrame -> RegisterEvent -> SetScript("OnEvent", ...)

it("registers + greets on login", function()
    assert.is_true(registered["PLAYER_LOGIN"])
    local out; _G.print = function(s) out = s end
    scripts.OnEvent(nil, "PLAYER_LOGIN")     -- fire the captured handler ourselves
    assert.equal("Hi Tester", out)
end)
```

You only mock the APIs your code actually calls — usually a handful. (For a bigger hand-mock surface **Adirelle/wowmock** loads your file under a mocked `_G` via `setfenv`, but it's **abandoned since 2014**; prefer wowless below.) Generate stub lists from Blizzard's API dumps at **Gethe/wow-ui-source** (`classic_era` branch).

## Layer 2½ — load the whole addon (wowless)

Beyond hand-mocks, **[wowless](https://github.com/wowless/wowless)** is a headless WoW client: it loads your real `.toc` + Lua + XML and *runs* them against a near-complete, auto-generated API surface (`CreateFrame`, frames, events, `C_*` namespaces). It targets **Classic Era as a first-class product** (`wow_classic_era`) and executes Blizzard's actual `classic_era` FrameXML rather than guessing returns — firing `ADDON_LOADED`/`PLAYER_LOGIN`, invoking your slash commands, and persisting SavedVariables — so it's a real *load / smoke / integration* test, complementary to busted's unit tests. **Verified hands-on:** it loaded a skill-built Classic Era addon end-to-end (`C_Timer.After`, events, SavedVariables, and a slash command all ran) and caught an injected typo with a `file:line` traceback.

**Run it (Docker-only):** `cp .env.dist .env && docker compose -f .devcontainer/docker-compose.yml up -d --build`, then inside the container `git submodule update --init --depth 1 && cmake --preset default && bin/run.sh wow_classic_era --addondir path/to/MyAddon` (first build ~5–10 min; it builds an `elune`-based Lua 5.1 + downloads the Era interface via TACT). **Gotchas:** the runner is **silent at the default log level** — add `-l 9` to watch the load/event lifecycle (and `-d graph.dot` to dump the addon dependency graph); and it **prints `error:` lines but still exits 0**, so gate CI on the output (or `--maxerrors 1`), not the exit code. Still pre-alpha (an error it reports may be wowless's own, not yours), and it's its own runner — no busted integration.

## Layer 3 — CI

Run the whole offline stack on every push (alongside the luacheck + `lua-language-server --check` jobs from [best-practices.md](best-practices.md)):

```yaml
# .github/workflows/test.yml — the robust pattern (mirrors Questie's CI)
on: [push, pull_request]
jobs:
  busted:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: leafo/gh-actions-lua@v13      # real Lua 5.1 — matches the client VM
        with: { luaVersion: "5.1" }
      - uses: leafo/gh-actions-luarocks@v6
      - run: luarocks install busted
      - run: luarocks install bit32          # see gotcha below
      - run: busted .
```

- **Gotcha — the `bit` library.** The client ships a global `bit` (`bit.band`/`bit.bor`, used in every CLEU flag test) that stock PUC Lua 5.1 lacks. If your specs touch bitwise code, `luarocks install bit32` and alias it (`bit = bit or require("bit32")`) or CI dies on `nil`. (Questie installs `bit32` for exactly this.)
- The bare `{uses: lunarmodules/busted@v0}` container also works for pure-logic specs with no native deps.
- **Coverage:** add **luacov** — `busted --coverage` writes `luacov.stats.out`; a `.luacov` file with an `exclude` list keeps your stubs/specs out of the percentage. Upload to Codecov via `codecov/codecov-action`.
- The **runeberry/wow-addon-container** Docker image bundles 5.1 + busted + luacov locally (unmaintained since 2020, the 5.1 env still runs).

## The offline toolkit at a glance

| Tool | What it does | Offline | Era-ready |
|---|---|---|---|
| **luacheck** | lint: leaked globals, typos, unused, style | ✅ | ✅ *verified* |
| **selene** | 2nd lint pass (Rust, different rules) | ✅ | ✅ `lua51` std; WoW globals = community gist |
| **StyLua** | auto-formatter (Rust); `syntax="Lua51"` | ✅ | ✅ |
| **Lua Language Server** + Ketho types | type-check + editor IntelliSense; `--check` in CI | ✅ | ✅ *verified* (Ketho ships a `vanilla-1.15.8` set) |
| **busted** + mock-what-you-use | unit tests (logic **and** mocked API-touching code) | ✅ | ✅ *verified* |
| **wowless** | headless client: loads your whole addon vs a real Era API surface | ✅ | ✅ **runs Classic Era** *(verified hands-on)*; pre-alpha, Docker |
| **luacov** | line coverage for busted specs | ✅ | ✅ |
| **Meorawr/elune** | Lua 5.1 VM with WoW's **taint** model — repro "action blocked" offline | ✅ | ✅ taint only; quiet since 2024 |
| **runeberry/wow-addon-container** | Docker Lua 5.1 + busted + luacov | ✅ | works; unmaintained (2020) |
| **Mechanic** | sandbox w/ 5000+ auto-generated API stubs, `mech` CLI | ✅ | built for **mainline 12.0** — Era unverified (use wowless) |
| **Adirelle/wowmock** | broader `_G` mock loader for busted | ✅ | ❌ **abandoned (2014) — use hand-mocks / wowless** |
| **WoWUnit** | in-client test runner | ❌ in-game | ✅ (TOC 11507) |
| **QhunUnitTest** | in-client test runner | ❌ in-game | ❌ **Legion-only (70300), never updated — use WoWUnit** |
| **WoWBench** | offline API emulator | — | ❌ **dead (2006, Lua 5.0) — use wowless** |

## Don't use these (abandoned — listed *only* so you don't rediscover them and waste a day)

Each surfaces in web searches and old forum threads and looks plausible. On Classic Era 1.15.x they're dead ends — **reach for the live replacement instead:**

- **WoWBench** → use **wowless** (or **busted** + mocks). ❌ Dead since 2006 (Lua 5.0, Windows): the source won't even parse on Lua 5.1+, and its stubs predate every modern API (`C_Timer`, `C_Container`, `CombatLogGetCurrentEventInfo`, `BackdropTemplate`, secure templates) — an Era addon hits `nil` on the first call.
- **Adirelle/wowmock** → use **mock-what-you-use** (hand-stub the few APIs you call), or **wowless** for the full surface. ❌ Abandoned (last commit 2014); only ever stubbed a tiny `_G` subset.
- **QhunUnitTest** → use **WoWUnit** (multi-flavor, includes Era). ❌ Never updated past Legion (`## Interface: 70300`, 2018); unsupported on 1.15.x.
- **mpeterv/luacheck** → use **lunarmodules/luacheck** (the maintained fork every rock and GitHub Action points to). ❌ Original repo abandoned.

Two more that aren't dead but still aren't the Era answer: **Mechanic** is actively built but for **mainline** 12.0 (its stubs are unverified on 1.15.x) — **wowless** targets `wow_classic_era` directly; **runeberry/wow-addon-container** still runs but is unmaintained since 2020 — the **leafo/gh-actions-lua + luarocks** CI pattern above supersedes it.
