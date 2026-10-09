-- HELLHOUND BITE: the Hellhound's own blow (data/characters/character_hellhound.lua; "The Crown's Bestiary", slice C).
-- A demon's bite burns -- a physical blow with fire on it, never moved to the magical channel (tests/bestiary_spec.lua's
-- demon rule). Standing in fire it lands 3 harder (trait_hearth_born), which the forecast reads off the tile.
local Curve = require("models.curve")

return {
    name = "Hellhound Bite",
    description = "Bites an adjacent foe.",
    flavor = "The heat comes off the teeth before they close.",
    sprite = "assets/items/weapon_hellhound_bite.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
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
