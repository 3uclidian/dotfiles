
local window = require("euclidian.lib.window")
local a = vim.api

local Dialog = {Opts = {}, }











local function setOpts(win, buf)
   a.nvim_buf_set_option(buf, "buftype", "nofile")
   a.nvim_buf_set_option(buf, "modifiable", false)
   a.nvim_win_set_option(win, "winblend", 5)
end

local function toDialog(win, buf)
   setOpts(win, buf)
   return setmetatable({
      win = win,
      buf = buf,
   }, { __index = Dialog })
end

local function new(x, y, wid, hei)
   return toDialog(window.floating(x or 10, y or 10, wid or 50, hei or 5))
end

local function centered(wid, hei)
   return toDialog(window.centeredFloat(wid or 50, hei or 5))
end

function Dialog:isModifiable()
   return a.nvim_buf_get_option(self.buf, "modifiable")
end
function Dialog:setModifiable(to)
   a.nvim_buf_set_option(self.buf, "modifiable", to)
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
      a.nvim_buf_set_lines(self.buf, 0, -1, false, txt)
   end)
end
function Dialog:setText(edits)

   return self:modify(function()
      for _, edit in ipairs(edits) do
         a.nvim_buf_set_text(self.buf, edit[2], edit[3], edit[4], edit[5], { edit[1] })
      end
   end)
end
function Dialog:setCursor(row, col)
   a.nvim_win_set_cursor(self.win, { row, col })
   return self
end
function Dialog:getCursor()
   local pos = a.nvim_win_get_cursor(self.win)
   return pos[1], pos[2]
end
function Dialog:getLine(n)
   return a.nvim_buf_get_lines(self.buf, n - 1, n, false)[1]
end
function Dialog:getLines(min, max)
   return a.nvim_buf_get_lines(self.buf, min or 0, max or -1, false)
end
function Dialog:setWin(o)
   a.nvim_win_set_config(self.win, {
      relative = "editor",
      row = assert(o.row, "no row"), col = assert(o.col, "no col"),
      width = assert(o.wid, "no wid"), height = assert(o.hei, "no hei"),
   })
   return self
end
function Dialog:addKeymap(mode, lhs, rhs, opts)
   a.nvim_buf_set_keymap(self.buf, mode, lhs, rhs, opts)
   return self
end
function Dialog:delKeymap(mode, lhs)
   a.nvim_buf_del_keymap(self.buf, mode, lhs)
   return self
end
function Dialog:setWinOpt(optName, val)
   a.nvim_win_set_option(self.win, optName, val)
   return self
end
function Dialog:setBufOpt(optName, val)
   a.nvim_buf_set_option(self.buf, optName, val)
   return self
end
function Dialog:setPrompt(prompt, cb, int)
   a.nvim_buf_set_option(self.buf, "modifiable", true)
   a.nvim_buf_set_option(self.buf, "buftype", "prompt")

   vim.fn.prompt_setprompt(self.buf, prompt or "> ")
   if cb then vim.fn.prompt_setcallback(self.buf, cb) end
   if int then vim.fn.prompt_setinterrupt(self.buf, int) end
   a.nvim_command("startinsert")
   return self
end
function Dialog:unsetPrompt()
   a.nvim_buf_set_option(self.buf, "modifiable", false)
   a.nvim_buf_set_option(self.buf, "buftype", "nofile")
   a.nvim_command("stopinsert")
   return self
end
function Dialog:close()
   a.nvim_win_close(self.win, true)
end

return {
   new = new,
   centered = centered,

   Dialog = Dialog,
}