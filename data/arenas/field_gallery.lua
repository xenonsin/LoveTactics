-- FIELD GALLERY -- a development board, not a fight. Every category look the board can draw, laid out
-- at once so the shader can be looked at rather than argued about (shaders/field.lua, ui/field_fx.lua).
-- Reached from the menu's debug column ("Field Gallery"); `fixed` keeps it out of the random pool, so
-- no ordinary castle fight can ever roll it.
--
-- The board no longer draws by ELEMENT. It draws by what a zone MEANS to the player, in two shapes the
-- controller colours and points: a chevron (orange falling for a threat, green rising for your buff, red
-- rising for the enemy's) and a cross (blue for a heal on your side, red for one on theirs). So what this
-- gallery proves is no longer "ten patterns are distinct" -- it is that the FIVE looks are distinct, and
-- that many different zones collapsing onto one of them is the point rather than a loss.
--
-- What it is arranged to prove, in the order you read it down the board:
--
--   y2  THE FIVE LOOKS, one per tile: a threat, your buff, their buff, your heal, their heal -- then
--       Muster (its fx.valence override making a neutral zone read friendly) and the two neutral zones
--       (Rain, Darkness) that fold in with the threats.
--   y3  ONE MEANING, MANY ZONES. Eight different hostile zones -- choking, quicksand, a storm, a hollow
--       -- every one of them the same orange chevrons. That they are no longer told apart by element is
--       the simplification this redesign is for, seen in a row.
--   y4  STACKS. Cells carrying two zones apiece, each of which must still read as two composited fields
--       (a threat over a heal) rather than as one smear or whichever was placed last.
--   y5-y7  CONTINUITY. A 3x3 heal on the left and a 3x3 threat on the right. Each must read as ONE patch
--       of ground: no interior seams, and no visible repetition of the same 1x1 loop nine times. This is
--       what the board-space sampling and the edge mask are for.
--
-- Every tile is plain ground on purpose. Terrain washes, costly-tile tints and impassable darkening
-- would all sit under the fields and muddy exactly what is being judged.
--
-- Durations are quoted long so the gallery holds still while it is being looked at; the birth ramp and
-- the death fade are watched in a real fight instead, where a Fireball's blaze actually runs out.
local LONG = 9999

local hazards = {}
local function place(id, x, y, side)
    hazards[#hazards + 1] = { id = id, x = x, y = y, side = side, duration = LONG }
end

-- y2: the five looks, then the three special cases. The `side` is what flips a friendly zone between
-- your colour and the enemy's -- a Sanctuary the party owns heals in blue, one the enemy owns in red.
place("hazard_fire", 1, 2)              -- threat            : orange, falling
place("hazard_rally", 2, 2, "party")    -- your buff         : green, rising
place("hazard_rally", 3, 2, "enemy")    -- their buff        : red, rising
place("hazard_heal", 4, 2, "party")     -- your heal         : blue crosses
place("hazard_heal", 5, 2, "enemy")     -- their heal        : red crosses
place("hazard_muster", 6, 2, "party")   -- neutral, but fx.valence makes it read as your buff
place("hazard_rain", 7, 2)              -- neutral, folded in with the threats
place("hazard_darkness", 8, 2)          -- neutral, folded in with the threats

-- y3: eight distinct hostile zones, every one now the same orange chevrons -- the whole point, in a row.
local THREATS = {
    "hazard_choking", "hazard_quicksand", "hazard_stillness", "hazard_gagging_storm",
    "hazard_grasping_hollow", "hazard_witchlight", "hazard_rimeguard", "hazard_halting_ground",
}
for i, id in ipairs(THREATS) do place(id, i, 3) end

-- y4: the stacks. A threat over a heal must still read as two fields, not one.
place("hazard_heal", 3, 4, "party"); place("hazard_fire", 3, 4)                 -- your heal under a threat
place("hazard_heal", 4, 4, "enemy"); place("hazard_rain", 4, 4)                 -- their heal under a threat
place("hazard_rally", 5, 4, "party"); place("hazard_quicksand", 5, 4)           -- your buff under a threat

-- y5..y7: the continuity blocks. A 3x3 heal (yours, blue) on the left, a 3x3 threat on the right.
for y = 5, 7 do
    for x = 1, 3 do place("hazard_heal", x, y, "party") end
    for x = 6, 8 do place("hazard_fire", x, y) end
end

return {
    biome = "castle",
    fixed = true, -- addressable by name only; never rolled by an ordinary castle fight
    -- x: 1        2         3         4         5         6         7         8
    tiles = {
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y1 enemy line
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y2 the five looks
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y3 one meaning, many zones
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y4 the stacks
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y5 |
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y6 | continuity
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y7 |
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" }, -- y8 party line
    },
    -- The party stands on the one clear row, so nothing is drawn under a unit until you walk it in --
    -- which is itself the test for the carried-status fields (walk into the blaze and take Burn, and
    -- watch the orange chevrons appear under the body).
    partySpawns = {
        { x = 4, y = 8 }, { x = 5, y = 8 }, { x = 3, y = 8 }, { x = 6, y = 8 },
    },
    enemySpawns = {
        { x = 4, y = 1 }, { x = 2, y = 1 }, { x = 7, y = 1 },
    },
    hazards = hazards,
}
