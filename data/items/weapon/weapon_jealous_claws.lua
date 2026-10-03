-- JEALOUS CLAWS: the Green-Eyed Monster's own blow (data/characters/character_green_eyed_monster.lua; "Envy's
-- Bestiary", round 2). A demon's claws burn -- a physical blow with fire on it, never moved to the magical channel
-- (tests/bestiary_spec.lua's demon rule) -- and every one of them is +2 for each pair standing side by side.
local Curve = require("models.curve")

return {
    name = "Jealous Claws",
    description = "Rakes an adjacent foe.",
    flavor = "Green to the knuckle, and hot the way a grudge is hot.",
    sprite = "assets/items/weapon_jealous_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
