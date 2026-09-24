-- THE EYRIE: a mated pair of griffins and the hawks that nest under them, on the wood's first floor.
-- Reviewed 2026-09-23 ("The Sated and the Flight"). The pair is the point: when one falls the other eats it
-- and fights on Gorged (data/traits/trait_mated_for_life.lua), so the company decides whether to bring them
-- down together or face the worse one alone.
--
-- A SPARE on the approach (Descent.SINS' Gluttony `spares`), beside the Unseeing and the Larder: the
-- approach is where the hawks live, so it is where their elite stands. Rung 1, exact, as every elite's is.
local Band = require("models.band")

return {
    name = "The Eyrie",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_griffin", "character_griffin" }, ctx, "character_hawk",
            { base = 2, per = 6, max = 3 })
    end,
}
