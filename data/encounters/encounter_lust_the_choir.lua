-- THE CHOIR: the fight that takes your formation apart.
--
-- The chorister Charms as it acts, so a body is pulled out of line and into cover where the wraiths are
-- waiting. Every other circle's control costs you a turn; this one costs you the shape of your company.
return {
    name = "The Choir",
    kind = "combat",
    weight = 4,
    minDay = 3,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_chorister", "character_bloom_wraith" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_petal_drift"
        end
        return list
    end,
}
