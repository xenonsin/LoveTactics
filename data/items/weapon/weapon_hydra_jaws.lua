-- HYDRA'S JAWS: the Lernaean Hydra's bite (data/characters/character_lernaean_hydra.lua). One bite per head:
-- `strikesPerHead` makes the brave rule's count the heads badge (models/lerna.lua's Lerna.strikes), so three heads
-- land three blows, each its own hit roll, and the hover quotes all of them. The per-bite figure is low on purpose
-- -- six heads on one body is six of these.
local Curve = require("models.curve")

return {
    name = "Hydra's Jaws",
    description = "Bites an adjacent foe once for each head.",
    flavor = "Every mouth has its own opinion about which of you to eat first. They compromise.",
    sprite = "assets/items/weapon_hydra_jaws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(4, 14),
        strikesPerHead = true,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
