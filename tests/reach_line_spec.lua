-- A REACH THAT SOMEBODY ELSE HAS TO MAKE, WITH NOBODY LEFT TO FIGHT, ENDS.
--
-- encounter_the_larder is a rescue: cut the Stray Delver free and walk them to the line (`who`). The
-- company's objective posture walks to the same line, so once the spiders were dead the four of them
-- parked on the exit row -- on the tiles the delver needed -- and the fight ran out the autobattle's 400
-- unit-turns with nothing standing (3 of 10 seeds, `. early-floors only=encounter_the_larder`, dice live).
-- models/ai.lua's AI.clearTheLine steps a body off the line once no foe stands. This sets up exactly that
-- board -- every spider down, the delver free, the company standing on the line -- and asks that it
-- resolve inside the objective-fight budget (tests/objective_fight_spec.lua's 70).
local Autobattle = require("models.autobattle")
local Combat = require("models.combat")
local EncounterBattle = require("models.encounter_battle")
local Encounter = require("models.encounter")
local Muster = require("models.muster")
local Run = require("tests.support.objective_run")

local BUDGET = 70

return {
    { name = "a cleared reach with the company parked on the line still walks the charge home", fn = function()
        local id = "encounter_the_larder"
        local def = Encounter.get(id)
        local biome, floor = Run.placeOf(def)
        local player = Run.company(floor)
        local built = EncounterBattle.build({
            encounter = { id = id, kind = def.kind }, biome = biome, depth = floor, rung = def.rung,
            party = player.roster, seed = Run.SEED,
        })
        local combat = built.combat
        EncounterBattle.autoDeploy(combat, built.arena, Muster.fielded(player))
        Combat.openBattle(combat)
        local obj = combat.objective
        assert(obj and obj.type == "reach" and obj.who, "the Larder is a reach somebody else makes")

        -- Nobody left to fight, and the charge already cut free.
        for _, u in ipairs(combat.units) do
            if u.side == "enemy" then u.alive = false end
        end
        combat.captiveFreed = true

        -- The company on the line, nearest tiles first, which is where its walk used to leave it.
        local who, company = nil, {}
        for _, u in ipairs(combat.units) do
            if u.alive and u.side == "party" then
                if u.char.id == obj.who then who = u
                elseif Combat.isPlayerControlled(u) then
                    u.postureOverride = "objective"
                    company[#company + 1] = u
                end
            end
        end
        assert(who, "the charge is on the board")
        local placed = 0
        for _, t in ipairs(obj.tiles) do
            local u = company[placed + 1]
            if not u then break end
            if not (who.x == t.x and who.y == t.y) and Combat.footprintFree(combat, 1, 1, t.x, t.y)
                and Combat.teleportUnit(combat, u, t.x, t.y, { silent = true }) then
                placed = placed + 1
            end
        end
        assert(placed > 0, "the fixture must stand somebody on the line")

        local result, turns = Autobattle.run(combat, {
            maxTurns = 400,
            between = function(c) Combat.settleObjective(c) end,
        })
        assert(result == "win", string.format("a cleared reach ended %s after %d unit-turns",
            tostring(result), turns))
        assert(turns <= BUDGET, string.format("and took %d unit-turns against a budget of %d", turns, BUDGET))
    end },
}
