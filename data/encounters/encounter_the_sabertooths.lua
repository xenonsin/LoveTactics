-- THE SABERTOOTHS: two cats in the long grass, a third deeper, and nothing else. The fight that teaches the
-- loop -- hide, pounce, stand exposed, hide again -- before the Longfang makes a kill keep her hidden. Cats
-- only: a wolf in the fight would stand in the open drawing the company's blows and blur the one lesson,
-- which is to hit the cat in the round after it strikes.
--
-- HOMED ON THE APPROACH (rung 1), beside the rest of the wood's first-floor animals and at the bear's and
-- the herd's weight: a fight you will certainly meet, not the one the floor is made of. It strays down to
-- the seat at Encounter.STRAY_SHARE, as every approach fight does. The teeth-without-a-head half of the
-- pair, as encounter_wolf.lua is to encounter_wolf_pack.lua.
-- Forest-locked with no depth gate, like the rest of the wood's stock (encounter_wolf_pack.lua argues it).
local Band = require("models.band")

return {
    name = "The Sabertooths",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_sabertooth", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
