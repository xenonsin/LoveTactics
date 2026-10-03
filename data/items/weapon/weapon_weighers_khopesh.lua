-- WEIGHER'S KHOPESH: the Jackal Weighers' own blade (data/characters/character_jackal_weigher.lua; "Envy's
-- Bestiary", round 2). A creature's copy, never shelf stock: the body is a judge, not a fighter with a trade.
local Curve = require("models.curve")

return {
    name = "Weigher's Khopesh",
    description = "Hooks an adjacent foe.",
    flavor = "Bronze, curved like the lip of a pan, and it has only ever been raised over the heavier side.",
    sprite = "assets/items/weapon_weighers_khopesh.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
