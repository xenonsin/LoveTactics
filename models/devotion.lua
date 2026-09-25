-- DEVOTION: what a kobold feels about its dragon, in the one place the race's rules, the dragons' own
-- rules and the planner all ask it (reviewed 2026-09-25, "The Kobolds of Greed", round 2).
--
-- "Kobolds don't care about gold" was the note that shaped the line: every heap, haul and purse mechanic
-- of the first pitch was cut, and what a kobold wants is the dragon. So the questions are three, and they
-- are asked by several files that must not disagree:
--
--   a DRAGON   anything carrying the `dragonkin` flag (trait_dragonkin): a Dragon Egg, a Wyrmling, the
--              Godling -- and a company body wearing the Godling's Scale, which is how a hired kobold
--              comes to treat its captain as its god.
--   DEVOUT     anything carrying the `devout` flag (trait_devotion, on the kobolds' Underfoot).
--   IN SIGHT   the kobolds a dragon's hurt or death reaches: devout, on its side, and with a clear line
--              to it (Combat.hasLineOfSight). A kobold round the corner neither rallies nor breaks.
--
-- Pure logic over a combat; Combat, Status and Trait are pulled lazily so this loads under the headless
-- suite and never sits in a require cycle.
local Devotion = {}

-- How near a dragon a kobold must stand to fight under the Dragon's Eye (trait_devotion's live bonus).
Devotion.EYE_RADIUS = 3

function Devotion.isDragon(unit)
    return unit ~= nil and require("models.trait").flag(unit, "dragonkin") ~= nil
end

function Devotion.isDevout(unit)
    return unit ~= nil and require("models.trait").flag(unit, "devout") ~= nil
end

-- The living dragon on `unit`'s side nearest to it (never itself), or nil.
function Devotion.nearestDragon(combat, unit)
    local Combat = require("models.combat")
    local best, bestD
    for _, u in ipairs((combat and combat.units) or {}) do
        if u ~= unit and u.alive and u.side == unit.side and Devotion.isDragon(u) then
            local d = Combat.unitGap(unit, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best, bestD
end

-- Every devout body on `dragon`'s side that can see it, in board order.
function Devotion.witnesses(combat, dragon)
    local Combat = require("models.combat")
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u ~= dragon and u.alive and u.side == dragon.side and Devotion.isDevout(u)
            and Combat.hasLineOfSight(combat, u.x, u.y, dragon.x, dragon.y) then
            out[#out + 1] = u
        end
    end
    return out
end

-- A dragon was struck and lived: every kobold that saw it is driven to FERVOR. A Forsaken kobold cannot be
-- rallied -- its god has already fallen once this fight.
function Devotion.rally(combat, dragon)
    local Status = require("models.status")
    local n = 0
    for _, u in ipairs(Devotion.witnesses(combat, dragon)) do
        if not Status.has(u, "status_forsaken") then
            Status.apply(combat, u, "status_fervor", { applier = dragon })
            n = n + 1
        end
    end
    return n
end

-- A dragon was destroyed: every kobold that saw it is FORSAKEN, and any Fervor it had is gone with it.
function Devotion.forsake(combat, dragon)
    local Status = require("models.status")
    local n = 0
    for _, u in ipairs(Devotion.witnesses(combat, dragon)) do
        Status.remove(combat, u, "status_fervor")
        Status.apply(combat, u, "status_forsaken", { applier = dragon })
        n = n + 1
    end
    return n
end

return Devotion
