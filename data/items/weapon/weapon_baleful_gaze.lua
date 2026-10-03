-- BALEFUL GAZE: the Evil Eye's own blow (data/characters/character_evil_eye.lua; "Envy's Bestiary", round 1). A
-- look that burns, thrown across the sand -- so it needs the same line of sight the souring does, and a body behind
-- a ridge is safe from both. It burns because the eye is a demon, and a demon's blows burn.
local Curve = require("models.curve")

return {
    name = "Baleful Gaze",
    description = "Strikes a foe it can see.",
    flavor = "Everyone in the waste has felt it once. Nobody has ever caught it looking.",
    sprite = "assets/items/weapon_baleful_gaze.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "magical", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
