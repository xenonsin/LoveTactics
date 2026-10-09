-- FIELD DRESSING: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Priest heals the Fighter and wards his tile, so he can trade blows he would lose alone. The
-- Hunter picks at whoever is trading with him. Deeper, a Barbarian takes the front and a Crusader
-- heals himself on every kill.
--
-- How you beat it: The front line is the bait. Reach past it to the priest; without the heals it
-- can't hold.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_dressing",
    name = "Field Dressing",
    core = { "priest", "fighter", "hunter" },
    grow = { "knight", "barbarian", "crusader" },
    combo = "The Priest heals the Fighter and wards his tile, so he can trade blows he would lose alone."
        .. " The Hunter picks at whoever is trading with him. Deeper, a Barbarian takes the front and a"
        .. " Crusader heals himself on every kill.",
    counter = "The front line is the bait. Reach past it to the priest; without the heals it can't hold.",
})
