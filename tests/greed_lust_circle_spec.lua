-- Tests for the GREED and LUST circles -- the last two strata, and the two whose rules are about
-- resources rather than about the board.
--
-- The tier's design rule, pinned as it is for every other circle: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST.
--
--   Aurea lifts an ITEM off an adjacent body from her opening bell; the Tally takes coin, and starts
--   taking gear at half health.
--   Luxuria drains a foe's held-back reserves on EVERY hit; the Suppliant drains only a body that spent
--   nothing, and drops the condition at half health.
--
-- Both circles are grouped here because both are about what a player is CARRYING rather than about
-- terrain, and the two rules are each other's mirror -- one takes what you hoarded, the other punishes
-- you for hoarding it.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

local function sinNamed(id)
    for _, s in ipairs(Descent.SINS) do if s.id == id then return s end end
end

return {
    -- ------------------------------------------------------------ both stairs
    {
        name = "Greed and Lust are each held by their own mini sin",
        fn = function()
            assert(sinNamed("greed").minor.lead == "character_the_tally", "the Tally holds the Undercroft")
            assert(sinNamed("lust").minor.lead == "character_the_suppliant", "the Suppliant holds the Cathedral")
            for _, id in ipairs({ "greed", "lust" }) do
                local sin = sinNamed(id)
                assert(sin.guardian.filler == sin.minor.lead,
                    id .. "'s mini sin must fill out its own general's stair")
            end
        end,
    },

    -- ------------------------------------------------------------ Greed: it reads your purse
    {
        name = "an Assayer is worth more the richer the party is, and nothing without a purse",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3) },
                { unit("character_assayer", 6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.char.id == "character_assayer" then assayer = u end
            end

            -- No purse injected: a draft duel, an arena, a headless fixture. It must read as nothing
            -- rather than faulting off the board it was not built for.
            assert(Trait.liveBonus(assayer, "damage") == 0,
                "with no campaign purse under the fight, the scales weigh nothing")

            -- states/battle.lua injects `combat.purse = { get, spend }` for a campaign fight.
            local gold = 3000
            c.purse = { get = function() return gold end, spend = function(n) gold = gold - n end }
            local rich = Trait.liveBonus(assayer, "damage")
            assert(rich > 0, "a full purse makes it heavier")

            gold = 100
            assert(Trait.liveBonus(assayer, "damage") < rich,
                "and it lightens as the purse empties -- which is why its own thieves are helping you")
        end,
    },
    {
        name = "the Assayer is capped, so a rich run does not meet an unkillable body",
        fn = function()
            local def = Trait.defs["trait_assayed"]
            assert(def and def.ceiling and def.per, "the scales declare both a rate and a ceiling")
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3) },
                { unit("character_assayer", 6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.char.id == "character_assayer" then assayer = u end
            end
            c.purse = { get = function() return 9999999 end, spend = function() end }
            assert(Trait.liveBonus(assayer, "damage") == def.ceiling,
                "an absurd purse still stops at the ceiling")
        end,
    },
    {
        name = "the Tally's second phase is Aurea's first",
        fn = function()
            local reck = Item.defs["utility_the_reckoning"]
            assert(reck and reck.phases and #reck.phases == 1, "a mini sin gets ONE phase")
            assert(reck.phases[1].at == 0.5, "and it turns at half health")
            local carries = false
            for _, t in ipairs(reck.traits or {}) do if t == "trait_assayed" then carries = true end end
            assert(carries, "it opens reading the purse")
        end,
    },
    {
        name = "the Hoard spends itself as you open it",
        fn = function()
            local hoard = Item.defs["utility_the_hoard"]
            assert(hoard and hoard.phases and #hoard.phases == 2, "it comes apart twice")
            for _, phase in ipairs(hoard.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_coin_chitter",
                            "what leaves a disturbed hoard is pieces of it, carrying as much as they can")
                    end
                end
            end
            local def = Character.defs["character_the_hoard"]
            assert(def.footprint and def.footprint.w == 2, "the apex stands on four tiles")
            assert(def.kind == "object", "it is the pile, not something guarding one")
        end,
    },

    -- ------------------------------------------------------------ Lust: it reads what you held back
    {
        name = "the Unasked drains a foe and takes half of it as health",
        fn = function()
            -- `isolate = "bare"` empties the victim's grid. Without it a knight PARRIES the touch and
            -- counters for more than the drain heals, so the Suppliant's net health goes DOWN and the
            -- rule looks broken when it is working exactly as authored.
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unit("character_the_suppliant", 5, 4) })
            local sup, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else sup = u end
            end
            Combat.dealFlatDamage(c, sup, 40, {}, "test")
            local hurt = Fixture.hp(sup)
            local stam = victim.char.stats.stamina.current

            openTurn(c, sup)
            assert(Combat.useItem(c, sup, itemNamed(sup.char, "weapon_petal_touch"), victim.x, victim.y),
                "the Suppliant acts")
            assert(victim.char.stats.stamina.current < stam, "it draws off what was held back")
            assert(Fixture.hp(sup) > hurt, "and takes it into itself")
        end,
    },
    {
        name = "the Unasked is Rapture with a condition on it",
        fn = function()
            local mine = Trait.defs["trait_unasked"]
            local hers = Trait.defs["trait_rapture"]
            assert(mine and hers, "both rules exist")
            assert(mine.stamina < hers.stamina and mine.mana < hers.mana,
                "the mini sin takes less per hit than its general")
            -- Both must honour Amana's counter, or the one answer to the sin works on only half of it.
            for _, id in ipairs({ "trait_unasked", "trait_rapture" }) do
                local src = love.filesystem.read("data/traits/" .. id .. ".lua")
                assert(src and src:find("trait_devotion_unbidden", 1, true),
                    id .. " must honour a will that gave everything away")
            end
        end,
    },
    {
        name = "a Chorister Charms as it acts, then has to wait",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_chorister", 5, 4) })
            local chor, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else chor = u end
            end
            openTurn(c, chor)
            assert(Combat.useItem(c, chor, itemNamed(chor.char, "weapon_petal_touch"), victim.x, victim.y),
                "the chorister sings")
            assert(Status.has(victim, "status_charm"), "and somebody goes to it")

            local def = Trait.defs["trait_lure"]
            assert(def.cooldown and def.cooldown > 0,
                "the cooldown is what makes it a decision rather than a lock")
        end,
    },
    {
        name = "the Beloved makes the choice worse rather than the fight",
        fn = function()
            local dev = Item.defs["utility_beloveds_devotion"]
            assert(dev and dev.phases and #dev.phases == 2, "it sheds twice")
            for _, phase in ipairs(dev.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_petal_drift",
                            "it sheds the chaff that makes holding your good ability feel correct")
                    end
                    assert(r.kind ~= "bonus" or r.amount < 0,
                        "the apex escalates the dilemma, not its own stat line")
                end
            end
        end,
    },

    -- ------------------------------------------------------------ both mini sins sit in band
    {
        name = "both mini sins sit between their line body and their general",
        fn = function()
            for _, case in ipairs({
                { mini = "character_the_tally", general = "character_general_greed",
                  line = "character_coffer_crawler" },
                { mini = "character_the_suppliant", general = "character_general_lust",
                  line = "character_bloom_wraith" },
            }) do
                local mini = Character.defs[case.mini]
                local gen = Character.defs[case.general]
                assert(mini.boss and mini.referenceLevel, case.mini .. ": a centrepiece that scales down")
                assert(mini.stats.health > Character.defs[case.line].stats.health,
                    case.mini .. " must outweigh its circle's line body")
                local share = mini.stats.health / gen.stats.health
                assert(share > 0.6 and share < 0.85, string.format(
                    "%s is %.0f%% of its general; the tier sits between 60%% and 85%%",
                    case.mini, share * 100))
            end
        end,
    },
    {
        name = "every Greed and Lust item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_cutpurse_nip", "weapon_coffer_shell", "weapon_gilt_maw",
                                  "utility_assay_scales", "utility_the_reckoning", "utility_the_hoard",
                                  "weapon_petal_touch", "weapon_bloom_reach", "weapon_antler_crown",
                                  "utility_chorister_call", "utility_offered_nothing",
                                  "utility_beloveds_devotion" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and not def.class and not def.discipline,
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
}
