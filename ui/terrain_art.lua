-- THE GROUND HAS A PICTURE ON IT.
--
-- Until this, every battlefield tile was one flat rectangle of one flat colour, and the board was a
-- brown sheet with a grid ruled over it. That is not a small cosmetic complaint: the tile colours are
-- picked per BIOME and per ART ROLE (ui/battle_map.lua's ART, data/tilesets/*.lua), and the roles are
-- only six, so a forest board painted `forest` (walkable cover, 2 move, blocks sight) and `thicket`
-- (a wall) in *the same green* and let a 45% darkening carry the entire difference. A desert did the
-- same to `sand` and its dunes; the tundra to `ice` and its drifts. The player could not read the
-- ground they were about to spend a turn crossing, which is the one thing a tactics board exists to
-- show.
--
-- The answer is a MARK PER TERRAIN TYPE, not a second colour. Colour is already spoken for twice over
-- -- the biome owns the ground's hue (a tundra must look like a tundra) and ui/colors.lua's five
-- families own every overlay, threat and field drawn on top of it (see the move-reach blue, the range
-- red, ui/field_fx.lua's chevrons). A terrain type that wanted its own hue would have to take one of
-- those, and the board has no spare ones. So the ground keeps the biome's colour and each type gets a
-- SHAPE, which is what [[marks that stack differ by geometry]] has already settled for every other
-- pair of marks that share a cell.
--
-- WHAT THE MARK IS, AND WHAT IT IS NOT. These are TEXTURE, not badges: each shades itself off the
-- ground tone it is handed rather than choosing a colour, so it reads as the tile being made of
-- something rather than as a verdict laid on the tile. Every verdict the board draws -- reachable,
-- in range, threatened, hazardous, the cursor -- is a saturated wash or a crisp rim and stays crisp on
-- top of this. A terrain mark never outlines its cell and never uses a signal hue, so it cannot be
-- mistaken for one of those.
--
-- HOW LOUD. Three bands, and the loudness is itself information:
--   * a floor you cross for free whispers (`bare` is a little grit and nothing else);
--   * a floor that CHARGES you speaks up -- ripples, dune crests, scree -- roughly in step with the
--     translucent cost wash it is drawn under (BattleMap.TERRAIN_TINT);
--   * a tile you cannot enter at all is the loudest thing on the ground: the canopy, the boulders and
--     the masonry are near-opaque and run edge to edge, so a wall reads as a wall at arm's length
--     without waiting for the darkening to be noticed.
--
-- SILHOUETTE AND GAPS, NOT DETAIL. Same lesson the house sigils learned at 14px (ui/vendor_icons.lua):
-- at 64 logical pixels -- less on a handheld -- what survives is coarse geometry with holes in it. A
-- conifer is two stacked triangles over a trunk; a bridge is four planks with daylight between them.
-- Nothing here has an interior.
--
-- DETERMINISTIC SCATTER. A mark that scatters (grit, scree, bubbles, boulders) is placed off a hash of
-- the tile's own grid position, so a field of rough ground is visibly irregular but a board redraws
-- identically every frame and reproduces from its seed. Nothing here calls math.random.
--
--   TerrainArt.draw("forest", x, y, w, h, r, g, b, col, row)
--
-- `r,g,b` is the ground tone the tile has ALREADY been painted in -- after its cost wash or its
-- impassable darkening -- so the mark is shaded against what is actually underneath it rather than
-- against the nominal palette entry.
--
-- Each mark is taught beside its name in the tile tooltip (ui/tile_tooltip.lua), which draws this same
-- vocabulary next to the terrain's name and its movement cost. A mark that only ever appeared on the
-- tile would be a rebus.
--
-- Kin to ui/glyphs.lua (a mark beside a number) and ui/vendor_icons.lua (a mark that names a house).
-- Kept apart from both because these are keyed by TERRAIN TYPE -- add one to models/terrain.lua and
-- this file owes it a mark, which tests/terrain_art_spec.lua enforces from both ends.
--
-- No love.graphics at require-time, so it loads under the headless suite.

local TerrainArt = {}

-- ---------------------------------------------------------------------------
-- Tones and scatter
-- ---------------------------------------------------------------------------

-- Darker than the ground by `k` (0 = black, 1 = the ground itself). A mark's shadow side, a crack, the
-- gap between two planks.
local function dark(r, g, b, k, a)
    love.graphics.setColor(r * k, g * k, b * k, a or 1)
end

-- Lifted `k` of the way from the ground toward white. A lit face, a crest of foam, a snow cap. Toward
-- WHITE rather than toward a brighter version of the hue, because these are lights on a surface and a
-- light is the same colour whatever it falls on -- the opposite of the shader rule for coloured field
-- marks, which must brighten along their own hue or they grey out (ui/field_fx.lua).
local function pale(r, g, b, k, a)
    love.graphics.setColor(r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k, a or 1)
end

-- Brighter ALONG ITS OWN HUE: every channel multiplied by `k` (> 1) and clamped, so a saturated ground
-- gets hotter rather than paler. The one mark that emits light instead of catching it -- lava's
-- fissures -- has to be shaded this way and `pale` above is wrong for it: the volcanic flow is
-- {0.86, 0.34, 0.14}, and lifting THAT toward white produced a tile of dusty pink cracks that read as
-- chalk. Multiplied instead it saturates to molten orange, and it stays derived from the biome's own
-- palette rather than being a colour this file picked. Same rule the field shader learned the hard way
-- (ui/field_fx.lua): a highlight toward white greys out everything that had a hue to begin with.
local function glow(r, g, b, k, a)
    love.graphics.setColor(math.min(1, r * k), math.min(1, g * k), math.min(1, b * k), a or 1)
end

-- A stable 0..1 draw for this tile and this index. Integer hash rather than math.random: the board is
-- redrawn every frame and a scatter that moved between frames would shimmer, and a seeded run has to
-- reproduce its own boards exactly (models/seed.lua).
--
-- TWO LCG ROUNDS, and the second one is not decoration. The first cut was one weighted sum taken
-- modulo a prime, which is linear in `i` -- so the six specks of grit on a tile landed on a straight
-- line, and since it was linear in `col` and `row` too, the SAME line on every tile. Eight by eight
-- cells of open ground came out ruled with diagonal dotted stripes, which is a worse artefact than the
-- flat colour it replaced. Mixing twice breaks both: neighbouring seeds diverge, and consecutive `i`
-- on one tile stop walking in step. Every product here stays under 2^53, so Lua 5.1's doubles carry it
-- exactly.
local function rnd(col, row, i)
    local n = (col * 1619 + row * 31337 + i * 6971) % 65536
    n = (n * 1103515245 + 12345) % 2147483648
    n = math.floor(n / 32768) % 65536
    n = (n * 1103515245 + 12345) % 2147483648
    return (math.floor(n / 32768) % 65536) / 65536
end

-- ---------------------------------------------------------------------------
-- The marks
-- ---------------------------------------------------------------------------
--
-- Each fills the box (x, y, w, h) it is handed, shades everything it draws off (r, g, b), and may use
-- (col, row) for scatter. None of them changes the line width without putting it back.

local Marks = {}

-- OPEN GROUND -- grit, and deliberately almost nothing. This is the floor every cost on the board is
-- measured against, so its job is to be the quiet one: four specks of shadow and two of light, spread
-- by the tile's own hash. Without them a field of open ground is a painted sheet and the grid lines
-- are the only thing saying it has tiles at all; with them it has a surface, and it still reads as the
-- cheapest thing to stand on because it is the only floor here with no structure.
function Marks.bare(x, y, w, h, r, g, b, col, row)
    for i = 1, 6 do
        local px = x + w * (0.12 + rnd(col, row, i) * 0.76)
        local py = y + h * (0.12 + rnd(col, row, i + 40) * 0.76)
        local d = w * (0.022 + rnd(col, row, i + 80) * 0.022)
        if i % 3 == 0 then pale(r, g, b, 0.12, 0.55) else dark(r, g, b, 0.74, 0.55) end
        love.graphics.circle("fill", px, py, d)
    end
end

-- A BRIDGE -- four planks with daylight between them, and a rail down each long side. The one floor on
-- the board that somebody BUILT, so it is the one drawn as straight lines meeting at right angles;
-- everything else here is landform. Over a river it is also the only way across, which is why the
-- planks run edge to edge: the crossing has to read from the tile next to it.
function Marks.bridge(x, y, w, h, r, g, b)
    for i = 0, 3 do
        local py = y + h * (0.16 + i * 0.19)
        pale(r, g, b, 0.16, 0.85)
        love.graphics.rectangle("fill", x + w * 0.04, py, w * 0.92, h * 0.13)
        dark(r, g, b, 0.52, 0.8)
        love.graphics.rectangle("fill", x + w * 0.04, py + h * 0.13, w * 0.92, h * 0.045)
    end
    dark(r, g, b, 0.46, 0.9) -- the two rails, along the direction of travel
    love.graphics.rectangle("fill", x + w * 0.04, y + h * 0.08, w * 0.055, h * 0.84)
    love.graphics.rectangle("fill", x + w * 0.885, y + h * 0.08, w * 0.055, h * 0.84)
end

-- FOREST -- two conifers with ground showing between and around them. WALKABLE cover: you can see the
-- floor it stands on, which is the whole difference from the thicket below, and the gaps are doing
-- that work rather than the colour.
function Marks.forest(x, y, w, h, r, g, b, col, row)
    local function tree(cx, base, size)
        dark(r, g, b, 0.55, 0.95)
        love.graphics.rectangle("fill", cx - size * 0.07, base - size * 0.20, size * 0.14, size * 0.24)
        for i = 0, 2 do -- three stacked skirts, widest at the bottom
            local t = base - size * (0.16 + i * 0.26)
            local half = size * (0.40 - i * 0.10)
            dark(r, g, b, 0.62 + i * 0.09, 0.95)
            love.graphics.polygon("fill", cx, t - size * 0.34, cx + half, t, cx - half, t)
        end
    end
    tree(x + w * 0.34, y + h * 0.86, w * 0.58)
    tree(x + w * 0.70, y + h * 0.95, w * 0.44)
    for i = 1, 3 do -- scrub at the feet, so the trees are standing in something
        local px = x + w * (0.08 + rnd(col, row, i) * 0.84)
        dark(r, g, b, 0.70, 0.7)
        love.graphics.rectangle("fill", px, y + h * 0.90, w * 0.10, h * 0.05)
    end
end

-- THICKET -- dense canopy, edge to edge, no floor anywhere. The map's fill and the thing a trail is cut
-- through: IMPASSABLE, so unlike the forest above it leaves no gap to stand in. Seven overlapping
-- crowns rather than one shape, because a single blob reads as a boulder and a lumpy silhouette reads
-- as leaves.
function Marks.thicket(x, y, w, h, r, g, b, col, row)
    for i = 1, 7 do
        local px = x + w * (0.10 + rnd(col, row, i) * 0.80)
        local py = y + h * (0.14 + rnd(col, row, i + 20) * 0.72)
        local rr = w * (0.19 + rnd(col, row, i + 60) * 0.11)
        dark(r, g, b, 0.48 + (i % 3) * 0.09, 0.97)
        love.graphics.circle("fill", px, py, rr)
        -- A lit crown on the upper-left of each, and this is what makes the mass read as LEAVES
        -- rather than as one dark smudge: seven highlights are seven rounded tops, and a silhouette
        -- with that many bumps in it cannot be mistaken for the boulders two marks down.
        pale(r, g, b, 0.16, 0.85)
        love.graphics.arc("fill", "pie", px, py, rr * 0.78, math.pi * 1.08, math.pi * 1.80)
    end
    dark(r, g, b, 0.40, 0.8) -- the shadow the mass sits in, under its lower edge
    love.graphics.rectangle("fill", x, y + h * 0.86, w, h * 0.14)
end

-- HIGH GROUND -- a peak with a lit face, a shadow face and a bright cap. The best tile on the board and
-- the only mark with a true HIGHLIGHT on it, which is what makes it the thing the eye finds first: a
-- rise is the one terrain you go out of your way to take.
function Marks.mountain(x, y, w, h, r, g, b)
    local cx, base = x + w * 0.50, y + h * 0.88
    local apex = y + h * 0.12
    dark(r, g, b, 0.55, 0.95) -- shadow face (right)
    love.graphics.polygon("fill", cx, apex, x + w * 0.94, base, cx, base)
    pale(r, g, b, 0.22, 0.95) -- lit face (left)
    love.graphics.polygon("fill", cx, apex, x + w * 0.06, base, cx, base)
    pale(r, g, b, 0.62, 0.95) -- the cap: snow, or simply the light on a bare summit
    love.graphics.polygon("fill", cx, apex,
        cx + w * 0.12, apex + h * 0.24, cx, apex + h * 0.15, cx - w * 0.12, apex + h * 0.24)
    dark(r, g, b, 0.38, 0.6)  -- the line the two faces meet on
    love.graphics.polygon("fill", cx - w * 0.015, apex, cx + w * 0.015, apex, cx + w * 0.015, base,
        cx - w * 0.015, base)
end

-- ROUGH GROUND -- scree. Broken chips scattered flat across the whole tile, none of them big enough to
-- stand on or hide behind: this floor charges you for picking your way over it and gives back a little
-- avoidance, and nothing more. Told from the boulders below by SIZE and by lying flat rather than
-- rising.
function Marks.rough(x, y, w, h, r, g, b, col, row)
    for i = 1, 8 do
        local px = x + w * (0.10 + rnd(col, row, i) * 0.72)
        local py = y + h * (0.14 + rnd(col, row, i + 30) * 0.70)
        local s = w * (0.13 + rnd(col, row, i + 70) * 0.07)
        local t = s * 0.46 -- chips lie FLAT: wider than they are tall, or they read as arrowheads
        dark(r, g, b, 0.56, 0.92)
        love.graphics.polygon("fill", px, py + t * 0.5, px + s * 0.34, py, px + s, py + t * 0.34,
            px + s * 0.62, py + t)
        pale(r, g, b, 0.20, 0.85) -- the top face of the chip, so it has a thickness
        love.graphics.polygon("fill", px, py + t * 0.5, px + s * 0.34, py, px + s, py + t * 0.34,
            px + s * 0.40, py + t * 0.44)
    end
end

-- BOULDERS -- three rounded masses filling the tile. Impassable, and ROUND where the obstacle below is
-- squared: one is landform, the other was cut and set down, and at this size the corner is the only
-- thing that tells them apart.
function Marks.rock(x, y, w, h, r, g, b, col, row)
    local function stone(cx, cy, rr)
        dark(r, g, b, 0.44, 0.97) -- the shadow side, and the seam between two stones that touch
        love.graphics.circle("fill", cx, cy, rr)
        dark(r, g, b, 0.78, 0.97) -- the body: still under the ground tone, but not by much
        love.graphics.circle("fill", cx, cy, rr * 0.88)
        pale(r, g, b, 0.30, 0.9) -- the lit shoulder, up and to the left on every stone on the board
        love.graphics.arc("fill", "pie", cx, cy, rr * 0.74, math.pi * 1.06, math.pi * 1.82)
    end
    stone(x + w * (0.33 + rnd(col, row, 1) * 0.06), y + h * 0.62, w * 0.29)
    stone(x + w * (0.70 + rnd(col, row, 2) * 0.06), y + h * 0.70, w * 0.24)
    stone(x + w * (0.56 + rnd(col, row, 3) * 0.08), y + h * 0.32, w * 0.22)
end

-- AN OBSTACLE -- set masonry: three courses of block with mortar between them, the joints staggered.
-- Solid, and squared off on purpose (see the boulders above). This is the wall a curated arena names
-- when it wants a room to have sides.
function Marks.obstacle(x, y, w, h, r, g, b)
    local left, wide = x + w * 0.08, w * 0.84
    dark(r, g, b, 0.38, 0.95) -- the mortar, which is simply what shows between the blocks
    love.graphics.rectangle("fill", left, y + h * 0.10, wide, h * 0.80, 2, 2)
    -- Three courses. The odd one is offset by half a block so the vertical joints never line up,
    -- which is the whole of what makes a stack of rectangles read as a built wall.
    for i = 0, 2 do
        local by = y + h * (0.135 + i * 0.262)
        local edges = (i % 2 == 0) and { 0.00, 0.50 } or { -0.25, 0.25, 0.75 }
        for _, f in ipairs(edges) do
            local bx = math.max(left, left + wide * f)
            local bw = math.min(left + wide, left + wide * (f + 0.50)) - bx
            if bw > w * 0.02 then
                pale(r, g, b, 0.18, 0.95)
                love.graphics.rectangle("fill", bx + w * 0.015, by, bw - w * 0.03, h * 0.205)
            end
        end
    end
end

-- SCRUB -- tufts. The fill's soft cosmetic variant, laid by noise beside the thicket; solid in the
-- data, so it is drawn dense enough to read as a mass rather than as lawn.
function Marks.grass(x, y, w, h, r, g, b, col, row)
    love.graphics.setLineWidth(math.max(1.5, w * 0.045))
    for i = 1, 11 do
        local px = x + w * (0.08 + rnd(col, row, i) * 0.84)
        local base = y + h * (0.34 + rnd(col, row, i + 25) * 0.58)
        local hh = h * (0.13 + rnd(col, row, i + 55) * 0.11)
        -- Three blades off ONE root, leaning apart. Two blades from a point read as a pair of legs;
        -- three read as a tuft, and a tile of tufts reads as scrub.
        dark(r, g, b, 0.54 + (i % 2) * 0.16, 0.92)
        love.graphics.line(px, base, px - w * 0.055, base - hh * 0.78)
        love.graphics.line(px, base, px + w * 0.012, base - hh)
        love.graphics.line(px, base, px + w * 0.062, base - hh * 0.70)
    end
    love.graphics.setLineWidth(1)
end

-- A RIVER -- full-width current. IMPASSABLE but transparent (you can see the far bank perfectly well,
-- you simply cannot get to it here), so it is drawn as lines running edge to edge rather than as a
-- mass: the tile stays open to the eye and closed to the feet, which is exactly what it is. The waves
-- run the same way on every river tile so a watercourse reads as one thing across several cells.
function Marks.river(x, y, w, h, r, g, b, col, row)
    dark(r, g, b, 0.72, 0.9) -- the depth, over the whole tile
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setLineWidth(math.max(1.5, w * 0.045))
    for i = 0, 3 do
        local wy = y + h * (0.16 + i * 0.23) + h * rnd(col, row, i + 5) * 0.05
        pale(r, g, b, 0.30 + (i % 2) * 0.16, 0.85)
        love.graphics.line(x, wy, x + w * 0.30, wy - h * 0.05, x + w * 0.62, wy + h * 0.05, x + w, wy)
    end
    love.graphics.setLineWidth(1)
end

-- A FORD -- shallow water, and the mark says shallow by showing the BOTTOM: two stones under the
-- surface, then two short ripples over them. Wadeable at double cost and it conducts, so this is a
-- floor you may choose to stand in, and it must never be mistaken for the river it is drawn beside.
function Marks.water(x, y, w, h, r, g, b, col, row)
    for i = 1, 3 do -- the bed, seen through
        local px = x + w * (0.18 + rnd(col, row, i) * 0.62)
        local py = y + h * (0.30 + rnd(col, row, i + 15) * 0.46)
        dark(r, g, b, 0.68, 0.75)
        love.graphics.circle("fill", px, py, w * (0.07 + rnd(col, row, i + 45) * 0.04))
    end
    love.graphics.setLineWidth(math.max(1.5, w * 0.04))
    for i = 0, 1 do
        local wy = y + h * (0.36 + i * 0.30)
        pale(r, g, b, 0.40, 0.8)
        love.graphics.line(x + w * 0.12, wy, x + w * 0.38, wy - h * 0.04, x + w * 0.62, wy + h * 0.04,
            x + w * 0.88, wy)
    end
    love.graphics.setLineWidth(1)
end

-- LAVA -- cooled crust with the flow showing through the cracks. The ONE mark on the board that is
-- brighter than its ground rather than darker, and it has to be: the tile is impassable and the reason
-- is heat, not bulk, so it cannot be drawn as a mass. The crust plates are the dark part and the
-- fissures between them glow.
function Marks.lava(x, y, w, h, r, g, b, col, row)
    dark(r, g, b, 0.42, 0.95) -- the crust, over the whole tile
    love.graphics.rectangle("fill", x, y, w, h)
    -- THREE plates, not a starburst. The first cut drew five fissures radiating from one point and it
    -- read as a white asterisk pinned to the middle of the tile -- the mark had a centre, and crusted
    -- ground does not. Two long cracks crossing the tile edge to edge cut it into plates instead, and
    -- the glow is what shows BETWEEN them.
    love.graphics.setLineWidth(math.max(2.5, w * 0.075))
    local jx = (rnd(col, row, 1) - 0.5) * w * 0.3
    local jy = (rnd(col, row, 2) - 0.5) * h * 0.3
    glow(r, g, b, 1.75, 0.95)
    love.graphics.line(x - w * 0.02, y + h * 0.30 + jy, x + w * 0.44, y + h * 0.44 + jy * 0.4,
        x + w * 0.70, y + h * 0.26 + jy * 0.2, x + w * 1.02, y + h * 0.38 + jy)
    love.graphics.line(x + w * 0.34 + jx, y - h * 0.02, x + w * 0.44 + jx * 0.5, y + h * 0.42,
        x + w * 0.28 + jx * 0.3, y + h * 0.72, x + w * 0.40 + jx, y + h * 1.02)
    love.graphics.setLineWidth(math.max(1.5, w * 0.04))
    glow(r, g, b, 1.35, 0.9) -- a hairline branch off the main crack, so the plates are not two squares
    love.graphics.line(x + w * 0.62, y + h * 0.30 + jy * 0.2, x + w * 0.74, y + h * 0.66,
        x + w * 0.66, y + h * 1.0)
    love.graphics.setLineWidth(1)
    -- The hottest point, where the two cracks meet: saturated first, then the core taken a little
    -- toward white, because that is what a light actually does once it is bright enough.
    glow(r, g, b, 2.1, 0.95)
    love.graphics.circle("fill", x + w * 0.42 + jx * 0.5, y + h * 0.40 + jy * 0.4, w * 0.095)
    pale(math.min(1, r * 2.1), math.min(1, g * 2.1), math.min(1, b * 2.1), 0.45, 0.95)
    love.graphics.circle("fill", x + w * 0.42 + jx * 0.5, y + h * 0.40 + jy * 0.4, w * 0.045)
end

-- A MIRE -- standing muck: bubbles surfacing, and two reeds standing in it. Ties the mountain for the
-- heaviest walkable floor and gives back less than nothing, so it gets the busiest surface of any
-- floor you can stand on -- a tile that looks like hard work.
function Marks.mire(x, y, w, h, r, g, b, col, row)
    -- Only a breath of extra shade over the whole tile. The mire already wears the heaviest cost wash
    -- on the board (BattleMap.TERRAIN_TINT) and a swamp's palette is dark to start with, so the first
    -- cut's 0.78 on top of both buried the reeds it was supposed to be standing behind.
    dark(r, g, b, 0.92, 0.7)
    love.graphics.rectangle("fill", x, y, w, h)
    -- Bubbles, FILLED with a lit top rather than drawn as rings: a ring at this size is a letter O,
    -- and five of them made the tile read as notation. Small and many, so the surface looks like it
    -- is working rather than like it has three objects on it.
    for i = 1, 8 do
        local px = x + w * (0.12 + rnd(col, row, i) * 0.76)
        local py = y + h * (0.18 + rnd(col, row, i + 18) * 0.66)
        local rr = w * (0.035 + rnd(col, row, i + 48) * 0.05)
        dark(r, g, b, 0.62, 0.92)
        love.graphics.circle("fill", px, py, rr)
        pale(r, g, b, 0.26, 0.85)
        love.graphics.arc("fill", "pie", px, py, rr * 0.8, math.pi * 1.10, math.pi * 1.78)
    end
    love.graphics.setLineWidth(math.max(1.5, w * 0.045))
    for i = 1, 3 do -- reeds, the one vertical thing in a tile of nothing but surface
        local px = x + w * (0.18 + rnd(col, row, i + 70) * 0.64)
        local hh = h * (0.42 + rnd(col, row, i + 88) * 0.26)
        dark(r, g, b, 0.46, 0.92)
        love.graphics.line(px, y + h * 0.92, px + w * 0.02, y + h * 0.92 - hh * 0.6,
            px + w * 0.075, y + h * 0.92 - hh)
    end
    love.graphics.setLineWidth(1)
end

-- SAND -- dune ripples, three shallow crests lying across the tile with a lit edge on each. Forest's
-- cost without forest's cover, so the mark has to be busy enough to say "slow" and flat enough to say
-- "nothing to hide behind" -- which is what a ripple is and a tree is not.
function Marks.sand(x, y, w, h, r, g, b, col, row)
    -- SHALLOW. The first cut used the river's wave amplitude and the tile came out ruled with
    -- zigzags -- a polyline this steep has corners, and corners read as chevrons, which is a mark
    -- ui/field_fx.lua already owns for a hostile zone. A dune ripple is nearly flat; its whole
    -- character is length, not height.
    love.graphics.setLineWidth(math.max(1.5, w * 0.042))
    for i = 0, 3 do
        local wy = y + h * (0.20 + i * 0.21) + h * rnd(col, row, i + 3) * 0.04
        local a = h * 0.022
        dark(r, g, b, 0.78, 0.85)
        love.graphics.line(x, wy + a, x + w * 0.36, wy - a, x + w * 0.70, wy + a, x + w, wy - a * 0.5)
        pale(r, g, b, 0.22, 0.8) -- the crest catching the light, just above its own trough
        love.graphics.line(x, wy - a * 0.6, x + w * 0.36, wy - a * 2.6, x + w * 0.70, wy - a * 0.6,
            x + w, wy - a * 2.1)
    end
    love.graphics.setLineWidth(1)
end

-- ICE -- a sheet with cracks through it. The ONLY terrain that does not tax a step, so the mark is
-- mostly empty: three straight fractures and a lit facet, and no scatter anywhere. What it charges
-- instead is conduction, which the board says with the charge overlay, not with this.
function Marks.ice(x, y, w, h, r, g, b, col, row)
    pale(r, g, b, 0.14, 0.55) -- the glaze
    love.graphics.rectangle("fill", x + w * 0.05, y + h * 0.05, w * 0.90, h * 0.90, 3, 3)
    local jx = w * (rnd(col, row, 1) - 0.5) * 0.26
    local jy = h * (rnd(col, row, 2) - 0.5) * 0.26
    local cx, cy = x + w * 0.5 + jx, y + h * 0.5 + jy
    love.graphics.setLineWidth(math.max(1.5, w * 0.032))
    for i = 0, 2 do -- straight fractures from one point: ice breaks in lines, never in curves
        local a = (i / 3) * math.pi * 2 + rnd(col, row, i + 9) * 0.9
        dark(r, g, b, 0.66, 0.9)
        love.graphics.line(cx, cy, cx + math.cos(a) * w * 0.55, cy + math.sin(a) * h * 0.55)
        pale(r, g, b, 0.42, 0.6) -- the lit lip along one side of each fracture
        love.graphics.line(cx + w * 0.02, cy - h * 0.02,
            cx + math.cos(a) * w * 0.52 + w * 0.02, cy + math.sin(a) * h * 0.52 - h * 0.02)
    end
    love.graphics.setLineWidth(1)
end

-- ---------------------------------------------------------------------------
-- The table, and the draw
-- ---------------------------------------------------------------------------

-- Terrain type (models/terrain.lua's keys) -> mark. `path` and `ground` are the same floor under two
-- names and share one mark, exactly as they share one colour and one cost.
TerrainArt.MARKS = {
    ground = Marks.bare, path = Marks.bare, bridge = Marks.bridge,
    forest = Marks.forest, thicket = Marks.thicket,
    mountain = Marks.mountain, rough = Marks.rough,
    rock = Marks.rock, obstacle = Marks.obstacle, grass = Marks.grass,
    river = Marks.river, water = Marks.water, lava = Marks.lava, mire = Marks.mire,
    sand = Marks.sand, ice = Marks.ice,
}

-- Draw `kind`'s mark into the box, shaded against the ground tone already painted there. An unknown
-- type draws NOTHING rather than a fallback mark: a wrong picture on the ground is worse than a plain
-- tile, and tests/terrain_art_spec.lua is what keeps the set complete so this never happens in play.
function TerrainArt.draw(kind, x, y, w, h, r, g, b, col, row)
    local mark = TerrainArt.MARKS[kind]
    if not mark then return end
    mark(x, y, w, h, r, g, b, col or 0, row or 0)
    love.graphics.setColor(1, 1, 1)
end

return TerrainArt
