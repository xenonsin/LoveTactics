-- BAKU'S TUSKS: Baku's natural weapon ("Sloth's Bestiary", 2026-10-04). A tapir's head on a beast's body, and two
-- tusks under the trunk. Plain on purpose: what it hits with is grown by the meal (status_dream_fed), not the tusk.
local Curve = require("models.curve")

return {
    name = "Baku's Tusks",
    description = "A heavy gore to an adjacent foe.",
    flavor = "The trunk is for the dreams. The tusks are for whoever is still awake.",
    sprite = "assets/items/weapon_baku_tusks.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
