-- HEXING: a blow it lands leaves the target Cursed for a turn -- losing health, and nothing heals it
-- (data/status/status_cursed.lua). Short on purpose: a minor hex that punishes standing in its reach,
-- not a second fight.
return {
    name = "Hexing",
    description = "Its blows leave the target Cursed for a turn: losing health, and no healing.",
    color = { 0.55, 0.38, 0.62 },
    onBlowLanded = function(ctx)
        local target = ctx.target
        if not (target and target.alive and ctx.unit and target.side ~= ctx.unit.side) then return end
        ctx.applyStatus(target, "status_cursed", { duration = 5, magnitude = 2 })
    end,
}
