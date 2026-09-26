-- THE GOLD SCEPTRE: the Gilded King's rod of office, and all he has left to swing (2026-09-26, the Gilded
-- King: "not strong in the arm"). A starved man with a heavy stick -- a crushing blow, low for the rung,
-- because his defence is the gold on him and not what he can do with his arms.
--
-- Creature kit: unpriced, classless to every shelf, `noSteal`. What drops off him is the crown and the
-- bread, not the rod.
local Curve = require("models.curve")

return {
    name = "Gold Sceptre",
    description = "Strikes an adjacent foe.",
    flavor = "He could still lift it. He could not lift much else.",
    sprite = "assets/items/weapon_gold_sceptre.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15), -- the ladder's narrowest span: a point per forge level, no more
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
