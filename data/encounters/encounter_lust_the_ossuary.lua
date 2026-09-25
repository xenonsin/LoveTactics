-- THE OSSUARY: the mushroom folk, all three roles on one board.
--
-- The bone-house under the chapel, where the pit's overflow was stacked, and it has been damp for a long
-- time. A Verger holds the front, Puffers walk in and pop, and a Thurifer casts from behind and sets the
-- Puffers off from where they stand. Physical and magical mixed, as the folk are.
--
-- WHAT THE PLAYER HAS TO READ IS THE ORDER. The Verger makes you hit it, and a melee blow on it swoons
-- the hand; the Puffers punish a company that bunches up; the Thurifer mends the Verger and turns every
-- Puffer into a mine. So: range on the Puffers, magic or reach on the Verger, and the Thurifer first if
-- you can reach it.
--
-- EITHER HALF. Nothing here roots or shoves, so the mushroom folk may stand in any Lust fight; this is
-- the one where they stand alone.
--
-- Locked to Lust's stratum by ctx.biome (the fen since the 2026-09-25 swap). NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT.
local Band = require("models.band")

return {
    name = "The Ossuary",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_swooncap_verger", "character_swooncap_thurifer" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 2, per = 5, max = 4 })
    end,
}
