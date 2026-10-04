-- SAND FROM HIS HANDS: the Sandman's own blow (data/characters/character_the_sandman.lua). His rules are where the
-- danger is (models/sandman.lua); this is only what he does with a turn when somebody is in reach of it -- a fistful
-- of sand thrown in a face, a short way off. Natural, unstealable and on no shelf, like every creature's body.
local Curve = require("models.curve")

return {
    name = "Sand from His Hands",
    description = "Throws stinging sand at a foe within 3.",
    flavor = "It gets everywhere. That is rather the point of it.",
    sprite = "assets/items/weapon_sand_from_his_hands.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "earth", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 24),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
