-- RUN THROUGH THE GLASS: the Sandman's organ for his escape (data/characters/character_the_sandman.lua;
-- data/traits/trait_run_through_the_glass.lua). No `reach` in traitParams, so he reforms on the tile his hourglass
-- has marked, across the board, and the mark is shown. Creature kit: bound, unstealable, on no shelf -- the Hourglass
-- is the same rule cut to four tiles for a ninja.
return {
    name = "Run Through the Glass",
    description = "When a foe ends its turn beside him, reforms on his marked tile. The tile he left sleeps whoever stops on it.",
    flavor = "The glass is turned. He is at the other end of it.",
    sprite = "assets/items/utility_run_through_the_glass.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_run_through_the_glass" },
}
