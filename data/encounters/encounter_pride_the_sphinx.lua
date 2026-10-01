-- THE SPHINX: Pride's one-off elite of the riddle, on the spire's approach ("Pride's Bestiary", 2026-09-30;
-- data/characters/character_sphinx.lua). Met again on the next trip, and asked different questions: the riddles
-- are dealt off the fight's own seed, so a repeat visit is not a repeat fight.
--
-- A CAST OF ONE, and `alone = true` for the Labyrinth's reason: the riddle is the whole fight, and a stat-line
-- rating is blind to a body that takes no damage until it is answered. An escort would also turn "two of you
-- strike the same foe" into a question about somebody else.
--
-- Spire-locked, `rung = 1`. Played out, never walked off.
return {
    name = "The Sphinx",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function()
        return { "character_sphinx" }
    end,
    objective = { type = "killAll" },
}
