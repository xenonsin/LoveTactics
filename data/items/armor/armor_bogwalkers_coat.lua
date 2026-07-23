-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- A trapper who IS the trap. `incense` is ground that walks (Combat.layIncense), so the quicksand is
-- laid in a square around the wearer every time they stop somewhere and lifted from where they were --
-- and Quicksand doubles the movement AND ability costs of anything standing in it (status_mired).
--
-- The Warren's traps have always been a thing you place before the fight and hope they walk into.
-- This is the same denial with the placement problem deleted: you carry it to them. What it costs is
-- that there is no version of this that is safe to stand near, because the cloud is UNSIDED -- unlike
-- the Rimeguard's, hazard_quicksand has no ally check, so the party's own knight bogs down in it
-- exactly as the enemy does.
--
-- That is deliberate and is the whole decision the coat asks for. A sided version would simply be a
-- better Rimeguard on a shelf that did not earn it; an unsided one makes the wearer a hazard their own
-- line has to route around, which is a real cost paid in the party's positioning rather than in a
-- number on this file.
return {
    name = "Bogwalker's Coat",
    description = "Lays Quicksand around you as you go: anything standing in it pays double to move or act.",
    flavor = "The Warren's trappers stopped carrying stakes the year somebody worked out how to carry the ground instead.",
    sprite = "assets/items/armor_bogwalkers_coat.png",
    type = "armor",
    tags = { "hide", "earth" },
    class = "hunter",
    incense = { hazard = "hazard_quicksand", radius = 1 },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
}
