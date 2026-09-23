-- THE ROOD LOFT: the Lust circle's Dryad fight, and the Move half of the circle growing its own walls.
--
-- The rood loft is the gallery over the chancel screen, and the rood beam was cut from the yew over the
-- pit. A Dryad and her Nymphs come out of the timber, and a Harpy comes with them -- which is the pairing
-- the Dryad line exists for. The Nymph lights a body (Mistlight: the next shove goes a tile further),
-- the Dryad grows the hedge behind it and the thorns under it, and the Harpy throws it.
--
-- WHAT THE PLAYER HAS TO READ: a fight board is open ground until she grows it shut, so the answer is
-- the order -- cut the hedges before a gust finds a body in front of them, burn the thorns, and kill the
-- Nymphs before there is a grove to step between.
--
-- MOVE ONLY. Nothing in this roster roots, and nothing may be added that does (Descent.SINS' Lust entry;
-- tests/greed_lust_circle_spec.lua sweeps every Lust roster for the mix).
--
-- Locked to the castle stratum by ctx.biome. NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT.
local Band = require("models.band")

return {
    name = "The Rood Loft",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_dryad", "character_nymph", "character_harpy" }
        return Band.fill(list, ctx, "character_nymph", { base = 0, per = 6, max = 2 })
    end,
}
