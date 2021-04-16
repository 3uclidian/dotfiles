
local a = vim.api

local function failsafe(f, err_prefix)
   local ok = true
   local err
   return function()
      if ok then
         ok, err = pcall(f)
      end
      if not ok then
         a.nvim_err_writeln((err_prefix or "") .. err)
      end
   end
end

local UI = {}















local auto = require("euclidian.lib.nvim._autogenerated")

local function unCamel(s)
   return (s:gsub("[A-Z]", function(m)
      return "_" .. m:lower()
   end))
end
local function genMetatable(t, prefix)
   local cache = setmetatable({}, { __mode = "kv" })
   local api = vim.api
   return {
      __call = function(_, n)
         if not n or n == 0 then
            n = api["nvim_get_current_" .. prefix]()
         end
         if not cache[n] then
            cache[n] = setmetatable({ id = n }, { __index = t })
         end
         return cache[n]
      end,
      __index = function(_, key)
         local fn = api["nvim_" .. prefix .. "_" .. unCamel(key)]
         return fn and function(self, ...)
            return fn(self.id, ...)
         end
      end,
      __eq = function(a, b)
         if not (type(a) == "table") or not (type(b) == "table") then
            return false
         end
         local aMt = getmetatable(a)
         local bMt = getmetatable(b)
         if not aMt or not bMt then
            return false
         end
         return (aMt.__index == bMt.__index) and
         ((a).id == (b).id)
      end,
   }
end
local function genSetMetatable(t, prefix)
   setmetatable(t, genMetatable(t, prefix))
end
genSetMetatable(auto.Buffer, "buf")
genSetMetatable(auto.Window, "win")
genSetMetatable(auto.Tab, "tab")

local AutocmdOpts = {}





local nvim = {
   Window = auto.Window,
   Buffer = auto.Buffer,
   Tab = auto.Tab,

   UI = UI,
   MapOpts = auto.MapOpts,
   AutocmdOpts = AutocmdOpts,

   _exports = {},
}

function nvim.ui(n)
   return (a.nvim_list_uis())[n or 1]
end

function nvim.openWin(b, enter, c)
   return nvim.Window(a.nvim_open_win(b and b.id or 0, enter, c))
end

function nvim.createBuf(listed, scratch)
   return nvim.Buffer(a.nvim_create_buf(listed, scratch))
end

function nvim.command(fmt, ...)
   a.nvim_command(string.format(fmt, ...))
end

local function toStrArr(s)
   if type(s) == "string" then
      return { s }
   else
      return s
   end
end

function nvim.autocmd(sEvents, sPatts, expr, maybeOpts)
   assert(sEvents, "no events")
   assert(expr, "no expr")

   local events = table.concat(toStrArr(sEvents), ",")
   local opts = maybeOpts or {}

   assert(sPatts or opts.buffer, "no patterns or buffer")
   local patts = sPatts and table.concat(toStrArr(sPatts), ",")

   local actualExpr
   if type(expr) == "string" then
      actualExpr = expr
   else
      local key = "autocmd" .. events .. (patts or "buffer=" .. tostring(opts.buffer))
      nvim._exports[key] = failsafe(expr, ("Error in autocmd for %s %s: "):format(events, patts))
      actualExpr = ("lua require'euclidian.lib.nvim'._exports[%q]()"):format(key)
   end
   local cmd = { "autocmd" }
   table.insert(cmd, events)
   if opts.buffer then
      table.insert(cmd, ("<buffer=%d>"):format(opts.buffer == true and vim.api.nvim_get_current_buf() or opts.buffer))
   end
   if patts then table.insert(cmd, patts) end
   if opts.once then table.insert(cmd, "++once") end
   if opts.nested then table.insert(cmd, "++nested") end
   table.insert(cmd, actualExpr)

   nvim.command(table.concat(cmd, " "))
end

function nvim.augroup(name, lst, clear)
   nvim.command("augroup %s", name)
   if clear then
      nvim.command("autocmd!")
   end
   for _, v in ipairs(lst) do
      nvim.autocmd(v[1], v[2], v[3])
   end
   nvim.command("augroup END")
end

function nvim.setKeymap(mode, lhs, rhs, userSettings)
   if type(rhs) == "string" then
      a.nvim_set_keymap(mode, lhs, rhs, userSettings)
   else
      local key = "keymap" .. mode .. a.nvim_replace_termcodes(lhs, true, true, true)
      nvim._exports[key] = failsafe(rhs, "Error in keymap (" .. key .. "): ")
      a.nvim_set_keymap(
      mode,
      lhs,
      ("<cmd>lua require'euclidian.lib.nvim'._exports[%q]()<cr>"):format(key),
      userSettings)

   end
end

function nvim.delKeymap(mode, lhs)
   pcall(a.nvim_del_keymap, mode, lhs)
end

nvim.Buffer.setKeymap = function(self, mode, lhs, rhs, userSettings)
   if type(rhs) == "string" then
      a.nvim_buf_set_keymap(self.id, mode, lhs, rhs, userSettings)
   else
      local key = "bufkeymap" .. tostring(self.id) .. mode .. a.nvim_replace_termcodes(lhs, true, true, true)
      nvim._exports[key] = failsafe(rhs, "Error in keymap (" .. key .. "): ")
      a.nvim_buf_set_keymap(
      self.id,
      mode,
      lhs,
      ("<cmd>lua require'euclidian.lib.nvim'._exports[%q]()<cr>"):format(key),
      userSettings)

      nvim.command("autocmd BufUnload <buffer=%d> ++once lua require'euclidian.lib.nvim'._exports[%q] = nil", self.id, key)
   end
end

nvim.Buffer.delKeymap = function(self, mode, lhs)
   pcall(a.nvim_buf_del_keymap, self.id, mode, lhs)
end

return nvim