-- BEAK AND CLAW: the Griffin's plain weapon -- the lion's half needs one. A bite that opens a Bleed, which
-- keeps a body paying for every tile it walks while the company chases it around the glade. Approved on
-- review (2026-09-23).
local Curve = require("models.curve")

return {
    name = "Beak and Claw",
    description = "Bites an adjacent foe and inflicts Bleed.",
    flavor = "Half of it is an eagle and half of it is a lion, and both halves are hungry.",
    sprite = "assets/items/weapon_beak_and_claw.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_bleed" })
        end,
    },
}
