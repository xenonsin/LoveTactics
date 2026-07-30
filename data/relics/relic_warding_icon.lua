-- VIRTUE · combat · common. The front line opens each fight behind a ward that soaks the first blows.
-- A battleStart barrier (status_physical_barrier) -- temp HP that eats the alpha strike and evaporates,
-- distinct from a heal. The found echo of Rowan's rebuilt Vigil.
return {
    name = "Warding Icon",
    blurb = "The front line opens each fight behind a barrier that soaks the first blows.",
    tier = "common", alignment = "virtue", affinity = "combat", weight = 2,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_physical_barrier") end
    end,
}
