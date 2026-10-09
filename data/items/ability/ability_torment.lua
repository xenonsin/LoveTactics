-- TORMENT: the Pit Locust's trophy ("The Crown's Bestiary", slice C, approved 2026-10-09), for a Plague Knight: "Strike
-- a foe: it can't drop below 1 health from this, and gains Torment: -3 damage, -1 movement."
--
-- The swarm's sting with the patience taken out: the locust Torments only a body already at 1, and this lays a stack
-- on any foe it lands on. The blow is held at 1 (`spares`, read by Combat.dealFlatDamage beside the Lioness's hold),
-- so it is never the blow that kills -- a Plague Knight's house is wearing a body down, not finishing it. The stack is
-- carried on the blow (`inflicts`), so a miss lays nothing.
local Curve = require("models.curve")

return {
    name = "Torment",
    description = "Strike a foe: it can't drop below 1 health from this, and gains Torment (-3 damage, -1 movement).",
    flavor = "The pit does not want you dead. It wants you to want it.",
    sprite = "assets/items/ability_torment.png",
    type = "ability",
    tags = { "pierce", "physical", "dark" },
    class = "plague_knight",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            fx.damage(fx.target, { spares = true, inflicts = "status_torment" })
        end,
    },
}
