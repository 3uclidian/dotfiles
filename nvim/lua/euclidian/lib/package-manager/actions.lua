local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local command = require("euclidian.lib.command")
local dialog = require("euclidian.lib.dialog")
local packagespec = require("euclidian.lib.package-manager.packagespec")
local set = require("euclidian.lib.package-manager.set")
local z = require("euclidian.lib.async.zig")

local actions = {
   listSets = nil,
   update = nil,
   install = nil,
   add = nil,
}

local Spec = packagespec.Spec
local Dialog = dialog.Dialog
local function setCmp(a, b)
   return a:title() < b:title()
end

local function createDialog(fn)
   return function()
      local d = dialog.centered(35, 17)
      return z.async(fn, d)
   end
end

local function waitForKey(d, ...)
   local keys = { ... }
   local function delKeymaps()
      for _, key in ipairs(keys) do
         d:delKeymap("n", key)
      end
   end
   local pressed
   local me = assert(z.currentFrame(), "attempt to waitForKey not in a coroutine")
   for _, key in ipairs(keys) do
      d:addKeymap("n", key, function()
         pressed = key
         delKeymaps()
         z.resume(me)
      end, { noremap = true, silent = true })
   end
   z.suspend()
   return pressed
end

actions.listSets = createDialog(function(d)

   repeat
      local pkgs = set.list()
      table.sort(pkgs)

      d:setLines(pkgs):
      fitText(35, 17):
      center()

      if waitForKey(d, "<cr>", "<bs>") == "<bs>" then
         break
      end

      local choice = d:getCurrentLine()
      local loaded = set.load(choice)

      table.sort(loaded, setCmp)
      local txt = {}

      for i, v in ipairs(loaded) do
         txt[i] = v:title()
      end

      d:setLines(txt):
      fitText(35, 17):
      center()

   until waitForKey(d, "<cr>", "<bs>") == "<cr>"

   d:close()
end)

local function chooseAndLoadSet(d)
   local pkgs = set.list()
   table.sort(pkgs)

   d:setLines(pkgs):
   fitText(35, 17):
   center()

   waitForKey(d, "<cr>")

   local name = d:getCurrentLine()
   return set.load(name), name
end

local function prompt(d, promptText)
   local f = z.currentFrame()
   local val
   d:setPrompt(promptText, function(s)
      print("Prompt: ", s)
      val = s
      d:unsetPrompt()
      vim.schedule(function()
         z.resume(f)
      end)
   end)
   z.suspend()
   return val
end

local function yesOrNo(d, pre, affirm, deny)
   affirm = affirm or "yes"
   deny = deny or "no"
   d:setLines({
      pre,
      affirm,
      deny,
   })
   local ln
   repeat
      waitForKey(d, "<cr>")
      ln = d:getCursor()
   until ln > 1
   return ln == 2
end

local checkKey = "a"
local function checklist(d, pre, opts)
   local lines = {}
   for i, v in ipairs(opts) do
      lines[i] = "[ ] " .. v
   end
   table.insert(lines, 1, pre)
   d:setLines(lines):fitText():center()
   d:addKeymap("n", checkKey, function()
      local ln = d:getCursor()
      local l = d:getLine(ln)
      d:setText({ {
         l:match("^%[%*") and " " or "*", ln - 1, 1, ln - 1, 2,
      }, })
   end, { silent = true, noremap = true })
   waitForKey(d, "<cr>")
   d:delKeymap("n", checkKey)
   local selected = {}
   for i, v in ipairs(d:getLines(1, -1)) do
      if v:match("^%[%*") then
         table.insert(selected, i)
      end
   end
   return selected
end

do
   local function addVimPlugPackage()
      print("Vim Plug Package: not yet implemented")
   end
   local function addPackerPackage()
      print("Packer Package: not yet implemented")
   end
   local function addGitPackage(d, s)
      d:setLines({})
      local repo = prompt(d, "Repo: ")
      local pkgNames = {}
      for i, v in ipairs(s) do
         pkgNames[i] = v:title()
      end
      local p = {
         kind = "git",
         dependents = {},
         repo = repo,
      }
      if yesOrNo(d, "Does this package depend on other packages?") then
         local deps = checklist(d, "Dependencies:", pkgNames)
         for _, idx in ipairs(deps) do
            if not s[idx].dependents then
               s[idx].dependents = {}
            end
            table.insert(s[idx].dependents, p)
         end
      end
      if yesOrNo(d, "Do other packages depend on this package?") then
         local deps = checklist(d, "Dependents:", pkgNames)
         for _, idx in ipairs(deps) do
            table.insert(p.dependents, s[idx])
         end
      end
      print("Pre insert length: ", #s)
      table.insert(s, p)
      print("Post insert length: ", #s)
      for i, v in ipairs(s) do
         print(i, v.repo)
      end
   end
   local function addLocalPackage()
      print("Local package: Not yet implemented")
   end
   local handlers = {
      [1] = addVimPlugPackage,
      [2] = addPackerPackage,
      [3] = addGitPackage,
      [4] = addLocalPackage,
   }

   actions.add = createDialog(function(d)
      local loaded, name = chooseAndLoadSet(d)

      d:setLines({
         "Add new package:",
         "  from Vim-Plug expression",
         "  from Packer expression",
         "  git",
         "  local",
      }):fitText():center()

      local ln
      repeat
         waitForKey(d, "<cr>")
         ln = d:getCursor()
      until ln > 1

      set.save("." .. name .. "__bak", loaded)
      handlers[ln - 1](d, loaded)
      set.save(name, loaded)
      d:close()
   end)
end

local maxConcurrent = 2
actions.update = createDialog(function(d)
   local loaded = chooseAndLoadSet(d)

   local lines = {}
   for i, pkg in ipairs(loaded) do
      lines[i] = " " .. pkg:title() .. " "
   end
   d:setLines(lines):fitText():center()

   local main = z.currentFrame()

   local jobsleft = #loaded
   local running = 0

   local onCmdExit = vim.schedule_wrap(function()
      jobsleft = jobsleft - 1
      running = running - 1
      z.resume(main)
   end)

   local jobqueue = {}
   for i, pkg in ipairs(loaded) do
      if pkg.kind == "git" then
         local updateTxt = vim.schedule_wrap(function(ln)


            d:setLine(i - 1, " " .. pkg:title() .. ": " .. ln:sub(1, 20) .. " "):
            fitText():
            center()
         end)

         table.insert(jobqueue, function()
            running = running + 1
            command.spawn({
               command = { "git", "pull" },
               cwd = pkg:location(),
               onStdoutLine = updateTxt,
               onStderrLine = updateTxt,
               onExit = onCmdExit,
            })
         end)
      else
         jobsleft = jobsleft - 1
         d:setLine(i - 1, pkg:title() .. ": not a git package :D")
      end
   end

   while jobsleft > 0 do
      while running < maxConcurrent and #jobqueue > 0 do
         table.remove(jobqueue, math.random(1, #jobqueue))()
      end
      z.suspend()
   end

   waitForKey(d, "<cr>")
   d:close()
end)

actions.install = createDialog(function(d)
   local loaded = chooseAndLoadSet(d)

   local lines = {}
   for i, pkg in ipairs(loaded) do
      lines[i] = " " .. pkg:title() .. " "
   end
   d:setLines(lines):fitText()

   local main = z.currentFrame()

   local jobsleft = #loaded
   local running = 0

   local onCmdExit = vim.schedule_wrap(function()
      jobsleft = jobsleft - 1
      running = running - 1
      z.resume(main)
   end)

   local jobqueue = {}
   for i, pkg in ipairs(loaded) do
      if pkg:isInstalled() then
         if pkg.kind == "git" then
            local updateTxt = vim.schedule_wrap(function(ln)


               d:setLine(i - 1, " " .. pkg:title() .. ": " .. ln:sub(1, 20) .. " "):
               fitText():center()
            end)

            table.insert(jobqueue, function()
               running = running + 1
               command.spawn({
                  command = { "git", "clone", "https://github.com/" .. pkg.repo, pkg:location() },
                  onStdoutLine = updateTxt,
                  onStderrLine = updateTxt,
                  onExit = onCmdExit,
               })
            end)
         else
            jobsleft = jobsleft - 1
            d:setLine(i - 1, pkg:title() .. ": not a git package :D")
         end
      else
         jobsleft = jobsleft - 1
         d:setLine(i - 1, pkg:title() .. ": already installed")
      end
   end

   while jobsleft > 0 do
      while running < maxConcurrent and #jobqueue > 0 do
         table.remove(jobqueue, math.random(1, #jobqueue))()
      end
      z.suspend()
   end

   waitForKey(d, "<cr>")
   d:close()
end)

return actions