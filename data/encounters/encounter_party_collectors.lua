-- THE COLLECTORS: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Thief steals off you; the Mammonite banks coin on every blow and spends it on damage, tempo
-- and his own survival. The Sentinel covers the mammonite while the purse fills. Deeper, a Rogue
-- steals too and a Bulwark pushes you away from the purse.
--
-- How you beat it: Kill the mammonite before he banks enough to spend, and kill the thief to stop
-- feeding him.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_collectors",
    name = "The Collectors",
    core = { "mammonite", "thief", "sentinel" },
    grow = { "rogue", "bulwark", "warlord" },
})
