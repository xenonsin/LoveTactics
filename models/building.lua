-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked` so the city can grow as prestige climbs.

local Registry = require("models.registry")

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- Ordered list of buildings for the given player prestige. Each entry is a
-- fresh copy of the def (blueprints stay untouched) plus `id` and `locked`.
function Building.list(prestige)
    prestige = prestige or 1

    local list = {}
    for id, def in pairs(Building.defs) do
        list[#list + 1] = {
            id = id,
            name = def.name,
            order = def.order or 0,
            x = def.x,
            y = def.y,
            w = def.w,
            h = def.h,
            panel = def.panel,
            vendor = def.vendor, -- vendor id for shop buildings; nil otherwise
            unlockPrestige = def.unlockPrestige or 1,
            locked = prestige < (def.unlockPrestige or 1),
        }
    end

    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

return Building
