-- FROST WORM'S BITE: the Frost Worm's own blow (data/characters/character_frost_worm.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). A plain bite: the worm's rules are the Trill and its death throes, both Frozen.
--
-- It Froze a sleeper until the creature identity pass (2026-11-19) took the worm off Sleep (ability_the_trill
-- says why). A bite that froze a body the Trill had already frozen would be the same rule twice.
local Curve = require("models.curve")

return {
    name = "Frost Worm's Bite",
    description = "Bites an adjacent foe.",
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
            fx.damage(fx.target)
        end,
    },
}
