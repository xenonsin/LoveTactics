-- PIT LOCUST STING: the Pit Locust's own blow (data/characters/character_pit_locust.lua; "The Crown's Bestiary", slice
-- C). Light, and it can never take a body below 1 (trait_seek_death, on the locust's organ). A demon's sting burns, as a
-- physical blow (tests/bestiary_spec.lua's demon rule). Creature kit, never loot.
local Curve = require("models.curve")

return {
    name = "Pit Locust Sting",
    description = "Stings an adjacent foe.",
    flavor = "It has a man's face, a woman's hair and a lion's teeth, and none of them is the part that hurts.",
    sprite = "assets/items/weapon_pit_locust_sting.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
