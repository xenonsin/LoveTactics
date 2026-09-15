-- The Undercroft's opening posting: standing, always on the board, never spent.
--
-- A POSTING OF WORK THAT ALREADY EXISTED. `quest_undercroft_slot_01` owns the map, the fight and both
-- scenes; this file owns what a board has to say about it before the player commits -- where it is, how
-- hard, who is at the end, and what that body gives up. See models/bounty.lua for why the two are
-- separate files.
--
-- WHY THIS IS THE PIECE. The coat is the only thing this work pays, so the choice makes itself -- and it is the right one
-- anyway: greed's opener handing over a cutpurse's coat is the house stating its own terms.
--
-- The work's other rewards are unchanged and still pay: the piece is a headline, not a narrowing
-- (models/bounty.lua's questFor).
--
-- STANDING, which is what an opener is for. It is the floor under the Undercroft's ladder -- a company
-- that burns every deeper posting it holds can always walk back here -- so a run of bad luck is a
-- setback rather than a lock-out. Exactly one posting per house carries the flag.
--
-- NO `requires`: it is the bottom of the ladder, and the two rungs above it are derived from the circle
-- table rather than written out (models/bounty.lua's deriveLadders). Tier 1, so the fight is exactly
-- what the blueprint was balanced as.
return {
    name = "The Vault Beneath",
    standing = true,

    sponsor = "undercroft",

    -- WHERE. One house, one ground -- the season table gives each house's opener a ground of its
    -- own so that shutting one never shuts three (data/biome_windows.lua's re-cut note). This is
    -- NOT the biome the underlying quest authored for itself, and it does not need to be: the
    -- ground is a posting's own field precisely so a posting can be moved.
    ground = "underworld",

    tier = 1,

    -- The work: its map, its fight, its scenes.
    quest = "quest_undercroft_slot_01",

    -- WHAT IT OWES YOU. The named piece -- the thing this trip is for.
    piece = "armor_cutpurse_coat",
}
