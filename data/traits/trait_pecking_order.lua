-- PECKING ORDER's rule (data/items/utility/utility_pecking_order.lua): the crystal slime's Rank, worn --
-- the bearer hits a foe harder when that foe is lower in the order than they are.
return {
    name = "Pecking Order",
    description = "+3 Damage against a foe with less health than you.",
    damageBonusVs = function(ctx)
        local mine = ctx.unit.char.stats.health.current or 0
        local theirs = ctx.target.char and ctx.target.char.stats.health.current or mine
        if theirs < mine then return ctx.param("bonus", 3) end
        return 0
    end,
}
