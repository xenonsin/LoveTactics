-- Thunder Storm: a barrage of lightning over a 3x3 area. Everyone within -- friend and foe, so mind
-- your line -- takes lightning damage (reaping the bonus on any Wet target, so rain it first) and is
-- Stunned (data/status/stun.lua), shoved down the turn order. The lightning counterpart to Blizzard;
-- a ground-target area cast.
local Curve = require("models.curve")

return {
    name = "Thunder Storm",
    description = "Inflicts Stun in area.",
    flavor = "Rain first. The Arcanum will not remind you, and will notice that you forgot.",
    sprite = "assets/items/ability_thunder_storm.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    discipline = "elementalist", -- deeper cut of the shelf: buyable only once the elementalist gate is cleared
    price = 740,
    unlockQuests = 5,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 5,
        windup = 6, -- mirrors Blizzard's wind-up
        cost = { stat = "mana", amount = 16 },
        damage = Curve.ramp(16, 26),
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_stun", { magnitude = fx.amount })
            end
        end,
    },
}
