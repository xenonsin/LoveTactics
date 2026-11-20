-- THE MANTICORES: three over the glade, give or take one. Manticores and nothing else -- a wolf
-- in the fight would take the volley's first quills and blur whose bite is coming next, and the whole
-- fight is a company reading its own Quilled badges.
--
-- HOMED ON THE SEAT (rung 2), beside the Tangle and at its weight, so the wood's second floor splits its
-- own traffic evenly between the two animals that fight it at range -- one that resists the company's
-- arrows and one that is weak to them. It strays nowhere: a seat's fight is never dealt above its home
-- (models/encounter.lua), and there is no floor under the seat in this circle.
--
-- Forest-locked with no depth gate, like the rest of the wood's stock (encounter_wolf_pack.lua argues it).
local Band = require("models.band")

return {
    name = "The Manticores",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2,
    composition = function(ctx)
        -- Three, not two: at two the seat's own fight rated 430 against the approach's 600-750, so the
        -- second floor was lighter than the first and a company arriving there walked it off.
        return Band.fill({}, ctx, "character_manticore", { base = 3, per = 6, max = 4 })
    end,
}
