-- Folder-scan loader. Given a directory of per-entity Lua def files, requires
-- each and returns a table keyed by id (the filename without extension).
--
--   local defs = Registry.load("data/items", "data.items")
--   -- data/items/weapon/weapon_iron_sword.lua  ->  defs.weapon_iron_sword
--   -- data/status/status_burn.lua              ->  defs.status_burn
--
-- The scan recurses into subfolders so a folder can be organised into type
-- buckets (data/items/weapon/, data/items/armor/, ...) without changing ids:
-- the key is always the bare filename -- prefix included, since the prefix IS
-- part of the id -- and only the require path follows the nesting. Ids must
-- stay unique across the whole tree.
--
-- A SECOND return value maps each id back to the file it came from
-- ("data/conversations/prologue/conversation_prologue_sponsor.lua"), which the id alone cannot
-- say once subfolders are in play -- knowing a scene is `conversation_prologue_sponsor` does not
-- tell you it lives under prologue/. It is returned rather than folded into the defs so nothing
-- downstream has to know it exists (`local defs = Registry.load(...)` is unchanged), and it is what
-- lets a debug affordance open a blueprint's source (see models/debug.lua's openFile).
--
-- Uses love.filesystem, which is rooted at the launched project.

local Registry = {}

function Registry.load(dir, requirePrefix)
    local defs, paths = {}, {}
    local function scan(subdir, subprefix)
        for _, file in ipairs(love.filesystem.getDirectoryItems(subdir)) do
            local path = subdir .. "/" .. file
            local info = love.filesystem.getInfo(path)
            if info and info.type == "directory" then
                scan(path, subprefix .. "." .. file)
            else
                local id = file:match("^(.+)%.lua$")
                if id then
                    defs[id] = require(subprefix .. "." .. id)
                    paths[id] = path
                end
            end
        end
    end
    scan(dir, requirePrefix)
    return defs, paths
end

return Registry
