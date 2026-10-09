-- FLAWLESS SHOT: the elf hunter's race item (data/items/utility/utility_flawless_shot.lua, "The Rift's
-- Adventurers", slice D). While the bearer is still Unblemished (status_unblemished), its bow shots are not
-- asked the dice (Combat.rollsToHit) and reach a tile further (Combat.abilityRange) -- on top of the tile the
-- status already lends. The first wound ends both, with the status. Read through models/race_items.lua.
return {
    name = "Flawless Shot",
    description = "While Unblemished, your bow shots cannot miss and reach 1 tile farther.",
    flawlessShot = true,
}
