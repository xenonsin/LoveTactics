-- SPINNERETS: Arachne's own (data/characters/character_arachne.lua; "Envy's Bestiary", 2026-10-03, slice C). A
-- thread thrown and drawn tight across three tiles. Her rule is the tapestry (utility_the_tapestry); this is the
-- thread she works with between casts.
local Curve = require("models.curve")

return {
    name = "Spinnerets",
    description = "Strikes a foe within 3.",
    flavor = "She does not need to be close. The thread is.",
    sprite = "assets/items/weapon_spinnerets.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
