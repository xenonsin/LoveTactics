-- UNSTEERED: the Goblin Fanatic's flag (data/items/utility/utility_unsteered.lua). ability_spin_out reads it: an
-- unsteered spinner does not stop at the lava's edge, it goes in. The immunities ride the item's own
-- `statusImmunity`, where every other innate immunity lives.
return {
    name = "Unsteered",
    description = "Your Spin Out does not stop at lava.",
    unsteered = true,
}
