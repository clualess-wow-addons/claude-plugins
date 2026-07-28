#!/usr/bin/env lua
-- export-errors.lua — digest BugGrabber's saved errors for repair triage.
--
-- Usage:
--   lua export-errors.lua "<WoW flavor dir, e.g. .../_classic_era_>" [--all-sessions]
--   lua export-errors.lua "<path to a !BugGrabber.lua SavedVariables file>" [--all-sessions]
--
-- Reads WTF/Account/*/SavedVariables/!BugGrabber.lua (written on logout//reload
-- by the standalone !BugGrabber addon), groups errors by addon and file, and
-- marks the first error per file as the ROOT CANDIDATE (see the skill's cascade
-- rule). Default shows only the latest session per account; --all-sessions shows
-- everything retained.

local args = {...}
local target = args[1]
local allSessions = false
for i = 2, #args do
  if args[i] == "--all-sessions" then allSessions = true end
end
if not target then
  io.stderr:write("usage: lua export-errors.lua <wow-flavor-dir | !BugGrabber.lua> [--all-sessions]\n")
  os.exit(2)
end

local function isFile(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

-- Collect candidate SavedVariables files
local files = {}
if target:match("%.lua$") and isFile(target) then
  files[#files + 1] = target
else
  -- shell out for globbing; ls is POSIX enough for WTF layouts
  local cmd = ('ls -1 "%s"/WTF/Account/*/SavedVariables/!BugGrabber.lua 2>/dev/null'):format(target)
  local p = io.popen(cmd)
  if p then
    for line in p:lines() do files[#files + 1] = line end
    p:close()
  end
end
if #files == 0 then
  io.stderr:write("No !BugGrabber.lua found. Checklist:\n")
  io.stderr:write("  1) standalone !BugGrabber addon installed? (embedded copies do NOT persist errors)\n")
  io.stderr:write("  2) did the game /reload or log out since the errors? (SavedVariables flush only then)\n")
  io.stderr:write("  3) path correct? expected <flavor dir>/WTF/Account/<ACCOUNT>/SavedVariables/!BugGrabber.lua\n")
  os.exit(1)
end

-- Parse "Interface/AddOns/<Addon>/<file>" (slashes vary) or [string "*Addon.xml..."]
local function attribute(msg)
  local addon, file, line =
    msg:match("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\](.-%.lua):(%d+)")
  if addon then return addon, addon .. "/" .. file:gsub("\\", "/"), tonumber(line) end
  local xml = msg:match('%[string "%*(.-%.xml)')
  if xml then return "(xml)" .. xml, xml, nil end
  -- BugGrabber sometimes prefixes "AddonName: message"
  local pfx = msg:match("^([%w_%-!]+):%s")
  if pfx then return pfx, "(no file)", nil end
  return "(unattributed)", "(no file)", nil
end

local function truncate(s, maxLines)
  if not s then return nil end
  local out, n = {}, 0
  for l in s:gmatch("[^\n]+") do
    n = n + 1
    if n > maxLines then
      out[#out + 1] = ("  ...(%d more lines truncated)"):format(select(2, s:gsub("\n", "")) + 1 - maxLines)
      break
    end
    out[#out + 1] = l
  end
  return table.concat(out, "\n")
end

for _, path in ipairs(files) do
  -- SavedVariables are plain Lua assignments; execute in an isolated env (Lua 5.2+)
  local env = {}
  local chunk, err = loadfile(path, "t", env)
  if not chunk then
    io.stderr:write(("PARSE FAILURE %s: %s\n"):format(path, err))
  else
    local ok, rerr = pcall(chunk)
    if not ok then
      io.stderr:write(("EXEC FAILURE %s: %s\n"):format(path, rerr))
    else
      local db = env.BugGrabberDB or {}
      local errors = db.errors or {}
      local latest = db.session or -1
      local account = path:match("Account/([^/]+)/") or path
      print(("################ ACCOUNT %s — %d stored error(s), latest session %d")
        :format(account, #errors, latest))

      -- group: addon -> file -> ordered error list (keeping stored order)
      local groups, addonOrder = {}, {}
      local shown = 0
      for _, e in ipairs(errors) do
        if allSessions or e.session == latest then
          shown = shown + 1
          local addon, file = attribute(e.message or "?")
          if not groups[addon] then groups[addon] = { order = {}, files = {} } addonOrder[#addonOrder + 1] = addon end
          local g = groups[addon]
          if not g.files[file] then g.files[file] = {} g.order[#g.order + 1] = file end
          table.insert(g.files[file], e)
        end
      end
      if shown == 0 then
        print(("  (no errors in latest session %d — pass --all-sessions for %d retained older ones)")
          :format(latest, #errors))
      end

      for _, addon in ipairs(addonOrder) do
        local g = groups[addon]
        print(("\n======== %s"):format(addon))
        for _, file in ipairs(g.order) do
          for i, e in ipairs(g.files[file]) do
            local tag = (i == 1) and "ROOT CANDIDATE (first error in this file)"
                                  or  "possible CASCADE or deferred (see skill step 1)"
            print(("\n-- [%s] session %s | x%s | %s"):format(tag, e.session or "?", e.counter or "?", e.time or "?"))
            print("Message: " .. (e.message or "?"))
            if e.stack  then print("Stack:\n"  .. truncate(e.stack, 25)) end
            if e.locals then print("Locals:\n" .. truncate(e.locals, 40)) end
          end
        end
      end
      print("")
    end
  end
end
