-- THE LABYRINTH: the Minotaur, alone, in the maze it brings (data/characters/character_minotaur.lua;
-- models/labyrinth.lua). A spare elite of Wrath's seat, reviewed 2026-09-26/27 ("The Minotaur").
--
-- `alone = true` as the Deep Bane's is, and for the same reason: the myth's beast is the only thing in the maze,
-- and a stat-line rating is blind to a fight whose weight is a maze, a second phase and a barbarian's kit.
-- Only an elite may claim it. Played out, never walked off (any authored objective keeps it off auto-resolve).
--
-- FIND THE WAY OUT (the objective pass, 2026-10-21): this reverses the explicit kill-all it was built with. A maze is
-- for getting through, so the fight is won on the far edge while the Minotaur hunts the company through the walls.
-- Killing it still ends it (`orKillAll`). `waves = {}` because a reach is otherwise handed a tide drawn from the
-- opening line, and the opening line is the one beast.
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
    objective = { type = "reach", region = "far", place = "out of the maze", orKillAll = true, waves = {},
                  enemy = "the Minotaur" },
}
