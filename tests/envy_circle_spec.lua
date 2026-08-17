-- Tests for the ENVY CIRCLE: the desert's five constructs, its mini sin, and the rule they share.
--
-- The tier's design rule, pinned here as it is for Gluttony: A MINI SIN'S SECOND PHASE IS ITS GENERAL'S
-- FIRST. Livia's Envious Glass copies your STRONGEST body at the opening bell, every fight
-- (data/traits/trait_covetous_reflection.lua). Second Water copies your WEAKEST, once, and only past
-- half health -- so the circle's first floor teaches the mechanic late, small and in the harmless
-- direction, and its second floor is a recognition.
--
-- Also pins the live bug this circle closed: Envy's honour-guard lead was character_homunculus, an
-- alchemist's SUMMON scaled by the summoning item's level, standing as a stratum's centrepiece with
-- tier-1 chaff stats.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

local function sinNamed(id)
    for _, sin in ipairs(Descent.SINS) do
        if sin.id == id then return sin end
    end
end

return {
    {
        name = "Envy's stair is held by its own mini sin, not by a summon target",
        fn = function()
            local sin = sinNamed("envy")
            assert(sin, "the envy circle exists")
            assert(sin.minor.lead == "character_second_water", "Second Water holds the honour-guard floor")
            assert(sin.minor.lead ~= "character_homunculus",
                "the alchemist's summon is not a stratum's centrepiece")
            assert(sin.minor.filler == "character_glass_mote", "escorted by the circle's own swarm")
            -- Cargo must never be fielded: the discard is a `protect` objective with a holdGround
            -- posture, and its own header says so at length.
            assert(sin.minor.filler ~= "character_homunculus_discard",
                "the discard is cargo -- a protect objective, not a combatant")
            assert(sin.guardian.filler == sin.minor.lead,
                "and the mini sin fills out its own general's stair")
        end,
    },

    -- ------------------------------------------------------------ the rule
    {
        name = "Lesser Reflection copies the weakest foe, once, and only past half health",
        fn = function()
            local def = require("models.registry").load("data/traits", "data.traits").trait_lesser_reflection
                or require("models.trait").defs.trait_lesser_reflection
            assert(def, "the trait exists")
            assert(def.at == 0.5, "it answers at half health")

            -- The inverse of its parent, stated as a property rather than as a number: Livia takes the
            -- one that towers, this one takes the least. If the two ever read the same body, the
            -- circle's whole escalation collapses into one fight told twice.
            local Reflect = require("models.trait").defs.trait_covetous_reflection
            assert(Reflect, "the general's rule exists to be cut down from")
            assert(Reflect.onCombatStart and def.onDamaged,
                "the general opens with it; the mini sin earns it by being wounded")
        end,
    },
    {
        name = "the mirror answers a wound, and answers only once",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3), unit("character_archer", 3, 5) },
                { unit("character_second_water", 8, 4) })
            local mirror
            for _, u in ipairs(c.units) do
                if u.char.id == "character_second_water" then mirror = u end
            end
            assert(mirror, "the mini sin took the field")

            local before = #c.units
            -- A scratch is not a wound: above the threshold nothing answers.
            Combat.dealFlatDamage(c, mirror, 5, {}, "test")
            assert(#c.units == before, "a scratch does not summon a reflection")

            -- Past half, exactly one copy arrives.
            local hp = mirror.char.stats.health
            Combat.dealFlatDamage(c, mirror, math.floor(hp.max * 0.6), {}, "test")
            local after = #c.units
            assert(after > before, "past half health the mirror finds a shape")

            -- ...and a long fight cannot fill the board with them.
            Combat.dealFlatDamage(c, mirror, 10, {}, "test")
            assert(#c.units == after, "the reflection comes once, ever")
        end,
    },

    -- ------------------------------------------------------------ the swarm decides who
    {
        name = "glass strips what you built, which is how it chooses who gets copied",
        fn = function()
            for _, id in ipairs({ "weapon_glass_shard", "weapon_vitreous_bite" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                local src = love.filesystem.read("data/items/weapon/" .. id .. ".lua")
                assert(src and src:find("dispelUnit", 1, true),
                    id .. " must strip blessings -- that is the circle's setup, not its damage")
            end
            -- The line body strips harder than the swarm and hits softer than anything on its rung.
            local mote = Item.defs.weapon_glass_shard.activeAbility
            local eater = Item.defs.weapon_vitreous_bite.activeAbility
            assert(eater.damage[1] > mote.damage[1], "the eater hits harder than a mote")
            assert(eater.damage[1] < 10, "...and still softly: what it takes is not health")
        end,
    },
    {
        name = "a Mimic hits harder the more it has been hit",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_mimic_of_ash", 5, 4) })
            local mimic, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else mimic = u end
            end
            local echo = itemNamed(mimic.char, "weapon_ashen_echo")

            openTurn(c, mimic)
            local before = Fixture.hp(victim)
            assert(Combat.useItem(c, mimic, echo, victim.x, victim.y), "the mimic strikes")
            local unhurtBlow = before - Fixture.hp(victim)

            -- Bruise it heavily, then let it swing again.
            Combat.dealFlatDamage(c, mimic, 40, {}, "test")
            openTurn(c, mimic)
            local mid = Fixture.hp(victim)
            assert(Combat.useItem(c, mimic, echo, victim.x, victim.y), "the mimic strikes again")
            local hurtBlow = mid - Fixture.hp(victim)

            assert(hurtBlow > unhurtBlow, string.format(
                "swing big at the mirror and it swings big back (%d then %d)", unhurtBlow, hurtBlow))
        end,
    },

    -- ------------------------------------------------------------ the apex
    {
        name = "the Unwanted sheds motes rather than getting stronger",
        fn = function()
            local def = Character.defs.character_the_unwanted
            assert(def.footprint and def.footprint.w == 2, "the apex stands on four tiles")

            local frac = Item.defs["utility_fracture_line"]
            assert(frac and frac.phases and #frac.phases == 2, "it comes apart twice")
            for _, phase in ipairs(frac.phases) do
                local summons = false
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        summons = true
                        assert(r.id == "character_glass_mote", string.format(
                            "it shatters into the circle's own swarm, never into %s -- the discard is "
                            .. "cargo and fielding it would rebuild the bug this pass removed", r.id))
                    end
                    assert(r.kind ~= "bonus" or r.amount < 0,
                        "the Unwanted multiplies; it does not escalate")
                end
                assert(summons, "every threshold sheds glass")
            end
        end,
    },
    {
        name = "the mirror's own pane and wash are natural kit",
        fn = function()
            for _, id in ipairs({ "utility_envys_pane", "utility_second_wash" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.noSteal and not def.price and not def.class,
                    id .. ": creature kit sits outside every shelf")
                local carries = false
                for _, t in ipairs(def.traits or {}) do
                    if t == "trait_lesser_reflection" then carries = true end
                end
                assert(carries, id .. " carries the circle's rule -- a blueprint's own traits are dead")
            end
        end,
    },
    {
        name = "Second Water is a step below its general and a step above the line",
        fn = function()
            local mini = Character.defs.character_second_water
            local livia = Character.defs.character_general_envy
            assert(mini.boss and mini.referenceLevel, "a centrepiece, and one that scales toward the shallows")
            assert(mini.stats.health > Character.defs.character_glass_eater.stats.health,
                "it outweighs its circle's line body")
            local share = mini.stats.health / livia.stats.health
            assert(share > 0.6 and share < 0.85, string.format(
                "Second Water is %.0f%% of Livia; the tier sits between 60%% and 85%%", share * 100))
        end,
    },
}
