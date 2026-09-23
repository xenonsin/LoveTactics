-- Harpy talons: the snatch, and half of the Lust circle's wind.
--
-- IT REACHES IN AND TAKES YOU SOMEWHERE ELSE. The flock has two weapons and they are the same verb
-- pointed in opposite directions -- this one hauls a body out of its line and onto the bird, the gust
-- drives a body off. Between four harpies a company does not get beaten so much as UNPICKED: the front
-- rank is pulled forward one at a time and the back rank is pushed off, and the two ranks end the
-- exchange standing in different rooms of a keep built out of rooms.
--
-- IT PINNED, AND THAT WAS THE WRONG VERB. The first cut of this weapon rooted what it landed on, which
-- made the flock a body that HOLDS -- and a hold is the one thing a circle about displacement should
-- never do, because Root sets `blocksForcedMove` and a pinned victim is a victim the rest of the flock
-- can no longer move at all. The talons were switching the circle off one target at a time. Nothing on
-- this stratum pins anything now; see the Lust entry in models/descent.lua.
--
-- REACH 2, WHICH IS WHAT MAKES THE HAUL MEAN ANYTHING. Combat.pull drags a body to a tile beside the
-- caster, so a snatch thrown from an adjacent tile moves nobody -- it would be a plain blow wearing a
-- displacement's name. Two tiles is the shortest reach at which the verb is real, and it is
-- deliberately one short of the gust's three: the bird has to come in for this and can shove from
-- where it hovers.
--
-- A DEMON'S BLOW BURNS (docs/bestiary.md, "...and a demon's blows burn"): `fire` is on the tag list and
-- the channel is not moved -- this is a physical blow with an element on it, so a coat still answers it
-- and a Salamander Hide is not dead weight against the flock.
--
-- THE HAUL IS GATED ON THE HIT, like the gust's shove. A rider that could not miss riding a blow that
-- could is the shape of bug the whole circle was rebuilt out of once already (docs/accuracy.md).
local Curve = require("models.curve")

return {
    name = "Harpy Talons",
    description = "Snatches a foe at reach and hauls it to the harpy's side.",
    flavor = "It does not carry you off. It has never once carried anything off. It simply will not let go.",
    sprite = "assets/items/harpy_talons.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        requiresSight = true,
        speed = 4, -- slower than a plain claw: the reach and the haul are bought with tempo
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            -- Dragged to a tile beside the bird (Combat.pull). Everything about what a dragged body
            -- crosses on the way belongs to the primitive and is deliberately not restated here.
            if dealt > 0 and fx.target.alive then fx.pull(fx.target) end
        end,
    },
}
