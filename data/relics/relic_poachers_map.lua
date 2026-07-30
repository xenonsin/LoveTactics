-- VIRTUE · overworld · common. The road's forgotten corners give up a little coin -- dead-ends most of
-- all. Rewards sweeping the board (the greed pillar), and each tile pays only once, so pacing mints
-- nothing (cell.mapped, the way Kaya's forage and Saber's paces mark a tile once).
return {
    name = "Poacher's Map",
    blurb = "Newly explored tiles turn up a little gold -- dead-ends most of all.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 2,
    step = function(_, bucket, ctx)
        local cell = ctx.cell
        if not cell or cell.mapped then return end
        cell.mapped = true
        local deadEnd = ctx.grid and #ctx.grid:pathNeighbors(cell.x, cell.y) <= 1
        if ctx.rnd() < (deadEnd and 0.6 or 0.2) then
            local g = 3 + math.floor(ctx.rnd() * 4) -- 3..6
            bucket.found = (bucket.found or 0) + g
            ctx.addGold(g)
            ctx.say("Poacher's Map  +" .. g .. "g")
        end
    end,
    banked = function(bucket) return bucket.found end,
}
