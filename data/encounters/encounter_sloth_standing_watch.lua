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
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_bulwark" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_bastion_sworn"
            list[#list + 1] = "character_grey_knight"
        end
        -- ...and a third rank once the floors are deep enough to want one.
        if (ctx.depth or 1) >= 12 then list[#list + 1] = "character_greywatch_captain" end
        return list
    end,
}
