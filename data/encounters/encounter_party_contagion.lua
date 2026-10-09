-- THE CONTAGION: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Plague Knight poisons whoever stands next to him, and the Poisoner's coatings stack more.
-- Whatever falls poisoned, the Necromancer bursts where it lies, poisoning the bodies around it. On
-- floor 12 a Herbalist harvests the poison into brews.
--
-- How you beat it: Don't trade in melee with the plague knight, and don't let a poisoned body fall
-- near your others. Cure or Cleanse before the bodies drop.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_contagion",
    name = "The Contagion",
    core = { "plague_knight", "poisoner", "necromancer" },
    grow = { "alchemist", "fighter", "herbalist" },
})
