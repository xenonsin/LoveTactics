-- HOARDKEEPER: the dwarf mammonite's race item ("The Rift's Adventurers", slice D, approved 2026-10-09).
-- Approved as "Hoard"; renamed because a status is already named Hoard and utility_the_hoard exists.
--
-- The mammonite's shelf spends gold as a weapon; this is the dwarf's half of that bargain, which is keeping it.
-- A Skimmer's Cut lifts nothing off the bearer, and a coin heap it picks up banks twice its gold -- into the
-- company's takings, or into a rift dwarf's own coffer (trait_hoardkeeper, models/race_items.lua).
--
-- Gated to dwarves (Character.canCarry). No price: a rift find on the mammonite's shelf at the class's floor.
return {
    name = "Hoardkeeper",
    description = "Gold you have banked cannot be stolen. Picking up loose gold banks it twice.",
    flavor = "A dwarf counts a heap once when it finds it and once more when it is safely put away.",
    sprite = "assets/items/utility_hoardkeeper.png",
    type = "utility",
    tags = { "trinket" },
    class = "mammonite",
    race = "dwarf",
    unlockLevel = 7,
    traits = { "trait_hoardkeeper" },
}
