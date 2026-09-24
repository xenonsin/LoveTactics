-- Tests for the SLOTH CIRCLE: what is left of the tundra's bodies, its mini sin, and the rule they
-- share. Four of the five went in the strata cut (2026-09-22) and the apex is the only one standing;
-- where a case's SUBJECT survived the deletion and only its fixture did not, it is staged on a bare
-- stand-in wearing the piece, and where the rule itself went with the body the case is deleted and
-- what it promised is written out where it stood.
--
-- The tier's design rule, pinned here as it is for the other circles: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST. Acedia's Forsworn Pike swears the WHOLE party at the opening bell; the Unkept Watch
-- swears one pair, on its own turn, and then at half health starts bracing the way her Oathkeeper Shield
-- does.
--
-- THE BODY THAT WORE IT IS GONE. The Late Watch was deleted with the other six lieutenants (2026-09-22,
-- Descent.SINS' header) and the watch is not, so the rule above is pinned on the ITEM alone and the case
-- that sized the blueprint is written out as a contract at the foot of this file. Sloth is also the one
-- circle with nothing ordinary left to stand in for it -- read the slot's own note in Descent.SINS.
--
-- The circle's real design property: SLOTH TAKES TURNS, NOT HEALTH. The tundra's floor is the one
-- terrain in the game that does not tax a step (data/biomes/tundra.lua), so a stratum built on it has to
-- charge the clock instead, and every body here does.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

return {
    {
        -- THE LATE WATCH IS DELETED AND THIS CASE IS THE MARKER -- and this is the loudest of the seven
        -- slots, because the tundra rolls exactly two bodies and one of them is tier 1, so the stand-in
        -- is this circle's own ELITE and the stratum bills the Long Winter twice. Named here on purpose:
        -- seating a replacement reddens this case, and whoever does it owes the contract at the foot of
        -- this file.
        name = "Sloth's lieutenant slot is filled, and by the only body left to fill it",
        fn = function()
            local sin
            for _, s in ipairs(Descent.SINS) do if s.id == "sloth" then sin = s end end
            assert(sin and sin.minor.lead == "character_the_long_winter",
                "the Long Winter stands in for the Late Watch")
            assert(Character.defs[sin.minor.lead], "and whatever stands there is a body that loads")
            assert(not Character.defs["character_the_late_watch"], "the Late Watch is gone")
        end,
    },

    -- ------------------------------------------------------------ the circle charges the clock
    {
        name = "every Sloth body costs a turn rather than health",
        fn = function()
            -- Stated as a property of the KIT rather than of one body: what makes this stratum itself is
            -- that its weapons all land control. A future body here that only dealt damage would be a
            -- Wrath creature wearing a tundra tileset.
            -- weapon_rime_nip went with the rime-gnat in the strata cut and is not on this list any
            -- more; the two below are what the circle still swings. A refill adds its own pieces here,
            -- and the point of the list is that adding one to the tundra without a control rider on it
            -- is what should redden.
            local expect = {
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
        -- BOTH BODIES THAT WORE THESE ARE GONE and only one of the two weapons survived with them.
        -- The drift-touch is still here and nobody ships carrying it, so it is measured on a bare
        -- stand-in; the rime-nip is deleted outright, and what it said -- that the circle's cheapest
        -- chaff Froze rather than bit -- is unasserted until something is authored to say it again.
        -- The apex's own antlers are the circle's other live control rider, and the case above holds
        -- both of them to it by reading the source.
        name = "a drift-touch Halts what it reaches",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_ice_elemental", 5, 4,
                    { isolate = "bare", items = { "weapon_drift_touch" } }) })
            local foe, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else foe = u end
            end
            openTurn(c, foe)
            assert(Combat.useItem(c, foe, itemNamed(foe.char, "weapon_drift_touch"), victim.x, victim.y),
                "the drifting thing reaches out")
            assert(Status.has(victim, "status_halted"),
                "and takes the turn rather than the health -- the circle's whole rule")
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

            -- THE SLEEPER IS DELETED AND TORPOR IS NOT. It still rides utility_unkept_watch -- the
            -- deleted mini sin's own piece, and the only live bearer -- so the rule is measured on a
            -- stand-in wearing the watch and the touch. Health well clear of the watch's half-health
            -- phase, which braces and would otherwise fire inside a case that is not about it.
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3), unit("character_archer", 3, 5),
                  unit("character_knight", 3, 7) },
                { unit("character_ice_elemental", 6, 4, { isolate = "bare", stats = { health = 200 },
                    items = { "weapon_drift_touch", "utility_unkept_watch" } }) })
            local sleeper, foes = nil, {}
            for _, u in ipairs(c.units) do
                if u.side ~= "party" then sleeper = u else foes[#foes + 1] = u end
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
    -- THE WINTER HART'S CASE IS DELETED WITH THE BODY, and it could not be repointed the way the two
    -- above were, because the rule went with it and not just the fixture. The ice was never the
    -- antlers' -- those survive on the apex and only Freeze -- it was `trait_conduction`, riding
    -- utility_hoarfrost_pelt, and both are gone. What it said:
    --
    --     it acts, and hazard_black_ice is left on the tile it acted FROM
    --
    -- So the danger was where the Hart had BEEN rather than where it was, and a company that chased
    -- it across the tundra was walking its own pursuit into the floor. Nothing in the game lays black
    -- ice now except the biome itself (data/biomes/tundra.lua), so the verb is the tundra's alone
    -- until something is authored to carry it again.


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
    -- THE CASE THAT SIZED THE LATE WATCH IS GONE WITH THE BODY, and this is what it said so the
    -- replacement can be held to it:
    --
    --     boss = true and a referenceLevel   a centrepiece that scales toward the shallows
    --     health above its circle's line     it outweighs the stock it stands over
    --     health 60-85% of Acedia's          and stands below the sin whose stair it holds
    --
    -- The same band tests/wrath_circle_spec.lua argues out in full. The line body it was measured
    -- against, character_drift_thing, went in the strata cut, so the replacement owes a line body too.

    -- ------------------------------------------------------------ the apex
    {
        name = "the Long Winter sheds bodies that take turns, not damage",
        fn = function()
            local dark = Item.defs["utility_long_dark"]
            assert(dark and dark.phases and #dark.phases == 2, "it thickens twice")
            for _, phase in ipairs(dark.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        -- It shed drift-things until the strata cut took them; the tundra's own
                        -- surviving stock stands in (see utility_long_dark's note). What the apex
                        -- must never shed is a body that trades in DAMAGE -- on the one board where
                        -- movement is free, tempo is the tax.
                        assert(r.id == "character_ice_elemental",
                            "the apex sheds the circle's own stock, not somebody else's")
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
            -- weapon_rime_nip, utility_sleepers_weight and utility_hoarfrost_pelt went with the three
            -- bodies that wore them. The four below are what the circle still carries.
            for _, id in ipairs({ "weapon_drift_touch", "weapon_hoarfrost_antlers",
                                  "utility_long_dark", "utility_unkept_watch" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
}
