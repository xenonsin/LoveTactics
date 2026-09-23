-- ONE ELITE, ONE FLOOR.
--
-- An elite is the one stop the rift asks a player to READ: seen from across the board, priced against
-- the company, routed around, and come back for on the trip that can afford it -- the Etrian FOE job the
-- descent kept when it took ordinary combat off the map (Descent.ELITE_WEIGHT). That only works while a
-- given elite is a LANDMARK. "The floor with the Meandering Stag on it" is a sentence a player can say
-- about a place; a Stag standing on both floors of the wood is traffic, and the sentence goes away.
--
-- WHY IT NEEDED A SPEC RATHER THAN A CONVENTION. Every circle elite in the tree is placed by a biome
-- condition -- `ctx.biome == "forest"` and so on -- and a circle owns TWO floors, so the lock every
-- blueprint header calls "its circle IS its placement" was in fact placing each one twice. Nothing said
-- so anywhere: the blueprints argue depth in prose, Descent.SINS bills an approach and a seat at a
-- heavier weight, and both of those are statements about RARITY sitting quietly on top of an elite being
-- legal on both stairs. The rule is a count, so this is the count -- taken by walking the fifteen floors
-- through the same seams states/game.lua walks (Descent.floorQuest for the descriptor, the floor's own
-- depth/rung/biome for the context) rather than by reading `rung` back out of the files it gates.
--
-- MEASURED, NOT READ, and that is what makes this hold a blueprint nobody has written yet. A spec that
-- asserted "every elite carries a rung" would pass on `rung = 3` (a floor no circle has), on a biome no
-- circle owns, and on a future placement field that is not `rung` at all. Counting floors fails all
-- three -- and the Crown's two elites pass it while carrying no rung at all, because the underworld is a
-- single floor and the ground alone already pins them.

local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")

-- THE MIMIC IS NOT A FLOOR'S ELITE, and it is the one exemption. It is filed `kind = "elite"` for its
-- size (Arena.UNCAPPED_KINDS) and authored at weight 0 so that NO pool anywhere ever deals it: the only
-- thing that can seat the fight is a hand on the wrong lid (models/mimic.lua), because a mimic that
-- could also turn up as a marked stop on open ground would be a monster that is sometimes disguised.
-- Scoped by the weight rather than by the id, so a second chest-only body needs no edit here.
local function dealable(def)
    return def.kind == "elite" and (def.weight or 0) > 0
end

-- Every floor of one rift, in the unit eligibility gates on: how deep it is, which of its circle's two
-- floors it is, and what ground it wears. The same three states/game.lua builds its ctx from.
local function walk(seed)
    local player = Player.new()
    local run = Descent.new(player, seed)
    local floors = {}
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local quest = Descent.floorQuest(run, player)
        floors[floor] = {
            floor = floor,
            sin = Descent.sinAt(run, floor),
            ctx = { depth = floor, rung = Descent.floorWithinCircle(floor),
                biome = quest.map.biome, quest = quest },
        }
    end
    return floors
end

-- Which floors deal each elite, through whichever pool the caller names.
local function floorsDealing(floors, pool)
    local seen = {}
    for _, f in ipairs(floors) do
        for _, e in ipairs(pool(f.ctx)) do
            if e.kind == "elite" then
                seen[e.id] = seen[e.id] or {}
                table.insert(seen[e.id], f.floor)
            end
        end
    end
    return seen
end

-- Three deals rather than one. Descent.sinOrder shuffles which circle owns which pair of floors, so a
-- single seed measures one arrangement of the same seven strata -- and a rule about floors ought to
-- survive the circles arriving in another order.
local SEEDS = { 1, 4242, 90210 }

return {
    { name = "no elite is dealt on more than one floor of the rift", fn = function()
        for _, seed in ipairs(SEEDS) do
            local floors = walk(seed)
            -- ASKED OF Descent.floorPool, WHICH IS THE WIRING. Encounter.pool is the gate; floorPool is
            -- what the generator actually draws a board from, and it re-weights and filters on top --
            -- so an elite that cleared eligibility and is then dealt twice by the thing downstream of it
            -- is exactly the failure a gate-only spec would miss.
            for id, on in pairs(floorsDealing(floors, Descent.floorPool)) do
                assert(#on == 1, string.format(
                    "%s is dealt on %d floors (%s) at seed %d -- an elite stands on one floor",
                    id, #on, table.concat(on, ", "), seed))
            end
        end
    end },

    { name = "every elite the pool can deal reaches a floor", fn = function()
        -- THE OTHER HALF, and without it the first case passes on content that does not exist: an elite
        -- runged onto a floor its circle has not got, or conditioned on a ground no circle wears, is
        -- dealt ZERO times and "no more than one" is delighted. `rung = 3` is the typo this catches.
        local floors = walk(1)
        local seen = floorsDealing(floors, Encounter.pool)
        for id, def in pairs(Encounter.defs) do
            if dealable(def) then
                assert(seen[id], id .. " is eligible on no floor of the rift at all")
            end
        end
    end },

    { name = "a circle bills an elite the floor it bills can actually deal", fn = function()
        -- A BILLING IS NOT A PLACEMENT, and when the two disagree nothing says so: Descent.floorPool
        -- weights the billed id to ELITE_NAMED_WEIGHT by comparing it against the entries it HAS, so a
        -- billing naming a body runged onto the circle's other floor raises the weight of nothing at
        -- all. The floor then deals its spares at ELITE_WEIGHT and reads as unbilled -- which is the
        -- state Gluttony's approach and both of Greed's floors were in before the rung split, except
        -- that here it would be silent instead of written down.
        local floors = walk(1)
        local byId = {}
        for _, f in ipairs(floors) do
            if f.sin then
                byId[f.sin.id] = byId[f.sin.id] or {}
                byId[f.sin.id][Descent.floorWithinCircle(f.floor)] = f
            end
        end
        for _, sin in ipairs(Descent.SINS) do
            local named = sin.elites or {}
            for _, billing in ipairs({ { 1, named.approach }, { 2, named.seat } }) do
                local rung, id = billing[1], billing[2]
                if id then
                    local f = byId[sin.id] and byId[sin.id][rung]
                    assert(f, sin.id .. " has no rung " .. rung .. " floor to bill on")
                    local found = false
                    for _, e in ipairs(Descent.floorPool(f.ctx)) do
                        if e.id == id then
                            found = true
                            assert(e.weight == Descent.ELITE_NAMED_WEIGHT, string.format(
                                "%s bills %s on rung %d but it is dealt at %s, not ELITE_NAMED_WEIGHT",
                                sin.id, id, rung, tostring(e.weight)))
                        end
                    end
                    assert(found, string.format(
                        "%s bills %s on rung %d and that floor cannot deal it -- the billing is a no-op",
                        sin.id, id, rung))
                end
            end
            -- ...and the spares, which are documentation rather than a table anything reads. A spare
            -- listed against a circle that can no longer deal it anywhere is a comment describing a
            -- floor that does not exist, which is how this table has gone stale before.
            for _, id in ipairs(named.spares or {}) do
                local anywhere = false
                for _, rung in ipairs({ 1, 2 }) do
                    local f = byId[sin.id] and byId[sin.id][rung]
                    for _, e in ipairs(f and Descent.floorPool(f.ctx) or {}) do
                        if e.id == id then anywhere = true end
                    end
                end
                assert(anywhere,
                    sin.id .. " lists " .. id .. " as a spare and neither of its floors deals it")
            end
        end
    end },

    { name = "the mimic is dealt by no pool at any depth", fn = function()
        -- The exemption, asserted rather than assumed, because it is the one elite this file's first
        -- case would pass without ever looking at. Its weight is the whole of the rule, so the weight is
        -- what is checked -- and then the consequence, over every floor of the rift.
        local def = Encounter.get("encounter_mimic")
        assert(def and def.kind == "elite", "encounter_mimic is no longer an elite")
        assert((def.weight or 0) == 0, "the mimic has a weight -- it would be dealt as a marked stop")
        for _, f in ipairs(walk(1)) do
            for _, e in ipairs(Descent.floorPool(f.ctx)) do
                assert(e.id ~= "encounter_mimic", "the mimic reached floor " .. f.floor .. " pool")
            end
        end
    end },
}
