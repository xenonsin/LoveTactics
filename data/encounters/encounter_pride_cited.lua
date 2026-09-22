-- THE CITED: an Arcanum party that will explain the mistake you are making.
--
-- Pride's own bodies are statues and colours -- things that were made to be looked at. These are the
-- people who made them, and they fight from the back at range, which is the sin as a preference:
-- they would rather be correct at a distance than right up close.
--
-- character_mage is the generic caster template and character_elementalist its one non-boss crossing;
-- both were authored and neither was ever seated on a board.
--
-- Weight and scaling follow the circle's existing traffic (encounter_pride_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Cited",
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
    condition = function(ctx) return ctx.biome == "spire" end,
    composition = function(ctx)
        local list = { "character_elementalist" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_mage"
        end
        return list
    end,
}
