-- THE SCORCHED GLADE: the Chimera, alone. An elite -- a body you take apart one head at a time is a puzzle,
-- and a puzzle body is an elite rather than traffic -- billed as one of the seat's rung-2 spares beside the
-- Sow, the Meandering Stag and the High Glade (Descent.SINS). Met once a trip, somewhere else the next.
--
-- NO ESCORT. Anything standing beside it would be in the cone, and the fight is reading three cards on
-- the strip, not a crowd. The heads are grown by its own grid at the bell (Combat.spawnHeads), so the
-- composition is one body.
--
-- Forest-locked with no depth gate, as every elite of the wood is (encounter_white_wolf.lua argues it).
return {
    name = "The Scorched Glade",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2,
    composition = function()
        return { "character_chimera" }
    end,
}
