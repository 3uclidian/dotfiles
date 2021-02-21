
local packagespec = require("euclidian.lib.package-manager.packagespec")
local cmd = require("euclidian.lib.package-manager.cmd")
local set = require("euclidian.lib.package-manager.set")
local nvim = require("euclidian.lib.nvim")
local dialog = require("euclidian.lib.dialog")
local ev = require("euclidian.lib.ev")

local a = vim.api

local Spec = packagespec.Spec
local Dialog = dialog.Dialog

local yield = coroutine.yield

local interface = {
   addPackage = nil,
   installSet = nil,
   updateSet = nil,
}

local function longest(lines)
   local idx, len = 1, #lines[1]
   for i = 2, #lines do
      if len < #lines[i] then
         len = #lines[i]
         idx = i
      end
   end
   return idx, lines[idx]
end

local floor, ceil = math.floor, math.ceil

local function accommodateText(d)
   local lines = d:getLines()
   local twid = longest(lines)
   local thei = #lines

   local col, row, wid, hei = dialog.centeredSize(twid, thei)
   d:setWin({ col = col, row = row, wid = wid, hei = hei })
end

function interface.displaySets()
   local sets = set.list()
   local _, longestSetName = longest(sets)

   local d = dialog.centered(#longestSetName + 3, #sets + 3)
   d:setLines(sets)

   return d
end

local currentDialog

function interface._step(data)
   local ok, err = coroutine.resume(currentDialog, data)
   if coroutine.status(currentDialog) == "dead" then
      currentDialog = nil
   end
   if not ok then
      error(err)
   end
end

local function getLastLine(txt)
   return txt:match("[\n]*([^\n]*)[\n]*$")
end

math.randomseed(os.time())

local stepCmd = "<cmd>lua require[[euclidian.lib.package-manager.interface]]._step()<cr>"
local stepCmdFmt = "<cmd>lua require[[euclidian.lib.package-manager.interface]]._step(%q)<cr>"

local function makeTitle(txt, width)
   local chars = width - #txt - 2
   return ("%s %s %s"):format(
   ("="):rep(math.floor(chars / 2)),
   txt,
   ("="):rep(ceil(chars / 2)))

end

local function newDialog(fn)
   return function()
      currentDialog = coroutine.create(fn)
      coroutine.resume(currentDialog)
   end
end

local function setComparator(a, b)
   if not b then
      return true
   end
   if not a then
      return false
   end
   return a:title() < b:title()
end

local defaultKeymapOpts = { silent = true, noremap = true }

local PkgInfo = {}




local function runForEachPkg(getCmd)
   return newDialog(function()
      local d = interface.displaySets()
      d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)
      yield()
      d:delKeymap("n", "<cr>")
      local ln = d:getCursor()
      local selected = d:getLine(ln)

      local textSegments = {}

      local selectedSet = set.load(selected)
      table.sort(selectedSet, setComparator)

      local maxCmds = 4
      local runningCmds = 0
      local jobs = {}
      local longestTitle = 0

      for i, p in ipairs(selectedSet) do
         local title = p:title()
         local segment = { title, "", "..." }
         if #title > longestTitle then
            longestTitle = #title
         end
         local command = getCmd(p)
         if command then

            local function updateStatus(status)
               segment[2] = status
            end
            local function updateText(txt)
               segment[3] = getLastLine(txt)
            end
            local function start()
               runningCmds = runningCmds + 1
               updateStatus("started")
            end
            local function close()
               runningCmds = runningCmds - 1
               updateStatus("finished")
               if not p.post then
                  return
               end








            end
            table.insert(jobs, function(t)
               cmd.runEvented({
                  command = command,
                  cwd = command.cwd,
                  on = {
                     start = start,
                     close = close,
                     stdout = updateText,
                     stderr = updateText,
                  },
                  thread = t,
               })
            end)
         else
            segment[2] = "installed"
         end
         textSegments[i + 1] = segment
      end

      local ui = nvim.ui()
      local width = floor(ui.width * .9)
      d:center(width, #textSegments + 1)
      textSegments[1] = {
         makeTitle("Package", longestTitle),
         makeTitle("Status", 10),
         makeTitle("Output", width - longestTitle - 18),
      }
      textSegments[#textSegments + 1] = textSegments[1]

      local lines = {}
      local fmtStr = " %" .. tostring(longestTitle) .. "s | %10s | %s"
      local function updateText()
         for i, segment in ipairs(textSegments) do
            lines[i] = fmtStr:format(segment[1], segment[2], segment[3])
         end
         d:setLines(lines)
      end
      updateText()
      local function jobsLeft()
         return not (runningCmds == 0 and #jobs == 0)
      end

      if jobsLeft() then
         ev.loop(function()
            local t = coroutine.running()
            local function startJobs()
               ev.wait()
               while runningCmds < maxCmds and #jobs > 0 do
                  table.remove(jobs, math.random(1, #jobs))(t)
               end
               ev.wait()
            end

            startJobs()

            while jobsLeft() do
               ev.wait()
               updateText()
               startJobs()
            end
            updateText()

            d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)
         end):asyncRun(150)
      else
         d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)
      end

      yield()
      d:close()
   end)
end

interface.installSet = runForEachPkg(function(p)
   if not p:isInstalled() then
      return p:installCmd()
   end
end)

interface.updateSet = runForEachPkg(function(p)
   if p:isInstalled() then
      return { "git", "pull", cwd = p:location() }
   else
      return p:installCmd()
   end
end)

local function ask(d, question, confirm, deny)
   d:setCursor(1, 0)
   d:setLines({
      question,
      confirm or "Yes",
      deny or "No",
   })






   d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)

   local ln
   repeat
      yield()
      ln = d:getCursor()
   until ln > 1

   d:delKeymap("n", "<cr>")

   return ln == 2
end


local checkKeymap = "a"
local function setChecklist(d, s)
   local text = {}
   for _, p in ipairs(s) do
      table.insert(text, "[ ] " .. p:title())
   end
   d:setLines(text)
   accommodateText(d)

   d:addKeymap("n", checkKeymap, stepCmdFmt:format("C"), defaultKeymapOpts)
   d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)

   while true do
      local res = yield()
      if not res then break end
      local ln = d:getCursor()
      local line = d:getLine(ln)
      d:setText({
         { line:match("^%[%*") and " " or "*", ln - 1, 1, ln - 1, 2 },
      })
   end

   d:delKeymap("n", checkKeymap)
   local checked = {}
   local lines = d:getLines(1, -1)
   for i, line in ipairs(lines) do
      if line:match("^%[%*") then
         table.insert(checked, s[i + 1])
      end
   end

   return checked
end

interface.addPackage = newDialog(function()
   local d = interface.displaySets()
   d:addKeymap("n", "<cr>", stepCmd, defaultKeymapOpts)
   yield()

   local selectedSet
   local setName
   local newPackage = {}

   do
      local ln = d:getCursor()
      local selected = d:getLine(ln)
      setName = selected
      selectedSet = set.load(selected)
      table.sort(selectedSet, setComparator)

      local text = {}
      for kind in pairs(packagespec.kinds) do
         table.insert(text, kind)
      end
      table.sort(text)

      d:setLines(text)
      yield()
      d:delKeymap("n", "<cr>")
   end

   do
      local ln = d:getCursor()
      local selectedKind = d:getLine(ln)
      newPackage.kind = selectedKind

      d:setLines({})
      local promptText
      if selectedKind == "git" then
         promptText = "git repo: "
      elseif selectedKind == "local" then
         promptText = "local path: "
      end
      d:setPrompt(promptText, function(txt)
         if selectedKind == "git" then
            newPackage.repo = txt
         elseif selectedKind == "local" then
            newPackage.path = txt
         end

         interface._step()
      end)
      yield()
      d:unsetPrompt()
   end

   if ask(d, "Do any other installed packages depend on this package?") then
      newPackage.dependents = setChecklist(d, selectedSet)
   end

   if ask(d, "Does this package depend on any other installed packages?") then
      local dependencies = setChecklist(d, selectedSet)
      for _, p in ipairs(dependencies) do
         if not p.dependents then
            p.dependents = {}
         end
         table.insert(p.dependents, newPackage)
      end
   end

   if ask(d, "Does this package have any post-install (vimscript) actions?") then
      d:addKeymap("n", "<CR>", stepCmd, defaultKeymapOpts)
      d:setLines({})
      d.buf:setOption("syntax", "vim")
      d:modify(function()
         a.nvim_command("startinsert")
         yield()
         a.nvim_command("stopinsert")
      end)
      d.buf:setOption("syntax", "")
      d.buf:setOption("modifiable", false)

      newPackage.post = table.concat(d:getLines(), "\n")
   end

   table.insert(selectedSet, newPackage)
   set.save(setName, selectedSet)

   d:setLines({ ("Saved set %s"):format(setName) })
   accommodateText(d)

   d:addKeymap("n", "<CR>", stepCmd, defaultKeymapOpts)
   yield()
   d:close()
end)

return interface