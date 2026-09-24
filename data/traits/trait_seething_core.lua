-- SEETHING CORE's rule (data/items/utility/utility_seething_core.lua): the cinder slime's Boil Over,
-- worn without the eruption. Every hit that lands on the bearer adds 1 Damage for the fight, up to 5.
return {
    name = "Seething Core",
    description = "When you're hit, +1 Damage for the fight, up to +5.",
    cap = 5,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or (ctx.amount or 0) <= 0 then return end
        local Status = require("models.status")
        local s = Status.get(u, "status_simmering")
        if not s then ctx.applyStatus(u, "status_simmering", { magnitude = 1 }) return end
        s.magnitude = math.min((s.magnitude or 0) + 1, ctx.param("cap", 5))
    end,
}
