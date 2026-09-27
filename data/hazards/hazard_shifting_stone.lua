-- The mark THE MAZE SHIFTS leaves a turn ahead (models/labyrinth.lua): a maze wall slides onto this tile when
-- the Minotaur's next turn ends. It does nothing on its own. It is there so a corridor closing is read off the
-- board the turn before, never learned by standing in it.
return {
    name = "Shifting Stone",
    description = "The maze is moving. A wall slides onto this tile at the end of the Minotaur's next turn.",
    tags = { "earth" },
    duration = 40, -- consumed by the slide itself; this is only a ceiling
    disposition = "neutral",
}
