-- THE UNWANTED, and the apex encounter of the Envy circle.
--
-- A 2x2 body that answers being cut by coming apart: each threshold sheds a pair of glass-motes
-- (data/items/utility/utility_fracture_line.lua), so the health bar going down is not the whole story --
-- there is more of it on the board than there was.
--
-- Fielded with a thin opening escort on purpose. The fight is supposed to START small and grow, which is
-- the exact inverse of The Sated one stratum over, where the apex opens enormous and deflates. Two
-- circles, two opposite readings of what a big body does as you hurt it, and both of them true to
-- the sin they belong to.
return {
    name = "The Unwanted",
    kind = "elite",
    weight = 1,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "desert" end,
    composition = function(ctx)
        local list = { "character_the_unwanted" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_glass_eater"
        end
        return list
    end,
}
