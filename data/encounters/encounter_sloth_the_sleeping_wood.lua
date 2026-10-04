-- THE SLEEPING WOOD: the Old Spruce and a cloud of Poppy-Moths ("Sloth's Bestiary", 2026-10-04, slice E). Every
-- melee kill among the trees puts your striker to sleep, and the roots are closing.
--
-- ITS OWN CEILING OF FIVE: the review's fight is the tree and four moths, which the skirmish tier's four would cut
-- to three every time. The band rates at four and rolls only lighter (three), so it never seats more than the
-- review wrote; the tree never attacks, so the fifth body is a moth's worth of fight, not a fifth swing.
local Band = require("models.band")

return {
    name = "The Sleeping Wood",
    kind = "combat",
    weight = 3,
    enemyCap = 5,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_old_spruce" }, ctx, "character_poppy_moth", { base = 4, min = 3, max = 4 })
    end,
}
