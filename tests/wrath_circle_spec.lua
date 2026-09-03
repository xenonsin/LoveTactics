-- Tests for the WRATH CIRCLE: the volcanic stratum's five bodies, its mini sin, and the rule they share.
--
-- The tier's design rule, pinned here as it is for Gluttony and Envy: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST. Ira's Unappeased Heart is two compounding terms with no ceiling; the Anvil runs one
-- term with a cap and then, at half health, takes the cap off.
--
-- Also pins the circle's real design property: the escalation is on the BOARD, not on the stat lines.
-- Everything here leaves fire behind, the drake drinks it, and the Anvil is paid for the trades you take
-- once you can no longer kite.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

return {
    {
        name = "Wrath's stair is held by its own mini sin, not by a borrowed arena fighter",
        fn = function()
            local sin
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then sin = s end end
            assert(sin, "the wrath circle exists")
            assert(sin.minor.lead == "character_the_anvil", "the Anvil holds the honour-guard floor")
            assert(sin.guardian.filler == sin.minor.lead, "and fills out Ira's own stair")
            -- The Champion is still a correctly built body and still the pattern for authoring phases;
            -- it just is not a sin.
            assert(Character.defs["character_champion"], "the Champion is still in the game")
        end,
    },

    -- ------------------------------------------------------------ the board escalates, not the stats
    {
        name = "a body that falls here leaves fire on the tile",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 2, 2) },
                { unit("character_ember_spit", 6, 6) })
            local spit
            for _, u in ipairs(c.units) do
                if u.char.id == "character_ember_spit" then spit = u end
            end
            assert(not Hazard.at(c, 6, 6, "hazard_fire"), "the tile starts clean")
            Combat.dealFlatDamage(c, spit, 99999, {}, "test")
            assert(not spit.alive, "the spit falls")
            assert(Hazard.at(c, 6, 6, "hazard_fire"),
                "and the tile it fell on is alight -- clearing the swarm costs you ground")
        end,
    },
    {
        name = "the Unquenched drinks the fire it is standing in, and nothing on clean ground",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_the_unquenched", 6, 4) })
            local drake, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else drake = u end
            end
            local jaws = itemNamed(drake.char, "weapon_rift_jaws")
            Combat.dealFlatDamage(c, drake, 60, {}, "test")

            -- On clean ground, acting pays it nothing.
            local clean = Fixture.hp(drake)
            openTurn(c, drake)
            assert(Combat.useItem(c, drake, jaws, 5, 4), "the drake bites")
            assert(Fixture.hp(drake) <= clean, "on clean ground it heals nothing")

            -- Set its own tile alight and let it act again.
            Hazard.place(c, drake.x, drake.y, "hazard_fire", { side = "enemy" })
            local burning = Fixture.hp(drake)
            openTurn(c, drake)
            assert(Combat.useItem(c, drake, jaws, 5, 4), "the drake bites again")
            assert(Fixture.hp(drake) > burning,
                "standing in fire, acting feeds it -- which is why clearing the swarm is the losing line")
        end,
    },

    -- ------------------------------------------------------------ the tier's rule
    {
        name = "Kindling climbs with blows taken and then stops",
        fn = function()
            local def = Trait.defs["trait_kindling"]
            assert(def, "the trait exists")
            assert(def.ceiling and def.ceiling > 0, "the CAP is the whole difference from Ira's version")
            local parent = Trait.defs["trait_wrath_rising"]
            assert(parent and parent.magnitude, "the general's rule has a missing-health term")
            assert(def.magnitude == nil,
                "the mini sin's version has no missing-health curve at all -- one term, not two")

            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 2, 2) },
                { unit("character_forge_wretch", 6, 6) })
            local wretch
            for _, u in ipairs(c.units) do
                if u.char.id == "character_forge_wretch" then wretch = u end
            end
            -- ctx.addBonus writes unit.bonus, NOT char.stats -- a per-battle bump that never touches the
            -- blueprint. So the reading is off the unit, which is also what combat itself adds in.
            local function sharpness(u) return (u.bonus and u.bonus.damage) or 0 end
            assert(sharpness(wretch) == 0, "it starts unsharpened")

            for _ = 1, 3 do Combat.dealFlatDamage(c, wretch, 4, {}, "test") end
            local sharpened = sharpness(wretch)
            assert(sharpened > 0, "chipping it builds it")

            -- ...and it stops. Many more blows must not carry it past the ceiling.
            for _ = 1, 20 do Combat.dealFlatDamage(c, wretch, 1, {}, "test") end
            assert(sharpness(wretch) <= def.ceiling, string.format(
                "Kindling holds at its ceiling of %d (reached %d); only Ira's version never stops",
                def.ceiling, sharpness(wretch)))
        end,
    },
    {
        name = "the Anvil's second phase is Ira's first",
        fn = function()
            local forge = Item.defs["utility_cold_forge"]
            assert(forge, "the Cold Forge exists")
            local carries = false
            for _, t in ipairs(forge.traits or {}) do if t == "trait_kindling" then carries = true end end
            assert(carries, "it opens on the capped rule")

            assert(forge.phases and #forge.phases == 1, "a mini sin gets ONE phase")
            local phase = forge.phases[1]
            assert(phase.at == 0.5, "and it turns at half health")
            local enrages = false
            for _, r in ipairs(phase.responses or {}) do
                if r.kind == "enrage" then enrages = true end
            end
            assert(enrages, "the phase switches on the general's own uncapped curve")
        end,
    },
    {
        name = "the Anvil opens soft, which is what makes it the player's own fault",
        fn = function()
            local anvil = Character.defs["character_the_anvil"]
            local ira = Character.defs["character_general_wrath"]
            assert(anvil.boss and anvil.referenceLevel, "a centrepiece that scales toward the shallows")
            assert(anvil.stats.damage < ira.stats.damage,
                "it starts below its general -- everything it becomes, you did to it")
            -- THE BAND IS 60-85%, AND THE TOP OF IT IS ARITHMETIC RATHER THAN TASTE. A mini sin is a
            -- boss-rung body (it is a floor's centrepiece with a phase table), so Balance.HEALTH_BANDS
            -- floors it at 155 -- and Ira is the lightest general in the game at 211. 155/211 is already
            -- 73%, so no Wrath mini sin can sit at "roughly 60%" and still be tier 4. The rule that
            -- actually holds across all seven circles is: comfortably under its general, comfortably
            -- over its own circle's line body.
            local share = anvil.stats.health / ira.stats.health
            assert(share > 0.6 and share < 0.85, string.format(
                "the Anvil is %.0f%% of Ira; the tier sits between 60%% and 85%%", share * 100))
            assert(anvil.stats.health > Character.defs["character_cinder_kin"].stats.health,
                "and it outweighs its circle's line body")
        end,
    },

    -- ------------------------------------------------------------ the apex
    {
        name = "Rift-Born shrinks the room instead of growing itself",
        fn = function()
            local rift = Item.defs["utility_riftline"]
            assert(rift and rift.phases and #rift.phases == 2, "it splits twice")
            for _, phase in ipairs(rift.phases) do
                local summons = false
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        summons = true
                        assert(r.id == "character_ember_spit",
                            "it sheds the swarm, which is TERRAIN: each one leaves fire where it falls")
                    end
                    assert(r.kind ~= "bonus" or r.amount < 0,
                        "the escalation is on the board, not on the Rift-Born's stat line")
                end
                assert(summons, "every threshold sheds something")
            end
            assert(Character.defs["character_rift_born"].footprint.w == 2, "the apex stands on four tiles")
        end,
    },

    -- ------------------------------------------------------------ the kit contract
    {
        name = "every Wrath item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_ember_spit", "weapon_cinder_brand", "weapon_rift_jaws",
                                  "utility_ember_husk", "utility_forge_scar", "utility_quenchless_gut",
                                  "utility_riftline", "utility_cold_forge" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
}
