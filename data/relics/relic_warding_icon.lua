-- COMMON. The front line opens each fight behind a ward that soaks the first blows -- temp HP that eats
-- the alpha strike and evaporates, which is a different thing from a heal and is why it can sit on the
-- same rung as one. The found echo of Rowan's rebuilt Vigil.
--
-- Stacks as the SIZE of the barrier rather than its duration: a ward is spent by what lands on it, so
-- what a second copy should buy is more soak.
return {
    name = "Warding Icon",
    blurb = "The front line opens each fight behind a barrier soaking %d damage.",
    tier = "common", mark = "Ic",
    scale = { 8, 5 },
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do
            ctx.grantBoon(c, "status_physical_barrier", { magnitude = ctx.mag(8, 5) })
        end
    end,
}
