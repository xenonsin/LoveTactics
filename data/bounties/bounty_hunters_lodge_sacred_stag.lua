-- The Hunter's Lodge's opening posting: standing, always on the board, never spent.
--
-- A POSTING OF WORK THAT ALREADY EXISTED. `quest_hunters_lodge_slot_01` owns the map, the fight and both
-- scenes; this file owns what a board has to say about it before the player commits -- where it is, how
-- hard, who is at the end, and what that body gives up. See models/bounty.lua for why the two are
-- separate files.
--
-- WHY THIS IS THE PIECE. The bow is the piece and it is the most Monster Hunter posting on the board: a named beast in a
-- named wood, and what it owes you is the weapon you would hunt the next one with.
--
-- The work's other rewards are unchanged and still pay: the piece is a headline, not a narrowing
-- (models/bounty.lua's questFor).
--
-- STANDING, which is what an opener is for. It is the floor under the Hunter's Lodge's ladder -- a company
-- that burns every deeper posting it holds can always walk back here -- so a run of bad luck is a
-- setback rather than a lock-out. Exactly one posting per house carries the flag.
--
-- NO `requires`: it is the bottom of the ladder, and the two rungs above it are derived from the circle
-- table rather than written out (models/bounty.lua's deriveLadders). Tier 1, so the fight is exactly
-- what the blueprint was balanced as.
return {
    name = "The Sacred Stag",
    standing = true,

    sponsor = "hunters_lodge",

    -- WHERE. One house, one ground -- the season table gives each house's opener a ground of its
    -- own so that shutting one never shuts three (data/biome_windows.lua's re-cut note). This is
    -- NOT the biome the underlying quest authored for itself, and it does not need to be: the
    -- ground is a posting's own field precisely so a posting can be moved.
    ground = "swamp",

    tier = 1,

    -- The work: its map, its fight, its scenes.
    quest = "quest_hunters_lodge_slot_01",

    -- WHO IS AT THE END, quoted rather than derived so the board can say it before the map is generated.
    bossName = "The Sacred Stag",

    -- WHAT IT OWES YOU. The named piece -- the thing this trip is for.
    piece = "weapon_deadfall_bow",
}
