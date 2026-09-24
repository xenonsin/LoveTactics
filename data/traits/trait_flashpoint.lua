-- FLASHPOINT's rule (data/items/utility/utility_flashpoint.lua): every third hit the bearer takes primes
-- the next blow they land (status_empowered, +8 Damage, spent on the hit).
return {
    name = "Flashpoint",
    description = "Every third time you're hit, your next hit deals +8 Damage.",
    every = 3,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or (ctx.amount or 0) <= 0 then return end
        ctx.trait.stacks = ctx.trait.stacks + 1
        if ctx.trait.stacks % ctx.param("every", 3) ~= 0 then return end
        ctx.applyStatus(u, "status_empowered", { magnitude = 8 })
    end,
}
