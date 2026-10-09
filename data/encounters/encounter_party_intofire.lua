-- INTO THE FIRE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Bombardier leaves a burning crater with every bomb. The Bulwark pushes you into one and Halts
-- you there. The next bomb sets off any bomb near it. The Hunter finishes what the blasts leave. On
-- floor 14 a Saboteur hides charges among the craters.
--
-- How you beat it: Never stand between the bulwark and a crater. Kill the bombardier first and the
-- bulwark's push only moves you.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_intofire",
    name = "Into the Fire",
    core = { "bulwark", "bombardier", "hunter" },
    grow = { "mage", "fighter", "saboteur" },
    combo = "The Bombardier leaves a burning crater with every bomb. The Bulwark pushes you into one and"
        .. " Halts you there. The next bomb sets off any bomb near it. The Hunter finishes what the"
        .. " blasts leave. On floor 14 a Saboteur hides charges among the craters.",
    counter = "Never stand between the bulwark and a crater. Kill the bombardier first and the bulwark's"
        .. " push only moves you.",
})
