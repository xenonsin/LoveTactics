-- MASONRY FIST: the Tower-Giant's blow (data/characters/character_tower_giant.lua; "Pride's Bestiary",
-- 2026-09-30). A fist of fitted stone, slow and heavy. Its fight is the fall, not the fist.
local Curve = require("models.curve")

return {
    name = "Masonry Fist",
    description = "Strikes an adjacent foe.",
    flavor = "Every course of it was laid by hand, and every hand was told it was building something that would last.",
    sprite = "assets/items/weapon_masonry_fist.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- ponderous: it lands once for what a sword lands twice
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(16, 28),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
