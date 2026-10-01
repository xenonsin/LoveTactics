-- LION'S PAW: the Sphinx's paw (data/characters/character_sphinx.lua; "Pride's Bestiary", 2026-09-30). A plain
-- blow from a lion's body. The Sphinx's fight is its riddle, so its weapon says nothing else.
local Curve = require("models.curve")

return {
    name = "Lion's Paw",
    description = "Strikes an adjacent foe.",
    flavor = "The question is the dangerous part. The paw is only there for people who will not answer it.",
    sprite = "assets/items/weapon_lions_paw.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
