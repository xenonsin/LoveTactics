-- BOTTLED RAGE: the stack-keeping half of the Brute's drop (data/items/ability/ability_bottled_rage.lua). Every
-- hit the bearer takes adds a stack of status_bottled_rage, up to 5; the ability spends them.
return {
    name = "Bottled Rage",
    description = "Each hit you take adds a stack of Bottled Rage, to 5.",
    notAReaction = true,
    onDamaged = function(ctx)
        if not (ctx.unit and ctx.unit.alive) or (ctx.amount or 0) <= 0 then return end
        ctx.applyStatus(ctx.unit, "status_bottled_rage", { magnitude = 1 })
    end,
}
