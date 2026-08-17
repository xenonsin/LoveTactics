-- THE ASSAY: the fight your own success sets.
--
-- The assayer gains damage for the coin your company is carrying, read live -- so a hoarding run meets a
-- harder fight than one that spent at the Forge. The chitters beside it lower that number as they rob
-- you, which is the circle's joke: the thieves are helping.
return {
    name = "The Assay",
    kind = "combat",
    weight = 4,
    minDay = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_assayer", "character_coffer_crawler" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_coin_chitter"
        end
        return list
    end,
}
