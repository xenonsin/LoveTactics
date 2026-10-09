-- HOARDKEEPER: the dwarf mammonite's race item (data/items/utility/utility_hoardkeeper.lua, "The Rift's
-- Adventurers", slice D). Approved as "Hoard"; renamed because status_hoard and utility_the_hoard exist.
--
-- Two halves under one flag: a Skimmer's Cut lifts nothing off the bearer (trait_skimmers_cut -- the one path
-- in the game that takes gold off a body mid-fight), and a coin heap the bearer picks up banks twice its gold
-- (hazard_coin_heap) -- into the company's takings for a company body, into its own coffer for a dwarf of the
-- rift. Read through models/race_items.lua.
return {
    name = "Hoardkeeper",
    description = "Gold you have banked cannot be stolen. Picking up loose gold banks it twice.",
    keepsHoard = true,
}
