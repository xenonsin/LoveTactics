-- THE LINE: the Reaper's own (data/characters/character_reaper.lua; "The Crown's Bestiary", slice C). It carries the
-- flag the board reads to draw the threshold on every health bar while a Reaper stands (trait_the_line). The rule it
-- shows is the scythe's.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player.
return {
    name = "The Line",
    description = "While it stands, every health bar shows a line at a quarter. Under it, its sweep downs you.",
    flavor = "Everybody has one. It is only that most people never see where theirs is drawn.",
    sprite = "assets/items/utility_the_line.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "dark" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_line" },
}
