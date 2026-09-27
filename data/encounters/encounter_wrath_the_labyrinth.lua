-- THE LABYRINTH: the Minotaur, alone, in the maze it brings (data/characters/character_minotaur.lua;
-- models/labyrinth.lua). A spare elite of Wrath's seat, reviewed 2026-09-26/27 ("The Minotaur").
--
-- `alone = true` as the Deep Bane's is, and for the same reason: the myth's beast is the only thing in the maze,
-- and a stat-line rating is blind to a fight whose weight is a maze, a second phase and a barbarian's kit.
-- Only an elite may claim it. Played out, never walked off (the kill-all keeps it off auto-resolve).
return {
    name = "The Labyrinth",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function()
        return { "character_minotaur" }
    end,
    objective = { type = "killAll" },
}
