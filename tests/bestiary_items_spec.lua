-- Tests for the natural weapons added with the warband/bestiary pass.
--
-- Both are creature kit, so both are held to the rule tests/bestiary_spec.lua states: natural weapons
-- only -- unpriced, noSteal, outside every shelf. What is checked here is what each one DOES, because
-- in both cases the mechanic is the whole reason the body exists.

local Combat = require("models.combat")
local Item = require("models.item")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, openTurn = Fixture.unit, Fixture.itemNamed, Fixture.openTurn

-- Fixture.unit returns a SPAWN entry ({ char, x, y }); Combat.new turns those into the live units the
-- rest of the model reads. So the combat's own `units`, split by side, is what a case must hold on to --
-- teleporting a spawn table moves nothing.
local function combatWith(partyIds, enemyIds)
    local map = Fixture.new(12, 12)
    local spawnParty, spawnEnemies = {}, {}
    for i, id in ipairs(partyIds) do spawnParty[i] = unit(id, 3, 3 + i) end
    for i, id in ipairs(enemyIds) do spawnEnemies[i] = unit(id, 6, 3 + i) end
    local c = Fixture.combat(map, spawnParty, spawnEnemies)

    local party, enemies = {}, {}
    for _, u in ipairs(c.units) do
        local into = (u.side == "party") and party or enemies
        into[#into + 1] = u
    end
    return c, party, enemies
end

return {
    -- ------------------------------------------------------------ the crawler
    {
        name = "carrion jaws bite the standing, and feed on the fallen instead",
        fn = function()
            local c, party, enemies = combatWith({ "character_knight", "character_knight" },
                { "character_carrion_crawler" })
            local crawler = enemies[1]
            local victim, bystander = party[1], party[2]
            local jaws = itemNamed(crawler.char, "weapon_carrion_jaws")
            assert(jaws, "the crawler carries its jaws")

            -- With nobody down, it is an ordinary bite: the target loses health.
            Combat.teleportUnit(c, crawler, victim.x + 1, victim.y)
            openTurn(c, crawler)
            local before = Fixture.hp(victim)
            assert(Combat.useItem(c, crawler, jaws, victim.x, victim.y), "the crawler bites")
            assert(Fixture.hp(victim) < before, "a standing body is bitten, not nibbled around")

            -- Put a body on the floor beside it and hurt the crawler, so a heal has somewhere to go.
            Combat.dealFlatDamage(c, crawler, 10, {}, "test")
            local hurt = Fixture.hp(crawler)
            Combat.dealFlatDamage(c, victim, 99999, {}, "test")
            assert(not victim.alive, "the victim goes down")

            -- Now the same swing feeds instead. The bystander must be untouched: feeding is the WHOLE
            -- turn, which is the property that makes the crawler a clock rather than extra damage.
            Combat.teleportUnit(c, crawler, victim.x + 1, victim.y)
            Combat.teleportUnit(c, bystander, crawler.x + 1, crawler.y)
            openTurn(c, crawler)
            local bystanderBefore = Fixture.hp(bystander)
            assert(Combat.useItem(c, crawler, jaws, bystander.x, bystander.y), "the crawler acts")
            assert(Fixture.hp(crawler) > hurt, "standing over a downed body, the crawler feeds and heals")
            assert(Fixture.hp(bystander) == bystanderBefore,
                "and it does not also bite -- feeding is the whole turn")
        end,
    },
    {
        name = "a crawler's jaws are natural kit: unpriced, unshelved and unstealable",
        fn = function()
            local def = Item.defs.weapon_carrion_jaws
            assert(def, "the jaws exist")
            assert(def.noSteal, "teeth do not come out of a head")
            assert(not def.price and def.class == "creature",
                "creature kit sits outside every shelf (tests/bestiary_spec.lua)")
        end,
    },

    -- ------------------------------------------------------------ the brood
    {
        name = "a wyrmling's breath is a cone, so two of them overlap and one does not",
        fn = function()
            local c, party, enemies = combatWith(
                { "character_knight", "character_knight", "character_knight" },
                { "character_wyrmling" })
            local wyrmling = enemies[1]
            local breath = itemNamed(wyrmling.char, "weapon_wyrmling_breath")
            assert(breath, "the wyrmling carries its breath")

            -- The cone fans out FROM the aimed cell, one tile each side per row (Chebyshev). So the
            -- three knights stand abreast one row PAST the aim point: row 0 is the aimed tile alone,
            -- row 1 is the three-wide rank that catches all of them.
            Combat.teleportUnit(c, wyrmling, 6, 6)
            for i, u in ipairs(party) do Combat.teleportUnit(c, u, 4, 5 + (i - 1)) end

            openTurn(c, wyrmling)
            local before = {}
            for i, u in ipairs(party) do before[i] = Fixture.hp(u) end
            assert(Combat.useItem(c, wyrmling, breath, 5, 6), "the wyrmling breathes")

            local burned = 0
            for i, u in ipairs(party) do
                if Fixture.hp(u) < before[i] then burned = burned + 1 end
            end
            assert(burned >= 2, "a cone catches more than the body it was aimed at -- caught " .. burned)
        end,
    },
    {
        name = "a wyrmling burns what its breath catches",
        fn = function()
            local Status = require("models.status")
            local c, party, enemies = combatWith({ "character_knight" }, { "character_wyrmling" })
            local wyrmling, target = enemies[1], party[1]
            Combat.teleportUnit(c, wyrmling, 6, 6)
            Combat.teleportUnit(c, target, 4, 6)
            openTurn(c, wyrmling)
            assert(Combat.useItem(c, wyrmling, itemNamed(wyrmling.char, "weapon_wyrmling_breath"),
                target.x, target.y), "the wyrmling breathes")
            assert(Status.has(target, "status_burn"), "fire leaves Burn behind")
        end,
    },
}
