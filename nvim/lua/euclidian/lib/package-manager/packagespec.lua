

local tree = require("euclidian.lib.package-manager.tree")
local uv = vim.loop

local Kind = {}



local Spec = {}


















local packagespec = {
   Spec = Spec,
   Kind = Kind,
   kinds = {
      ["git"] = true,
      ["local"] = true,
   },
}

local SpecMt = { __index = Spec }
function packagespec.new(p)

   return (setmetatable)(p, SpecMt)
end

function Spec:location()
   if self.kind == "git" then
      if self.alias then
         return tree.neovim .. "/" .. self.alias
      else
         return tree.neovim .. "/" .. self.repo:match("[^/]+$")
      end
   elseif self.kind == "local" then
      return self.path
   end
end

function Spec:title()
   if self.kind == "git" then
      return self.repo .. (self.alias and " (" .. self.alias .. ")" or "")
   elseif self.kind == "local" then
      return self.path
   end
end

function Spec:installCmd()
   if self.kind == "git" then
      return { "git", "clone", "https://github.com/" .. self.repo, self:location() }
   end
end

local function fileExists(fname)
   return uv.fs_stat(fname) ~= nil
end

function Spec:isInstalled()
   if self.kind == "git" then
      return fileExists(self:location())
   else
      return true
   end
end

return packagespec