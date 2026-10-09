-- THE BAIT: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Champion's Provoke pulls your attacks onto him, and he strikes back at everyone who bites.
-- The Apothecary keeps him standing with doses. The Hunter shoots whoever took the bait. From floor
-- 9 a Shaman's spirits fight around him.
--
-- How you beat it: Ignore the taunt where you can and kill the apothecary first. The champion is
-- built to be attacked; he isn't built to win on his own.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_bait",
    name = "The Bait",
    core = { "champion", "apothecary", "hunter" },
    grow = { "shaman", "monk", "summoner" },
})
