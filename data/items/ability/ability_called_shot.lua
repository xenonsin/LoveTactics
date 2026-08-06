-- Called Shot: the hunter's follow-up to Mark Target. Against a Marked foe the arrow finds the painted
-- spot and hits for double; against anyone else it is an ordinary shot. Pairs directly with
-- data/items/ability/ability_mark_target.lua. Requires an adjacent bow in the grid.
local Curve = require("models.curve")

return {
    name = "Called Shot",
    description = "Doubles its damage against a Marked foe. Requires an adjacent bow.",
    flavor = "The Lodge calls the shot before it takes it. The calling is most of the skill.",
    sprite = "assets/items/ability_called_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 260,
    unlockQuests = 6,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        damage = Curve.ramp(11, 21),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.hasStatus(t, "status_mark") then
                fx.damage(t, { amount = fx.amount * 2 })
            else
                fx.damage(t)
            end
        end,
    },
}
