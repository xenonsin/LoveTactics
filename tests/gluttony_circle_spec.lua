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
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

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
        -- THE GRALLOCH IS DELETED AND THIS CASE IS THE MARKER. Gluttony's lieutenant slot holds the
        -- pack's alpha as a stand-in (see the lieutenant note at the head of Descent.SINS), which is
        -- ordinary forest traffic and not a lesser embodiment of anything. The stand-in is named here on
        -- purpose: seating a replacement reddens this case, and whoever does it owes the contract written
        -- out where the sizing case used to be, below.
        name = "Gluttony's lieutenant slot is filled, and by a stand-in that says so",
        fn = function()
            local sin = sinNamed("gluttony")
            assert(sin, "the gluttony circle exists")
            assert(sin.minor.lead == "character_wolf_alpha", "the alpha stands in for the Gralloch")
            assert(Character.defs[sin.minor.lead], "and whatever stands there is a body that loads")
            assert(not Character.defs["character_the_gralloch"], "the Gralloch is gone")
            -- The invariant tests/descent_spec.lua pins across every circle survives the cut, because a
            -- stand-in fills both slots exactly as a lieutenant did: the body that barred the stair two
            -- floors ago is at her shoulder when you reach her. What is missing is that it be a SIN.
            assert(sin.guardian.filler == sin.minor.lead,
                "whatever holds the approach fills out its own general's stair")
        end,
    },

    -- ------------------------------------------------------------ the rule
    --
    -- BOTH ENGORGE CASES LOST THEIR FIXTURE AND KEPT THEIR SUBJECT. The pack they were staged with --
    -- a Tallow Hound fed by its own Gorge-Flies -- is deleted, but trait_engorge is not: it still
    -- rides utility_gralloch_hook, and the hook is the only live bearer left. So the pair is staged
    -- on a bare body WEARING the hook rather than on a body authored to carry it. That is the trait's
    -- rule under test either way; what is no longer asserted is that any SHIPPED body carries it,
    -- which is the replacement's job and is watched by the reachability sweep, not by this file.
    {
        name = "Engorge feeds on any death nearby, including the pack's own",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 2, 2) },
                -- 200 health so the twenty below lands nowhere near the hook's own half-health phase.
                { unit("character_slime", 5, 5, { isolate = "bare", stats = { health = 200 },
                    items = { "utility_gralloch_hook" } }),
                  unit("character_slime", 5, 6, { isolate = "bare" }) })
            local eater, chaff
            for _, u in ipairs(c.units) do
                if u.side ~= "party" then
                    if u.y == 5 then eater = u else chaff = u end
                end
            end
            assert(eater and chaff, "both bodies took the field")

            Combat.dealFlatDamage(c, eater, 20, {}, "test")
            local hurt = Fixture.hp(eater)

            -- Kill its OWN chaff beside it. The pack's combo is that clearing the chaff also feeds it.
            Combat.dealFlatDamage(c, chaff, 99999, {}, "test")
            assert(not chaff.alive, "the chaff falls")
            assert(Fixture.hp(eater) > hurt,
                "it is fed by a death on its own side -- Engorge does not check whose")
        end,
    },
    {
        name = "Engorge is out of reach across the board",
        fn = function()
            local map = Fixture.new(20, 20)
            local c = Fixture.combat(map,
                { unit("character_knight", 1, 1) },
                { unit("character_slime", 18, 18, { isolate = "bare", stats = { health = 200 },
                    items = { "utility_gralloch_hook" } }),
                  unit("character_slime", 2, 2, { isolate = "bare" }) })
            local eater, chaff
            for _, u in ipairs(c.units) do
                if u.side ~= "party" then
                    if u.x == 18 then eater = u else chaff = u end
                end
            end
            Combat.dealFlatDamage(c, eater, 20, {}, "test")
            local hurt = Fixture.hp(eater)
            Combat.dealFlatDamage(c, chaff, 99999, {}, "test")
            assert(Fixture.hp(eater) == hurt,
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
    -- THE CASE THAT SIZED THE GRALLOCH IS GONE WITH THE BODY, and this is what it said so the
    -- replacement can be held to it:
    --
    --     boss = true                        a centrepiece is off the execute and Charm tables
    --     referenceLevel                     and scales DOWN toward the shallows, since circles shuffle
    --     health above its circle's line      a mini sin outweighs the stock it stands over
    --     health 60-85% of its general's      and stands below the sin whose stair it is holding
    --
    -- The same band tests/wrath_circle_spec.lua argues out in full: comfortably under its general,
    -- comfortably over its own circle's line body.

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
    --
    -- THREE CASES ARE DELETED WITH THEIR SUBJECTS, and this is what each one said so a replacement
    -- can be held to it. All three bodies and all three weapons are gone (see the deletion's own
    -- commit); nothing survives to repoint them onto, which is the line between the two Engorge
    -- cases above and these:
    --
    --   the gorge-fly    weapon_gorge_bite left status_bleed          -- chaff that OPENS a wound the
    --                                                                    pack behind it can finish
    --   the bogswallow   weapon_swallowing_grip left status_root      -- the mire keeps what it catches
    --   the Grendlemaw   weapon_grendlemaw_gullet left status_suspended  -- a swallowed body is off the
    --                                                                    board in BOTH directions: it
    --                                                                    cannot act and nobody can
    --                                                                    reach it
    --
    -- What the three of them said together is the circle's combo -- chaff that softens, a body that
    -- holds, and an apex that removes -- and none of it is asserted anywhere now. Whatever the swamp
    -- is refilled with owes those three verbs, or owes an argument for why it does not.

    -- ------------------------------------------------------------ the kit contract
    {
        -- Creature kit is natural weapons only: unpriced, noSteal, outside every shelf
        -- (tests/bestiary_spec.lua states the rule; this holds the circle's own gear to it).
        name = "every Gluttony item is natural kit and nothing else",
        fn = function()
            -- The cut took weapon_gorge_bite, weapon_swallowing_grip, weapon_grendlemaw_gullet and
            -- utility_rendered_hide with the four bodies that swung them. What is left is the two
            -- pieces a survivor still carries plus the two the deleted mini sin left behind.
            for _, id in ipairs({ "weapon_tallow_maw", "weapon_glutted_bulk",
                                  "utility_distended_hide", "utility_gralloch_hook" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal, id .. ": a pickpocket cannot lift a creature's own body off it")
                assert(not def.price, id .. ": creature kit is unpriced")
                -- A hound is not an Alchemist. Since the fold that is said by naming the bucket rather
                -- than by naming nothing: `class = "creature"` (data/classes/creature.lua), which
                -- is a job no shelf sells and no body takes up.
                assert(def.class == "creature",
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
            -- Four of the five are deleted; the apex is the whole of what the circle still fields.
            -- A refill puts its own bodies back on this list.
            for _, id in ipairs({ "character_the_sated", "character_manticore" }) do
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
