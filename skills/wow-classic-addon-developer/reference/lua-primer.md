# Lua 5.1 primer (WoW-flavored)

WoW runs Lua 5.1. Six everyday types, one data structure (the table), and a pattern engine that only *looks* like regex. For the sandboxed stdlib (`os`/`io` removed — `time`/`date`/`difftime` survive as bare globals), global/taint rules, and string/table micro-perf, see [SKILL.md](../SKILL.md) and [best-practices.md](best-practices.md) — not repeated here.

## Types & truthiness

`nil`, `boolean`, `number`, `string`, `table`, `function`. `type(v)` returns the name. Numbers are one type — **no int/float distinction** (`2^10`, `3/2 == 1.5`).

```lua
type(42)    -- "number"   (no int vs float)
type({})    -- "table"
type(print) -- "function"

-- ONLY nil and false are falsy. 0, "", {} are ALL truthy:
if 0 then  --[[ runs ]] end
if "" then --[[ runs ]] end
local n = UnitLevel("target")   -- nil if invalid
if not n then return end        -- guard the nil, NOT `n == 0`
```

## Variables & assignment

Globals by default; prefer `local` (see scope notes). Unassigned reads as `nil`. Multiple assignment spreads right-to-left; extra targets get `nil`.

```lua
local a, b, c = 1, 2        -- c == nil
a, b = b, a                 -- swap, no temp
local hp, max = UnitHealth("player"), UnitHealthMax("player")
```

## Operators

Arithmetic `+ - * / % ^` (unary `-`). **No `//`, no `++`/`+=`.** Concat `..` (numbers auto-coerce). Relational `== ~= < > <= >=` — inequality is **`~=`, not `!=`**, and `==` never coerces types. Logical `and`/`or`/`not` short-circuit and **return operands, not booleans**. Length `#`. Precedence high→low: `^` > `not # -(unary)` > `* / %` > `+ -` > `..` > relational > `and` > `or` (`^` and `..` right-associative).

```lua
print(math.floor(7/2))      -- 3   (no // operator)
print("dmg: " .. 1500)      -- "dmg: 1500"
print(0 == "0")             -- false (== never coerces)
local name = UnitName("target") or "nobody"   -- default-value idiom
local kind = dmg >= 0 and "heal" or "hit"      -- ternary
-- PITFALL: ternary breaks when the true-branch is itself false/nil:
local v = cond and false or true   -- ALWAYS true; use a real if
```

## Control structures

`then`/`do`/`end` required; no parens needed. Numeric `for` bounds are **inclusive**, step optional (negatives allowed), loop var is loop-local. `pairs` = all keys, any order; `ipairs` = `1,2,3…` until the first `nil`. `repeat…until` runs at least once. `break` exits the innermost loop — **there is no `continue`**.

```lua
for i = 1, GetNumGroupMembers() do ... end    -- inclusive
for i = #t, 1, -1 do table.remove(t, i) end    -- reverse, negative step
for k, v in pairs(opts)  do ... end            -- whole table, any order
for i, v in ipairs(list) do ... end            -- array part, in order

for _, u in ipairs(units) do                   -- no `continue`: invert it
  if not UnitIsDead(u) then
    -- work
  end
end
repeat poll() until done                        -- body runs once minimum
```

## Functions

First-class values with **multiple return values**, varargs `...` + `select` (event payloads use this), `:` colon sugar that passes `self`, and closures over upvalues.

```lua
local function minmax(t)
  local lo, hi = t[1], t[1]
  for i = 2, #t do
    if t[i] < lo then lo = t[i] end
    if t[i] > hi then hi = t[i] end
  end
  return lo, hi                       -- multiple returns
end
local a, b = minmax({3,1,9})          -- 1, 9

local function sum(...)
  local s = 0
  for i = 1, select("#", ...) do s = s + select(i, ...) end
  return s                            -- select('#') counts args incl. nils
end

function frame:OnClick(btn) print(self, btn) end  -- self == frame
frame:OnClick("LeftButton")

local function counter()              -- closure captures `n` as upvalue
  local n = 0
  return function() n = n + 1; return n end
end
```

## Tables

The only data structure — arrays, dicts, objects, namespaces. **Array part is 1-based.** `t.k` is sugar for `t["k"]` (identifier keys only). `#t` is the array length but **undefined when holes exist**.

```lua
local t = { "a", "b", "c" }                 -- t[1] == "a"  (1-based!)
local c = { name = "Sky Golem", id = 522 }  -- hash part
c.id            -- 522 (sugar);  c["my key"] needs brackets
local nest = { { id = 522, name = "Sky Golem" } }
nest[1].name    -- "Sky Golem"  (nested)

local s = { [1]="a", [2]="b", [4]="d" }     -- hole at 3
for i,v in ipairs(s) do end                 -- stops after "b" (first nil)
print(#s)                                    -- 2 OR 4: undefined with holes

table.insert(t, "d")            -- append
table.insert(t, 1, "z")         -- insert at index, shifts up
table.remove(t, 2)              -- remove & shift down, returns removed
table.sort(t, function(x,y) return x > y end)  -- in-place, custom order
local line = table.concat(t, ", ")             -- join (see perf notes)

local Bag = {}; Bag.__index = Bag              -- table as object
function Bag.new() return setmetatable({ items = {} }, Bag) end
function Bag:add(x) table.insert(self.items, x) end
```

## Strings & patterns

Strings are immutable; call methods with `:`. `string.format` builds text. **Lua patterns are NOT regex** — smaller, faster, different syntax (no `|`, no `{n,m}`).

```lua
string.format("WTS %dx %s for %dg", 6, "Apples", 30)  -- %d %s %f %x
("hp:%d"):format(100)            -- :method form (the string is self)
("HELLO"):lower()                -- "hello"

string.match("level 60 mage", "%d+")          -- "60"
string.find("a.b", "%.")                       -- 2,2  (escape magic '.')
for w in string.gmatch("a,b,c", "[^,]+") do end  -- iterate fields
string.gsub("hello", "l", "L")                 -- "heLLo", 2  (also count)
string.match("04/19/64", "(%d+)/(%d+)/(%d+)")  -- "04","19","64" (captures)
string.match(" trim ", "^%s*(.-)%s*$")         -- "trim" (anchors, lazy -)
```

Classes: `.` any · `%d` digit · `%a` letter · `%s` space · `%w` alphanumeric · `%u`/`%l` upper/lower · `%p` punct — **capital negates** (`%D` = non-digit). Quantifiers: `+` 1+, `*` 0+, `-` 0+ lazy, `?` 0/1. `()` captures, `^ $` anchor start/end. Escape magic chars `^$()%.[]*+-?` with `%`.

## Metatables (brief)

A table's metatable hooks operations. The key one is `__index`, consulted when a key is **missing**: as a *table* it's a fallback (defaults/inheritance); as a *function* it computes on miss. This is exactly what AceDB defaults and the localization table use. `__newindex` hooks writes; `__call` makes a table callable.

```lua
-- __index as TABLE: defaults / inheritance
local defaults = { volume = 1.0, enabled = true }
local cfg = setmetatable({}, { __index = defaults })
cfg.volume          -- 1.0   (missing on cfg → falls through to defaults)
cfg.volume = 0.5    -- writes to cfg, shadowing the default

-- __index as FUNCTION: compute on miss (the localization trick)
local L = setmetatable({}, { __index = function(_, k) return k end })
L["Not translated"] -- "Not translated"  (returns the key itself)
```

## Errors: `pcall` / `error` / `assert`

Runtime errors (indexing nil, calling a nil, bad arithmetic) *propagate* and abort the running handler. Catch them with `pcall` (protected call) — it returns `ok, ...` instead of throwing:

```lua
local ok, err = pcall(risky, arg)            -- ok=false, err=message on failure
if not ok then geterrorhandler()(err) end    -- re-surface via WoW's handler (see best-practices.md)

assert(cond, "msg")                          -- errors with "msg" if cond is falsy
error("bad state")                           -- raise manually (prefixes file:line)
```

Don't blanket-`pcall` your whole addon — let logic errors surface (BugSack shows them); protect only *boundaries* (event dispatch, callbacks, savedvars migration). See [best-practices.md](best-practices.md).

## Gotchas

- **1-based** indexing; `t[0]` is just a hash key, ignored by `#`/`ipairs`.
- Setting a key to `nil` **deletes** it; a `nil` hole in the array part ends `#`/`ipairs` early.
- Reading an unset variable/field gives `nil` silently — typos don't error (lint with luacheck).
- No int type, no `//`: use `math.floor(a/b)`; `5/2 == 2.5`.
- `==` on tables compares **identity**, never contents.
- No `++`/`+=`/`!=`: write `x = x + 1` and `~=`.
- `and`/`or` return operands, so `a and b or c` misfires when `b` is falsy.
- **`nil` in arithmetic/concat/comparison throws** — `x .. nil`, `nil + 1`, `nil < 2` all error (unlike *reading* a nil field, which is silent). Guard API returns before combining them.

For depth, see *Programming in Lua*: https://www.lua.org/pil/
