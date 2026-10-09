-- FIRE AND STEEL: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Mage lays burning ground; the Alchemist throws a Fire Bomb into it and drinks an elixir that
-- raises the Fighter's blow. The Fighter sweeps the front and pays health to swing. Deeper, a
-- Bombardier adds craters and a Battlemage casts fire with every swing.
--
-- How you beat it: Stay off the burning tiles and let the fighter come to you: every swing costs
-- him. Kill the mage before the ground spreads.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_fire",
    name = "Fire and Steel",
    core = { "fighter", "alchemist", "mage" },
    grow = { "hunter", "bombardier", "battlemage" },
})
