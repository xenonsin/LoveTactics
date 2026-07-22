-- The flight to the capital, HAND-AUTHORED (models/overworld.lua's Overworld.fromLayout). The prologue
-- leg that teaches the overworld cannot be a roll: the coach says "walk to the chest ahead," and the
-- chest has to actually BE ahead -- the first thing on the trail, with nothing else crowding the start.
-- A procedural maze placed the route by distance from the centre, which put the chest nearest but left
-- other markers a step away and reshaped the walk every run. This trail is fixed instead.
--
-- The road is ONE simple path from S to X -- no branches, no dead-end spurs, no loops -- so the only
-- thing to do is follow it, and because it never forks, BFS distance from the start rises monotonically
-- along it: the stops are met in exactly the authored order (the flight_leg / prologue specs lean on
-- this). Legend (see Overworld.fromLayout):
--   #  forest (wall)      .  trail        S  the player start        X  the objective (the Champion)
--   1..7  a route stop: the Nth hosts the Nth entry of the quest's `encounters.always`
--         (states/prologue.lua's FLIGHT_QUEST) -- so THIS file fixes WHERE each stop sits and the quest
--         stays the single source of WHAT it is (id / loot / conversation).
--
--   1 chest (bow kit)   2 shrine event   3 defend   4 survivor event   5 extract   6 chest   7 rest
--   Each stop past the chest also teaches a class via one ability (states/prologue.lua's FLIGHT_QUEST):
--   2 priest (Heal)  3 knight (Shout)  4 alchemist (Disarm)  5 rogue (Pickpocket)  6 mage (Fire Bolt)  7 fighter (Power Strike)
--
-- Shape: five roughly-horizontal legs strung top-to-bottom, but deliberately NOT a rigid boustrophedon.
-- The switchbacks turn on STAGGERED columns (not one fixed edge) and descend as short diagonal
-- STAIRCASES rather than hard right angles, and a leg drifts off its row, so the road reads as a trail
-- winding through the forest instead of a machine-cut zigzag. Two rules keep it honest and are asserted
-- by the specs above: every interior tile has exactly two trail neighbours (only S and X are dead-ends,
-- so the path never forks), and consecutive legs sit at least three rows apart -- far enough that the
-- 2-tile vision never lifts the fog off the next leg early, so the road ahead stays a mystery.
-- EVERY CELL IS LOAD-BEARING: the stops sit where the walk reaches them in order (1..7), so nudging a
-- glyph re-times the tutorial.
return {
    biome = "forest",
    tileSize = 32,
    -- 25 wide x 21 tall. Read it as the map: S top-left, X bottom-right, the road snaking between.
    map = {
        "#########################", --  1
        "#########################", --  2
        "##S.....1......##########", --  3  Leg A ->  (start, then the chest); drifts down at col 15
        "##############.........##", --  4     the drift settles onto a lower row
        "######################.##", --  5  \  staircase turn (down the right, stepping left)
        "####################...##", --  6  /
        "####...3........2....####", --  7  Leg B <-  (shrine at 2, then defend at 3)
        "####.####################", --  8  \
        "####..###################", --  9   } staircase turn (down the left, stepping right)
        "#####..##################", -- 10  /
        "######....4.......5....##", -- 11  Leg C ->  (survivor event at 4, extract at 5)
        "######################.##", -- 12  \
        "#####################..##", -- 13   } staircase turn (down the right, stepping left)
        "####################..###", -- 14  /
        "####........6........####", -- 15  Leg D <-  (the plain chest)
        "####.####################", -- 16  \
        "####..###################", -- 17   } staircase turn (down the left, stepping right)
        "#####..##################", -- 18  /
        "######....7.........X####", -- 19  Leg E ->  (the rest, then the Champion)
        "#########################", -- 20
        "#########################", -- 21
    },
}
