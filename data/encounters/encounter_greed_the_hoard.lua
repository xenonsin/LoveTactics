-- THE HOARD, the apex of the Greed circle -- and a fight with a clock made of its own reward.
--
-- It does not chase. Every threshold you cut it past sheds a pair of chitters that run for the dark
-- carrying as much as they can hold, so the pile is worth more the faster you get through it and being
-- careful costs you the thing you were being careful about.
--
-- The sharpest reading of the sin available, and the reason this is the apex rather than the Wyrm.
return {
    name = "The Hoard",
    kind = "elite",
    weight = 1,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_the_hoard" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_coin_chitter"
        end
        return list
    end,
}
