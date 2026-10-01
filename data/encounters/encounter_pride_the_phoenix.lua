-- THE PHOENIX: Pride's one-off elite of the return, on the spire's seat ("Pride's Bestiary", 2026-09-30;
-- data/characters/character_phoenix.lua). Every felling leaves an Ember on the board that rises again in three
-- turns, angrier -- so where it falls on THIS board decides how far the company has to go to break it.
--
-- A CAST OF ONE, and `alone = true` for the Labyrinth's reason: its weight is a second and third life a stat line
-- cannot see, and an escort standing over the Ember would turn a race into a siege.
--
-- Spire-locked, `rung = 2`. Played out, never walked off: the Ember is on its side, so the kill-all is not won
-- while one stands.
return {
    name = "The Phoenix",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2,
    composition = function()
        return { "character_phoenix" }
    end,
    objective = { type = "killAll" },
}
