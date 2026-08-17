-- THE FEN SWARM: the Gluttony circle's ordinary traffic, and its combo stated at the cheapest rung.
--
-- The flies bleed your line for almost nothing; the hound finishes what they softened and is fed by the
-- kill; and every fly YOU kill inside its reach feeds it too, because Engorge reads any death nearby and
-- does not care whose (data/traits/trait_engorge.lua). There is no order of operations that starves it
-- completely, only orders that starve it more -- which is the whole sin, playable in two minutes.
--
-- Locked to the swamp, which is how every circle keeps its stock. The gate is `ctx.biome`, the same
-- predicate encounter_stag.lua has always used, so no engine work was needed to make a stratum mean
-- something.
return {
    name = "The Fen Swarm",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_tallow_hound" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_gorge_fly"
        end
        return list
    end,
}
