-- Ghost Kit: the rogue half of the Saboteur (rogue x alchemist). The detonator to the Set Charge's bomb
-- -- the signal that sets the ground off. Called on a tile, it erupts in a 3x3 of fire, the demolition
-- the Saboteur has been arranging. Greed's guile with envy's chemistry: she does not fight the room,
-- she decides the moment the room stops being safe.
local Curve = require("models.curve")

return {
    name = "Ghost Kit",
    description = "Sets off a demolition on a tile: a 3x3 burst of fire on the ground you chose.",
    flavor = "She is never in the room when it goes. That was, from the very beginning, the entire plan.",
    sprite = "assets/items/ability_ghost_kit.png",
    type = "ability",
    tags = { "fire", "utility" },
    class = "rogue",
    discipline = "saboteur", -- rogue x alchemist; the Planted-charges mechanic's first stock
    price = 740,
    unlockQuests = 5,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        aoe = { radius = 1, shape = "square" },
        damage = Curve.ramp(16, 26),
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { tags = { "fire" } }) end
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 3 + fx.level, duration = 8 + fx.level })
            end
        end,
    },
}
