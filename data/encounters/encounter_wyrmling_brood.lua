-- THE WYRMLING BROOD: three short cones, and the tile where they cross.
--
-- The pack's combo is pure geometry and needs no trait to state it. Each wyrmling breathes a two-tile
-- cone from three tiles out, and the `skirmish` archetype holds them apart rather than letting them
-- stack -- so the danger is not any one breath, it is standing where two of them overlap. Thin the
-- brood or move; those are the answers, and both are real.
--
-- NO ADULT, deliberately. Whatever laid them is deeper down and is not this encounter -- and reaching
-- for character_wild_wyrm to play the parent would be fielding a druid's worn shape as an enemy, which
-- is the mistake character_dire_bear already embodies on Gluttony's honour-guard floor.
local Band = require("models.band")

return {
    name = "Wyrmling Brood",
    kind = "combat",
    weight = 3,
    depth = 3, -- a brood is not roadside texture; it wants a party that can spread out
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        -- THREE IS THE LESSON AND SO IT IS THE FLOOR (`min = 3`). The whole fight is where the cones
        -- cross, and a brood that rolled down to two is a brood with one crossing in it -- the geometry
        -- still there and no longer the point. It may roll up.
        return Band.fill({}, ctx, "character_wyrmling", { base = 3, min = 3, per = 6 })
    end,
}
