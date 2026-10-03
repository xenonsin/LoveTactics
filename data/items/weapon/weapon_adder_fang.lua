-- ADDER FANG: the bite of an adder sprung from Gorgon's blood (data/characters/character_adder.lua). Small, and
-- the Poison does the work -- a small poisoner, as the page asked. Natural, unstealable, on no shelf.
local Curve = require("models.curve")

return {
    name = "Adder Fang",
    description = "Inflicts Poison.",
    flavor = "Ovid says every snake in the desert came from one drop of her. He did not say which drop.",
    sprite = "assets/items/weapon_adder_fang.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
