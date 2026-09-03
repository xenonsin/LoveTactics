-- The flight to the capital, HAND-AUTHORED (models/overworld.lua's Overworld.fromLayout). The prologue
-- leg that teaches the overworld cannot be a roll: the coach says "walk to the chest ahead," and the
-- chest has to actually BE ahead -- the first place on the road, with nothing else beside the start.
--
-- IT IS A GRID OF PLACES NOW, and it went from 27x43 tiles to 4x3 cells. Everything that file said about
-- itself was true of the board it was drawn for -- a road that wandered so no leg ran straight for more
-- than five tiles, three authored chambers so a fight had somewhere to happen, a fill weathered by noise
-- so the wood did not read as one flat green -- and every one of those is a statement about TILES. A
-- place has no width to wander in and no fill around it, and a fight builds its own board
-- (models/arena.lua, docs/overworld.md), so the chambers were the last thing holding the size up.
--
-- WHAT SURVIVES IS THE ONLY THING THE PROLOGUE ACTUALLY NEEDED: one road, no branches, no loops, the
-- stops in authored order, and the road running NORTH -- S at the bottom, X at the top, because a walk
-- toward the top of the screen is the one the map is drawn for.
--
-- Legend (see Overworld.fromLayout):
--   #  a cell that is not there    .  a place        S  the start     X  the objective (the Champion)
--   1..7  a stop: the Nth hosts the Nth entry of the quest's `encounters.always`
--         (states/prologue.lua's FLIGHT_QUEST) -- so THIS file fixes WHERE each stop sits and the quest
--         stays the single source of WHAT it is (id / loot / conversation).
--
--   1 chest (bow kit)   2 shrine event   3 DEFEND   4 survivor event   5 EXTRACT   6 chest   7 rest
--   Each stop past the chest also teaches a class via one ability (states/prologue.lua's FLIGHT_QUEST):
--   2 priest (Heal)  3 knight (Shout)  4 alchemist (Assayer's Eye)  5 rogue (Drain Mana)  6 mage (Fire
--   Bolt)  7 fighter (Power Strike)
--
-- EVERY CELL IS LOAD-BEARING. The road is a single chain: each place has exactly two neighbours except
-- the two ends, so BFS distance from S rises by one at every step and the stops are met in exactly the
-- authored order -- which the flight_leg and prologue specs read directly. Open a second route between
-- any two of these and the order stops being a fact about the file.
--
-- NO STOP IS READ BEFORE YOU ARE BESIDE IT. The reveal is adjacency (Overworld:reveal at radius 1), and
-- on a chain that means you see what the next place holds exactly one step early -- which is the same
-- relationship the old radius-2 fog had against a road that never ran straight. The one after it is
-- still dark.
--
-- The hazards went with the tiles. Two smouldering cells stood beside the Champion's treeline so the
-- world was already burning when you reached it; they never reached the fight (an arena carries its own
-- `hazards` now), and a place cannot be half on fire.
return {
    biome = "forest",
    -- 4 wide x 3 tall, read as the map: S bottom-left, X top-left, the road climbing between them the
    -- long way round. Eight steps from the start to the Champion, which is about what a descent floor's
    -- crossing costs -- the prologue teaches the walk at the length the game keeps asking for.
    map = {
        "X765", --  the Champion, then the rest, the last chest and the extraction behind her
        "###4", --  the survivors, on the turn
        "S123", --  the start, the teaching chest, the shrine and the defence
    },
}
