
local M = { _exports = {} }

local util = require("euclidian.lib.util")
local keymapper = require("euclidian.lib.keymapper")
local a = vim.api
local cmdf, trim = util.cmdf, util.trim

local map = function(m, lhs, rhs)
   keymapper.map(m, lhs, rhs, { noremap = true, silent = true })
end
local unmap = keymapper.unmap


map("n", "<leader>c", function()
   local cursorPos = a.nvim_win_get_cursor(0)
   require("euclidian.lib.commenter").commentLine(0, cursorPos[1])
end)
map("v", "<leader>c", function()
   local start = (a.nvim_buf_get_mark(0, "<"))[1]
   local finish = (a.nvim_buf_get_mark(0, ">"))[1]
   require("euclidian.lib.commenter").commentRange(0, start - 1, finish)
end)
local getchar = vim.fn.getchar
map("n", "<leader>a", function()
   require("euclidian.lib.append").toCurrentLine(string.char(getchar()))
end)
map("v", "<leader>a", function()
   local start = (a.nvim_buf_get_mark(0, "<"))[1] - 1
   local finish = (a.nvim_buf_get_mark(0, ">"))[1]
   require("euclidian.lib.append").toRange(start, finish, string.char(getchar()))
end)
for mvkey, szkey in util.unpacker({
      { "h", "<" },
      { "j", "+" },
      { "k", "-" },
      { "l", ">" }, }) do

   unmap("n", "<C-W>" .. mvkey)
   map("n", "<C-" .. mvkey .. ">", ":wincmd " .. mvkey .. "<CR>")
   map("n", "<M-" .. mvkey .. ">", "<C-w>3" .. szkey)
   map("n", "<C-w>" .. mvkey, ":echoerr 'stop that'<CR>")
end

local function setupTerm()
   local termCmd = vim.fn.input("Command to execute in terminal: ")
   if #trim(termCmd) == 0 then
      return
   end
   local currentWin = a.nvim_get_current_win()
   cmdf([[sp +term]])
   local termWin = a.nvim_get_current_win()
   local termBuf = a.nvim_get_current_buf()
   local ok, job = pcall(a.nvim_buf_get_var, 0, "terminal_job_id")
   if not ok then
      print("Unable to get terminal job id\n")
      return
   end
   map("n", "<leader>t", function()
      local ok = pcall(vim.fn.chansend, job, termCmd .. "\n")
      if not ok then
         print("Unable to send command to terminal, (" .. termCmd .. ")")
      end
   end)
   cmdf([[autocmd BufDelete <buffer> lua require'euclidian.config.keymaps'._exports.setupTermMapping()]])
   a.nvim_set_current_win(currentWin)
end
M._exports.setupTermMapping = function()
   unmap("n", "<leader>t")
   map("n", "<leader>t", setupTerm)
end

map("n", "<leader>t", setupTerm)
map("n", "<leader>lp", require("euclidian.lib.luaprinter").attach)
map("n", "<leader>ll", function()
   require("euclidian.lib.luaprinter").getLine(a.nvim_win_get_cursor(0)[1])
end)

local r = require
local teleBuiltin = r("telescope.builtin")
map("n", "<leader>fz", teleBuiltin.find_files)
map("n", "<leader>g", teleBuiltin.live_grep)

map("n", "<leader>s", require("euclidian.lib.snippet").start)

return M
