-- VIRTUE · overworld · rare. A found echo of Gyeom's Ledger: after two fights studied, the fog lifts off
-- the objective so the run's back half can be planned around the boss. Powers reveal-then-choose without
-- needing the scholar in the party.
return {
    name = "Cartographer's Eye",
    blurb = "After two fights, the fog lifts off the objective.",
    tier = "rare", alignment = "virtue", affinity = "overworld", weight = 1,
    encounterCleared = function(_, bucket, ctx)
        bucket.study = (bucket.study or 0) + 1
        if bucket.study >= 2 and not bucket.revealed and ctx.grid and ctx.grid.objective then
            bucket.revealed = true
            ctx.grid:reveal(ctx.grid.objective.x, ctx.grid.objective.y, 1)
            ctx.say("Cartographer's Eye reads the quarry's seat")
        end
    end,
    banked = function(bucket) return (not bucket.revealed) and bucket.study or nil end,
}
