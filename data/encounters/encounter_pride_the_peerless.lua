-- THE PEERLESS, the apex of the Pride circle -- and the only apex in the descent that is one tile.
--
-- Every other stratum's apex occupies ground. This one refuses to be surrounded: it duels, and it is at
-- its best in a doorway where only one of you can reach it. So the castle's warren, which is where you
-- BREAK a formation everywhere else on this floor, is the Peerless's advantage instead.
--
-- Escorted thinly on purpose. The fight should be about the one body.
return {
    name = "The Peerless",
    kind = "elite",
    weight = 1,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "spire" end,
    composition = function(ctx)
        local list = { "character_the_peerless" }
        for _ = 1, 1 + math.floor((ctx.depth or 1) / 6) do
            list[#list + 1] = "character_gilded_sworn"
        end
        return list
    end,
}
