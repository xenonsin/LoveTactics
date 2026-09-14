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
    minDay = 2,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_fighter" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_fighter"
        end
        return list
    end,
}
