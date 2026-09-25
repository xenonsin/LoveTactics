local Band = require("models.band")

-- THE WALLOW: a Giant Toad in the wet under the trees, and the moss slimes that grow where it sits. Floor
-- two's own fight (settled on review 2026-09-25: "toad with slimes"), and the first thing in the wood that
-- takes a body off the board. The slimes are why it is not a toad on its own: slow bodies to read on the
-- ground while the one that hops is choosing who to eat.
return {
    name = "The Wallow",
    kind = "combat",
    weight = 4, -- the floor's other own fights (the Tangle, the Wyverns, the Manticores)
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        return Band.fill({ "character_giant_toad" }, ctx, "character_moss_slime",
            { base = 2, min = 1, per = 6, max = 2 })
    end,
}
