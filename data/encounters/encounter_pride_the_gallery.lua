-- THE GALLERY: armour that keeps standing more of itself up.
--
-- Every threshold it is cut past adds a Gilded Sworn, which in a circle where power IS adjacency means
-- the formation is being repaired while you dismantle it. Killing the Gallery is the only way to stop
-- the hall refilling.
return {
    name = "The Gallery",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_the_gallery", "character_standard_bearer" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_gilded_page"
        end
        return list
    end,
}
