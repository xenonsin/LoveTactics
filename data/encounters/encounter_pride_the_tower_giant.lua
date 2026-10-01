-- THE TOWER-GIANT: Pride's one-off elite of ambition, on the spire's seat ("Pride's Bestiary", 2026-09-30;
-- data/characters/character_tower_giant.lua). It gains Ambition every turn and crashes wider and harder the more
-- it holds when it falls -- so the fight is read off the ground around it on this board, every time.
--
-- A CAST OF ONE, and `alone = true` for the Labyrinth's reason: its weight is the fall, which a stat line cannot
-- see, and anything standing beside it would be standing under it.
--
-- Spire-locked, `rung = 2`. Played out, never walked off.
return {
    name = "The Tower-Giant",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2,
    composition = function()
        return { "character_tower_giant" }
    end,
    objective = { type = "killAll" },
}
