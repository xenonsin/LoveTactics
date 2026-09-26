-- MANDIBLES: the Coin-Eaters' bite -- the Gilded Scarab's, the Rust Mite's and the Brood Queen's. One
-- plain pinching blow; everything each beetle is known for is in the rest of its grid.
--
-- A natural weapon: creature kit, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Mandibles",
    description = "A pinching bite.",
    flavor = "It was made for cutting gold out of rock. You are softer than rock.",
    sprite = "assets/items/weapon_mandibles.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "slash" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
