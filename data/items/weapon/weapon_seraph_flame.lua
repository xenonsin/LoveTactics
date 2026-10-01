-- THE SERAPH'S FLAME: the Burning One's own hands (reviewed 2026-09-30, "Pride's Bestiary"). A seraph is fire
-- that was given a shape, and it fights at arm's length because arm's length is where its other rule lives:
-- a foe that starts its turn beside it burns (armor_seraphs_wing). The touch is the reason to stand there.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Seraph's Flame",
    description = "Sears an adjacent foe with fire.",
    flavor = "The word means the burning ones. Nobody who has stood next to one has asked why.",
    sprite = "assets/items/weapon_seraph_flame.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
