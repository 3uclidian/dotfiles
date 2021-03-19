local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math
local nvim = require("euclidian.lib.nvim")

local Dialog = {Opts = {}, }











local dialog = {
   Dialog = Dialog,
}

local BufOrId = {}

local function getBuf(maybeBuf)
   if not maybeBuf then
      return nvim.createBuf(false, true)
   elseif type(maybeBuf) == "table" then
      return maybeBuf
   else
      return nvim.Buffer(maybeBuf)
   end
end

function dialog.new(opts, maybeBuf)
   local buf = getBuf(maybeBuf)

   buf:setOption("buftype", "nofile")
   buf:setOption("modifiable", false)

   local win = nvim.openWin(buf, true, {
      relative = "editor",
      row = 1, col = 1,
      width = 1, height = 1,
   })
   win:setOption("winblend", 5)

   local ui = nvim.ui()

   local col = opts.col < 0 and
   ui.width + opts.col or
   opts.col
   local row = opts.row < 0 and
   ui.height + opts.row or
   opts.row

   win:setConfig({
      relative = "editor", style = "minimal", anchor = "NW",
      width = opts.wid, height = opts.hei,
      row = row, col = col,
   })

   return setmetatable({ buf = buf, win = win }, { __index = Dialog })
end

local floor, max, min =
math.floor, math.max, math.min

local function clamp(n, lower, upper)
   return min(max(lower, n), upper)
end

function dialog.centeredSize(wid, hei)
   local ui = nvim.ui()

   local actualWid = clamp(
   wid,
   floor(ui.width * .25),
   floor(ui.width * .90))

   local actualHei = clamp(
   hei,
   floor(ui.height * .25),
   floor(ui.height * .90))


   return {
      col = math.floor((ui.width - actualWid) / 2),
      row = math.floor((ui.height - actualHei) / 2),
      wid = actualWid,
      hei = actualHei,
   }
end

function dialog.centered(wid, hei, maybeBuf)
   return dialog.new(dialog.centeredSize(wid, hei), maybeBuf)
end

function Dialog:isModifiable()
   return self.buf:getOption("modifiable")
end
function Dialog:setModifiable(to)
   self.buf:setOption("modifiable", to)
end
function Dialog:modify(fn)
   local orig = self:isModifiable()
   self:setModifiable(true)
   fn(self)
   self:setModifiable(orig)
   return self
end
function Dialog:setLines(txt)
   return self:modify(function()
      self.buf:setLines(0, -1, false, txt)
   end)
end
function Dialog:setLine(num, ln)
   return self:modify(function()
      self.buf:setLines(num, num + 1, false, { ln })
   end)
end
function Dialog:setText(edits)

   return self:modify(function()
      for _, edit in ipairs(edits) do
         self.buf:setText(edit[2], edit[3], edit[4], edit[5], { edit[1] })
      end
   end)
end
function Dialog:setCursor(row, col)
   self.win:setCursor({ row, col })
   return self
end
function Dialog:getCursor()
   local pos = self.win:getCursor()
   return pos[1], pos[2]
end
function Dialog:getLine(n)
   return self.buf:getLines(n - 1, n, false)[1]
end
function Dialog:getCurrentLine()
   return self:getLine((self:getCursor()))
end
function Dialog:getLines(min, max)
   return self.buf:getLines(min or 0, max or -1, false)
end
function Dialog:setWin(o)
   self.win:setConfig({
      relative = "editor",
      row = assert(o.row, "no row"), col = assert(o.col, "no col"),
      width = assert(o.wid, "no wid"), height = assert(o.hei, "no hei"),
   })
   return self
end
function Dialog:center(width, height)
   return self:setWin(dialog.centeredSize(width, height))
end
function Dialog:addKeymap(mode, lhs, rhs, opts)
   self.buf:setKeymap(mode, lhs, rhs, opts)
   return self
end
function Dialog:delKeymap(mode, lhs)
   self.buf:delKeymap(mode, lhs)
   return self
end
function Dialog:setPrompt(prompt, cb, int)
   self.buf:setOption("modifiable", true)
   self.buf:setOption("buftype", "prompt")

   vim.fn.prompt_setprompt(self.buf.id, prompt or "> ")
   if cb then vim.fn.prompt_setcallback(self.buf.id, cb) end
   if int then vim.fn.prompt_setinterrupt(self.buf.id, int) end
   nvim.command("startinsert")
   return self
end
function Dialog:unsetPrompt()
   self.buf:setOption("modifiable", false)
   self.buf:setOption("buftype", "nofile")
   nvim.command("stopinsert")
   return self
end
function Dialog:fitText(minWid, minHei, maxWid, maxHei)
   local lines = self.buf:getLines(0, -1, false)
   local line = ""
   for _, ln in ipairs(lines) do
      if #ln > #line then
         line = ln
      end
   end
   local ui = nvim.ui()
   self.win:setHeight(clamp(#lines, minHei or 1, maxHei or ui.height))
   self.win:setWidth(clamp(#line, minWid or 1, maxWid or ui.width))
   return self
end
function Dialog:center()
   local ui = nvim.ui()
   local cfg = self.win:getConfig()
   self.win:setConfig({
      relative = "editor",
      col = math.floor((ui.width - cfg.width) / 2),
      row = math.floor((ui.height - cfg.height) / 2),
      width = cfg.width,
      height = cfg.height,
   })
   return self
end
function Dialog:close()
   self.win:close(true)
end

return dialog