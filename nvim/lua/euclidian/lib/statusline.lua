local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local nvim = require("euclidian.lib.nvim")

local function set(t)
   local s = {}
   for _, v in ipairs(t) do
      s[v] = true
   end
   return s
end

local statusline = {
   higroup = "StatuslineModeText",
   _funcs = {},
}

local active = {}

local modeMap = setmetatable({
   ["n"] = { "Normal", "Constant" },
   ["i"] = { "Insert", "Function" },
   ["r"] = { "Confirm", "Special" },
   ["R"] = { "Replace", "Special" },
   ["v"] = { "Visual", "String" },
   ["V"] = { "Visual Line", "String" },
   [""] = { "Visual Block", "String" },
   ["c"] = { "Command", "Special" },
   ["s"] = { "Select", "Visual" },
   ["S"] = { "Select Line", "Visual" },
   [""] = { "Select Block", "Visual" },
   ["t"] = { "Terminal", "Number" },
   ["!"] = { "Shell", "Comment" },
   ["?"] = { " ???? ", "Error" },
}, {
   __index = function(self, key)
      return rawget(self, string.sub(key, 1, 1)) or self["?"]
   end,
})

local userModes = setmetatable({}, {
   __index = function(self, key)
      return rawget(self, string.sub(key, 1, 1)) or modeMap[key]
   end,
})

function statusline.mode(mode, text, hlgroup)
   userModes[mode] = { text, hlgroup }
end

function statusline.getModeText()
   local m = vim.fn.mode(true)
   local map = userModes[m]
   nvim.command("hi! clear StatuslineModeText")
   nvim.command("hi! link StatuslineModeText %s", map[2])
   return map[1]
end

local Component = {}








local lineComponents = {}
local currentTags = {}

function statusline.add(tags, invertedTags, text, hiGroup)
   local comp = {
      tags = set(tags),
      invertedTags = set(invertedTags),
   }
   comp.hiGroup = hiGroup
   if type(text) == "string" then
      comp.text = text
   elseif text then
      statusline._funcs[#lineComponents + 1] = text
      comp.isFunc = true
      comp.funcId = #lineComponents + 1
   end
   table.insert(lineComponents, comp)
end

local function makeLine(tags, winId)
   local tagSet = set(tags)
   local buf = {}
   for i, component in ipairs(lineComponents) do
      local include = false
      for t in pairs(component.tags) do
         if tagSet[t] or currentTags[t] then
            include = true
            break
         end
      end
      if include then
         for t in pairs(component.invertedTags) do
            if tagSet[t] or currentTags[t] then
               include = false
               break
            end
         end
      end
      if include then
         table.insert(buf, ("%%#%s#"):format(component.hiGroup))
         if component.isFunc then
            table.insert(
            buf,
            ([[%%{luaeval("require'euclidian.lib.statusline'._funcs[%d](%d)")}]]):
            format(component.funcId, winId))
         else
            table.insert(buf, component.text)
         end
         if i < #lineComponents then
            table.insert(buf, "%#Normal#")
         end
      end
   end
   return table.concat(buf)
end

local function setLine(winId)
   local win = nvim.Window(winId)
   local tags = active[win.id] and
   { "Active" } or
   { "Inactive" }
   win:setOption("statusline", makeLine(tags, win.id))
end

function statusline.updateWindows()
   for _, winId in ipairs(vim.api.nvim_list_wins()) do
      setLine(winId)
   end
end

function statusline.setInactive(winId)
   winId = winId or nvim.Window().id
   active[winId] = false
   statusline.updateWindows()
end

function statusline.setActive(winId)
   winId = winId or nvim.Window().id
   active[winId] = true
   statusline.updateWindows()
end

function statusline.toggleTag(name)
   if type(name) == "string" then
      currentTags[name] = not currentTags[name]
   else
      for _, v in ipairs(name) do
         currentTags[v] = not currentTags[v]
      end
   end
   statusline.updateWindows()
end

function statusline.isActive(winId)
   winId = winId or nvim.Window().id
   return active[winId]
end

nvim.augroup("Statusline", {
   { { "WinEnter", "BufWinEnter" }, "*", statusline.setActive },
   { "WinLeave", "*", statusline.setInactive },
})

statusline.setActive()
statusline.updateWindows()

return statusline