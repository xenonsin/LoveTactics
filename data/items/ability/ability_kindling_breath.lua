-- KINDLING BREATH: the Wyrmling's short breath (approved 2026-09-24: "a bite, and a short breath on a
-- cooldown"). A small cone of fire that burns what it catches. The Godling's Dragon's Breath is what it
-- grows into. Creature kit, not for sale.
local Curve = require("models.curve")

return {
    name = "Kindling Breath",
    description = "Breathes a short cone of fire. Every foe caught is burned.",
    flavor = "More smoke than fire, the first year. Nobody standing in it has ever found that a comfort.",
    sprite = "assets/items/ability_kindling_breath.png",
    type = "ability",
    tags = { "fire", "magical", "breath" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cooldown = 15,
        cost = { stat = "stamina", amount = 6 },
        aoe = { shape = "cone", length = 2 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { inflicts = "status_burn" }) end
            end
        end,
    },
}
