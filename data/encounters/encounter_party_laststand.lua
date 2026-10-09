-- THE LAST STAND: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Barbarian hits harder the more hurt he is. The Sentinel stands beside him and takes every
-- blow meant for him, so he can sit at low health without dying. The Alchemist raises his damage
-- with elixirs. From floor 6 a Crusader's kills heal him and a Warlord's banner stands over them.
--
-- How you beat it: Kill the sentinel first, or push the barbarian off him. A wounded barbarian with
-- nobody covering him dies in one blow.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_laststand",
    name = "The Last Stand",
    core = { "barbarian", "sentinel", "alchemist" },
    grow = { "crusader", "warlord", "fighter" },
})
