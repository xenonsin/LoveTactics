-- THE GILT WYRM: the circle's dragon, on the pile it stopped being separable from.
--
-- A four-tile body on a warren carve is a door that closed, and this one takes coin off everything it
-- catches. The crawlers with it are the rest of the treasury, which means the fight is fought in a
-- corridor against something that does not need to move.
return {
    name = "The Gilt Wyrm",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_the_gilt_wyrm" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_coffer_crawler"
        end
        return list
    end,
}
