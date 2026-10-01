-- SPIRAL HORN: the Unicorn's horn as it strikes (data/characters/character_unicorn.lua; "Pride's Bestiary",
-- 2026-09-30). The horn decides who is unworthy: its blow inflicts Blighted, which is a debuff, and a body
-- carrying a debuff cannot hurt the Unicorn (trait_rejects_the_unworthy). So every body it touches is turned
-- away until somebody Cures it.
--
-- Blighted applied off a blow has no ground to be bound to, so it runs its own clock (about three turns) and
-- rots the body a little each tick while it does. Carried, never sold, never stolen: a creature's body.
local Curve = require("models.curve")

return {
    name = "Spiral Horn",
    description = "Inflicts Blighted.",
    flavor = "It does not wound so much as judge, and the judgement stays in you.",
    sprite = "assets/items/weapon_spiral_horn.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "holy", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            -- The Blight rides the blow (`inflicts`), so a hit that lands marks the body and a miss marks nothing.
            fx.damage(fx.target, { inflicts = "status_blighted" })
        end,
    },
}
