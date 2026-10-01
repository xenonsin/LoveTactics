-- COMPOSED: the Highborn Circlet's, as a badge (data/traits/trait_highborn_circlet.lua; 2026-09-30, "Pride's
-- Bestiary"). A full round untouched: +2 Damage until the next blow that wounds. Ends exactly as Unblemished does,
-- on the wound and not on the miss.
return {
    name = "Composed",
    abbr = "Cmpd",
    description = "Composed: increases damage by 2 until wounded.",
    color = { 0.780, 0.800, 0.880 }, -- badge tint (silver)
    duration = math.huge,
    hideDuration = true,
    statBonus = { damage = 2 },
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.expire() end
    end,
}
