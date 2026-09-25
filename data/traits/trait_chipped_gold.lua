-- CHIPPED GOLD (round 1): every blow that lands on a Gold Golem knocks coin off it -- 3 gold into the
-- fight's spoils (Combat.bounty) -- and the striker has taken gold off a foe, which is what Heart of Gold
-- heals on (Golem.took). The one fight in the game where hitting the enemy is paying you.
--
-- `notAReaction`: the gold comes off whether or not the golem is in any state to answer.
local CHIP = 3

return {
    name = "Chipped Gold",
    description = "Each blow that lands on it knocks 3 gold into the spoils.",
    notAReaction = true,
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not (attacker and attacker.side ~= ctx.unit.side and (ctx.amount or 0) > 0) then return end
        require("models.combat").bounty(ctx.combat, CHIP)
        require("models.golem").took(ctx.combat, attacker)
    end,
}
