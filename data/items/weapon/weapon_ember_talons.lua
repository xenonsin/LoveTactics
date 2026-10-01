-- EMBER TALONS: the Phoenix's claws (data/characters/character_phoenix.lua; "Pride's Bestiary", 2026-09-30).
-- A physical blow with fire on it -- the element is added, the channel is not moved (docs/bestiary.md) -- and
-- it inflicts Burn. The Phoenix's fight is its return, so its weapon is an ordinary fire bird's.
local Curve = require("models.curve")

return {
    name = "Ember Talons",
    description = "Inflicts Burn.",
    flavor = "It has been on fire for longer than anything you own has existed. It no longer notices.",
    sprite = "assets/items/weapon_ember_talons.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_burn" })
        end,
    },
}
