-- THE STANDING WATCH: a Bastion picket that was never relieved and never left.
--
-- The sin as a posture. They do not advance, they do not pursue, and they will hold the tile they are
-- standing on until somebody moves them off it -- so the fight is a question about whether going
-- through them is worth the turns, which is the same question their orders were about.
--
-- The deepest bench of the seven: five non-boss knights were authored and none of them was ever
-- placed. Sloth also carries the worst of the boss-queue problem -- twenty-one items behind Acedia,
-- thirteen of them past any reachable position (docs/drops.md) -- so this is where the spread has
-- the most to do.
--
-- Weight and scaling follow the circle's existing traffic (encounter_sloth_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Standing Watch",
    kind = "combat",
    weight = 4,
    minDay = 2,
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_bulwark" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_bastion_sworn"
            list[#list + 1] = "character_grey_knight"
        end
        -- ...and a third rank once the floors are deep enough to want one.
        if (ctx.day or 1) >= 12 then list[#list + 1] = "character_greywatch_captain" end
        return list
    end,
}
