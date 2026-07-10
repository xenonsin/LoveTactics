-- Materials: the raw stock spent at the Blacksmith to upgrade gear. Unlike items, a material is not
-- carried in a character's 3x3 grid -- it is a plain resource the player accrues (player.materials =
-- { [id] = count }) and the forge consumes. Blueprints live in data/materials/<id>.lua (name,
-- description, sprite, tier). Pure logic (only the tolerant Sprite loader), headless-safe.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Material = {}

Material.defs = Registry.load("data/materials", "data.materials")

function Material.get(id)
    return Material.defs[id]
end

-- The tier of material a given upgrade level draws on: iron scrap (1) for +1/+2, steel (2) for
-- +3/+4, mythril (3) for +5. The single mapping the blacksmith cost curve reads.
Material.TIER_BY_LEVEL = { "iron_scrap", "iron_scrap", "steel_ingot", "steel_ingot", "mythril" }

function Material.forLevel(level)
    return Material.TIER_BY_LEVEL[level] or Material.TIER_BY_LEVEL[#Material.TIER_BY_LEVEL]
end

-- Ordered list (by tier) for any UI that enumerates materials.
function Material.list()
    local list = {}
    for id, def in pairs(Material.defs) do
        list[#list + 1] = { id = id, name = def.name, description = def.description, tier = def.tier or 1 }
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        return a.name < b.name
    end)
    return list
end

return Material
