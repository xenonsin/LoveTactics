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
return {
    name = "Running Shot",
    description = "A shot that hits harder for every tile you covered this turn.",
    flavor = "The bow is not the difficult part. Neither is the horse.",
    sprite = "assets/items/ability_running_shot.png",
    type = "ability",
    tags = { "ranged", "physical", "pierce" },
    class = "hunter",
    discipline = "skirmisher",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = { 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
        description = "Damage rises with the ground you covered before taking the shot.",
        effect = function(fx)
            local moved = require("models.combat").tilesMovedThisTurn(fx.user)
            fx.damage(fx.target, { amount = fx.amount + moved * 3 })
        end,
    },
}
