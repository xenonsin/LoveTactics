-- RALLYING: an ally that starts its turn beside it is Empowered -- its next blow lands harder. Rides the
-- Empowered status (data/status/status_empowered.lua) so the lift is a badge the player can read on the
-- ally it lands on, and it is spent on the hit, so killing or separating the rallier is the answer.
return {
    name = "Rallying",
    description = "Allies that start a turn beside it are Empowered: +3 damage on their next blow.",
    mark = "R",
    color = { 0.95, 0.70, 0.30 },
    power = 3,
    onAnyTurnStart = function(ctx)
        local actor, unit = ctx.actor, ctx.unit
        if not (actor and unit and actor.alive and actor.side == unit.side) then return end
        if math.abs(actor.x - unit.x) + math.abs(actor.y - unit.y) > 1 then return end
        ctx.applyStatus(actor, "status_empowered", { magnitude = ctx.param("power", 3), duration = 5 })
    end,
}
