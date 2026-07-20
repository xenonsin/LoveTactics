-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked` so the city can grow as prestige climbs.

local Registry = require("models.registry")
local Player = require("models.player")

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- Ordered list of buildings for a player. Each entry is a fresh copy of the def (blueprints stay
-- untouched) plus `id` and `locked`.
--
-- Accepts either the player table or, as it always did, a bare prestige number -- a building gated
-- only on prestige has nothing to ask a player about, and the callers that pass a number are not
-- wrong. A `unlockQuest` gate needs the player, so a def that names one is treated as locked when
-- all that was handed over is a number.
--
-- Two kinds of gate, ANDed: `unlockPrestige` is the city growing as the company does, and
-- `unlockQuest` is a door a particular story opens -- the dueling grounds do not appear because you
-- got richer, they appear because you fought on the sand once.
function Building.list(playerOrPrestige)
    local player = type(playerOrPrestige) == "table" and playerOrPrestige or nil
    local prestige = player and player.prestige or playerOrPrestige or 1

    local list = {}
    for id, def in pairs(Building.defs) do
        local locked = prestige < (def.unlockPrestige or 1)
        if def.unlockQuest then
            locked = locked or not (player and Player.hasCompleted(player, def.unlockQuest))
        end
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
            unlockQuest = def.unlockQuest, -- quest id that opens this door, or nil
            locked = locked,
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
