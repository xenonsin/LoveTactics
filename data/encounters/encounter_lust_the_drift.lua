-- THE DRIFT: the Lust circle's ordinary traffic, and its dilemma stated cheaply.
--
-- Drifts that Charm and are not worth a turn to kill; a wraith that will not stand still to be answered.
-- The fight is not a damage problem, it is a question about whether to spend -- which is exactly what the
-- deeper stops of this circle charge for.
return {
    name = "The Drift",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_bloom_wraith" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 13) do
            list[#list + 1] = "character_petal_drift"
        end
        return list
    end,
}
