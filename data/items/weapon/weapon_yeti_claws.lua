-- YETI CLAWS: the yeti's own blow, and the Dread's (data/characters/character_yeti.lua,
-- character_dread_of_the_whiteout.lua). Approved 2026-10-04 on "Sloth's Bestiary", slice A. Nothing on it: the
-- yeti's rule is the roar, and a Rooted body is simply easy to reach.
local Curve = require("models.curve")

return {
    name = "Yeti Claws",
    description = "Rakes an adjacent foe.",
    flavor = "Mostly it is the cold that kills you. This is for the ones who keep walking.",
    sprite = "assets/items/weapon_yeti_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(11, 21),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
