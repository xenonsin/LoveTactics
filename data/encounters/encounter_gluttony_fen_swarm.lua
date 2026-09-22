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
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_tallow_hound" }
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_gorge_fly"
        end
        return list
    end,
}
