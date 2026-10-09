-- FIT THE CRIME: the Erinys's bow (data/characters/character_erinys.lua; "The Crown's Bestiary", slice B, approved
-- 2026-10-09). Her arrow lands the status that answers what the target did on its last turn: attacked, Disarmed;
-- cast, Silenced; moved, Root; healed someone, Interred (models/crown_demons.lua's verdict). The body she aims at
-- chooses its crime -- act in the way whose punishment you can afford, or step behind cover.
--
-- A demon's blow burns: a physical arrow with fire on it (tests/bestiary_spec.lua's demon rule).
local Curve = require("models.curve")

return {
    name = "Fit the Crime",
    description = "Shoots a foe and punishes its last turn: attacked, Disarmed; cast, Silenced; moved, Root; healed, Interred.",
    flavor = "She does not ask what you did. She already knows, and she has brought the right arrow.",
    sprite = "assets/items/weapon_fit_the_crime.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 20),
        effect = function(fx) require("models.crown_demons").fitTheCrime(fx) end,
    },
}
