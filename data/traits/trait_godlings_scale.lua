-- THE GODLING'S SCALE: the Godling's trophy, worn (data/items/utility/utility_godlings_scale.lua). Round 2
-- (2026-09-25), "You are the dragon" -- picked over "Bare Patch, reversed", on Keno's round-1 note on the
-- first trophy: "I don't like the per fight". So nothing on it builds up or resets across a fight.
--
-- ALLIES WITHIN 2 OF THE WEARER FIGHT UNDER THE DRAGON'S EYE: +2 Damage, +1 Defense, moment to moment -- a
-- `presence` turned round to reach the bearer's own side (Trait.liveBonus). The Scale ALSO carries
-- trait_dragonkin, so to a hired kobold the wearer IS a dragon: it rallies when its captain is struck and
-- breaks when its captain falls, and its own Devotion adds the kobold's Eye on top. A company that hired
-- kobolds is the one this pays most.
return {
    name = "You Are the Dragon",
    description = "Allies within 2 of you gain damage and defense.",
    presence = { allies = true, radius = 2, damage = 2, defense = 1 },
}
