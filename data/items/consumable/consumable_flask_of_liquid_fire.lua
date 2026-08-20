-- Crucible rank-1. The alchemist's answer to a crowd: a thrown flask that bursts into a 3x3 sheet of
-- flame and leaves the ground burning. Cheap, loud, and no substitute for a mage -- it carries no
-- magic scaling at all, so what it does to a knight it does to a wizard.
--
-- Mechanically it is Fireball with the caster taken out of it (data/items/ability/ability_fireball.lua):
-- fixed power, no `magical` tag, and the same fire hazard laid across its footprint.
local Curve = require("models.curve")

return {
    name = "Flask of Liquid Fire",
    description = "Leaves Fire in area.",
    flavor = "Cheap, loud, and no substitute for a mage. Which the Crucible tells you before it takes your gold.",
    sprite = "assets/items/flask_of_liquid_fire.png",
    type = "consumable",
    tags = { "fire" }, -- no "magical": the fire is chemistry, and cares nothing for magic defense
    class = "alchemist",
    price = 295,
    unlockQuests = 5,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the burst may be centred ON a foe, like Fireball
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(12), -- flat: nothing about the thrower makes the fire hotter
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 4 + fx.level, duration = 15 + fx.level })
            end
        end,
    },
}
