-- The flight to the capital, HAND-AUTHORED (models/overworld.lua's Overworld.fromLayout). The prologue
-- leg that teaches the overworld cannot be a roll: the coach says "walk to the chest ahead," and the
-- chest has to actually BE ahead -- the first place on the road, with nothing else beside the start.
--
-- IT IS A GRID OF PLACES, not a rectangle of tiles. Everything the old file said about itself was true
-- of the board it was drawn for -- a road that wandered so no leg ran straight for more than five tiles,
-- three authored chambers so a fight had somewhere to happen, a fill weathered by noise so the wood did
-- not read as one flat green -- and every one of those is a statement about TILES. A place has no width
-- to wander in and no fill around it, and a fight builds its own board (models/arena.lua,
-- docs/overworld.md), so the chambers were the last thing holding the size up. The hazards went the same
-- way: two smouldering cells stood beside the Champion's treeline so the world was already burning when
-- you reached it, they never reached the fight (an arena carries its own `hazards` now), and a place
-- cannot be half on fire.
--
-- BUT THE FLOOR IT SHRANK TO WAS TOO SMALL, and that is this file's own correction rather than a new
-- argument. Cutting the tiles cut the ROAD with them: 4x3, twelve cells, nine of them places, eight
-- steps end to end and every cell on the board holding something. That is the shape of a diagram of a
-- road, not of a place -- and it teaches the overworld against a board the overworld never deals. A
-- descent floor is 11x11 (models/descent.lua's Descent.FLOOR_COLS), about seventy-five places and a
-- crossing near twenty steps, and the prologue is where the walk is learned at the length the game keeps
-- asking for.
--
-- SO: 9x7, and only twenty-one of its sixty-three cells are somewhere to stand. THE FORTY-TWO BLOCKED
-- CELLS ARE THE CONTENT, not waste around it -- a road threading a wood is mostly wood, and a board
-- whose every cell is a place has no silhouette to read. What that buys is twenty steps from the start
-- to the Champion (against eight), with the stops two to four apart instead of shoulder to shoulder, so
-- the road has walking between its beats and the wood either side of it is visibly a wood.
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
-- THE ROAD IS A SINGLE CHAIN. Every place has exactly two walkable neighbours except the two ends, so
-- BFS distance from S rises by one at every step and the stops are met in exactly the authored order --
-- which the flight_leg and prologue specs read directly, and which tests/flight_leg_spec.lua now pins
-- neighbour by neighbour rather than trusting this paragraph. Open a second route between any two places
-- and the order stops being a fact about the file. The empty places are load-bearing for the same
-- reason: they are the chain, and one of them turned into a junction is a branch.
--
-- NO STOP IS READ BEFORE YOU ARE BESIDE IT. The reveal is adjacency (Overworld:reveal at radius 1), and
-- on a chain that means you see what the next place holds exactly one step early -- which is the same
-- relationship the old radius-2 fog had against a road that never ran straight. The one after it is
-- still dark.
return {
    biome = "forest",
    -- 9 wide x 7 tall, read as the map: S bottom-left, X top-left, the road running east along the
    -- bottom, climbing the far side of the wood and coming back west across the top to the Champion.
    map = {
        "X7#######", -- y1  the Champion, and the rest on her doorstep
        "#.6######", -- y2  the last chest
        "##..5####", -- y3  the extraction
        "####..4.#", -- y4  the survivors, on the long turn west
        "#######.#", -- y5  the climb
        "####2..3#", -- y6  the shrine, and the defence at the top of the eastern leg
        "S1...####", -- y7  the start and the teaching chest, with the road east ahead of it
    },
}
