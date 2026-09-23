-- THE PIT GARTH: the Lust circle's Alraune fight, and the Hold half of the circle played as a trap.
--
-- A garth is the square of garden a cloister walks round. This one was the burial pit, and something
-- came up in it. An Alraune stands among her Mandrakes, and the fill is the mushroom folk's Puffers --
-- the circle's filler body, which neither roots nor shoves and so belongs in either half.
--
-- WHAT THE PLAYER HAS TO READ: the honey heals, and a turn ended on it ends in sleep; the Mandrakes hold
-- a body on it; the seed decides who the healing was for; and every Mandrake screams when it dies. So the
-- fight is ordered by where you stand rather than by what you kill first -- cut the Mandrakes from range,
-- step off the honey before your turn ends, and the Alraune is a thin caster behind a garden.
--
-- HOLD ONLY. Nothing in this roster shoves, drags or swaps, and nothing may be added here that does
-- (Descent.SINS' Lust entry; tests/greed_lust_circle_spec.lua sweeps every Lust roster for the mix).
--
-- Locked to the castle stratum by ctx.biome. NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT.
local Band = require("models.band")

return {
    name = "The Pit Garth",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_alraune", "character_mandrake", "character_mandrake" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 1, per = 6, max = 3 })
    end,
}
