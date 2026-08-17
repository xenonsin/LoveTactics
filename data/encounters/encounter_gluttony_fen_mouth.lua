-- THE FEN MOUTH: the Grendlemaw, with a screen in front of it.
--
-- ONE MAW, EVER. It swallows a body whole -- out of the fight in both directions until somebody cuts it
-- back out (data/items/weapon/weapon_grendlemaw_gullet.lua) -- and two of them could halve a company in
-- two turns with no interaction at all. So the composition names it once and thickens the screen
-- instead, which also makes the fight the right shape: the maw is slow and short-reached, and the
-- bogswallows exist to stop you simply walking away from it.
--
-- `elite`, so it opens at Arena.ELITE_CAP rather than the four-body skirmish ceiling. A set-piece that
-- opened at four would be the maw and two swallows, which is not a screen.
return {
    name = "The Fen Mouth",
    kind = "elite",
    weight = 2,
    minDay = 5,
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_grendlemaw", "character_bogswallow" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_bogswallow"
        end
        return list
    end,
}
