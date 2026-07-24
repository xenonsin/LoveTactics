-- FIELD GALLERY -- a development board, not a fight. Every tile-field pattern the board can draw,
-- laid out at once so the shader can be looked at rather than argued about (shaders/field.lua,
-- ui/field_fx.lua). Reached from the menu's debug column ("Field Gallery"); `fixed` keeps it out of
-- the random pool, so no ordinary castle fight can ever roll it.
--
-- What it is arranged to prove, in the order you read it down the board:
--
--   y2  THE TEN PATTERNS, one tile each. They must be distinguishable from one another at tile size.
--   y3  THE SIX OVERRIDES -- zones whose tags resolve to a pattern another zone already uses, and
--       which carry an `fx` colour so the two do not read as the same ground. Darkness beside the
--       fumes, Witchlight beside the sanctuary, the Grasping Hollow beside the quicksand.
--   y4  STACKS. Four cells carrying two or three zones apiece. Each must read as two or three
--       fields, not as one smear and not as whichever was placed last -- the entire reason the old
--       one-flat-rect-per-hazard picture had to go.
--   y5-y7  CONTINUITY. A 3x3 sanctuary on the left and a 3x3 blaze on the right. Each must read as
--       ONE patch of ground: no interior seams, and no visible repetition of the same 1x1 noise
--       loop nine times. This is what the board-space sampling and the edge mask are for, and it is
--       the property painted tile art was going to have to be commissioned for (docs/art-assets.md).
--
-- Every tile is plain ground on purpose. Terrain washes, costly-tile tints and impassable darkening
-- would all sit under the fields and muddy exactly what is being judged.
--
-- Durations are quoted long so the gallery holds still while it is being looked at; the birth ramp
-- and the death fade are watched in a real fight instead, where a Fireball's blaze actually runs out.
local LONG = 9999

-- Ten singles, left to right along y2 -- one hazard per pattern, in the ORDER shaders/field.lua
-- declares them, so the row reads as that file's table. Eight fit a row; the last two open y3.
local SINGLES = {
    "hazard_fire",           -- flame
    "hazard_choking",        -- smoke
    "hazard_rimeguard",      -- rime
    "hazard_rain",           -- rain
    "hazard_gagging_storm",  -- spark
    "hazard_quicksand",      -- mire
    "hazard_graven_circle",  -- rune
    "hazard_heal",           -- halo
}

-- The two remaining patterns, then every zone that overrides its family's default colour.
local OVERRIDES = {
    "hazard_rally",          -- banner
    "hazard_shared_bulwark", -- ward
    "hazard_darkness",       -- smoke, near-black: a hole in the board
    "hazard_witchlight",     -- halo, cold blue-white: light that is not a blessing
    "hazard_grasping_hollow",-- mire, bruised violet: not the same mud as quicksand
    "hazard_exposure",       -- smoke, cloying rose: not the same cloud as the fumes
    "hazard_bloodsong",      -- banner, crimson
    "hazard_halting_ground", -- rune, amber: a warden's line, not a wizard's circle
}

local hazards = {}
local function place(id, x, y)
    hazards[#hazards + 1] = { id = id, x = x, y = y, duration = LONG }
end

for i, id in ipairs(SINGLES) do place(id, i, 2) end
for i, id in ipairs(OVERRIDES) do place(id, i, 3) end

-- y4: the stacks. Two cells of two, one of three, and one pairing a stain with a mist so the
-- bottom-to-top compositing order is visible rather than merely asserted in a test.
place("hazard_rain", 3, 4);      place("hazard_heal", 3, 4)                              -- mist over glow
place("hazard_fire", 4, 4);      place("hazard_rain", 4, 4)                              -- body under mist
place("hazard_quicksand", 5, 4); place("hazard_choking", 5, 4)                           -- stain under mist
place("hazard_fire", 6, 4);      place("hazard_rain", 6, 4); place("hazard_heal", 6, 4)  -- three, at the cap

-- y5..y7: the continuity blocks. A 3x3 of one zone on each side of the board.
for y = 5, 7 do
    for x = 1, 3 do place("hazard_heal", x, y) end
    for x = 6, 8 do place("hazard_fire", x, y) end
end

return {
    biome = "castle",
    fixed = true, -- addressable by name only; never rolled by an ordinary castle fight
    -- x: 1        2         3         4         5         6         7         8
    tiles = {
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y1 enemy line
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y2 the ten patterns
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y3 the overrides
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y4 the stacks
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y5 |
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y6 | continuity
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y7 |
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y8 party line
    },
    -- The party stands on the one clear row, so nothing is drawn under a unit until you walk it in --
    -- which is itself the test for the carried-status fields (walk into the blaze and take Burn).
    partySpawns = {
        { x = 4, y = 8 }, { x = 5, y = 8 }, { x = 3, y = 8 }, { x = 6, y = 8 },
    },
    enemySpawns = {
        { x = 4, y = 1 }, { x = 2, y = 1 }, { x = 7, y = 1 },
    },
    hazards = hazards,
}
