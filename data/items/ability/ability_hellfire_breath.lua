-- HELLFIRE BREATH: the Hellhound's breath ("The Crown's Bestiary", slice C, approved 2026-10-09): "Its breath (a 2-tile
-- cone) leaves fire on the ground." The Wyrmling's Kindling Breath is the shape (a short cone that burns what it
-- catches); what this one adds is the ground left alight behind it -- the fire a hound then stands in to heal and hit
-- harder (trait_hearth_born). Unsided, as all fire is: a locust or a Reaper caught in the cone burns too, and a hound
-- does not. Creature kit, not for sale.
local Curve = require("models.curve")

return {
    name = "Hellfire Breath",
    description = "Breathes a short cone of fire. Every foe caught is burned, and the ground is left alight.",
    flavor = "It does not breathe on you so much as on the floor you are standing on, and then it comes and stands there.",
    sprite = "assets/items/ability_hellfire_breath.png",
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
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { inflicts = "status_burn" }) end
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 4, duration = 15 })
            end
        end,
    },
}
