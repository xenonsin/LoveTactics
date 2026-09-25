-- THE CLUTCH: a Broodkeeper, Skulkers, and two eggs -- or one egg and a Wyrmling that has already hatched
-- ("Can have already hatched in the encounter", round-1 note). Approved 2026-09-24/25.
--
-- It teaches the eggs and Devotion, in the fight where the egg is the only clock: the Broodkeeper stands at
-- one egg and broods it every turn, so the company has three of its turns. Smash an egg in one blow and the
-- kobolds that saw it are Forsaken; chip it and they rage. When a Wyrmling is already up, the Dragon's Eye
-- is live from the first turn.
--
-- WHICH OF THE TWO is a seeded draw (Band.count), and with no seed -- every rating path -- it lands on the
-- centre, which is the two eggs.
--
-- HOMED ON THE APPROACH (rung 1).
local Band = require("models.band")

return {
    name = "The Clutch",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        local hatched = Band.count(ctx, { base = 0, min = 0, max = 1, vary = 1, key = "clutch_hatched" }) == 1
        local list = { "character_kobold_broodkeeper", "character_dragon_egg",
                       hatched and "character_wyrmling" or "character_dragon_egg" }
        return Band.fill(list, ctx, "character_kobold_skulker", { base = 1, per = 6, max = 2 })
    end,
}
