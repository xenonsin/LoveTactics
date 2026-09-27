-- THE THOUSAND-WINGED: an elite on Wrath's approach (Wrath's vampires, round 3, floor 7). Eight familiars and no
-- body (character_swarm_familiar). At the end of any turn in which 4 or more stand next to each other they fuse into
-- a vampire lord with 12 health per bat in it (character_thousand_winged); strike it to 0 and it scatters back into
-- its survivors (models/swarm.lua). Kill bats to shrink it; let them gather and it comes back. The fight is won
-- when every bat is dead -- a bat inside the lord is alive, so `killAll` cannot resolve over it.
--
-- ITS OWN CEILING OF EIGHT (the author's note on the bats, "Many bats in an encounter is ok"): the elite tier's six
-- would cut the swarm to six every time.
local Band = require("models.band")

return {
    name = "The Thousand-Winged",
    kind = "elite",
    weight = 1,
    enemyCap = 8,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_swarm_familiar", { base = 8, min = 6, max = 8 })
    end,
}
