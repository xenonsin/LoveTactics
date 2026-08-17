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
return {
    name = "Wyrmling Brood",
    kind = "combat",
    weight = 3,
    minDay = 6, -- a brood is not roadside texture; it wants a party that can spread out
    composition = function(ctx)
        local list = {}
        for _ = 1, 3 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_wyrmling"
        end
        return list
    end,
}
