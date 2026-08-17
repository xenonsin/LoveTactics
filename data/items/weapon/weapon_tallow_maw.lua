-- A tallow hound's maw. The bite is ordinary; what carries it is the trait beside it in the grid.
--
-- The hound is the Gluttony circle's specialist, so its weapon is deliberately unremarkable -- the body
-- is interesting because of data/traits/trait_engorge.lua, not because of its teeth. A specialist whose
-- weapon ALSO did something would make the rule the pack is built on hard to see, and the whole reason
-- a mini sin exists two floors below Gula is to make that rule legible before it is turned up.
--
-- It does hit harder than the swarm around it, because something has to make finishing the flies feel
-- urgent rather than optional.
local Curve = require("models.curve")

return {
    name = "Tallow Maw",
    description = "Bites an adjacent foe.",
    flavor = "Rendered fat, and the animal it was rendered out of, still walking.",
    sprite = "assets/items/tallow_maw.png",
    type = "weapon",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
