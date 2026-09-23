-- A flashover: the moment a room stops being a room with a fire in it and becomes a fire with a room
-- in it. The Whirl Elemental's close weapon, and what it does to anything that got all the way in.
--
-- THE PLAIN ONE OF ITS TWO HANDS, deliberately. The Chimney-Draw is the body's whole argument and it is
-- slow, expensive and aimed at a circle; this is what it swings at whatever the draw has already
-- delivered to its feet, and it is fast enough to follow one. An alpha with only a set-piece cast is an
-- alpha a company answers by standing next to it.
--
-- IT BURNS, WHICH IS THE POINT AND NOT A RIDER. Every burn this body lays is a handhold for its own
-- next haul (data/items/weapon/weapon_chimney_draw.lua hauls a burning body the whole way and a cold
-- one a single tile), so the cheap swing is also how it re-arms the expensive one. That is the loop
-- closing without the blueprint having to say so anywhere but here.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Flashover",
    description = "Strikes an adjacent foe, burning it.",
    flavor = "Nothing catches. Everything is already alight, all at once, and then it is over.",
    sprite = "assets/items/flashover.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_burn")
        end,
    },
}
