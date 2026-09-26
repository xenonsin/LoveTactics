-- THE TIDE POOL: the whole fen faction in one ordinary fight.
--
-- Soak, song and tide together: the Fen Lancer wets the back rank, the Siren sings to the wet, and the
-- Tidecaller moves the water they are standing in. Until this fight they met at full strength only in the
-- Undertow and Still Water elites. EITHER half: none of the four roots or shoves.
--
-- Approved on review 2026-09-25 (variety round 1, `l4_tidepool`); the approach's Mere is its light twin.
local Band = require("models.band")

return {
    name = "The Tide Pool",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_tidecaller", "character_siren", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 1, max = 1, min = 0 }) -- sometimes the four are three
    end,
}
