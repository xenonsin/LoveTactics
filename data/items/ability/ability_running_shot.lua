-- Running Shot: the hunter half of the Skirmisher (fighter x hunter). A shot that lands harder for every
-- tile you covered before you took it.
--
-- The shelf's other pieces all pay you for moving AFTER the blow -- Harrying Strike hands back a step,
-- the Harrier's Bow leaves your move unspent. This is the one that pays for the approach, which is what
-- makes the discipline a loop rather than a getaway: ride in hard, shoot, and be somewhere else by the
-- time anyone answers.
--
-- Scaled off Combat.tilesMovedThisTurn -- distance from where the turn opened, not steps taken. A rider
-- who circles back to their own tile has covered no ground, whatever the pathfinder counted, and an
-- item that paid for pacing in a circle would be an item about the pathfinder.
--
-- Uncapped on purpose. The ceiling is the mover's own movement stat and the board, both of which the
-- player can see, and a skirmisher who spends everything on the approach has nothing left to leave with.
local Curve = require("models.curve")

return {
    name = "Running Shot",
    description = "Fires a shot. Increase damage by 3 per tile you covered this turn.",
    flavor = "The bow is not the difficult part. Neither is the horse.",
    sprite = "assets/items/ability_running_shot.png",
    type = "ability",
    tags = { "ranged", "physical", "pierce" },
    class = "skirmisher",
    price = 330,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(10, 20),
        description = "Increase damage by 3 per tile covered before the shot.",
        effect = function(fx)
            local moved = require("models.combat").tilesMovedThisTurn(fx.user)
            fx.damage(fx.target, { amount = fx.amount + moved * 3 })
        end,
    },
}
