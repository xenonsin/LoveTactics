-- MIRAGE: Envy's one-off elite of illusions, on the Ribstone Waste's approach ("Envy's Bestiary", round 1;
-- data/characters/character_mirage.lua). Fielded ALONE on purpose: it brings its own three bodies at the bell, and an
-- escort would be a fifth and sixth thing to sort, which buries the question the fight asks -- which one is real.
--
-- Desert-locked, no depth gate (the circle is the placement); `rung = 1` is an exact lock for an elite. Played out,
-- never walked off (the kill-all keeps it off auto-resolve).
return {
    name = "Mirage",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = { "character_mirage" },
    objective = { type = "killAll" },
}
