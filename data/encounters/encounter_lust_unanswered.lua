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
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_monk" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_priest"
        end
        return list
    end,
}
