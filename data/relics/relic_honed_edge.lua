-- VIRTUE · combat · common. Granted by choosing to SHARPEN at a rest (states/game.lua), not found in a
-- cache -- the run boon you buy with a breather instead of a mend. The front line opens each fight
-- emboldened (status_heroism), a lasting edge in trade for the HP a Mend would have returned. Its weight
-- is 0 so a Reliquary never rolls it: it is a rest reward only.
return {
    name = "Honed Edge",
    blurb = "Sharpened at a rest: the front line opens every fight emboldened.",
    tier = "common", alignment = "virtue", affinity = "combat", weight = 0,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_heroism") end
    end,
}
