-- THE NAVE: the mushroom folk's own fight, on the approach.
--
-- The Puffers fill other people's fights all over this circle; here they are the congregation, with the
-- Verger (down from the seat's Ossuary) leading them. EITHER half: the swooncaps neither root nor shove.
--
-- Approved on review 2026-09-25 (variety round 1, `l3_nave`).
local Band = require("models.band")

return {
    name = "The Nave",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_swooncap_verger" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 2, per = 6, max = 3 })
    end,
}
