-- LIGHT OF THE CHOIR: the Herald's and the Virtue's own hand, the small light every lesser angel carries
-- (reviewed 2026-09-30, "Pride's Bestiary"). Neither body is FOR striking -- one sings and one wards -- so this is
-- an afterthought on purpose: a short holy bolt that keeps a singer from being a free kill.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Light of the Choir",
    description = "A bolt of holy light at a foe up to 3 tiles away.",
    flavor = "It is not aimed in anger. It is aimed the way a lamp is held up to a stain.",
    sprite = "assets/items/weapon_choir_light.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "holy", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
