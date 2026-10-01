-- THE SPHINX'S RIDDLE: what the Sphinx drops (data/characters/character_sphinx.lua; "Pride's Bestiary",
-- 2026-09-30). Its rule, asked of the bearer's own side instead of its foes: each of the bearer's turns names a
-- riddle (one of the Sphinx's five), and a side that meets it by the bearer's next turn leaves the bearer
-- Empowered -- a coiled strike, spent on the next blow that lands.
--
-- The same trait the Sphinx carries, told three different numbers through `traitParams`: it asks its own side,
-- it does not ward, and a failed round heals nothing. An Inquisitor's, because the Inquisitor's whole shelf is
-- questions put to somebody. An unstocked trophy on the approach's rung.
return {
    name = "Sphinx's Riddle",
    description = "Each turn names a riddle for your side. Meet it by your next turn and gain Empowered.",
    flavor = "The answer was never the point. The point was that you had to stop and think about it.",
    sprite = "assets/items/utility_sphinxs_riddle.png",
    type = "utility",
    tags = { "charm" },
    class = "inquisitor",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_the_riddle" },
    traitParams = { asks = "own", wards = false, failHeal = 0, reward = "status_empowered" },
}
