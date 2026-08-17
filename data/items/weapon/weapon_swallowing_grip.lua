-- A bogswallow's grip: it does not chase, it holds.
--
-- The swamp's floor is `mire` -- ground that charges a mountain's price and gives back none of a
-- mountain's reach -- so a crossing already costs more here than anywhere else. This makes the crossing
-- stop being possible at all: it Roots, and a Rooted body cannot walk out of reach of the thing that
-- heals when things die near it.
--
-- Which is why the line body of a Gluttony pack is a grappler rather than a bruiser. The circle's rule
-- is about being unable to leave a trade, and the ground and the teeth say the same thing.
local Curve = require("models.curve")

return {
    name = "Swallowing Grip",
    description = "Seizes an adjacent foe and leaves Root.",
    flavor = "The bog does not pull you under all at once. It simply stops letting go.",
    sprite = "assets/items/swallowing_grip.png",
    type = "weapon",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_root")
        end,
    },
}
