-- OPEN THE LINE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Vanguard's knockback strips guard and armour from your front body. The Duelist locks onto it
-- and grows stronger each turn the two stay locked. The Barbarian walks through the gap. Grows with
-- a Champion, a Warlord and on floor 15 a Warbrewer.
--
-- How you beat it: Rotate who stands at the front so the duelist's lock resets. Kill the vanguard
-- and your armour stays on.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_openline",
    name = "Open the Line",
    core = { "vanguard", "duelist", "barbarian" },
    grow = { "champion", "warlord", "warbrewer" },
    combo = "The Vanguard's knockback strips guard and armour from your front body. The Duelist locks"
        .. " onto it and grows stronger each turn the two stay locked. The Barbarian walks through the"
        .. " gap. Grows with a Champion, a Warlord and on floor 15 a Warbrewer.",
    counter = "Rotate who stands at the front so the duelist's lock resets. Kill the vanguard and your"
        .. " armour stays on.",
})
