-- Tests for the GLUTTONY CIRCLE: the swamp's five creatures, its mini sin, and the one rule they share.
--
-- The tier's design rule, which this file exists to pin: A MINI SIN'S SECOND PHASE IS ITS GENERAL'S
-- FIRST. The Gralloch opens with Engorge (it feeds when something dies near it) and at half health picks
-- up heal-on-hit, which is Gula's baseline from her own opening bell (data/traits/trait_ravenous.lua).
-- So the circle's first floor teaches the sin the slow way and the second floor is a recognition.
--
-- Also pins the two live bugs this circle closed: Gluttony's honour-guard lead was character_dire_bear,
-- a Wild Shape whose pools are placeholders, and its guardian filler was the same body.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Growth = require("models.growth")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

local function sinNamed(id)
    for _, sin in ipairs(Descent.SINS) do
        if sin.id == id then return sin end
    end
end

return {
    -- ------------------------------------------------------------ the bug it closed
    {
        name = "no circle is led by a body that cannot stand on its own",
        fn = function()
            -- A Wild Shape carries placeholder pools -- the wearer's own health is carried across
            -- (models/transform.lua) -- so its blueprint health is meaningless as a standalone body.
            -- Gluttony fielded character_dire_bear (health 1) as its honour-guard lead AND as its
            -- guardian filler. Swept over every circle so the next one cannot reintroduce it.
            -- TIER 0 IS THE SIGNAL, not a health floor. Rung 0 is the declared "this body does not
            -- fight" -- a prop, an escortee, a worn shape -- and it is exactly what character_dire_bear
            -- is. A health threshold would be the wrong test: a gorge-fly is legitimately 12 health, and
            -- chaff that dies to one blow is correct FILLER. What a floor's centrepiece may not be is
            -- chaff, so the lead is held to the line rung as well.
            for _, sin in ipairs(Descent.SINS) do
                for _, band in ipairs({ "guardian", "minor" }) do
                    for _, slot in ipairs({ "lead", "filler" }) do
                        local id = sin[band][slot]
                        local def = Character.defs[id]
                        assert(def, sin.id .. "." .. band .. "." .. slot .. ": unknown body " .. tostring(id))
                        assert((def.tier or 0) > 0, string.format(
                            "%s.%s.%s is %s, which is tier 0 -- a prop, an escortee or a worn shape, "
                            .. "whose pools are placeholders its wearer replaces. It has no statline to "
                            .. "fight with.", sin.id, band, slot, id))
                        if slot == "lead" then
                            assert(def.tier >= 2, string.format(
                                "%s.%s.lead is %s at tier %d. A floor's centrepiece is not chaff.",
                                sin.id, band, id, def.tier))
                        end
                    end
                end
            end
        end,
    },
    {
        name = "Gluttony's stair is held by its own mini sin, escorted by its own stock",
        fn = function()
            local sin = sinNamed("gluttony")
            assert(sin, "the gluttony circle exists")
            assert(sin.minor.lead == "character_the_gralloch", "the Gralloch holds the honour-guard floor")
            assert(sin.minor.filler == "character_gorge_fly", "escorted by the circle's own swarm")
            -- ...and it is Gula's own lieutenant, which tests/descent_spec.lua pins across every circle.
            -- That invariant is what the whole tier is for: the body that barred the stair two floors ago
            -- is at her shoulder when you reach her, so the rule it taught you the slow way stands beside
            -- the thing that has had it from the opening bell.
            assert(sin.guardian.filler == sin.minor.lead,
                "the mini sin fills out its own general's stair")
        end,
    },

    -- ------------------------------------------------------------ the rule
    {
        name = "Engorge feeds on any death nearby, including the pack's own",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 2, 2) },
                { unit("character_tallow_hound", 5, 5), unit("character_gorge_fly", 5, 6) })
            local hound, fly
            for _, u in ipairs(c.units) do
                if u.char.id == "character_tallow_hound" then hound = u end
                if u.char.id == "character_gorge_fly" then fly = u end
            end
            assert(hound and fly, "both bodies took the field")

            Combat.dealFlatDamage(c, hound, 20, {}, "test")
            local hurt = Fixture.hp(hound)

            -- Kill its OWN fly beside it. The pack's combo is that clearing the chaff also feeds it.
            Combat.dealFlatDamage(c, fly, 99999, {}, "test")
            assert(not fly.alive, "the fly falls")
            assert(Fixture.hp(hound) > hurt,
                "the hound is fed by a death on its own side -- Engorge does not check whose")
        end,
    },
    {
        name = "Engorge is out of reach across the board",
        fn = function()
            local map = Fixture.new(20, 20)
            local c = Fixture.combat(map,
                { unit("character_knight", 1, 1) },
                { unit("character_tallow_hound", 18, 18), unit("character_gorge_fly", 2, 2) })
            local hound, fly
            for _, u in ipairs(c.units) do
                if u.char.id == "character_tallow_hound" then hound = u end
                if u.char.id == "character_gorge_fly" then fly = u end
            end
            Combat.dealFlatDamage(c, hound, 20, {}, "test")
            local hurt = Fixture.hp(hound)
            Combat.dealFlatDamage(c, fly, 99999, {}, "test")
            assert(Fixture.hp(hound) == hurt,
                "a death sixteen tiles away feeds nothing -- it has to get to the body")
        end,
    },

    -- ------------------------------------------------------------ the tier's rule
    {
        name = "the Gralloch's second phase is Gula's first",
        fn = function()
            -- Before the phase: the hook carries Engorge and nothing else. Gula carries Ravenous, which
            -- heals her on every blow she lands. The mini sin picks that up at half health, so the two
            -- floors of the circle are the same rule at two speeds.
            local hook = Item.defs.utility_gralloch_hook
            assert(hook, "the hook exists")
            local carriesEngorge = false
            for _, t in ipairs(hook.traits or {}) do
                if t == "trait_engorge" then carriesEngorge = true end
            end
            assert(carriesEngorge, "it opens on Engorge -- the cheap, legible half")

            assert(hook.phases and #hook.phases == 1,
                "a mini sin gets ONE phase; a general gets two or three")
            local phase = hook.phases[1]
            assert(phase.at == 0.5, "and it turns at half health")

            local armsThirst = false
            for _, r in ipairs(phase.responses or {}) do
                if r.kind == "status" and r.id == "status_red_thirst" then
                    armsThirst = true
                    assert((r.opts or {}).duration and r.opts.duration > 100,
                        "the thirst must outlast the fight -- a phase that lapsed would be a lie")
                end
            end
            assert(armsThirst, "the phase arms heal-on-hit, which is Gula's baseline")
        end,
    },
    {
        name = "the Gralloch is a step below its general and a step above the line",
        fn = function()
            local mini = Character.defs.character_the_gralloch
            local gula = Character.defs.character_general_gluttony
            assert(mini.boss, "a centrepiece is off the execute and Charm tables")
            assert(mini.referenceLevel, "and scales DOWN toward the shallows, since circles are shuffled")

            local line = Character.defs.character_bogswallow.stats.health
            assert(mini.stats.health > line, "a mini sin outweighs the line body of its own circle")
            assert(mini.stats.health < gula.stats.health,
                "and stands below the sin whose stair it is holding")
            -- The band the tier was authored to: around 60% of a general.
            local share = mini.stats.health / gula.stats.health
            assert(share > 0.6 and share < 0.85, string.format(
                "the Gralloch is %.0f%% of Gula; the tier sits between 60%% and 85%%", share * 100))
        end,
    },

    -- ------------------------------------------------------------ the apex
    {
        name = "the Sated is a four-tile body that gets weaker as it is cut",
        fn = function()
            local def = Character.defs.character_the_sated
            assert(def.footprint and def.footprint.w == 2 and def.footprint.h == 2,
                "the apex stands on four tiles")
            local hide = Item.defs.utility_distended_hide
            assert(hide and hide.phases, "and carries a phase table")

            -- Every magnitude in it is NEGATIVE. That is the whole conceit and the thing most likely to
            -- be "fixed" by somebody reading it as a typo.
            local drops = 0
            for _, phase in ipairs(hide.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "bonus" then
                        assert(r.amount < 0, string.format(
                            "the Sated's phases must TURN IT DOWN -- %s %+d is an escalation, which is "
                            .. "Wrath's rule, not Gluttony's", r.stat, r.amount))
                        drops = drops + 1
                    end
                end
            end
            assert(drops >= 3, "it should shed real numbers, not one token point")
        end,
    },

    -- ------------------------------------------------------------ the swarm's own combo
    {
        name = "a gorge-fly bleeds, so the hound behind it has something to finish",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_gorge_fly", 5, 4) })
            local fly, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else fly = u end
            end
            openTurn(c, fly)
            assert(Combat.useItem(c, fly, itemNamed(fly.char, "weapon_gorge_bite"), victim.x, victim.y),
                "the fly bites")
            assert(Status.has(victim, "status_bleed"), "and leaves Bleed for the pack to cash")
        end,
    },
    {
        name = "a bogswallow roots, so nothing walks out of the trade",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_bogswallow", 5, 4) })
            local swallow, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else swallow = u end
            end
            openTurn(c, swallow)
            assert(Combat.useItem(c, swallow, itemNamed(swallow.char, "weapon_swallowing_grip"),
                victim.x, victim.y), "the bogswallow seizes")
            assert(Status.has(victim, "status_root"), "and the mire keeps what it catches")
        end,
    },
    {
        name = "the Grendlemaw removes a body from the fight in both directions",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_grendlemaw", 5, 4) })
            local maw, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else maw = u end
            end
            openTurn(c, maw)
            assert(Combat.useItem(c, maw, itemNamed(maw.char, "weapon_grendlemaw_gullet"),
                victim.x, victim.y), "the maw swallows")
            assert(Status.has(victim, "status_suspended"),
                "a swallowed body is lifted off the board -- unable to act, and unreachable by anyone")
        end,
    },

    -- ------------------------------------------------------------ the kit contract
    {
        -- Creature kit is natural weapons only: unpriced, noSteal, outside every shelf
        -- (tests/bestiary_spec.lua states the rule; this holds the circle's own gear to it).
        name = "every Gluttony item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_gorge_bite", "weapon_swallowing_grip", "weapon_tallow_maw",
                                  "weapon_grendlemaw_gullet", "weapon_glutted_bulk",
                                  "utility_rendered_hide", "utility_distended_hide",
                                  "utility_gralloch_hook" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal, id .. ": a pickpocket cannot lift a creature's own body off it")
                assert(not def.price, id .. ": creature kit is unpriced")
                assert(not def.class and not def.discipline,
                    id .. ": a hound is not an Alchemist -- creature kit sits outside every shelf")
                local natural = false
                for _, tag in ipairs(def.tags or {}) do
                    if tag == "natural" then natural = true end
                end
                assert(natural, id .. ": creature kit is tagged `natural`")
            end
        end,
    },
    {
        name = "the Sated's bulk sweeps a front rather than picking one body",
        fn = function()
            local bulk = Item.defs.weapon_glutted_bulk
            local aoe = bulk.activeAbility and bulk.activeAbility.aoe
            assert(aoe and aoe.shape == "front" and (aoe.width or 0) >= 3,
                "a four-tile body reaching out to poke one knight reads wrong; it sweeps")
        end,
    },

    -- ------------------------------------------------------------ it still scales
    {
        name = "every new Gluttony body grows through the same tables as everything else",
        fn = function()
            for _, id in ipairs({ "character_gorge_fly", "character_bogswallow", "character_tallow_hound",
                                  "character_grendlemaw", "character_the_sated", "character_the_gralloch" }) do
                local base = Character.instantiate(id)
                local grown = Growth.spawn(id, 20)
                assert(grown.stats.health.max >= base.stats.health.max,
                    id .. " does not climb with the company")
                assert(grown.stats.health.current == grown.stats.health.max,
                    id .. " should arrive at full health")
            end
        end,
    },
}
