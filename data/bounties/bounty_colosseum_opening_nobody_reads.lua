-- The Colosseum's opening posting: standing, always on the board, never spent.
--
-- A POSTING OF WORK THAT ALREADY EXISTED. `quest_colosseum_slot_01` owns the map, the fight and both
-- scenes; this file owns what a board has to say about it before the player commits -- where it is, how
-- hard, who is at the end, and what that body gives up. See models/bounty.lua for why the two are
-- separate files.
--
-- WHY THIS IS THE PIECE. The debut, and the first posting a new company can read. The axe is the piece because it is
-- the only reward here a player can picture wanting before they know what the Colosseum is:
-- a ledgeman's axe is a job, and the board is offering the job.
--
-- The work's other rewards are unchanged and still pay: the piece is a headline, not a narrowing
-- (models/bounty.lua's questFor).
--
-- STANDING, which is what an opener is for. It is the floor under the Colosseum's ladder -- a company
-- that burns every deeper posting it holds can always walk back here -- so a run of bad luck is a
-- setback rather than a lock-out. Exactly one posting per house carries the flag.
--
-- NO `requires`: it is the bottom of the ladder, and the two rungs above it are derived from the circle
-- table rather than written out (models/bounty.lua's deriveLadders). Tier 1, so the fight is exactly
-- what the blueprint was balanced as.
return {
    name = "The Opening Nobody Reads",
    standing = true,

    sponsor = "colosseum",

    -- WHERE. Named here rather than inherited, because the ground is a posting's own field and one that
    -- took it silently would be one that could not be moved.
    ground = "colosseum",

    tier = 1,

    -- The work: its map, its fight, its scenes.
    quest = "quest_colosseum_slot_01",

    -- WHO IS AT THE END, quoted rather than derived so the board can say it before the map is generated.
    bossName = "Saber",

    -- WHAT IT OWES YOU. The named piece -- the thing this trip is for.
    piece = "weapon_ledgemans_axe",
}
