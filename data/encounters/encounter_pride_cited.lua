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
    minDay = 2,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_elementalist" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_mage"
        end
        return list
    end,
}
