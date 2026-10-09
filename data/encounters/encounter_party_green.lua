-- GREEN HANDS: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Bombardier covers the board in craters. The Herbalist harvests those hazards into brews mid-
-- fight, a poison for you or a cure for them. The Alchemist throws what she brews. Grows with a
-- Poisoner, a Plague Knight and a Necromancer.
--
-- How you beat it: Kill the herbalist before she harvests, or fight on clean ground away from the
-- craters.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_green",
    name = "Green Hands",
    core = { "herbalist", "bombardier", "alchemist" },
    grow = { "poisoner", "plague_knight", "necromancer" },
})
