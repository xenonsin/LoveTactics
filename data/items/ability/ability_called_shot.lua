-- Called Shot: the hunter's follow-up to Mark Target. Against a Marked foe the arrow finds the painted
-- spot and hits for double; against anyone else it is an ordinary shot. Pairs directly with
-- data/items/ability/ability_mark_target.lua. Requires an adjacent bow in the grid.
--
-- Its reach is the BOW'S, not its own: `rangeFromAdjacent` hands it the longest range among the bows
-- beside it (Combat.borrowedRange), the same borrow Mark Target makes -- the shot goes as far as the
-- bow it is loosed from. The authored 3 below is the floor every bow in the game clears, so the shelf
-- quoting it without a grid to read never overstates the reach.
local Curve = require("models.curve")

return {
    name = "Called Shot",
    description = "Doubles its damage against a Marked foe. Reaches as far as the bow beside it, which it needs.",
    flavor = "The Lodge calls the shot before it takes it. The calling is most of the skill.",
    sprite = "assets/items/ability_called_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 390,
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 3,
        rangeFromAdjacent = { type = "weapon", tag = "bow" },
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
