-- Nightshade: the Alraune's one real wound, and it is aimed at whoever fell asleep in her honey.
--
-- DOUBLE ON A SLEEPER, AND IT WAKES THEM. Sleep breaks on any hit (data/status/status_sleep.lua), so a
-- body that swallowed the honey is a body she gets one heavy blow on and no more -- the blow is the
-- alarm clock. That is the end of the trap the other three spells lay: the root holds, the honey feeds,
-- the seed pays her, and this collects.
--
-- DARK AND POISON, magical: the berry, not the thorn. A natural weapon: no class, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Nightshade",
    description = "Deals double damage to a sleeping foe, and wakes it.",
    flavor = "Bella donna. The ladies of the court put it in their eyes. She puts it somewhere else.",
    sprite = "assets/items/nightshade.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "dark", "poison", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            local amount = fx.amount
            if fx.hasStatus(fx.target, "status_sleep") then amount = (amount or 0) * 2 end
            fx.damage(fx.target, { amount = amount })
        end,
    },
}
