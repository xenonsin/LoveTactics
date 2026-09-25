-- THE VELVET SLIMES: Lust's slimes, on the keep's approach floor (rung 1).
--
-- An ELITE, for the fen ooze's reason (data/encounters/encounter_fen_ooze.lua): a body steel cannot touch
-- makes a long fight by construction, and one that also takes your armour off should be a thing a
-- company SEES and decides about, never something that jumps it in a corridor. Two at the mouth of the
-- keep, three deeper in.
local Band = require("models.band")

return {
    name = "The Velvet Slimes",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_velvet_slime", { base = 2, per = 4, max = 3 })
    end,
}
