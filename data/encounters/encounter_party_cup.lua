-- BOTTOM OF THE CUP: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Warbrewer drinks a draught mid-swing at no cost to his action. The Vanguard strips your
-- armour ahead of him. The Monk banks chi off the openings and spends it on one heavy blow. Fielded
-- at six: a Barbarian, a Champion and a Warlord.
--
-- How you beat it: Kill the warbrewer before the draughts stack. Keep your armoured body away from
-- the vanguard.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_cup",
    name = "Bottom of the Cup",
    core = { "warbrewer", "vanguard", "monk" },
    grow = { "barbarian", "champion", "warlord" },
})
