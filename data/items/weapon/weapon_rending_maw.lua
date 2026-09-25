-- Gula's own mouth, and all she needs. She fights with what she has EATEN (models/palate.lua), so her
-- own weapon is deliberately plain: a heavy bite at arm's length, no rider, nothing that would bury the grid it is
-- growing. The Glutted Bulk's rule, one circle over: the interesting property is on the body.
local Curve = require("models.curve")

return {
    name = "Rending Maw",
    description = "Deals damage.",
    flavor = "It was a woman's mouth once. It remembers being hungry, and nothing else.",
    sprite = "assets/items/rending_maw.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
