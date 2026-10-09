-- AN ADVENTURING PARTY ENDS (models/adventurers.lua). People were taken out of rift traffic on 2026-09-22
-- because a company met by a company is a mirror match the combat model could not close: the Broken
-- Column sat at autobattle's 400-turn cap. The parties came back under limits written for exactly that
-- stall -- a core of three growing to six, at most one sustain body per three, a closer in every party --
-- and this is the case that says whether the limits held, measured the way tests/skirmish_spec.lua
-- measures an ordinary fight: the real build, deploy and open sequence, against Descent.COMPANY levelled
-- to the floor.
--
-- MEASURED WHERE A PARTY IS BIGGEST: the first floor it fields six (floor 10, or its own opening floor
-- if deeper). A party that resolves at six resolves smaller.
--
-- ITS OWN BUDGET, NOT THE SKIRMISH'S: a six-body company is a bigger fight than a four-body skirmish by
-- design (the author: "it's max a party of 6"). PARTY_TURN_BUDGET is set from the first measurement with
-- headroom, the way SKIRMISH_TURN_BUDGET was, and is a guard against a party growing into a stall rather
-- than a number to nudge when it fails.

local Autobattle = require("models.autobattle")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Muster = require("models.muster")
local Player = require("models.player")
local Descent = require("models.descent")
local Experience = require("models.experience")
local Adventurers = require("models.adventurers")

local PARTY_TURN_BUDGET = 60

local function companyAtDepth(depth)
    local player = Player.new()
    player.roster = {}
    for _, id in ipairs(Descent.COMPANY) do Player.recruit(player, id) end
    for _, char in ipairs(player.roster) do
        Experience.award(char, Experience.totalFor(Descent.expectedLevel(depth)))
    end
    Player.resolveLevels(player)
    return player
end

local function parties()
    local out = {}
    for id, def in pairs(Encounter.defs) do
        if def.party then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- One party, fought at `depth`. Returns the unit-turns, the result, and the bodies it opened with.
local function fight(e, depth)
    local player = companyAtDepth(depth)
    if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(20261009)
    else math.randomseed(20261009) end
    local built = EncounterBattle.build({
        encounter = { id = e.id, kind = e.def.kind },
        biome = "forest", depth = depth,
        party = player.roster, seed = 20261009,
    })
    EncounterBattle.autoDeploy(built.combat, built.arena, Muster.fielded(player))
    Combat.openBattle(built.combat)
    local result, turns = Autobattle.run(built.combat, { maxTurns = 400 })
    return turns, result, #built.arena.enemies
end

return {
    { name = "a party opens at its full size past the skirmish cap", fn = function()
        for _, e in ipairs(parties()) do
            local depth = math.max(10, e.def.depth)
            local _, _, bodies = fight(e, depth)
            local want = #Adventurers.members(e.def.core, e.def.grow, depth)
            assert(bodies == want, string.format("%s opened %d bodies on floor %d, its roll says %d",
                e.id, bodies, depth, want))
        end
    end },

    { name = "every party resolves, inside its own budget, at six", fn = function()
        local rows, worst, worstId = {}, 0, nil
        for _, e in ipairs(parties()) do
            local depth = math.max(10, e.def.depth)
            local turns, result = fight(e, depth)
            rows[#rows + 1] = string.format("%s=%d(%s)", e.id:gsub("^encounter_party_", ""), turns,
                tostring(result))
            assert(result ~= nil, string.format(
                "%s did not resolve in 400 unit-turns on floor %d -- the mirror match is back", e.id, depth))
            if turns > worst then worst, worstId = turns, e.id end
        end
        assert(worst <= PARTY_TURN_BUDGET, string.format(
            "the longest party took %d unit-turns (%s), past the party budget of %d. All: %s",
            worst, tostring(worstId), PARTY_TURN_BUDGET, table.concat(rows, " ")))
    end },
}
