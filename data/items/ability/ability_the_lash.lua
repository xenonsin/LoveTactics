-- THE LASH: the Hobgoblin whipping a goblin into acting again (approved as pitched, 2026-09-26). The ally half of
-- its whip (weapon_hobgoblins_lash), written as a support cast of its own so the planner can plan it -- a
-- `target = "unit"` weapon is offered to the AI at foes only. The goblin loses 10% of its health and takes an
-- extra turn right away. A body's own, never shelved: the drop is the whip, which does both.
local ALLY_TOLL = 0.10

return {
    name = "The Lash",
    description = "Lashes an ally within 2: it loses 10% of its health and acts again at once.",
    flavor = "Faster. It does not say anything else, and it never needs to.",
    sprite = "assets/items/ability_the_lash.png",
    type = "ability",
    tags = { "command" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        range = 2,
        speed = 2,
        cooldown = 15,
        support = true,
        cost = { stat = "stamina", amount = 4 },
        ai = { priority = "high", act = "cast", targetPref = "highest_hp" },
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive) or target == user or target.side ~= user.side then return end
            local Combat = require("models.combat")
            local toll = math.max(1, math.floor(Combat.unreservedMax(target.char, "health") * ALLY_TOLL + 0.5))
            fx.flatDamage(target, toll, { "slash" })
            fx.grantExtraAction(1, target)
            fx.hasten(target, 1.0)
        end,
    },
}
