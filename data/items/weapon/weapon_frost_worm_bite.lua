-- FROST WORM'S BITE: the Frost Worm's own blow (data/characters/character_frost_worm.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). Its bite on a sleeper Freezes -- the Trill puts a company down, and the bite is what it
-- does with one. Asked BEFORE the blow lands, because the blow is what wakes the sleeper (status_sleep).
local Curve = require("models.curve")

return {
    name = "Frost Worm's Bite",
    description = "Inflicts Frozen on a sleeping foe.",
    flavor = "It does not chew. The cold does that part later.",
    sprite = "assets/items/weapon_frost_worm_bite.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee", "ice" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            local asleep = fx.hasStatus(fx.target, "status_sleep")
            fx.damage(fx.target)
            if asleep and fx.target.alive then fx.applyStatus(fx.target, "status_freeze") end
        end,
    },
}
