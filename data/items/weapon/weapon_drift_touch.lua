-- A drift-thing's touch: it Halts.
--
-- The Sloth circle's line weapon, carried by the drift-things and by the Late Watch above them. A Halted
-- body that is also SWORN drags its partner's tempo down with it (data/traits/trait_torpor.lua), which
-- is the circle's combo: one lost turn costs two.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Drift Touch",
    description = "Touches an adjacent foe and leaves Halted.",
    flavor = "It has been reaching for the same thing since before the ice came. It is in no hurry.",
    sprite = "assets/items/drift_touch.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_halted")
        end,
    },
}
