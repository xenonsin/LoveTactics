-- The Suppliant's bough: it calls you out of your line without taking you.
--
-- THE CIRCLE'S THEME AT A SURVIVABLE SEVERITY. Lust breaks formations -- that sentence is written in
-- data/traits/trait_lure.lua and in the glades carve both -- and until this the only way it had of
-- saying so was Charm, which does not break a rank so much as delete it and hand the pieces to the
-- other side. So the stratum had exactly one idea and one volume for it, and the boss fight's adds had
-- nothing to threaten with between "nothing" and "your knight is theirs now".
--
-- A haul is the same sentence at a volume the party can answer. The body comes out of the line, alone,
-- at the far end of the trail from everyone who was covering it -- and it is still YOURS when it gets
-- there, still takes your orders, can still walk back. That is a problem to solve on the turn it
-- happens rather than a turn you do not get.
--
-- `minRange = 2` because a body already beside it has nowhere to be hauled to, and the reach is what
-- makes it a threat you see coming across an open trail.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Beckoning Bough",
    description = "Hauls a distant foe to its feet.",
    flavor = "It does not ask twice, and it was never really asking.",
    sprite = "assets/items/beckoning_bough.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,
        requiresSight = true,
        speed = 6, -- the slowest thing this body does: a haul is a commitment
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(3, 14),
        effect = function(fx)
            -- Bite first, haul second, and skip the haul on a corpse -- the same order and the same
            -- guard the Gaff Line uses (data/items/ability/ability_gaff_line.lua), for the same reason:
            -- a killing blow leaves the body where it fell rather than dragging it home.
            fx.damage(fx.target)
            if not fx.target.alive then return end
            fx.pull(fx.target)
        end,
    },
}
