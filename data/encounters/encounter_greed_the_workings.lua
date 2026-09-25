-- THE WORKINGS: an old gallery the mountain has stood up in (reviewed 2026-09-25, "The Golems of Greed").
-- Earth Golems and nothing else -- the mountain's golems never share a board with the dwarves or the
-- kobolds. It teaches the line cheaply before the Gold Golem charges for it: read the Delve mark, take the
-- heap the hole leaves behind, and bring a mace to the plate.
--
-- ON BOTH OF GREED'S FLOORS, AND THE ONLY GOLEM FIGHT. A second, bigger one (The Deep Vein, three or four
-- golems on the seat) was cut on review: it fielded this cast again -- one cast, one stop -- and ran 34
-- unit-turns against the road's budget of 22 (tests/skirmish_spec.lua). So no `rung`: a rung on an
-- ordinary fight is a home it strays from at a fraction of its weight, and this one belongs to both.
local Band = require("models.band")

return {
    name = "The Workings",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    composition = function(ctx)
        return Band.fill({ "character_earth_golem" }, ctx, "character_earth_golem",
            { base = 1, per = 6, max = 2 })
    end,
}
