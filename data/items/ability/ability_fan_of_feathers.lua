-- Fan of Feathers: the raven form throws its wings open and rakes everything in front of it -- a cone
-- fanning out from the aimed cell, three rows deep, each row a tile wider to either side than the last
-- (the aimed cell alone, then three, then five -- see Combat.aoeCells's "cone").
--
-- The ANSWER TO THE FORM'S OWN WEAKNESS, and the reason the raven carries two things rather than one.
-- Flung Quills keeps a bow's dead zone (minRange 2), so a foe that closes to touching distance is a foe
-- the raven cannot shoot at all. This is what it does instead: aimed at the tile right beside you, the
-- fan opens away from you and catches the whole press of bodies walking in. Reach while they are far, a
-- sweep the moment they are not.
--
-- The cone orients off the caster->target vector, so WHERE YOU AIM IS WHICH WAY IT FANS -- pointing it
-- at the nearest body in a crowd decides which half of that crowd is caught. It is friendly-fire blind
-- like every other blast in this game: it is thrown at ground, and everything standing on that ground
-- takes it.
--
-- `natural`-family creature gear: unpriced, classless, `noSteal`, reachable only by wearing the shape
-- (data/items/ability/ability_wild_shape_raven.lua). No vendor stocks it and no quest hands it over,
-- which is exactly why it carries no `class` -- see tests/obtainable_spec.lua, which only holds an
-- unpriced item to account when it claims a shelf.
local Curve = require("models.curve")

return {
    name = "Fan of Feathers",
    description = "Rakes a widening cone in front of you with thrown feathers.",
    flavor = "Everything it has, at once, at whatever walked into the wings.",
    sprite = "assets/items/ability_fan_of_feathers.png",
    type = "ability",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "pierce", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- aimed at the body that closed, not at the gap beside it
        range = 1,            -- aim adjacent; the fan opens away from there
        speed = 5,
        cost = { stat = "stamina", amount = 7 },
        aoe = { shape = "cone", length = 3 }, -- 1 cell, then 3, then 5
        --        level:  0  1  2  3  4  5  6  7  8   9  10
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
