-- The throat of the flue a Whirl Elemental lives in, and the vessel Backdraught rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
--
-- THE ALPHA'S COPY OF THE CHAFF'S RULE, AND IT COSTS WHAT AN ALPHA'S COPY SHOULD. A Fire Elemental burns
-- whoever damages it, free, at any range, forever (data/items/utility/utility_living_flame.lua). This
-- lights EVERYTHING adjacent instead of only the hand that reached in -- and pays stamina for it, and
-- is gated to melee, and gets dearer with every answer inside a round (Trait.answerCost). Wider, and
-- bought rather than owned. That is the same escalation the Matriarch's Downdraft makes over the
-- flock's gust one animal over, in this circle's other element.
--
-- AND THE SECOND RULE IS THE ALPHA'S COPY OF THE CHAFF'S OTHER ONE, escalated the same way. A Fire
-- Elemental lays a PRINT: a line behind it, legible, avoidable, and a corridor closed on purpose
-- (data/items/utility/utility_living_flame.lua). This throws fire into the room instead --
-- `trail.scatter`, one tile somewhere within two of where the body just was, never the same shape
-- twice. A company can plan around a line. It cannot plan around a room catching, and it cannot clear
-- the fire faster than a moving body lays it.
--
-- WHICH IS ALSO HOW THE HAUL STAYS ARMED WITHOUT COSTING A TURN. The Chimney-Draw pulls a BURNING body
-- the whole length of the room and a cold one a single tile, so every tile of scattered fire is a
-- handhold this body made while it was walking somewhere it wanted to be anyway
-- (data/items/weapon/weapon_chimney_draw.lua). The two halves of the elite pay for each other, and
-- neither one is a turn spent setting the other up.
return {
    name = "Flue Throat",
    description = "When struck in melee, sets fire to everything adjacent, and scatters fire as it moves.",
    flavor = "A chimney is a hole with a habit. This one has had a long time to practise.",
    sprite = "assets/items/flue_throat.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_backdraught" },
    -- Longer than the chaff's eight, because this fire is meant to still be there when the haul comes:
    -- a scattered tile has to outlive the walk that laid it and the turn that cashes it.
    trail = { hazard = "hazard_fire", duration = 14, scatter = 2 },
}
