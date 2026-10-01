-- SPEAR OF THE MORNING: the light Superbia and her Reflections strike with (reviewed over three rounds, "Pride's
-- Generals"). A holy thrust that reaches two tiles. Physical, so the Fall's +2 Damage a ring lands in it.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Spear of the Morning",
    description = "A thrust of holy light at a foe up to 2 tiles away.",
    flavor = "It is not a weapon she carries. It is the light, held still long enough to have a point.",
    sprite = "assets/items/weapon_spear_of_the_morning.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "holy", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
