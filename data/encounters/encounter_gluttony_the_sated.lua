-- THE SATED, and the apex encounter of the Gluttony circle.
--
-- A 2x2 body on a mire board is a door closed across the only dry line -- it blocks four tiles, is
-- struck from beside any of them, eats an area blast once rather than four times, and slides as one when
-- knocked back. The flies around it are not a screen so much as a supply: they are what it has been
-- eating, and they are still arriving.
--
-- The fight's shape is the inverse of every other set-piece in the descent. The Sated opens at the top
-- of its band and gets WEAKER at each threshold (data/items/utility/utility_distended_hide.lua), so a
-- party that commits everything into the first two turns is rewarded rather than punished. That is a
-- true thing about an appetite that has already been satisfied, and it is the deliberate opposite of
-- what Wrath's circle teaches one stratum over.
return {
    name = "The Sated",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    minDay = 8,
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_the_sated" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 12) do
            list[#list + 1] = "character_gorge_fly"
        end
        return list
    end,
}
