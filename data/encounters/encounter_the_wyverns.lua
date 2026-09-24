-- THE WYVERNS: two over the glade, a third deeper, and nothing else. The fight that teaches the loop -- cut
-- from range, go up when reached, come down on whoever stands alone -- before an alpha makes it a kill
-- order. Wyverns only: a wolf would stand beside the company's stragglers and blur whether "alone" was
-- the reason one of them was taken.
--
-- HOMED ON THE SEAT (rung 2), beside the Tangle and the Manticores and at their weight. It strays nowhere:
-- a seat's fight is never dealt above its home, and this circle has no floor under the seat.
-- Forest-locked with no depth gate, like the rest of the wood's stock (encounter_wolf_pack.lua argues it).
local Band = require("models.band")

return {
    name = "The Wyverns",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_wyvern", { base = 2, per = 6, max = 3 })
    end,
}
