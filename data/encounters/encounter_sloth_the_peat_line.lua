-- THE PEAT LINE: Bog Bodies across the lanes and a Cairn-Keeper at the back, approach traffic on the tundra
-- ("Sloth's Bestiary", 2026-10-04, slice C). The line's teaching fight: only heavy blows count, and do not end a
-- turn beside them unless you mean to stay. The Keeper doubles both near it, so the real question is how to
-- reach it through the line.
--
-- The Keeper is listed first so the skirmish ceiling (Arena.clampComposition) keeps it: three to four Bog Bodies
-- were approved, and the tier's four-body cap seats three of them beside the Keeper.
local Band = require("models.band")

return {
    name = "The Peat Line",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_cairn_keeper" }, ctx, "character_bog_body", { base = 3, min = 3, max = 4 })
    end,
}
