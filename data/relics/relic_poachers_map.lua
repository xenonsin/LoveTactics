-- VIRTUE · overworld · common. The road's forgotten corners give up a little coin -- dead-ends most of
-- all. It pays for DISCOVERY, not for walking: the step has to lift fog off ground nobody has seen yet
-- (ctx.revealed, counted by Overworld:reveal). Marking each tile once (cell.mapped, the way Kaya's forage
-- and Saber's paces mark a tile once) stops pacing; the fog gate stops the wider abuse of touring an
-- already-mapped board tile by tile to mint coin off ground the party had long since read.
return {
    name = "Poacher's Map",
    blurb = "Pushing into unmapped country turns up a little gold -- dead-ends most of all.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 2,
    step = function(_, bucket, ctx)
        local cell = ctx.cell
        if not cell or cell.mapped then return end
        cell.mapped = true
        if (ctx.revealed or 0) <= 0 then return end -- the step opened no new ground: nothing to sell
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
