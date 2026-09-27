-- Minotaur: the ONE beast of Wrath's labyrinth (data/characters/character_minotaur.lua; "The Minotaur",
-- 2026-09-26/27). This is a record for a single body, NOT a people: the author struck the race pitch outright
-- ("Don't make this a race, it's just a mythical beast"), and nothing else will ever be seated on it. No clan
-- rule, nothing granted, and not playable -- a company does not hire a minotaur.
--
-- WHY IT EXISTS AT ALL: the author also approved the beast fighting AS A BARBARIAN, and only a `humanoid` may
-- carry a shelf (tests/bestiary_spec.lua: a beast's kit is natural weapons only -- a wolf is what a Beastmaster
-- has). A man's body under a bull's head is the one reading of the myth that satisfies both, so its record
-- says humanoid and its resists say bull.
return {
    name = "Minotaur",
    description = "A man's body under a bull's head, alone at the heart of its maze.",
    kind = "humanoid",
    resist = {
        impact = 2,   -- a skull made for butting takes a blow...
        pierce = -2,  -- ...and a spear finds its ribs. Sums to zero.
    },
    playable = false,
}
