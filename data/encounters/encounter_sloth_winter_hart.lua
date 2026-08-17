-- THE WINTER HART: an animal that makes the ground worse by walking on it.
--
-- It lays black ice as it acts, and the gnats around it keep you from simply walking away from where the
-- ice is going. What the fight asks is which of the two you would rather let happen -- the Hart moving,
-- or the Hart swinging -- because it pays for the ground with its turn.
return {
    name = "The Winter Hart",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_the_winter_hart" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_rime_gnat"
        end
        return list
    end,
}
