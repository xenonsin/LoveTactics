-- THE OPEN ROOF: the Lust circle's ordinary traffic, and the stratum's rule at the cheapest rung.
--
-- ONE ROOM OF THE KEEP HAS NO CEILING, which is how the flock got in and why the fight is on this
-- ground rather than out in the weather. Every body here is a repositioner: the gust beats a foe back a
-- tile, the talons pin whatever closes, and neither one does enough damage to matter on its own. What
-- does the damage is the Thinwall Keep (data/biomes/castle.lua) -- a warren of thin walls and doorways
-- where one tile of shove is a wall, a threshold, or somebody else's back, and Combat.knockback bills
-- the impact of everything the shove could not spend.
--
-- SO THE FIGHT IS ABOUT WHERE YOU AGREE TO HAVE IT. Fought in a doorway it is a beating; fought in the
-- middle of the one roofless room -- which is the only open floor on the whole stratum -- it is four
-- thin birds. That choice is the lesson, and it is the lesson everything deeper in this circle bills
-- against: the Matriarch's cry (encounter_lust_the_eyrie) exists to take the choice away, and the
-- Suppliant's stair is held by a body that charges you for standing still.
--
-- CLOSING PART OF A HOLE, AND SAYING SO. The 2026-09-22 cut left the castle fielding 0 ordinary fights
-- and 0 elites -- Lust's two floors rolled nothing at all. This is the first of the ordinary fights
-- back; the ground is owed at least one more that is not a harpy.
--
-- Locked to Lust's stratum by ctx.biome (the fen since the 2026-09-25 swap), the same gate every circle uses. NO DEPTH GATE: ITS
-- CIRCLE IS ITS PLACEMENT. A circle owns a fixed stratum, so a depth on top of that is a second opinion
-- about where this goes, and it disagrees the moment the shuffle deals Lust at another depth
-- (Descent.sinOrder).
local Band = require("models.band")

return {
    name = "The Open Roof",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        -- A FLOCK OF ONE KIND, where the wood and the glass field each lead with a heavier body. There
        -- is nothing else on this ground yet to lead with -- and a flock that is all one bird is also
        -- the honest shape of the rule: what makes four harpies worse than one is not that one of them
        -- is bigger, it is that four of them are shoving in four directions at once.
        local list = { "character_harpy" }
        return Band.fill(list, ctx, "character_harpy", { base = 2, per = 5 })
    end,
}
