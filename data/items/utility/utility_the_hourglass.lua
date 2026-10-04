-- THE HOURGLASS: the Sandman's escape, cut down for a ninja (data/characters/character_the_sandman.lua; "Sloth's
-- Bestiary", slice G, approved word for word). When a foe ends its turn beside you, reappear up to 4 tiles away; the
-- tile you left puts sleepers under.
--
-- The same trait the Sandman's organ carries (trait_run_through_the_glass), at `reach = 4` instead of his marked
-- tile: the bearer is set down on the open tile within 4 farthest from the foe that came, and the tile it left is a
-- Sand Patch that sleeps whoever ends a turn on it -- either side, as every patch does. A reflex, so a stunned or
-- sleeping ninja stays where it is.
--
-- An unstocked trophy on the approach's rung (floor 9), noSteal like every stair piece.
return {
    name = "The Hourglass",
    description = "When a foe ends its turn beside you, reappear up to 4 tiles away. The tile you left sleeps whoever stops on it.",
    flavor = "Turn it over and you are somewhere else. The sand stays where you were.",
    sprite = "assets/items/utility_the_hourglass.png",
    type = "utility",
    tags = { "charm", "earth" },
    class = "ninja",
    unlockLevel = 9,
    unstocked = true,
    noSteal = true,
    traits = { "trait_run_through_the_glass" },
    traitParams = { reach = 4 },
}
