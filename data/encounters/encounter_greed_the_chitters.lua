-- THE CHITTERS: the Greed circle's ordinary traffic, and its decision stated cheaply.
--
-- The chitters take coin and run; the crawler is slow, armoured and worth opening. So the fight is two
-- questions at once -- is chasing the thieves worth the tempo, and is the treasury worth the turns --
-- and both of them are the sin.
return {
    name = "The Chitters",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_coffer_crawler" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_coin_chitter"
        end
        return list
    end,
}
