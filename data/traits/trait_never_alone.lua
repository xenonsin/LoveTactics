-- NEVER ALONE: the goblin saboteur's race item (data/items/utility/utility_never_alone.lua, "The Rift's
-- Adventurers", slice D). A hidden charge the bearer set itself (any trap it placed) within two tiles counts as
-- a goblin for Mob Courage (trait_mob_courage), so a saboteur sitting on its own powder does not Cower. Read
-- through models/race_items.lua's `chargeNear`.
return {
    name = "Never Alone",
    description = "Your hidden charges count as goblins, so you do not Cower beside one.",
    neverAlone = true,
}
