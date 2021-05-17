
local set = require("euclidian.lib.package-manager.set")
local loader = {}








local command = vim.api.nvim_command
local function packadd(pkg)
   command(([[packadd %s]]):format(pkg))
end

local function packaddSet(setname)
   local pre, post = {}, {}
   local ps = set.load(setname)
   for _, pkg in ipairs(ps) do
      if pkg:isInstalled() then
         if pkg.kind == "git" then
            packadd(pkg.alias or pkg.repo:match("[^/]+$"))
         elseif pkg.kind == "local" then
            table.insert(pre, 1, pkg.path)
            table.insert(post, pkg.path .. "/after")
         end
      end
   end
   local rtp = vim.api.nvim_list_runtime_paths()
   vim.list_extend(pre, rtp)
   vim.list_extend(pre, post)
   command([[set rtp=]] .. table.concat(pre, ","))
end

function loader.enableSet(setname)

   packaddSet(setname)

end

return loader