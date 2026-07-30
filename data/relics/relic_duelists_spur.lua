-- VIRTUE · combat · common. The front line opens every fight a step ahead of the foe. A battleStart
-- boon (status_hasted), spent through the same opening-boons seam the abilities use -- so a found relic
-- and a companion's readiness stack onto the same unit without either knowing about the other.
return {
    name = "Duelist's Spur",
    blurb = "The front line opens every fight Hasted -- a step ahead.",
    tier = "common", alignment = "virtue", affinity = "combat", weight = 2,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_hasted") end
    end,
}
