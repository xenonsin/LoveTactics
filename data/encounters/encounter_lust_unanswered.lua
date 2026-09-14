-- THE UNANSWERED: a Cathedral company still keeping its hours on a floor that stopped listening.
--
-- They are not hostile because they were turned; they are hostile because you are interrupting. The
-- fight is slow and it mends itself, which is the sin read as tactics -- a thing that will not let go
-- of what it loves, including the office it is halfway through.
--
-- Two blueprints and no more, because the Cathedral's non-boss cast is two. That thinness is the
-- measurement docs/drops.md's bill is about rather than a shape anybody chose: Lust owes twenty-one
-- items and has the fewest bodies of the seven to hand them over.
--
-- Weight and scaling follow the circle's existing traffic (encounter_lust_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Unanswered",
    kind = "combat",
    weight = 4,
    minDay = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_monk" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_priest"
        end
        return list
    end,
}
