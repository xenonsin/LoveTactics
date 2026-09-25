-- DRAGON'S BREATH: the Godling's fire (approved as pitched, 2026-09-24): a wind-up cone, telegraphed a
-- turn early by its own channel, that burns what it catches and leaves the ground alight. The Godling's
-- one big verb, so the company has a turn to get out of the cone or to put a critical into the bare patch
-- before it lands. Creature kit, not for sale.
local Curve = require("models.curve")

return {
    name = "Dragon's Breath",
    description = "Winds up for a turn, then breathes a long cone of fire. Every foe caught is burned, and the ground is left alight.",
    flavor = "It learned to breathe fire before it learned there was anything it should not burn.",
    sprite = "assets/items/ability_dragons_breath.png",
    type = "ability",
    tags = { "fire", "magical", "breath" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 2,
        speed = 5,
        windup = 5, -- a turn: the cone is committed here, and everyone gets to read it
        cooldown = 15,
        cost = { stat = "stamina", amount = 8 },
        aoe = { shape = "cone", length = 4 },
        damage = Curve.ramp(8, 24),
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { inflicts = "status_burn" }) end
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 3 + fx.level, duration = 8 + fx.level })
            end
        end,
    },
}
