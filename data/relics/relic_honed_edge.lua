-- COMMON. Granted by choosing to SHARPEN at a rest (states/game.lua), never found in a cache -- the run
-- boon you buy with a breather instead of a heal. `weight = 0` keeps it off the rollable shelf entirely.
--
-- IT DEEPENS ON A SECOND CAMP, which is the whole reason the Sharpen choice stopped being dead. It used
-- to answer a repeat visit with "your edge is already keen" and pay nothing; now a company that keeps
-- choosing the whetstone over the bandage opens harder every time, and that is a real strategy for a
-- floor you intend to fight rather than survive.
return {
    name = "Honed Edge",
    blurb = "Sharpened at a rest: the front line opens Emboldened for %d turns.",
    tier = "common", mark = "He", weight = 0,
    scale = { 3, 2 },
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do
            ctx.grantBoon(c, "status_heroism", { duration = ctx.mag(3, 2) })
        end
    end,
}
