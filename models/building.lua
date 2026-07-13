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

-- The prestige at which the vendor with `vendorId` first opens for business -- i.e. the
-- unlock threshold of the building that houses it. A quest hides its sponsor's line until
-- that shop exists in the hub (see models/quest.lua); showing a quest for a vendor the
-- player cannot yet visit only advertises a locked door. A vendor with no building, or a
-- nil id, defaults to 1 (always open).
function Building.vendorUnlockPrestige(vendorId)
    if not vendorId then return 1 end
    for _, def in pairs(Building.defs) do
        if def.vendor == vendorId then
            return def.unlockPrestige or 1
        end
    end
    return 1
end

return Building
