-- HUNGRY GRASP: the Hungry Ghost's hands (data/characters/character_hungry_ghost.lua). A plain cold touch: the
-- ghost's rule is what it eats (utility_never_full), not what it strikes, so the blow carries nothing else.
local Curve = require("models.curve")

return {
    name = "Hungry Grasp",
    description = "Strikes an adjacent foe.",
    flavor = "It is not trying to hurt you. It is checking whether you are food.",
    sprite = "assets/items/weapon_hungry_grasp.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "dark", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
