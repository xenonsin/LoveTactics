-- THE STILL WATER: Nethrys's fight, on Lust's seat (floor four) beside the Eyrie (2026-09-25).
--
-- She had been written, named and statted since the Mere was authored and fielded by nothing -- the
-- rift never placed her. Keno's call on review was to make her an elite, which is the right shelf for a
-- body whose rule is the BOARD: her Rising Water turns the shallows under a company into deep water one
-- tile at a time (data/characters/character_nethrys.lua), so the ground a line deployed onto is not the
-- ground it finishes on. Two Fen Lancers soak and hold the bank; Shoalkin pad it as it deepens.
--
-- MOVE half of Lust's hold/move rule -- she drags and drives with the Undertow's pike and lane casts --
-- so nothing here roots. A spare, at elite weight: the Eyrie is what floor four is about.
local Band = require("models.band")

return {
    name = "The Still Water",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2,
    composition = function(ctx)
        local list = { "character_nethrys", "character_fen_lancer", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 0, per = 6, max = 2 })
    end,
}
