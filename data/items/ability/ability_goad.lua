-- GOAD: the orc Beast-Handler's cast, and its drop (approved as pitched, 2026-09-26, "The Orcs of Wrath"). An ally
-- within 2 loses 10% of its health and acts again at once, its next blow empowered by half its Damage -- the
-- Handler's point-and-strike, spending an ally's blood to hit out of turn. The Handler goads its War Ogre.
local ALLY_TOLL = 0.10

return {
    name = "Goad",
    description = "An ally within 2 loses 10% of its health, acts again at once, and its next blow deals 50% more.",
    flavor = "The goad is iron at one end and a promise at the other. The ogre knows both.",
    sprite = "assets/items/ability_goad.png",
    type = "ability",
    tags = { "command" },
    class = "beastmaster",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        range = 2,
        speed = 2,
        cooldown = 15,
        support = true,
        cost = { stat = "stamina", amount = 5 },
        ai = { priority = "high", act = "cast", targetPref = "highest_hp" },
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive) or target == user or target.side ~= user.side then return end
            local Combat = require("models.combat")
            local toll = math.max(1, math.floor(Combat.unreservedMax(target.char, "health") * ALLY_TOLL + 0.5))
            fx.flatDamage(target, toll, { "impact" })
            fx.applyStatus(target, "status_empowered",
                { magnitude = math.max(1, math.floor(Combat.flatStat(target, "damage") * 0.5 + 0.5)) })
            fx.grantExtraAction(1, target)
            fx.hasten(target, 1.0)
        end,
    },
}
