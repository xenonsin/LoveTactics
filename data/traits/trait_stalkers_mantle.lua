-- Stalker's Mantle: the Sabertooth's ambush, worn by a person. The first blow of the fight that you land
-- from a tile no foe can see is a critical.
--
-- A FLAG (Trait.flag), read by Combat.forcesCrit alongside the Pounce and the Ambush Charm, so the
-- forecast, the planner and the swing all quote 100 together. "No foe can see" is Combat.seenByFoe --
-- Combat.hasLineOfSight, the same measure a shot is refused by -- so two tiles of wood or one hill hide you
-- here exactly as they block an arrow. "The first blow" is the `hitDealt` tally still at nought, which is
-- a LANDED blow: a first swing that misses has not spent the ambush.
--
-- It is an archer's piece and says so by arithmetic rather than by a gate: a body beside you always sees
-- you, so a blade can only collect it off a foe that cannot see the one standing next to it.
return {
    name = "Stalker's Mantle",
    description = "The first blow you land in a fight, from a tile no foe can see, is a critical.",
    critFromCover = true,
}
