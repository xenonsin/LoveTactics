-- Stout: the two FLAGS a dwarf's organ carries (data/items/utility/utility_stout.lua). No hook of its own;
-- both are read where the thing they refuse or invite already happens.
--
--   wardsTheft  Combat.steal and Combat.strip refuse a grid that carries it -- the Jealous Resin's own
--               flag, so a dwarf is as unrobbable as a body wearing that.
--   seeksHeaps  hazard_coin_heap `welcomes` its bearer (Hazard.tileBias reads a welcoming zone as
--               friendly ground to the planner), the heap pays its bearer when stepped on, and
--               models/ai.lua's fallback walk heads for the nearest heap when there is nothing to hit.
--
-- Sundered gags both, as it gags every flag (Trait.flag): a silenced dwarf forgets its gold for a turn,
-- and a thief's hand can find its pocket.
return {
    name = "Stout",
    description = "Cannot be robbed, and goes for loose gold.",
    wardsTheft = true,
    seeksHeaps = true,
}
