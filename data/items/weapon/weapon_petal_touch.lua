-- A petal-drift's touch: it Charms, and it is not worth a turn to kill.
--
-- Both halves of that sentence are the mechanic. The Lust circle's swarm exists to make spending a real
-- ability feel like waste -- and holding your turn instead is exactly what the Suppliant behind it
-- drains you for (data/traits/trait_unasked.lua). The dilemma IS the floor.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Petal Touch",
    description = "Brushes an adjacent foe and leaves Charm.",
    flavor = "It wants nothing at all. That is most of the trouble with it.",
    sprite = "assets/items/petal_touch.png",
    type = "weapon",
    tags = { "natural", "slash", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_charm")
        end,
    },
}
