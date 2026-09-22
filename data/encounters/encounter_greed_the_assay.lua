-- THE ASSAY: the fight your own success sets.
--
-- The assayer gains damage for the coin your company is carrying, read live -- so a hoarding run meets a
-- harder fight than one that spent at the Forge. The chitters beside it lower that number as they rob
-- you, which is the circle's joke: the thieves are helping.
return {
    name = "The Assay",
    kind = "combat",
    weight = 4,
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
        local list = { "character_assayer", "character_coffer_crawler" }
        for _ = 1, 1 + math.floor((ctx.depth or 1) / 6) do
            list[#list + 1] = "character_coin_chitter"
        end
        return list
    end,
}
