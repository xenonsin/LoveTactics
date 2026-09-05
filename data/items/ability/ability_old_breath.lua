-- Old Breath: the wyrm form's third attack (data/characters/character_wild_wyrm.lua), and the one that
-- ties the shape to the shelf it came off rather than merely being bigger than it.
--
-- IT BREATHES WHATEVER IT IS STANDING IN. A cone, and its element is read off the ground beneath the
-- caster at the moment of the cast -- fire if the wyrm is standing in a burn, cold out of black ice,
-- and so on down whatever the druid has been laying all fight. On bare ground it is a plain physical
-- gout, which is the floor rather than a failure.
--
-- That is the whole reason the form is a build-around and not a stat block. Mira's shelf is hazards and
-- ground -- Thicketing, the sigil-adjacent primal stock, whatever the run has handed her -- and every
-- one of those was already worth casting. This makes them worth casting HERE, so a druid who has been
-- shaping the floor has been loading her signature's third attack without being told to.
--
-- The element is taken from the hazard's own `tags` (data/hazards/*.lua each declare one), passed
-- through as a per-cast tag on the damage, so mitigation, resistance, immunity and every Vulnerable
-- reading treat it exactly as they would the same element thrown by a mage. No new resolver, no
-- special case: it is the ordinary damage path with a tag chosen at runtime.
--
-- `natural`, `noSteal`, sold by nobody -- creature gear, outside every family roster.
local Curve = require("models.curve")
local Hazard = require("models.hazard")

return {
    name = "Old Breath",
    description = "A cone carrying the element of the ground you stand in.",
    flavor = "Older than the wood, and it has been breathing the wood in the whole time.",
    sprite = "assets/items/old_breath.png",
    type = "ability",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "primal" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1, -- aim the adjacent tile; the cone opens away from there
        speed = 6,
        cost = { stat = "stamina", amount = 8 },
        aoe = { shape = "cone", length = 3 }, -- 1 cell, then 3, then 5
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = Curve.ramp(9, 21),
        effect = function(fx)
            -- What is underfoot, if anything. Guarded on every hop: the tooltip's dry run hands over a
            -- stand-in board with no hazards and a user proxy that may carry no tile at all, and an
            -- ability that faulted here would describe itself as doing nothing (see the note on the
            -- preview context in models/combat.lua).
            local element
            local u = fx.user
            if fx.combat and u and u.x and u.y then
                local ground = Hazard.at(fx.combat, u.x, u.y)
                local tags = ground and ground.tags
                element = tags and tags[1]
            end
            local opts = element and { tags = { element } } or nil
            for _, other in ipairs(fx.aoeUnits()) do
                if other.side ~= fx.user.side then fx.damage(other, opts) end
            end
        end,
    },
}
