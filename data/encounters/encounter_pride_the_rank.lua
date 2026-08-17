-- THE RANK: the Pride circle's ordinary traffic, and the lesson stated cheaply.
--
-- Nothing here is individually frightening. Both halves of the formation rule read adjacency LIVE, so a
-- closed rank is armoured and hitting properly, and the same bodies pulled through a doorway are four
-- suits of armour with opinions. The castle's `rooms` carve is what makes that a puzzle rather than a
-- number.
return {
    name = "The Rank",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_gilded_sworn" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 13) do
            list[#list + 1] = "character_gilded_page"
        end
        return list
    end,
}
