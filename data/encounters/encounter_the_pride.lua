-- THE PRIDE: the Longfang and one or two of her cats. The exam after The Sabertooths' lesson -- the pride
-- hides and pounces exactly as the pair did, and she is the one a kill does not bring out of hiding. So
-- the question the fight asks is a health one: keep every body above one critical bite, or she takes
-- somebody a turn and is never seen.
--
-- HOMED ON THE APPROACH (rung 1) at a lighter weight than the pair's, so the lesson usually comes first.
-- The name was kept on review despite Pride being one of the seven circles.
-- Forest-locked with no depth gate, like the rest of the wood's stock (encounter_wolf_pack.lua argues it).
local Band = require("models.band")

return {
    name = "The Pride",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_the_longfang" }, ctx, "character_sabertooth", { base = 1, per = 6, max = 2 })
    end,
}
