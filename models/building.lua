-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked` so the city can grow as prestige climbs.

local Registry = require("models.registry")
local Player = require("models.player")

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- THE CITY'S GRID, and the authoritative copy of it. Cards are 270x130 on a 4x4 lattice:
--
--   columns  x = 40, 350, 660, 970
--   rows     y = 120, 268, 416, 564
--
-- Sixteen slots for fifteen doors, laid out in what the player does with them:
--
--   row 1   the loop      the Gate, the Hiring Hall, the Inn        (go down, find people, sleep)
--   row 2   your benches  the Armory, the Forge, the Cafe, the Duel
--   rows 3-4 the seven houses, which open one at a time as their circles fall (`unlockCircle`)
--
-- It was a 4/4/3 of 270x140 with the last row centred, which fit eleven doors and not fifteen -- the
-- houses came back from being parked and the city was three cards over its own grid, drawing two of them
-- underneath two others. Keep new buildings on this lattice; two cards on one slot is invisible in the
-- data and obvious only on the screen.
Building.GRID = {
    cols = { 40, 350, 660, 970 },
    rows = { 120, 268, 416, 564 },
    w = 270, h = 130,
}

-- DOORS THE CITY NO LONGER HAS. See the note in Building.list: the campaign is parked, not cut, and
-- this table is the whole of the parking. Everything a retired building led to is still on disk.
Building.RETIRED = {
    quest_board = true,
}

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
-- `opts.includeRetired` lists the parked doors too, and exists for one caller: the specs that pin the
-- UNLOCK RULES of buildings the city no longer shows. Retiring hides a card; it does not change what
-- would open it, and those gates are still authored, still correct, and still what the campaign runs on
-- if it is ever brought back. Without this the parking would silently delete their coverage as well as
-- their card, which is the difference between parking something and losing it.
function Building.list(playerOrPrestige, opts)
    local player = type(playerOrPrestige) == "table" and playerOrPrestige or nil
    -- Quests finished, on the authored scale (Player.standing). A bare number still works for the
    -- callers that pass one directly.
    local prestige = player and require("models.player").standing(player) or playerOrPrestige or 1

    local list = {}
    for id, def in pairs(Building.defs) do
        local locked = prestige < (def.unlockPrestige or 1)
        -- RETIRED, not deleted. The Quest Board was the campaign's front door -- seven houses' work over
        -- forty days -- and the city has one door now, and it goes down (data/buildings/the_gate.lua).
        -- The board's blueprint, every quest, the calendar and the biome windows are all still on disk
        -- and untouched; what changed is that nothing shows them. Bringing the campaign back is removing
        -- this table, which is why parking it was worth doing rather than cutting it.
        if not Building.RETIRED[id] or (opts and opts.includeRetired) then
            -- A HOUSE OPENS WHEN ITS CIRCLE FALLS. The seven shops were gated on the campaign's
            -- completed-quest count, which is parked at zero forever -- so as written they were seven
            -- cards reading "? (prestige 2)" for the rest of the save, promising a city that grows and
            -- delivering one that cannot.
            --
            -- What they open on instead is the thing the mode already counts: each house IS a circle
            -- (models/descent.lua's SINS carries the sin-to-vendor join), and putting that circle's
            -- general down credits the house. So the city grows as the company goes deeper, the seven
            -- circles get a reward that outlives the run, and the shelves -- most of the game's economy
            -- -- come back online without a line of new content.
            --
            -- The quest gate is IGNORED for these, not satisfied: it names a quest that cannot be
            -- completed, so honouring it would keep the door shut whatever the player did underground.
            local byCircle = def.unlockCircle
            if byCircle then
                locked = (((player and player.standing) or {})[id] or 0) <= 0
            elseif def.unlockQuest then
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
                state = def.state, -- a whole screen this door opens instead of a pop-up, or nil
                vendor = def.vendor, -- vendor id for shop buildings; nil otherwise
                unlockPrestige = def.unlockPrestige or 1,
                unlockQuest = def.unlockQuest, -- quest id that opens this door, or nil
                locked = locked,
            }
        end
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
