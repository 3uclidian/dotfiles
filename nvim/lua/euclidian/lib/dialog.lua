
local nvim = require("euclidian.lib.nvim")

local TextRegion = {Position = {}, }











local Dialog = {Opts = {Center = {}, }, }





























local function copyCenterOpts(o)
   local cpy = {}
   if not o then
      cpy.vertical = false
      cpy.horizontal = false
   elseif type(o) == "boolean" then
      cpy.vertical = true
      cpy.horizontal = true
   else
      cpy.vertical = o.vertical
      cpy.horizontal = o.horizontal
   end
   return cpy
end

local function copyOpts(o)

   return {
      wid = o.wid,
      hei = o.hei,
      row = o.row,
      col = o.col,
      notMinimal = o.notMinimal,
      interactive = o.interactive,
      hidden = o.hidden,
      border = o.border,
      centered = copyCenterOpts(o.centered),
   }
end

local dialog = {
   Dialog = Dialog,
   TextRegion = TextRegion,
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

local defaultBorderHighlight = "Normal"
local defaultBorder = {
   { "╭", defaultBorderHighlight },
   { "─", defaultBorderHighlight },
   { "╮", defaultBorderHighlight },
   { "│", defaultBorderHighlight },
   { "╯", defaultBorderHighlight },
   { "─", defaultBorderHighlight },
   { "╰", defaultBorderHighlight },
   { "│", defaultBorderHighlight },
}

local floor, max, min =
math.floor, math.max, math.min

local function clamp(n, lower, upper)
   return min(max(lower, n), upper)
end




local function convertNum(n, base)
   if n < 0 then
      return floor(base + n)
   elseif n < 1 then
      return floor(base * n)
   else
      return floor(clamp(n, 1, base))
   end
end

function dialog.optsToWinConfig(opts)
   local cfg = {
      relative = "editor",
      style = not opts.notMinimal and "minimal" or nil,
      border = opts.border or defaultBorder,
      focusable = opts.interactive,
   }
   local ui = nvim.ui()

   local center = copyCenterOpts(opts.centered)

   if center.horizontal then
      cfg.width = convertNum(
      assert(opts.wid, "centered dialogs require a 'wid' field"),
      ui.width)

      cfg.col = math.floor((ui.width - cfg.width) / 2)
   else
      cfg.col = convertNum(assert(opts.col, "non-centered dialogs require a 'col' field"), ui.width)
      cfg.width = convertNum(assert(opts.wid, "non-centered dialogs require a 'wid' field"), ui.width)
   end

   if center.vertical then
      cfg.height = convertNum(
      assert(opts.hei, "centered dialogs require a 'hei' field"),
      ui.height)

      cfg.row = math.floor((ui.height - cfg.height) / 2)
   else
      cfg.row = convertNum(assert(opts.row, "non-centered dialogs require a 'row' field"), ui.height)
      cfg.height = convertNum(assert(opts.hei, "non-centered dialogs require a 'hei' field"), ui.height)
   end

   return cfg
end

function dialog.new(opts, maybeBuf)
   local buf = getBuf(maybeBuf)

   if buf:getOption("buftype") == "" then
      buf:setOption("buftype", "nofile")
   end
   buf:setOption("modifiable", false)

   local cfg = dialog.optsToWinConfig(opts)
   local win = opts and not opts.hidden and nvim.openWin(
   buf,
   opts.interactive,
   cfg) or
   { isValid = function() return false end }

   if win:isValid() then
      win:setOption("winhighlight", "Normal:Normal,NormalFloat:Normal")
   end

   return setmetatable({
      buf = buf,
      win = win,
      regions = {},
      _origOpts = copyOpts(opts),
   }, { __index = Dialog })
end

function Dialog:show(dontSwitch, cfg)
   if self.win:isValid() then

      return self
   end

   self.win = nvim.openWin(
   self.buf,
   not dontSwitch,
   cfg or (self._origOpts and dialog.optsToWinConfig(self._origOpts)) or {})


   self.win:setOption("winhighlight", "Normal:Normal,NormalFloat:Normal")
   return self
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
function Dialog:appendLines(txt)
   return self:modify(function()
      self.buf:setLines(-1, -1, false, txt)
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
function Dialog:setWinConfig(c)
   local orig = self.win:getConfig()
   local new = {}
   for k, v in pairs(orig) do
      new[k] = (c)[k] or v
   end
   self.win:setConfig(new)
   return self
end
function Dialog:moveAbsolute(row, col)
   local c = self.win:getConfig()
   c.row = row
   c.col = col
   self.win:setConfig(c)
   return self
end
function Dialog:moveRelative(drow, dcol)
   local c = self.win:getConfig()
   c.row = c.row + drow
   c.col = c.col + dcol
   self.win:setConfig(c)
   return self
end
function Dialog:setOpts(opts)
   return self:setWinConfig(dialog.optsToWinConfig(opts))
end
function Dialog:center(width, height)
   assert(false and width and height)

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
function Dialog:fitTextPadded(colPad, rowPad, minWid, minHei, maxWid, maxHei)
   local lines = self.buf:getLines(0, -1, false)
   local line = ""
   for _, ln in ipairs(lines) do
      if #ln > #line then
         line = ln
      end
   end
   local ui = nvim.ui()
   self.win:setHeight(clamp(
   #lines + (rowPad or 0),
   minHei or 1,
   maxHei or ui.height))

   self.win:setWidth(clamp(
   #line + (colPad or 0),
   minWid or 1,
   maxWid or ui.width))

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
function Dialog:centerHorizontal()
   local ui = nvim.ui()
   local cfg = self.win:getConfig()
   self.win:setConfig({
      relative = "editor",
      col = math.floor((ui.width - cfg.width) / 2),
      row = cfg.row,
      width = cfg.width,
      height = cfg.height,
   })
   return self
end
function Dialog:centerVertical()
   local ui = nvim.ui()
   local cfg = self.win:getConfig()
   self.win:setConfig({
      relative = "editor",
      col = cfg.col,
      row = math.floor((ui.height - cfg.height) / 2),
      width = cfg.width,
      height = cfg.height,
   })
   return self
end
function Dialog:hide()
   self.win:hide()
   return self
end
function Dialog:close()
   self.win:close(true)
end

local function cmpPos(a, b)
   return a.line == b.line and
   a.char < b.char or
   a.line < b.line
end

function Dialog:claimRegion(start, nlines, nchars)
   local r = setmetatable({
      start = { line = start.line, char = start.char },
      finish = {
         line = start.line + nlines,
         char = nlines > 0 and
         nchars or
         start.char + nchars,
      },
      nlines = nlines,
      nchars = nchars,
   }, {
      __index = TextRegion,
      parent = self,
   })
   for i = 1, #self.regions - 1 do
      local cur, nxt = self.regions[i], self.regions[i + 1]
      if cmpPos(cur.finish, r.start) and cmpPos(r.finish, nxt.start) then
         table.insert(self.regions, i, r)
         return r
      end
   end
   table.insert(self.regions, r)
   return r
end

local TextRegionMt = {}





local function getmt(tr)
   return getmetatable(tr)
end

local function pad(s, len)
   return s .. (" "):rep(len - #s)
end

function TextRegion:set(s, clear)
   local d = getmt(self).parent
   local buf = d.buf
   local inputLns = { unpack(vim.split(s, "\n"), 1, self.nlines + 1) }

   d:modify(function()

      if self.nlines == 1 and self.start.char == 0 then
         buf:setLines(
         self.start.line,
         self.finish.line + 1,
         false,
         inputLns)

         return
      end


      if self.start.char ~= 0 and self.nlines == 0 then

         local txt = inputLns[1]

         local sRow = self.start.line
         local sCol = self.start.char

         local nchars = math.min(#txt, self.nchars)
         local eCol
         if clear then
            txt = pad(txt, self.nchars)
            eCol = sCol + self.nchars
         else
            txt = txt:sub(1, nchars)
            eCol = sCol + nchars
         end

         buf:setText(
         sRow, sCol,
         sRow, eCol,
         { txt })


         return
      end

      local currentLines = buf:getLines(self.start.line, self.finish.line + 1, false)
      if self.nlines > 0 then
         currentLines[1] = currentLines[1]:sub(1, self.start.char) .. inputLns[1]
      end

      local batchIncludesLastLine = true

      if self.nlines > 1 and self.nchars > 0 then
         batchIncludesLastLine = false
         local txt = table.remove(currentLines)

         local nchars = math.min(#txt, self.nchars)
         local eCol
         if clear then
            txt = pad(txt, self.nchars)
            eCol = self.nchars
         else
            txt = txt:sub(1, nchars)
            eCol = nchars
         end

         buf:setText(
         self.finish.line, 0,
         self.finish.line, eCol,
         { txt })

      end

      buf:setLines(
      self.start.line,
      self.finish.line + (batchIncludesLastLine and 1 or 0),
      false,
      currentLines)

   end)
end

for name, fn in pairs(TextRegion) do
   (TextRegion)[name] = function(self, ...)
      if getmt(self).unclaimed then
         error("TextRegion has already been unclaimed", 2)
      end
      return fn(self, ...)
   end
end

function TextRegion:unclaim()
   local mt = getmt(self)
   if mt.unclaimed then return end
   mt.unclaimed = true
   local d = mt.parent
   for i, v in ipairs(d.regions) do
      if self == v then
         table.remove(d.regions, i)
         return
      end
   end
end

return dialog