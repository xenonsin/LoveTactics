-- FLOOR ONE, FAKED (2026-10-16). Act 0 no longer walks the capital's streets: the company is on floor one
-- of the rift -- Gluttony's wood -- and this is a HAND-BUILT floor MODELLED LIKE A REAL ONE. The order of the
-- stops is still fixed, because the lessons lean on each other (the bow before Mark Target, the rest before
-- the Champion); what changed is that the floor HIDES it. Everything below the next rule describes the
-- city-sweep map this file used to hold and is kept as the record of why it was shaped the way it was.
--
--   * A REAL FLOOR'S SIZE: 16x11 (Descent.floorDims(1)), 112 places, 12 dead ends.
--   * THREE PARTS JOINED BY TWO CHOKEPOINTS (`a`, `b`). Inside a part the company wanders freely; the parts
--     come in order because the only way on is through the one cell between them. A real floor blocks its
--     routes the same way (docs/overworld.md, "The fights that block the way").
--   * THE TWO RESCUE FIGHTS ARE NOT ON THE MAP. They find the company as it walks, off a step count, the way
--     ordinary fighting is dealt underground (states/prologue.lua's FLIGHT_QUEST `prowl`, states/game.lua).
--     A chokepoint letter is where a fight that is still owed finds you if the steps have not -- so the
--     Shout and the fire coat are always in hand before the part that needs them.
--   * EVERY STOP BUT TWO IS IN A DEAD END, found by exploring: the shrine, the wounded delver and the last
--     chest. The bow chest sits beside the door (the coach says "walk to the chest ahead"), and the rest is
--     on the Champion's doorstep, which is the only way to the stair.
--   * THE CHAMPION STANDS ON THE STAIR DOWN (X), and the way out is the door (S): the company walks back up
--     the floor it crossed, as it would from any floor one.
--
--   1 chest (bow kit)   2 shrine   3 the wounded delver   4 chest (Renewal)   5 rest   X the Champion
--   a / b  chokepoints, in walking order
--
-- THE STOPS WERE SPREAD OUT (2026-10-23, by the author, on a screenshot): the bow chest moved a walk in from
-- the door, the shrine out east, the last chest to the far end of part two, the rest to a spur of its own
-- and the Champion to the far end of part three -- so a part is crossed before its stops are, rather than
-- every stop sitting near where the part is entered. The two notes above about the bow chest "beside the
-- door" and the rest "on the Champion's doorstep" describe the layout before this.
--
-- =====================================================================================================
-- THE CITY-SWEEP MAP'S OWN RECORD (superseded):
--
-- (Was: the city sweep, HAND-AUTHORED (models/overworld.lua's Overworld.fromLayout). The prologue leg that
-- teaches the overworld cannot be a roll: the coach says "walk to the chest ahead," and the chest has
-- to actually BE ahead -- the first place on the route, with nothing else beside the start.
--
-- IT IS A BREACHED CITY, NOT A ROAD. This file was authored as the flight to the capital -- a forest,
-- a king's road, a wood either side of it -- and the premise moved inside the walls: Act 0 happens in
-- the capital itself and this leg is its streets, block by block (states/prologue.lua's FLIGHT_QUEST).
-- `biome = "castle"` is the whole re-skin; every argument below about SHAPE survives it unchanged,
-- because a route threading a city is mostly buildings for the same reason a road threading a wood is
-- mostly wood. The filename and the ids still say "flight".
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
-- CELLS ARE THE CONTENT, not waste around it -- a route threading a city is mostly city, and a board
-- whose every cell is a place has no silhouette to read. What that buys is twenty steps from the start
-- to the Champion (against eight), with the stops two to four apart instead of shoulder to shoulder, so
-- the route has walking between its beats and the blocks either side of it are visibly blocks.
--
-- Legend (see Overworld.fromLayout):
--   #  a cell that is not there    .  a place        S  the start     X  the objective (the Champion)
--   1..7  a stop: the Nth hosts the Nth entry of the quest's `encounters.always`
--         (states/prologue.lua's FLIGHT_QUEST) -- so THIS file fixes WHERE each stop sits and the quest
--         stays the single source of WHAT it is (id / loot / conversation).
--
--   1 chest (bow kit)   2 shrine event   3 DEFEND   4 survivor event   5 EXTRACT   6 chest   7 rest
--   Each stop also teaches ONE ITEM MECHANIC through what it hands over (states/prologue.lua's
--   FLIGHT_QUEST, whose `always` list carries the whole argument):
--     1 range band      2 adjacency AURA (censer)     3 forced targeting (the Shout)
--     4 adjacency GATE (mark)   5 typed mitigation (fire coat)   6 a status you want (Renewal)
--     7 nothing -- a rest, so the champion is fought fresh
--   It used to be one CLASS per stop, which is a name rather than a rule, and a name is not a thing
--   this route gives anybody a use for.
--
-- THE ROUTE IS A SINGLE CHAIN. Every place has exactly two walkable neighbours except the two ends, so
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
    -- 16 x 11, read as the map: the door bottom-left, the stair top-middle. Part one is the bottom three
    -- rows, part two the middle three, part three the top three; `a` and `b` are the only ways between.
    map = {
        "#..#...##.5#....", -- y1  the rest, down its own spur
        "..#...#...#..#X.", -- y2  the Champion on the stair, at the far end of part three
        "....#...#.....#.", -- y3
        "#b##############", -- y4  the second chokepoint
        "..#3#...#..#..#4", -- y5  the wounded delver down a spur, the last chest at the far end
        ".#...##.#.....#.", -- y6
        "...#........#...", -- y7
        "########a#######", -- y8  the first chokepoint
        "...#.#.#...#..2.", -- y9  the shrine, out east
        ".#.....1..#..#..", -- y10  the bow chest, a walk in from the door
        "S...#...#...#...", -- y11  the door
    },
}
