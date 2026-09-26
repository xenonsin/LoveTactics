-- THE GILDED KING: Greed's rung-2 spare elite (approved over review rounds on 2026-09-26). The dead king and
-- the dwarves he hired to dig his vault, and kept -- two or three Dwarf Skeletons, every one of them opening
-- the fight Gilded (the King's own trait_the_gilded_guard: "His guard are also all gilded").
--
-- THE FIGHT PAYS AS IT GOES. Every blow on the King knocks a gold plate off as a coin heap, a heal on him is
-- one more heap, and a guard cut down while its gilding holds pays its bounty. So the company splits the
-- way the Gold Golem's fight splits: somebody keeps hitting, somebody loots -- and here nothing on the other
-- side wants the gold back, because the dead forget it (trait_stout's `deadForget`) and he does not eat it.
-- The guard is the clock instead: gilded and Stout, they hold the line for four turns and Delve up beside
-- whoever went for the heaps.
--
-- KILLALL, NEVER `assassinate`: the King is `boss`, and his guard is the half of the fight that is a fight.
local Band = require("models.band")

return {
    name = "The Gilded King",
    kind = "elite",
    weight = 1,
    -- No depth gate: its circle is its placement, and `rung` picks which of the circle's two floors (see
    -- encounter_the_king_slime.lua for the whole argument). RUNG 2 -- the seat, floor six, beside the
    -- Counting Hall, the Nest and the King Slime.
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    -- Two or three: a band floored at two and capped at three, so the stop rolls its guard per seed.
    composition = function(ctx)
        return Band.fill({ "character_the_gilded_king" }, ctx, "character_dwarf_skeleton",
            { base = 2, min = 2, max = 3 })
    end,
}
