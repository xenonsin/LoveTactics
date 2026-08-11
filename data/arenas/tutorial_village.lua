-- The village lane: the board the prologue's first fight is fought on (states/prologue.lua,
-- data/tutorials/village.lua). A curated layout like data/arenas/forest_01.lua, with one
-- difference that matters -- `fixed = true`.
--
-- Every other curated arena joins a uniform random pool in Arena.pickLayout, so a forest quest may
-- roll it. This one must NEVER be rolled by an ordinary fight: the tutorial authors exact tiles
-- ("step onto 5,5") against it, and those coordinates are meaningless anywhere else. `fixed` keeps
-- it out of the pool while leaving it addressable by name (spec.layout), which is how the tutorial
-- asks for it. tests/tutorial_spec.lua guards both halves of that.
--
-- EVERY CELL BELOW IS LOAD-BEARING. The lesson is a fixed choreography (see the tutorial file), and
-- the geometry is what makes it come out right without asking the AI to cooperate:
--
--      x: 1  2  3  4  5  6  7  8
--   y=1              .  .  G  .        G -- the grunt walks on here, mid-lesson (a `spawn`)
--   y=2     .  .  .  A  .  B  .        A, B start here; C starts one row down at (7,3)
--   y=3     .  .  .  .  .  .  C
--   y=4     .  .  .  a  W  b  .        A and B are driven to a and b, two tiles off their marks
--   y=5     .  .  .  V1 .  V2 .        the two vanguards -- across the lane, not on top of anyone
--   y=6     .  #  .  x  .  r  c  #     x, r = where the avatar and Rowan close to; c = C's mark
--   y=7     .  .  .  .  .  .  .  .     open ground: the tiles they cross
--   y=8     .  .  .  @  .  R  .  .     @ = avatar, R = Rowan
--
-- NOBODY STARTS IN REACH OF ANYBODY, and nobody reaches anybody in one step. The opening exchange is
-- two kills, but each is a walk of two tiles and then a blow -- Rowan crosses to V2 and cuts it down,
-- and the player is asked to do the same to V1. That costs a beat and buys the thing a tactics game
-- most needs taught first: the board is distance, and a swing starts with getting there. A single
-- shuffle would not have said it; two tiles is a crossing, and it reads as one.
--
-- Everything else falls out of where that leaves them standing:
--
--   * V1 and V2 sit three tiles out, so the approach is two tiles and the swing is the third. Rowan
--     covers exactly two -- she wears chainmail, which costs her a point of movement -- so her walk
--     is her whole turn's worth, and the avatar's is one tile short of his.
--   * W (5,4) is the one tile adjacent to both a and b, so the Clear Out thrown from it takes them
--     together. It sits 3 steps from x, where the opening kill leaves the avatar standing.
--   * c (7,6) is adjacent to r and NOT inside a Clear Out thrown from W (it is four tiles off), so the
--     third imp is Rowan's to cut down and never steals one of the player's.
--
-- The party stands two apart rather than shoulder to shoulder for a reason of its own: it splits the
-- imps' approach down two lanes instead of bunching them, and leaves the middle tile free.
-- The biome is ART ONLY on a curated board -- Arena.BIOME_TERRAIN is consulted by generateLayout and
-- nothing else, so every cell above keeps the exact walkability, move cost and sight cost it was
-- authored with. `castle` is here because Bellmere is a WALLED MARKET TOWN and this lane is paved:
-- flagstone and cold stone rather than the forest's greens (data/tilesets/castle.lua). A `town` biome
-- would be the honest name, but tests/biome_spec.lua requires every biome to be used by a QUEST and
-- the prologue's map is inline in states/prologue.lua, so a new one would be dead weight on arrival.
--
-- The single `forest` tile at (2,3) is deliberately NOT retyped, and it still reads GREEN on the
-- flagstone. That is not the tileset leaking: ui/battle_map.lua washes BattleMap.TERRAIN_TINT over
-- any costly floor and that table is keyed by MOVE COST rather than by biome, on purpose -- the wash
-- is how a player sees at a glance that a tile charges 2 and gives cover. So a forest tile is green
-- on every board there is. Read it as the one tree in the market square, which is what a town square
-- has; retyping the cell to chase the colour would move a load-bearing cell for a purely visual reason.
return {
    biome = "castle",
    fixed = true, -- addressable by name, never randomly rolled (see Arena.pickLayout)
    tiles = {
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        { "ground", "forest",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        -- Column 7 is deliberately CLEAR all the way down: it is the third imp's run at Rowan's
        -- flank, and an obstacle in it would leave the poor thing shuffling in the open.
        { "ground", "obstacle", "ground", "ground", "ground", "ground", "ground", "obstacle" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground", "ground"   },
    },
    -- Slot 1 is the avatar, slot 2 is Rowan -- Arena.build binds these in party order, and
    -- prologue.begin puts the avatar at roster[1] with Player.recruit appending Rowan. The tutorial's
    -- authored cells assume that pairing (tests/prologue_spec.lua pins it).
    partySpawns = {
        { x = 4, y = 8 }, { x = 6, y = 8 },
        { x = 3, y = 8 }, { x = 7, y = 8 }, -- unused here; the party is two at this point
    },
    -- The first TWO spawns are the vanguards, standing across the lane rather than on top of anyone:
    -- close enough that one turn's walk-and-swing reaches them, far enough that the walk is real.
    -- Neither ever acts -- the imp's Cinder Spit is slower than an iron sword, so the party's whole
    -- line moves first, and both die on the opening exchange.
    --
    -- The other three hold the back line and are hand-driven from there (data/tutorials/village.lua's
    -- `script`, keyed by these very spawn cells). Order matters only in that each cell names a
    -- distinct imp; the composition in states/prologue.lua fields five identical ones.
    enemySpawns = {
        { x = 4, y = 5 }, { x = 6, y = 5 },
        { x = 4, y = 2 }, { x = 6, y = 2 }, { x = 7, y = 3 },
    },
}
