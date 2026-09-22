-- THE GRUDGE: pit fighters who came down for the one thing the sand could not give them.
--
-- Wrath's cast is otherwise demons and fire, and a circle whose every body is a creature has nothing
-- in it that can hand over a weapon (docs/bestiary.md's split). These can. They close on the shortest
-- line and they do not break off a wound, which on a volcanic carve is a decision they will lose.
--
-- ONE BLUEPRINT, REPEATED, and it is the honest state of the Colosseum's non-boss cast rather than a
-- shape anybody wanted: character_warbrewer is a boss and character_saber is a companion, so the
-- house's whole rollable line is character_fighter. Wrath owes thirty-four items. This is the
-- clearest single instance of the bill in docs/drops.md.
--
-- Weight and scaling follow the circle's existing traffic (encounter_wrath_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Grudge",
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
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_fighter" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_fighter"
        end
        return list
    end,
}
