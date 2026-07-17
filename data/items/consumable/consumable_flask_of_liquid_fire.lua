-- Crucible rank-1. The alchemist's answer to a crowd: a thrown flask that bursts into a 3x3 sheet of
-- flame and leaves the ground burning. Cheap, loud, and no substitute for a mage -- it carries no
-- magic scaling at all, so what it does to a knight it does to a wizard.
--
-- Mechanically it is Fireball with the caster taken out of it (data/items/ability/ability_fireball.lua):
-- fixed power, no `magical` tag, and the same fire hazard laid across its footprint.
return {
    name = "Flask of Liquid Fire",
    description = "Deals fire damage in the target area and leaves the ground burning.",
    flavor = "Cheap, loud, and no substitute for a mage -- which the Crucible tells you before it takes your gold.",
    sprite = "assets/items/flask_of_liquid_fire.png",
    type = "consumable",
    tags = { "fire" }, -- no "magical": the fire is chemistry, and cares nothing for magic defense
    class = "alchemist",
    price = 110,
    repRank = 1,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the burst may be centred ON a foe, like Fireball
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = { 12, 13, 14, 16, 17, 18, 19, 20, 22, 23, 24 }, -- flat: nothing about the thrower makes the fire hotter
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
