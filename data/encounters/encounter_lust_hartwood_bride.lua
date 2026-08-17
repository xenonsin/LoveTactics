-- THE HARTWOOD BRIDE: where the Chorister takes one body out of your line, she takes a rank.
--
-- A four-tile body standing in an open trail is that trail closed, which in a circle built on breaking
-- formations means the ground you would have re-formed on has gone.
return {
    name = "The Hartwood Bride",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_the_hartwood_bride" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_petal_drift"
        end
        return list
    end,
}
