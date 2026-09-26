-- THE SACRISTY: a charm fight whose congregation is smoke rather than plate.
--
-- A succubus, one blooded priest, and the mushroom folk's censer-bearer where the Chapter House has
-- knights. Plate is what makes the church's fights long (the Long Gallery measured it), so trading it for
-- a Thurifer and a Puffer keeps the charm rule and shortens the stop. MOVE: the succubus trades tiles, and
-- the swooncaps do neither.
--
-- Approved on review 2026-09-25 (variety round 1, `l4_sacristy`).
local Band = require("models.band")

return {
    name = "The Sacristy",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_succubus", "character_swooncap_thurifer", "character_priest" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 1, max = 1, min = 0 }) -- sometimes the four are three
    end,
}
