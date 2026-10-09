-- STRIPPED BARE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Thief's blow takes a buff off you and gives it to him. The Exorcist's rites strip what's
-- left, clear your wards and banish your summons. The Knight holds the line while they work. On
-- floor 13 a Spellbreaker Silences whoever tries to put the buffs back.
--
-- How you beat it: Don't open with buffs; they'll be stolen or stripped. Fight plain, and kill the
-- thief before he wears your own boons.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_stripped",
    name = "Stripped Bare",
    core = { "exorcist", "thief", "knight" },
    grow = { "rogue", "spellbreaker", "hunter" },
    combo = "The Thief's blow takes a buff off you and gives it to him. The Exorcist's rites strip what's"
        .. " left, clear your wards and banish your summons. The Knight holds the line while they work."
        .. " On floor 13 a Spellbreaker Silences whoever tries to put the buffs back.",
    counter = "Don't open with buffs; they'll be stolen or stripped. Fight plain, and kill the thief before"
        .. " he wears your own boons.",
})
