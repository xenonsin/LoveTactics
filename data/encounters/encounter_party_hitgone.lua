-- HIT AND GONE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Skirmisher moves after every strike and never ends a turn where it swung. The Ninja blinks
-- out of reach and leaves a clone to take the blow. The Hunter marks a body for both. Grows with an
-- Assassin, a Thief and an Inquisitor.
--
-- How you beat it: Use what doesn't miss: area spells, hazards and blasts. Kill the hunter, who
-- stands still.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_hitgone",
    name = "Hit and Gone",
    core = { "ninja", "skirmisher", "hunter" },
    grow = { "assassin", "thief", "inquisitor" },
})
