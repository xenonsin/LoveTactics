-- THE SHIELDWALL: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Paladin's aura cuts the damage taken by every ally beside him. The Battlemage strikes and
-- casts in one action from inside it, and the Crusader heals on every kill. From floor 12 a
-- Vanguard strips your armour, from 13 a Spellbreaker Silences your caster, and on 15 a Theurge
-- channels inside the aura.
--
-- How you beat it: Pull them apart: a body stepped off the paladin's aura takes full damage. Keep
-- your casters back from the spellbreaker.
--
-- DEPARTURE FROM THE APPROVED PAGE: it grew with a Sentinel, which put two sustain bodies (the paladin
-- and the sentinel) in a party of four on floor 12 and five on 13 -- past the one-per-three limit the
-- same page approved. A Vanguard takes the slot: it strips your front body's armour, which is the hole
-- the battlemage's cast-with-the-swing walks through.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_shieldwall",
    name = "The Shieldwall",
    core = { "paladin", "battlemage", "crusader" },
    grow = { "spellbreaker", "vanguard", "theurge" },
})
