-- THE GALLERY: armour that keeps standing more of itself up.
--
-- Every threshold it is cut past adds a Gilded Sworn, which in a circle where power IS adjacency means
-- the formation is being repaired while you dismantle it. Killing the Gallery is the only way to stop
-- the hall refilling.
return {
    name = "The Gallery",
    kind = "elite",
    weight = 2,
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
        local list = { "character_the_gallery", "character_standard_bearer" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 6) do
            list[#list + 1] = "character_gilded_page"
        end
        return list
    end,
}
