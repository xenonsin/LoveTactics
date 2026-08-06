-- Pinning Shot: an arrow through the foot. Modest damage, then the target is Rooted (data/status/root.lua)
-- -- it cannot move on its turn and still burns the time as if it had. Lock a charger in place and let
-- the line reposition around it. Requires an adjacent bow in the grid.
local Curve = require("models.curve")

return {
    name = "Pinning Shot",
    description = "Deals damage and inflicts Root. Requires an adjacent bow.",
    flavor = "Lock the charger down and let the line walk around it at leisure.",
    sprite = "assets/items/ability_pinning_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 220,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(8, 18),
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
