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
-- THE ROAD RUNS NORTH -- S at the bottom of the map, X at the top -- AND EVERY CHAMBER IS THEREFORE
-- ENTERED FROM THE SOUTH. That is load-bearing twice over, and the second reason is why this file was
-- flipped end for end after it was first written.
--
-- The first reason is the objective regions. Arena.fromGrid gives the party the edge it walked in from,
-- and the REGIONS both fights are pointed at are read off rows (models/arena.lua's OBJECTIVE_REGIONS):
-- `rally` is two rows ahead of the party's own line, `far` is the row across the board from it. Walk
-- into a chamber from the side and those resolve to a row the party is standing along rather than to the
-- ground in front of them. Entering each one from a short edge keeps the fight pointed the way the
-- player is already facing.
--
-- The second is which side of the SCREEN the company opens on, and only one of the two answers is right
-- for the leg that teaches the game. The party takes the edge it arrived by, so a trail that ran south
-- stood the company along the TOP of the picture with the enemy below it -- the mirror of the read every
-- body-hung readout is authored for (the HP bar under each body, the badge row above it, the turn-order
-- number). states/battle.lua's faceParty can turn the picture back for a player who asks for it
-- (Settings' "party_at_bottom"), but a tutorial cannot lean on a setting: the one leg where the player
-- has never seen a board before is the one leg that must open in the arrangement everything is drawn
-- for. Walking north spends nothing to get it -- the deploy band is simply the bottom of the screen,
-- with the demons across from it, on the first fight and every fight after.
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
--   transcribed here ROW FOR ROW -- no flip. That arena seats the party on its bottom row, and coming up
--   into the chamber from the south seats them on the bottom row too, so the two files now read as the
--   same picture and chamber row j IS arena row j. (They did not, while the trail ran south: the copy
--   here was upside down against its source, which is exactly the kind of transcription that drifts.)
--   That arena is no longer what the flight fights on -- a windowed board wins over `spec.layout`
--   outright -- so it survives as the fallback for a caller with no map under it, and
--   tests/flight_board_spec.lua pins the two to each other rather than trusting that they were copied
--   carefully. Every lever answers a stage of the fight (see data/characters/
--   character_demon_champion.lua): the neck is the only passage, so the slow Champion must squeeze it
--   and can be shoved into the rock beside it for doubled impact; the mountains are the bow perches
--   that overlook the lane; the treelines are what Fire Bolt lights and what the Bomblets creep up
--   behind; and the pool is the melee tile a Jolt rewards -- which, with the neck, is also the firebreak
--   that keeps the burning treeline off the party's side.
--
-- Everything the first version got right is kept. The road is still ONE path from S to X -- no branches,
-- no dead-end spurs, no loops -- so the only thing to do is follow it, and BFS distance from the start
-- still rises monotonically along it, which is how the stops are met in exactly the authored order (the
-- flight_leg / flight_board / prologue specs lean on this).
--
-- THE ROAD BETWEEN THE CHAMBERS WANDERS, and that is the one thing this file used to get wrong. It was
-- ten dead-straight runs joined at right angles -- east eleven, north two, west eight, north two -- laid
-- on a metronome of three rows a leg. Every one of those was defensible on its own and the sum of them
-- was a floor plan: a ruler-straight line through a fill of a single colour, turning only in square
-- corners, which is the fault docs/overworld.md names when it says a frame of even thickness with four
-- right angles in it says ARCHITECTURE, and six of the seven grounds mean the opposite. So the trail now
-- bends the way a trail bends -- around a standing tree at (10,40), south again past the shrine, over a
-- shoulder at (15,26) -- and no leg of it runs more than five tiles before it turns.
--
-- The metronome is gone with the straight lines, so the rule the metronome existed to serve is stated
-- directly instead: NO STOP IS LIT BEFORE YOU ARE TWO STEPS FROM IT. The radius-2 vision is measured
-- against every tile of the road, not against a row spacing that only implied it -- which the wandering
-- road could not have honoured anyway, since it doubles back within its own band. A chamber still opens
-- up as you walk into it and not a beat before.
--
-- WHAT THE FILL IS MADE OF IS NO LONGER THIS FILE'S BUSINESS. Every solid tile outside the chambers is
-- typed `#` and Overworld.fromLayout weathers them through Overworld:decorate -- the same noise pass
-- every rolled board gets -- so the wood carries scrub and standing rock in drifts rather than being one
-- flat green. Typing a variant here would only fight it, and the pass touches nothing else: a chamber
-- names all sixty-four of its tiles outright, so none of them is thicket and none of them can be moved
-- by it.
--
-- EVERY CELL IS LOAD-BEARING -- nudging a glyph re-times the tutorial, and nudging one inside a chamber
-- redraws a battlefield. Two more that are easy to nudge and expensive to get back: the row BELOW each
-- chamber holds exactly one walkable tile, and the row ABOVE it exactly one, because a second is a
-- second door -- it would let the party into the room without meeting what stands in the doorway, and
-- it would close a loop through the chamber that the route order is measured on.
return {
    biome = "forest",
    tileSize = 32,
    -- The opening state of a board, in MAP coordinates (models/overworld.lua stamps these onto the
    -- cells; Arena.fromGrid carries whichever fall inside the locked window into the fight). The world
    -- is already burning when you reach the Champion: a smouldering patch on its own side of the
    -- treeline. The pool and the neck between it and the party are what keep it there.
    hazards = {
        { id = "hazard_fire", x = 10, y = 3 },
        { id = "hazard_fire", x = 13, y = 3 },
    },
    -- 27 wide x 43 tall. Read it as the map: S bottom-left, X at the top, the road climbing between
    -- three chambers. The right-hand notes give each chamber's rows in ITS OWN coordinates (w1..w8, top
    -- to bottom), which are the rows of the battlefield that chamber becomes -- so w8 is always the
    -- party's own line, the same row a board has seated a company on since before there was a map.
    map = {
        "###########################", --  1
        "#######........############", --  2  THE NECK      w1  the Champion's back line
        "#######..f..f..############", --  3                w2  the smouldering treeline (see `hazards`)
        "#######........############", --  4                w3  the approach
        "#######^^^..^^^############", --  5                w4  THE NECK: the only passage, gap at w4-5
        "#######..f..f..############", --  6                w5  burnable shoulders
        "#######.f.ww.f.############", --  7                w6  the pool, and the firebreak it makes
        "#######..m..m..############", --  8                w7  the bow perches
        "#######...X....############", --  9                w8  the party's own line (and the deploy band)
        "##########.################", -- 10  the one way in
        "##########.#7..############", -- 11  the rest on the doorstep
        "##########...#.6.##########", -- 12  and the last chest, off the bank
        "################..#########", -- 13
        "#################.#########", -- 14  the one way out
        "################........###", -- 15  THE FORD      w1  the far row: what the driver is walking for
        "################........###", -- 16                w2
        "################..f..f..###", -- 17                w3
        "################........###", -- 18                w4
        "################^wwwwww^###", -- 19                w5  the crossing, closed at both ends
        "################........###", -- 20                w6
        "################.f....f.###", -- 21                w7
        "################...5....###", -- 22                w8  the party's own line
        "###################.#######", -- 23  up out of the water
        "###################.#######", -- 24
        "#########...4.###...#######", -- 25  west past the apothecary
        "########..###.....#########", -- 26  over a shoulder of rock
        "########.##################", -- 27  the one way out
        "##........#################", -- 28  THE STEADING  w1  the demons open here; the road leaves by it
        "##..f..f..#################", -- 29                w2
        "##.^^..^^.#################", -- 30                w3  THE WALL: two gaps, both flanks open
        "##.f....f.#################", -- 31                w4  scrub at the shoulders
        "##........#################", -- 32                w5  the survivors rally here
        "##........#################", -- 33                w6
        "##........#################", -- 34                w7
        "##...3....#################", -- 35                w8  the party's own line (and the deploy band)
        "#####.#####################", -- 36  the one way up into the yard
        "#####.##.2...##############", -- 37  the roadside shrine, on the bend
        "#####....###.##############", -- 38
        "###########..##############", -- 39  it goes round, and the road climbs back over it
        "####...1.#..###############", -- 40  the teaching chest -- nothing else in reach -- then a tree
        "##S..###...################", -- 41  the start; the trail climbs off the row almost at once
        "###########################", -- 42
        "###########################", -- 43
    },
}
