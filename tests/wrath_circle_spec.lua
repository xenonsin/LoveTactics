-- Tests for the WRATH CIRCLE: its lieutenant slot, and the tier's rule as the Cold Forge still carries it.
--
-- The tier's design rule, pinned here as it is for Gluttony and Envy: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST. Ira's Unappeased Heart is two compounding terms with no ceiling; the Cold Forge runs
-- one term with a cap and then, at half health, takes the cap off.
--
-- THE BODY THAT WORE THE FORGE IS GONE. The Anvil was deleted with the other six lieutenants
-- (2026-09-22, Descent.SINS' header) and the rule above is now pinned on the ITEM alone, which is still
-- on disk and is the material a replacement is built from. Every case here that read the blueprint is
-- deleted; the contract it held is written out beside the slot below.
--
-- THE CIRCLE'S FIRST FIVE BODIES ARE GONE TOO (2026-09-26): the ember-spit, the cinder-kin, the forge
-- wretch, the Unquenched and the Rift-Born, with their kit and the two traits only they carried
-- (Cinderfall, Drinks the Fire). The cases that pinned the fire-on-the-board escalation went with them;
-- the goblins, orcs, oni and vampires carry their own specs.

local Character = require("models.character")
local Descent = require("models.descent")
local Item = require("models.item")
local Trait = require("models.trait")

return {
    {
        -- THE ANVIL IS DELETED AND THIS CASE IS THE MARKER. Wrath's lieutenant slot holds the oni's alpha
        -- as a stand-in (see the lieutenant note at the head of Descent.SINS), which is not a mini sin
        -- and does not pretend to be one. The stand-in is named here on purpose: seating a replacement
        -- reddens this case, and whoever does it owes the contract the deleted case below used to hold --
        -- boss-rung, a `referenceLevel`, opening damage under its general's, and health between 60% and
        -- 85% of hers and over its own line body's.
        name = "Wrath's lieutenant slot is filled, and by a stand-in that says so",
        fn = function()
            local sin
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then sin = s end end
            assert(sin, "the wrath circle exists")
            assert(sin.minor.lead == "character_oni_general", "the Oni General stands in for the Anvil")
            assert(Character.defs[sin.minor.lead], "and whatever stands there is a body that loads")
            assert(Character.defs[sin.minor.filler], "and so does its escort")
            assert(Character.defs[sin.guardian.filler], "and so does Ira's")
            assert(not Character.defs["character_the_anvil"], "the Anvil is gone")
            -- The Champion is still a correctly built body and still the pattern for authoring phases;
            -- it just is not a sin.
            assert(Character.defs["character_champion"], "the Champion is still in the game")
        end,
    },
    {
        name = "the circle's first bodies are gone, and Wrath bills no elite in their place",
        fn = function()
            for _, id in ipairs({ "character_ember_spit", "character_cinder_kin", "character_forge_wretch",
                                  "character_the_unquenched", "character_rift_born" }) do
                assert(not Character.defs[id], id .. " is deleted")
            end
            for _, s in ipairs(Descent.SINS) do
                if s.id == "wrath" then
                    assert(s.elites.approach == nil and s.elites.seat == nil,
                        "nothing is promoted into the Unquenched's or the Rift-Born's billing")
                end
            end
        end,
    },

    -- ------------------------------------------------------------ the tier's rule
    {
        -- NO BODY CARRIES KINDLING NOW. The forge wretch wore it and is deleted; the Cold Forge still
        -- names it and is still on disk. So the rule is pinned on its definition, not on a fight.
        name = "Kindling is capped, and is one term where Ira's is two",
        fn = function()
            local def = Trait.defs["trait_kindling"]
            assert(def, "the trait exists")
            assert(def.ceiling and def.ceiling > 0, "the CAP is the whole difference from Ira's version")
            local parent = Trait.defs["trait_wrath_rising"]
            assert(parent and parent.magnitude, "the general's rule has a missing-health term")
            assert(def.magnitude == nil,
                "the mini sin's version has no missing-health curve at all -- one term, not two")
        end,
    },
    {
        name = "the Cold Forge's second phase is Ira's first",
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
    -- THE CASE THAT SIZED THE ANVIL IS GONE WITH THE BODY, and this is what it said so the replacement
    -- can be held to it:
    --
    --     boss = true and a referenceLevel        a centrepiece that scales toward the shallows
    --     stats.damage < its general's            it starts below her; everything it becomes, you did
    --     health between 60% and 85% of hers      and above its own circle's line body
    --
    -- THE BAND'S TOP IS ARITHMETIC RATHER THAN TASTE. A mini sin is a boss-rung body (it is a floor's
    -- centrepiece with a phase table), so Balance.HEALTH_BANDS floors it at 155 -- and Ira is the
    -- lightest general in the game at 211. 155/211 is already 73%, so no Wrath mini sin can sit at
    -- "roughly 60%" and still be tier 4. The rule that actually holds across all seven circles is:
    -- comfortably under its general, comfortably over its own circle's line body.

    -- ------------------------------------------------------------ the kit contract
    {
        name = "the Cold Forge is natural kit and nothing else",
        fn = function()
            local def = Item.defs["utility_cold_forge"]
            assert(def, "utility_cold_forge does not exist")
            assert(def.noSteal and not def.price and def.class == "creature",
                "creature kit is unpriced, unshelved and unstealable")
        end,
    },
}
