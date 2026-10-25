-- VAMPIRIC: a blow it lands heals it for a third of the wound. A hook of its own rather than a lifesteal
-- status, so it rides no badge and nothing can strip it; it fires on a blow the target survives
-- (Trait.onBlowLanded), the same seam the Flaying and the King-Eats-First read.
return {
    name = "Vampiric",
    description = "Heals for a third of the damage its blows deal.",
    mark = "V",
    color = { 0.78, 0.16, 0.22 },
    share = 1 / 3,
    onBlowLanded = function(ctx)
        local amount = math.floor((ctx.amount or 0) * ctx.param("share", 1 / 3))
        if amount >= 1 and ctx.unit and ctx.unit.alive then ctx.heal(ctx.unit, amount) end
    end,
}
