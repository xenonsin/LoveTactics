-- RAISE THE FALLEN: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Druid takes bear shape and holds the front. The Monk banks chi and spends it all on one heavy
-- blow. Any body that falls, yours included, the Necromancer raises to fight on their side, or
-- bursts where it lies. On floor 9 a Plague Knight poisons the bodies before they fall.
--
-- How you beat it: Don't let anyone go down near the necromancer, and kill him early. Burst him
-- before the monk's bank fills.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_fallen",
    name = "Raise the Fallen",
    core = { "necromancer", "monk", "druid" },
    grow = { "knight", "plague_knight", "fighter" },
    combo = "The Druid takes bear shape and holds the front. The Monk banks chi and spends it all on one"
        .. " heavy blow. Any body that falls, yours included, the Necromancer raises to fight on their"
        .. " side, or bursts where it lies. On floor 9 a Plague Knight poisons the bodies before they"
        .. " fall.",
    counter = "Don't let anyone go down near the necromancer, and kill him early. Burst him before the"
        .. " monk's bank fills.",
})
