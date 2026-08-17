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
    minDay = 8,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_the_peerless" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_gilded_sworn"
        end
        return list
    end,
}
