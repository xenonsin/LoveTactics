-- THE REED CHOIR: the Siren's ordinary fight, on Lust's approach (floor three).
--
-- The faction's new sentence, read in order: the Fen Lancer soaks the back rank, the Siren sings to the
-- soaked (a Wet body hears her from anywhere, data/status/status_singing.lua), and the Shoalkin stand in
-- the water a company would have to walk toward to get out of the song. Every piece of it is answered by
-- something the player already carries -- a bow ends the song, a dry company hears less of it, and a
-- line that walks IN pays nothing.
--
-- Floor three only (`rung = 1`), so the circle's two floors deal different fights: floor four has the
-- Shoal (docs/descent -- a circle's floors do not share fights). EITHER half of Lust's hold/move rule:
-- nobody here roots or shoves.
local Band = require("models.band")

return {
    name = "The Reed Choir",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1,
    composition = function(ctx)
        local list = { "character_siren", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 1, per = 6, max = 2 })
    end,
}
