-- UNCOMMON. The company opens every fight quick and exposed: Hasted, so its first turns come around
-- sooner and cost half, and Marked, so those same turns are the ones it is easiest to hurt in. A trade
-- made entirely inside the opening, which makes it a decision about HOW to open rather than a number
-- that is simply on.
--
-- BOTH STATUSES LAST THE SAME TURNS, and the ladder deepens both together -- a longer fuse is a longer
-- window either way. Durations are in ticks (Status.TICKS_PER_TURN = 5), so "2 turns" is 10.
--
-- The whole COMPANY, not the front line: ctx.party is everyone deployed (states/game.lua's
-- resolveOpening), where Duelist's Spur narrows to ctx.frontRow().
local TICKS = 5

return {
    name = "The Lit Fuse",
    blurb = "The company opens every fight Hasted, for %d turns.",
    tier = "uncommon", mark = "Lf",
    cost = "...and Marked for as long: -5 defense, -5 magic defense, -4 luck.",
    scale = { 2, 1 },
    battleStart = function(_, _, ctx)
        local ticks = ctx.mag(2, 1) * TICKS
        for _, c in ipairs(ctx.party or {}) do
            ctx.grantBoon(c, "status_hasted", { duration = ticks })
            ctx.grantBoon(c, "status_mark", { duration = ticks })
        end
    end,
}
