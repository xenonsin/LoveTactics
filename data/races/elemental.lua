-- Elemental: fire, ice, stone and the rest, given an outline and a grudge.
--
-- Coarse like the other creature races (see data/races/beast.lua). The elemental lines are authored per
-- body and must be: a fire elemental's `fire` and `water` are the whole of what it is, and two of them
-- sharing one table would make every elemental in the game the same puzzle.
return {
    name = "Elemental",
    description = "An element with an outline around it. What it is made of is what answers it.",
    kind = "elemental",
    playable = false,
}
