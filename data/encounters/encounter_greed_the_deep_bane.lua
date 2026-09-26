-- TOO DEEP: the Thing Under the Seam, alone. "They dug too greedily and too deep" -- the seat's third spare
-- elite beside the King Slime and the Nest (Descent.SINS' greed `elites`; the Counting Hall is the named
-- one), approved on review 2026-09-26. Met once a trip, somewhere else the next, as every elite is.
--
-- NO ESCORT, on review. The fight is one body reading the board against four: its trail closing the ground
-- behind it, its cone marked a turn ahead, and the floor falling away at half. Anything standing beside it
-- would be standing in all three.
--
-- `alone = true` IS WHAT LETS A FLOOR SEAT IT, and it excuses the fight from BOTH of Descent.floorPool's
-- light-fight rules. A dungeon fight is never one animal (Descent.MIN_BODIES), and that is right about a
-- lone stag; the Chimera clears it by growing heads. And Muster.encounter rates a fight by summing its
-- bodies' stat lines, which is blind to everything this one is: measured at floor six it rates about 560
-- against the Counting Hall's ~2250, the Nest's ~1760, the King Slime's ~1440 and a floor median of ~1570
-- -- under the share's bar -- and no lone stat block inside the elite band gets near those (a 500-health
-- variant still rates ~940). A set-piece authored to stand alone is judged by what it does, so it says so.
-- Only an elite may claim it.
--
-- PLAYED OUT, NEVER WALKED OFF: the kill-all is stated as an objective so EncounterBattle.eligible keeps
-- it off auto-resolve. A rating that low would otherwise offer a floor-six company the walk-over, and the
-- floor falling away is not something the model should get to skip.
--
-- Cave-locked with no depth gate, as every encounter_greed_the_* is; `rung = 2` stands it on the seat.
return {
    name = "Too Deep",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function()
        return { "character_deep_bane" }
    end,
    objective = { type = "killAll" },
}
