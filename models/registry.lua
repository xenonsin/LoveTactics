-- Folder-scan loader. Given a directory of per-entity Lua def files, requires
-- each and returns a table keyed by id (the filename without extension).
--
--   local defs = Registry.load("data/items", "data.items")
--   -- data/items/iron_sword.lua  ->  defs.iron_sword
--
-- Uses love.filesystem, which is rooted at the launched project.

local Registry = {}

function Registry.load(dir, requirePrefix)
    local defs = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local id = file:match("^(.+)%.lua$")
        if id then
            defs[id] = require(requirePrefix .. "." .. id)
        end
    end
    return defs
end

return Registry
