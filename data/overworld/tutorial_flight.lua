-- The flight to the capital, HAND-AUTHORED (models/overworld.lua's Overworld.fromLayout). The prologue
-- leg that teaches the overworld cannot be a roll: the coach says "walk to the chest ahead," and the
-- chest has to actually BE ahead -- the first thing on the trail, with nothing else crowding the start.
-- A procedural maze placed the route by distance from the centre, which put the chest nearest but left
-- other markers a step away and reshaped the walk every run. This trail is fixed instead.
--
-- THE BOARD IS THE MAP, AND THAT IS WHAT REWROTE THIS FILE. A fight is no longer given a rolled arena:
-- it is fought on the 8x8 window of these very tiles that the lock closes around the tile it was met on
-- (models/arena.lua's Arena.fromGrid, docs/overworld.md). The first version of this trail was written
-- before that was true, and it was one tile wide from S to X -- which was correct then and unplayable
-- after. Measured against Overworld.BOX_OK (32 walkable of 64, the floor below which the generator
-- refuses to seat a fight at all), every stop on it scored 17-26, and NOT ONE TILE of the whole map was
-- open ground in the Overworld:isOpen sense (a 3x3 with nothing solid in it). What that produced on
-- screen: the defend stop stood four bodies, two survivors and the demons in a single-file queue on one
-- row of trail, the deploy band offered two tiles to place a company on, waves authored to walk in from
-- the flank and to surround had no flank and no sides to surround from, and Arena.enemyCap -- which
-- converts standing room into a ceiling -- cut the Champion's own three-body cast down to two.
--
-- So the rule this map is now built on: A STOP THAT OPENS A BOARD STANDS IN A ROOM, AND THE ROOM IS THE
-- BOARD. Each of the three fights sits in an authored 8x8 chamber walled on every side, laid out so that
-- of every window containing the stop's tile the chamber is the richest -- which is the window
-- Overworld:bestBox will therefore choose. What is drawn between these lines IS the battlefield, tile
-- for tile; there is no second board to keep in step with it.
--
-- The corridor stops keep their corridor. A chest, a shrine, an apothecary and a rest open no board, so
-- room would say nothing there except that the clearings are not special.
--
-- Legend (see Overworld.fromLayout):
--   #  thicket (wall)    .  trail        S  the player start     X  the objective (the Champion)
--   ^  rock (wall)       f  forest -- walkable, slow, soft cover, and it BURNS (the Fire Bolt target)
--   m  mountain -- walkable high ground: +1 range to whoever holds it, and it screens the view behind
--   w  water -- a wadeable ford: slow underfoot and it carries a charge (the Jolt payoff)
--   1..7  a route stop: the Nth hosts the Nth entry of the quest's `encounters.always`
--         (states/prologue.lua's FLIGHT_QUEST) -- so THIS file fixes WHERE each stop sits and the quest
--         stays the single source of WHAT it is (id / loot / conversation).
--
--   1 chest (bow kit)   2 shrine event   3 DEFEND   4 survivor event   5 EXTRACT   6 chest   7 rest
--   Each stop past the chest also teaches a class via one ability (states/prologue.lua's FLIGHT_QUEST):
--   2 priest (Heal)  3 knight (Shout)  4 alchemist (Assayer's Eye)  5 rogue (Drain Mana)  6 mage (Fire Bolt)  7 fighter (Power Strike)
--
-- EVERY CHAMBER IS ENTERED FROM THE NORTH, and that is load-bearing rather than tidy. Arena.fromGrid
-- gives the party the edge it walked in from, and the objective REGIONS that both fights are pointed at
-- are read off rows (models/arena.lua's OBJECTIVE_REGIONS): `rally` is two rows ahead of the party's
-- own line, `far` is the row across the board from it. Walk into a chamber from the side and those
-- resolve to a row the party is standing along rather than to the ground in front of them. Descending
-- into each one keeps the fight pointed the way the player is already facing.
--
-- The three chambers, each answering the fight it holds:
--
--   THE STEADING (stop 3, encounter_survivors_defend). A burnt yard with the stub of its wall still
--   standing across the middle: solid at the shoulders, open at the two gaps and open again round both
--   flanks. The survivors rally on the row in front of the party (the `rally` anchor), the demons open
--   on the far side of the wall, and the lesson is to step forward into the gaps and hold them rather
--   than to turtle on the back row. The flanks stay open ON PURPOSE -- the stop's late waves arrive
--   `from = "flank"` and `from = "surround"`, so the wall has to be something the encirclement can get
--   around, or the fight it teaches is a corridor again.
--
--   THE FORD (stop 5, encounter_survivors_extract). A lane running the full depth of the chamber with a
--   shallow crossing cut across its waist, boulders closing both ends of the crossing. The driver walks
--   for the far row on its own; the ford is where it is slowest and most exposed, and clearing the road
--   ahead of it before it wades in is the whole of the lesson. Nothing here is a hard block: an escort
--   that walks itself into a wall is a softlock, not a difficulty.
--
--   THE NECK (the objective, the Demon Champion). This is data/arenas/demon_champion.lua's board,
--   transcribed here and flipped so the party stands at the top, because entering from the north is
--   what puts them there. That arena is no longer what the flight fights on -- a windowed board wins
--   over `spec.layout` outright -- so it survives as the fallback for a caller with no map under it,
--   and tests/flight_board_spec.lua pins the two to each other rather than trusting that they were
--   copied carefully. Every lever answers a stage of the fight (see data/characters/
--   character_demon_champion.lua): the neck is the only passage, so the slow Champion must squeeze it
--   and can be shoved into the rock beside it for doubled impact; the mountains are the bow perches
--   that overlook the lane; the treelines are what Fire Bolt lights and what the Bomblets creep up
--   behind; and the pool is the melee tile a Jolt rewards -- which, with the neck, is also the firebreak
--   that keeps the burning treeline off the party's side.
--
-- Everything the first version got right is kept. The road is still ONE path from S to X -- no branches,
-- no dead-end spurs, no loops -- so the only thing to do is follow it, and BFS distance from the start
-- still rises monotonically along it, which is how the stops are met in exactly the authored order (the
-- flight_leg / flight_board / prologue specs lean on this). Consecutive legs still sit at least three
-- rows apart, so the radius-2 vision never lifts the fog off the next one early: a chamber opens up as
-- you walk into it and not a beat before. EVERY CELL IS LOAD-BEARING -- nudging a glyph re-times the
-- tutorial, and nudging one inside a chamber redraws a battlefield.
return {
    biome = "forest",
    tileSize = 32,
    -- The opening state of a board, in MAP coordinates (models/overworld.lua stamps these onto the
    -- cells; Arena.fromGrid carries whichever fall inside the locked window into the fight). The world
    -- is already burning when you reach the Champion: a smouldering patch on its own side of the
    -- treeline. The pool and the neck between it and the party are what keep it there.
    hazards = {
        { id = "hazard_fire", x = 10, y = 41 },
        { id = "hazard_fire", x = 13, y = 41 },
    },
    -- 27 wide x 43 tall. Read it as the map: S top-left, X at the bottom, the road descending between
    -- three chambers. The right-hand notes give each chamber's rows in ITS OWN coordinates (w1..w8),
    -- which are the rows of the battlefield that chamber becomes.
    map = {
        "###########################", --  1
        "###########################", --  2
        "##S....1.....##############", --  3  the start, then the teaching chest -- nothing else in reach
        "############.##############", --  4
        "############.##############", --  5
        "#####....2...##############", --  6  west to the roadside shrine
        "#####.#####################", --  7
        "#####.#####################", --  8
        "##...3....#################", --  9  THE STEADING  w1  the party's own line (and the deploy band)
        "##........#################", -- 10                w2
        "##........#################", -- 11                w3
        "##........#################", -- 12                w4  the survivors rally here
        "##.f....f.#################", -- 13                w5  scrub at the shoulders
        "##.^^..^^.#################", -- 14                w6  THE WALL: two gaps, both flanks open
        "##..f..f..#################", -- 15                w7
        "##........#################", -- 16                w8  the demons open here; the road leaves by it
        "########.##################", -- 17
        "########.##################", -- 18
        "########....4.......#######", -- 19  east past the apothecary
        "###################.#######", -- 20
        "###################.#######", -- 21
        "################...5....###", -- 22  THE FORD      w1  the party's own line
        "################.f....f.###", -- 23                w2
        "################........###", -- 24                w3
        "################^wwwwww^###", -- 25                w4  the crossing, closed at both ends
        "################........###", -- 26                w5
        "################..f..f..###", -- 27                w6
        "################........###", -- 28                w7
        "################........###", -- 29                w8  the far row: what the driver is walking for
        "#################.#########", -- 30
        "#################.#########", -- 31
        "##########.7...6..#########", -- 32  west past the last chest to the rest on the doorstep
        "##########.################", -- 33
        "##########.################", -- 34
        "#######...X....############", -- 35  THE NECK      w1  the party's own line
        "#######..m..m..############", -- 36                w2  the bow perches
        "#######.f.ww.f.############", -- 37                w3  the pool, and the firebreak it makes
        "#######..f..f..############", -- 38                w4  burnable shoulders
        "#######^^^..^^^############", -- 39                w5  THE NECK: the only passage, gap at w4-5
        "#######........############", -- 40                w6  the approach
        "#######..f..f..############", -- 41                w7  the smouldering treeline (see `hazards`)
        "#######........############", -- 42                w8  the Champion's back line
        "###########################", -- 43
    },
}
