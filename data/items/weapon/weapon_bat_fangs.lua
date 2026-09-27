-- BAT FANGS: the Familiar's natural weapon (Wrath's vampires, 2026-09-26). A weak bite that opens a vein -- and
-- what it draws is carried to the nearest vampire (trait_blood_courier).
local Curve = require("models.curve")

return {
    name = "Bat Fangs",
    description = "Inflicts Bleed.",
    flavor = "Two needle teeth, a numbing lick, and a wound that keeps running after the bat has gone.",
    sprite = "assets/items/weapon_bat_fangs.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_bleed" })
        end,
    },
}
