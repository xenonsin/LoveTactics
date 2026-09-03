-- ANIMATION GALLERY -- a development board, not a fight. Every clip the board can play, running at
-- once so the animation can be looked at rather than remembered (ui/combat_fx.lua). Reached from the
-- menu's debug column ("Animation Gallery"); `fixed` keeps it out of the random pool, so no ordinary
-- castle fight can ever roll it. Sibling of data/arenas/field_gallery.lua, same idea one layer up: that
-- one puts every FIELD look on one board, this one puts every BODY motion on one board.
--
-- The board's characters are not rigged. There is no skeleton and no authored art -- the six clips the
-- commission brief names (idle, move, attack, hit, cast, death) are transform curves over a flat token,
-- because a unit drawn at ~56px on a 64px tile cannot show skeletal deformation anyway. Which means the
-- clips are CODE, and the only way to judge code that is only ever seen for a fifth of a second in the
-- middle of a fight is to stand it still and put it in a row.
--
-- What it is arranged to prove, in the order you read it down the board:
--
--   y3  THE SEVEN DRIVEN CLIPS, one body each, each looping its own on its own period. Left to right:
--
--         x2 walk      a step in from the west: two footfalls per tile, a lean into the travel
--         x3 attack    gather BACKWARD, strike, hold one beat at extension, drift home
--         x4 hit       a scratch -- barely rocks the body, and that is the point
--         x5 hit       a heavy blow -- the same clip, saying how bad it was
--         x6 cast      aimed: the gather, the thrust toward the target, the glow
--         x7 cast      on itself: no aim, so the hop instead of the thrust
--         x8 death     the collapse. Non-destructive -- the model is never touched, so the body is
--                      standing again a moment later and falls over once more.
--
--       They are given DIFFERENT periods on purpose. A rank that all fired together would be its own
--       kind of lockstep, and what is being judged is eight things that each read as a body.
--
--   y6  IDLE, four bodies, doing nothing else. The clip that answers to no cue and that every other
--       one is layered over. Two things to look for, and neither of them is "does it move":
--         * the breath has to be VISIBLE at this size. It was first authored at half its current
--           amplitude, which at a 64px tile is one pixel, and one pixel is not a breath.
--         * the four must be OUT OF PHASE with each other. Sharing a phase is the single tell that
--           gives a procedural idle away -- a rank of guards breathing in unison reads as one
--           animation played four times, which is exactly what it is and exactly what must not show.
--
-- The enemy rank is three rows clear of the party and is driven by nobody -- states/menu.lua sets
-- `control = "none"` on every one of them, so each hands its turn straight on and none of them
-- projects threat. The gallery therefore holds still while it is looked at instead of dissolving into
-- a fight on turn two, and the board stays clean instead of washing red under seven foes' reach.
-- Every tile is plain ground for the same reason field_gallery's are: terrain washes and costly-tile
-- tints would sit under the bodies and muddy exactly what is being judged.

return {
    biome = "castle",
    fixed = true, -- addressable by name only; never rolled by an ordinary castle fight
    -- x: 1        2         3         4         5         6         7         8
    tiles = {
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y1
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y2
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y3 the seven clips
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y4
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y5
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y6 idle
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y7
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y8
    },
    -- The idle rank, centred and evenly spaced. Four identical bodies side by side is the whole test:
    -- anything they do not do together is the per-unit phase working.
    partySpawns = {
        { x = 3, y = 6 }, { x = 4, y = 6 }, { x = 5, y = 6 }, { x = 6, y = 6 },
    },
    -- The seven driven clips, in the order the header reads them. `walk` sits at x2 rather than x1 so
    -- it has a tile to the west to step in from -- the slide is purely visual and would work off the
    -- board's edge, but a step you can see the whole of is the point.
    enemySpawns = {
        { x = 2, y = 3 }, { x = 3, y = 3 }, { x = 4, y = 3 }, { x = 5, y = 3 },
        { x = 6, y = 3 }, { x = 7, y = 3 }, { x = 8, y = 3 },
    },
}
