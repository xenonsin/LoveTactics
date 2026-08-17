-- THE BELOVED, the apex of the Lust circle -- and the one whose escalation is on your DECISION.
--
-- Every threshold sheds more drifts, and every drift is one more argument for holding your good ability.
-- Holding it is what this stratum charges for. So the fight does not get harder so much as the choice
-- gets worse, which is the most Lust thing an apex could do.
return {
    name = "The Beloved",
    kind = "elite",
    weight = 1,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_the_beloved", "character_chorister" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_bloom_wraith"
        end
        return list
    end,
}
