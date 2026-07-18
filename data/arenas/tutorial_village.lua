-- The village lane: the board the prologue's first fight is fought on (states/prologue.lua,
-- data/tutorials/village.lua). A curated layout like data/arenas/forest_01.lua, with one
-- difference that matters -- `fixed = true`.
--
-- Every other curated arena joins a uniform random pool in Arena.pickLayout, so a forest quest may
-- roll it. This one must NEVER be rolled by an ordinary fight: the tutorial authors exact tiles
-- ("step onto 4,5") against it, and those coordinates are meaningless anywhere else. `fixed` keeps
-- it out of the pool while leaving it addressable by name (spec.layout), which is how the tutorial
-- asks for it. tests/tutorial_spec.lua guards both halves of that.
--
-- Shaped for the lesson rather than for tactics: one clear central lane from the party's line to the
-- demons', flanked by a pair of obstacles. So when the bubble says "step onto the lit tile", the
-- tiles the player CAN'T take read as terrain in the way -- not as an arbitrary rule.
return {
    biome = "forest",
    fixed = true, -- addressable by name, never randomly rolled (see Arena.pickLayout)
    tiles = {
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
        { "ground", "forest",   "ground", "ground", "ground", "ground", "forest",   "ground" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
        { "ground", "obstacle", "ground", "ground", "ground", "ground", "obstacle", "ground" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
        { "ground", "ground",   "ground", "ground", "ground", "ground", "ground",   "ground" },
    },
    -- Slot 1 is the avatar, slot 2 is Rowan -- Arena.build binds these in party order, and
    -- prologue.begin puts the avatar at party[1] with Player.recruit appending Rowan. The tutorial's
    -- authored cells assume that pairing (tests/prologue_spec.lua pins it).
    partySpawns = {
        { x = 4, y = 7 }, { x = 5, y = 7 },
        { x = 3, y = 8 }, { x = 6, y = 8 }, -- unused here; the party is two at this point
    },
    -- The first spawn is a VANGUARD, deliberately close: the avatar's two-tile advance to (4,5) puts
    -- it face to face with this one, so move -> ready -> strike is a single continuous lesson on the
    -- opening turn instead of three turns with a wait in the middle. It cannot pre-empt that: the
    -- party's initiative puts both the avatar and Rowan ahead of any grunt, so it is still standing
    -- here when the player's first turn begins.
    --
    -- The rest hold the back line, five rows off and out of reach (movement 3, reach 1), so the
    -- lesson is taught against one demon rather than a scrum.
    enemySpawns = {
        { x = 4, y = 4 },
        { x = 3, y = 2 }, { x = 5, y = 2 }, { x = 6, y = 2 },
    },
}
