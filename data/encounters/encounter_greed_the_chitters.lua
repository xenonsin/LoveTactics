-- THE CHITTERS: the Greed circle's ordinary traffic, and its decision stated cheaply.
--
-- The chitters take coin and run; the crawler is slow, armoured and worth opening. So the fight is two
-- questions at once -- is chasing the thieves worth the tempo, and is the treasury worth the turns --
-- and both of them are the sin.
return {
    name = "The Chitters",
    kind = "combat",
    weight = 5,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_coffer_crawler" }
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_coin_chitter"
        end
        return list
    end,
}
