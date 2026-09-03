-- Tests for the SLOTH CIRCLE: the tundra's five bodies, its mini sin, and the rule they share.
--
-- The tier's design rule, pinned here as it is for the other circles: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST. Acedia's Forsworn Pike swears the WHOLE party at the opening bell; the Late Watch
-- swears one pair, on its own turn, and then at half health starts bracing the way her Oathkeeper Shield
-- does.
--
-- The circle's real design property: SLOTH TAKES TURNS, NOT HEALTH. The tundra's floor is the one
-- terrain in the game that does not tax a step (data/biomes/tundra.lua), so a stratum built on it has to
-- charge the clock instead, and every body here does.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

return {
    {
        name = "Sloth's stair is held by its own mini sin",
        fn = function()
            local sin
            for _, s in ipairs(Descent.SINS) do if s.id == "sloth" then sin = s end end
            assert(sin and sin.minor.lead == "character_the_late_watch", "the Late Watch holds the floor")
            assert(sin.guardian.filler == sin.minor.lead, "and fills out Acedia's own stair")
        end,
    },

    -- ------------------------------------------------------------ the circle charges the clock
    {
        name = "every Sloth body costs a turn rather than health",
        fn = function()
            -- Stated as a property of the KIT rather than of one body: what makes this stratum itself is
            -- that its weapons all land control. A future body here that only dealt damage would be a
            -- Wrath creature wearing a tundra tileset.
            local expect = {
                weapon_rime_nip = "status_freeze",
                weapon_drift_touch = "status_halted",
                weapon_hoarfrost_antlers = "status_freeze",
            }
            for id, status in pairs(expect) do
                local src = love.filesystem.read("data/items/weapon/" .. id .. ".lua")
                assert(src and src:find(status, 1, true),
                    id .. " must land " .. status .. " -- Sloth charges the clock, not the body")
            end
        end,
    },
    {
        name = "a drift-thing Halts, and a rime-gnat Freezes",
        fn = function()
            for _, case in ipairs({
                { id = "character_drift_thing", weapon = "weapon_drift_touch", status = "status_halted" },
                { id = "character_rime_gnat", weapon = "weapon_rime_nip", status = "status_freeze" },
            }) do
                local map = Fixture.new(10, 10)
                local c = Fixture.combat(map,
                    { unit("character_knight", 4, 4) },
                    { unit(case.id, 5, 4) })
                local foe, victim
                for _, u in ipairs(c.units) do
                    if u.side == "party" then victim = u else foe = u end
                end
                openTurn(c, foe)
                assert(Combat.useItem(c, foe, itemNamed(foe.char, case.weapon), victim.x, victim.y),
                    case.id .. " acts")
                assert(Status.has(victim, case.status), case.id .. " must land " .. case.status)
            end
        end,
    },

    -- ------------------------------------------------------------ the rule
    {
        name = "Torpor swears one pair, once, where Acedia swears the whole party",
        fn = function()
            local def = Trait.defs["trait_torpor"]
            local parent = Trait.defs["trait_unrelieved"]
            assert(def and parent, "both rules exist")
            assert(parent.onCombatStart, "the general's version arrives before anybody moves")
            assert(def.onCast, "the mini sin's is paid for with a turn")

            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3), unit("character_archer", 3, 5),
                  unit("character_knight", 3, 7) },
                { unit("character_hollow_sleeper", 6, 4) })
            local sleeper, foes = nil, {}
            for _, u in ipairs(c.units) do
                if u.char.id == "character_hollow_sleeper" then sleeper = u else foes[#foes + 1] = u end
            end

            -- Nothing sworn before it acts: that is the whole difference from the general.
            local sworn = 0
            for _, u in ipairs(foes) do if Status.has(u, "status_sworn") then sworn = sworn + 1 end end
            assert(sworn == 0, "nobody is sworn until the sleeper does it")

            -- The touch is reach 1, so the sleeper has to actually be beside somebody or useItem
            -- refuses and onCast never fires -- which reads in a test exactly like the trait not working.
            Combat.teleportUnit(c, sleeper, foes[1].x + 1, foes[1].y)
            openTurn(c, sleeper)
            assert(Combat.useItem(c, sleeper, itemNamed(sleeper.char, "weapon_drift_touch"),
                foes[1].x, foes[1].y), "the sleeper acts")

            sworn = 0
            for _, u in ipairs(foes) do if Status.has(u, "status_sworn") then sworn = sworn + 1 end end
            assert(sworn == 2, string.format(
                "Torpor swears exactly one PAIR (saw %d) -- swearing all three is Acedia's version", sworn))
        end,
    },
    {
        name = "the Winter Hart lays the biome's own ice as it acts",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_the_winter_hart", 7, 4) })
            local hart
            for _, u in ipairs(c.units) do
                if u.char.id == "character_the_winter_hart" then hart = u end
            end
            assert(not Hazard.at(c, hart.x, hart.y, "hazard_black_ice"), "it starts on clean ground")
            openTurn(c, hart)
            Combat.useItem(c, hart, itemNamed(hart.char, "weapon_hoarfrost_antlers"), 6, 4)
            assert(Hazard.at(c, hart.x, hart.y, "hazard_black_ice"),
                "the danger is where the Hart has BEEN, not the Hart")
        end,
    },

    -- ------------------------------------------------------------ the tier's rule
    {
        name = "the Late Watch's second phase is Acedia's other half",
        fn = function()
            local watch = Item.defs["utility_unkept_watch"]
            assert(watch, "the Unkept Watch exists")
            local carries = false
            for _, t in ipairs(watch.traits or {}) do if t == "trait_torpor" then carries = true end end
            assert(carries, "it opens on the one-pair rule")
            assert(watch.phases and #watch.phases == 1, "a mini sin gets ONE phase")
            assert(watch.phases[1].at == 0.5, "and it turns at half health")

            local braces = false
            for _, r in ipairs(watch.phases[1].responses or {}) do
                if r.kind == "bonus" and r.amount > 0 then braces = true end
            end
            assert(braces, "the phase braces, which is the Oathkeeper Shield half of Acedia's kit")
        end,
    },
    {
        name = "the Late Watch sits between its line body and its general",
        fn = function()
            local watch = Character.defs["character_the_late_watch"]
            local acedia = Character.defs["character_general_sloth"]
            assert(watch.boss and watch.referenceLevel, "a centrepiece that scales toward the shallows")
            assert(watch.stats.health > Character.defs["character_drift_thing"].stats.health,
                "it outweighs its circle's line body")
            local share = watch.stats.health / acedia.stats.health
            assert(share > 0.6 and share < 0.85, string.format(
                "the Late Watch is %.0f%% of Acedia; the tier sits between 60%% and 85%%", share * 100))
        end,
    },

    -- ------------------------------------------------------------ the apex
    {
        name = "the Long Winter sheds bodies that take turns, not damage",
        fn = function()
            local dark = Item.defs["utility_long_dark"]
            assert(dark and dark.phases and #dark.phases == 2, "it thickens twice")
            for _, phase in ipairs(dark.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_drift_thing",
                            "it sheds Halters -- on the board where movement is free, tempo is the tax")
                    end
                    assert(r.kind ~= "bonus" or r.amount < 0, "the apex adds bodies, not strength")
                end
            end
            assert(Character.defs["character_the_long_winter"].footprint.w == 2,
                "the apex stands on four tiles")
        end,
    },
    {
        name = "every Sloth item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_rime_nip", "weapon_drift_touch", "weapon_hoarfrost_antlers",
                                  "utility_sleepers_weight", "utility_hoarfrost_pelt",
                                  "utility_long_dark", "utility_unkept_watch" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
}
