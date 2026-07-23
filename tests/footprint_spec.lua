-- Tests for multi-tile units (footprints) in models/combat.lua. A unit's blueprint may declare a
-- `footprint = { w, h }`; the runtime unit then occupies a w×h block of cells anchored at its
-- top-left (unit.x, unit.y). These cases pin the behaviour the whole engine depends on: occupancy,
-- placement, pathing, targeting/range, area effects, and whole-body forced movement. Pure logic,
-- runs headless. character_ogre is the reference 2×2 body.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- A flat, all-walkable arena (no terrain), with an optional list of impassable cells.
local function arena(cols, rows, blocked)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    for _, b in ipairs(blocked or {}) do
        tiles[b.y][b.x].walkable = false
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Find a unit in the combat by the name on its blueprint.
local function named(c, name)
    for _, u in ipairs(c.units) do
        if u.char.name == name then return u end
    end
end

return {
    {
        name = "a 2x2 unit occupies all four cells, and unitAt resolves it from every one",
        fn = function()
            local c = Combat.new(arena(8, 8), {}, { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            assert(ogre.w == 2 and ogre.h == 2, "ogre footprint threaded to the runtime unit")
            assert(#Combat.unitCells(ogre) == 4, "four cells covered")
            for _, cell in ipairs({ { 3, 3 }, { 4, 3 }, { 3, 4 }, { 4, 4 } }) do
                assert(Combat.unitAt(c, cell[1], cell[2]) == ogre,
                    string.format("unitAt(%d,%d) is the ogre", cell[1], cell[2]))
            end
            assert(Combat.unitAt(c, 5, 3) == nil, "a cell outside the body is empty")
            assert(Combat.unitAt(c, 2, 3) == nil, "the cell left of the anchor is empty")
        end,
    },
    {
        name = "footprintFree rejects out-of-bounds and overlapping placements, accepts clear ground",
        fn = function()
            local c = Combat.new(arena(8, 8), {}, { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            -- Clear ground away from the ogre: fits.
            assert(Combat.footprintFree(c, 2, 2, 6, 6), "a 2x2 fits on open ground")
            -- Runs off the east/south edge: the far cells are off the board.
            assert(not Combat.footprintFree(c, 2, 2, 8, 8), "a 2x2 can't hang off the board edge")
            -- Overlaps the ogre's body (shares cell 4,4): blocked...
            assert(not Combat.footprintFree(c, 2, 2, 4, 4), "a placement overlapping the ogre is refused")
            -- ...unless we tell it to ignore that very unit (a body testing its own tiles).
            assert(Combat.footprintFree(c, 2, 2, 4, 4, ogre), "ignoreUnit lets a body test its own cells as free")
        end,
    },
    {
        name = "cellGap / unitGap measure to the nearest cell of a wide body",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 6, 3) },
                { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            local knight = c.units[1] -- the party unit, added first
            -- Ogre spans x=3..4; the knight at x=6 is two tiles from the near edge (4,3), not from (3,3).
            assert(Combat.cellGap(6, 3, ogre) == 2, "cellGap uses the nearest body cell")
            assert(Combat.cellGap(4, 3, ogre) == 0, "a point inside the body has gap 0")
            assert(Combat.unitGap(knight, ogre) == 2, "unitGap is nearest cell to nearest cell")
        end,
    },
    {
        name = "reachable never stops a wide body where its footprint won't fit",
        fn = function()
            -- A wall cell at (3,1). Any anchor whose 2x2 body would cover it is not a legal stop.
            local c = Combat.new(arena(8, 8, { { x = 3, y = 1 } }), {}, { unit("character_ogre", 1, 3) })
            local ogre = named(c, "Ogre")
            local reach = Combat.reachable(c, ogre)
            for _, node in pairs(reach) do
                assert(Combat.footprintFree(c, 2, 2, node.x, node.y, ogre),
                    string.format("reachable anchor (%d,%d) fits the whole body", node.x, node.y))
            end
            -- Anchor (2,1) would cover the wall at (3,1); anchor (3,1) would sit on it. Neither is reachable.
            assert(not reach["2,1"], "an anchor whose body covers a wall is not a stop tile")
            assert(not reach["3,1"], "an anchor sitting on a wall is not a stop tile")
        end,
    },
    {
        name = "a wide body walks as one: moveUnit carries every cell to the new anchor",
        fn = function()
            local c = Combat.new(arena(8, 8), {}, { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            openTurn(c, ogre)
            local ok = Combat.moveUnit(c, ogre, 3, 1) -- two tiles north, well inside movement 4
            assert(ok, "the move is legal")
            assert(ogre.x == 3 and ogre.y == 1, "anchor moved")
            assert(Combat.unitAt(c, 3, 1) == ogre and Combat.unitAt(c, 4, 2) == ogre,
                "the whole body is at the new anchor")
            assert(Combat.unitAt(c, 3, 3) == nil and Combat.unitAt(c, 4, 4) == nil,
                "the old cells are vacated")
        end,
    },
    {
        name = "knockback slides the whole body, and stops against a unit blocking any destination cell",
        fn = function()
            -- Free lane first: shove the ogre two tiles east off a source to its west.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 3) },
                { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            local src = c.units[1]
            local moved = Combat.knockback(c, src, ogre, 2)
            assert(moved == 2, "the body slid two tiles")
            assert(ogre.x == 5 and ogre.y == 3, "anchor advanced by two")
            assert(Combat.unitAt(c, 6, 4) == ogre, "the far cell moved with the body")

            -- Now a blocker sits where the body's leading cell would land: the slide stops short.
            local c2 = Combat.new(arena(8, 8),
                { unit("character_knight", 1, 3), unit("character_knight", 6, 3) },
                { unit("character_ogre", 3, 3) })
            local ogre2 = named(c2, "Ogre")
            local src2 = c2.units[1] -- the one at (1,3), to the ogre's west
            local m2, collided = Combat.knockback(c2, src2, ogre2, 5)
            assert(m2 == 1, "the body advanced one tile before the block")
            assert(collided, "the shove reported a collision")
            assert(ogre2.x == 4, "anchor stopped at (4,3) because (6,3) barred the next step")
        end,
    },
    {
        name = "an area blast catches a wide body exactly once",
        fn = function()
            local c = Combat.new(arena(8, 8), {}, { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            -- A radius-1 diamond centred on (3,3) covers (3,3),(2,3),(4,3),(3,2),(3,4): three of those
            -- are the ogre's cells. It must be returned once, not three times.
            local ab = { aoe = { shape = "diamond", radius = 1 } }
            local hit = Combat.aoeUnits(c, ab, 3, 3, nil)
            assert(#hit == 1 and hit[1] == ogre, "the ogre is caught a single time")
        end,
    },
    {
        name = "a wide body is a legal melee target from beside any of its cells",
        fn = function()
            -- Knight at (5,3) is adjacent to the ogre's near cell (4,3), though two tiles from its anchor.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 5, 3) },
                { unit("character_ogre", 3, 3) })
            local knight = c.units[1]
            knight.char.inventory[1] = Item.instantiate("weapon_iron_sword")
            local reach = Combat.attackReach(c, knight, 1, {}) -- range 1, no move
            assert(reach["4,3"], "the ogre's near cell is within the knight's melee reach")
            -- And useItem accepts a strike aimed at that near cell.
            openTurn(c, knight)
            local ok = Combat.useItem(c, knight, knight.char.inventory[1], 4, 3)
            assert(ok, "the melee strike on the ogre's near cell is legal")
        end,
    },
    {
        name = "swapping bodies of different sizes is refused when the wide one wouldn't fit",
        fn = function()
            -- Knight in the far corner: swapping would push the ogre's 2x2 off the board edge.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 8, 8) },
                { unit("character_ogre", 3, 3) })
            local ogre = named(c, "Ogre")
            local knight = c.units[1]
            assert(not Combat.swapUnits(c, ogre, knight), "a swap that can't seat the wide body is refused")
            assert(ogre.x == 3 and knight.x == 8, "nothing moved on the refused swap")

            -- Knight in open space: the ogre fits at its tile, so the swap goes through.
            local c2 = Combat.new(arena(8, 8), { unit("character_knight", 5, 5) },
                { unit("character_ogre", 1, 1) })
            local ogre2 = named(c2, "Ogre")
            local knight2 = c2.units[1]
            assert(Combat.swapUnits(c2, ogre2, knight2), "a swap with room for the wide body succeeds")
            assert(ogre2.x == 5 and ogre2.y == 5, "the ogre took the knight's tile")
            assert(knight2.x == 1 and knight2.y == 1, "the knight took the ogre's anchor")
        end,
    },
    {
        name = "an ordinary 1x1 character is unchanged: single cell, single occupancy",
        fn = function()
            local c = Combat.new(arena(8, 8), {}, { unit("character_knight", 4, 4) })
            local knight = c.units[1]
            assert(knight.w == 1 and knight.h == 1, "no footprint means 1x1")
            assert(#Combat.unitCells(knight) == 1, "one cell")
            assert(Combat.unitAt(c, 4, 4) == knight and Combat.unitAt(c, 5, 4) == nil,
                "occupancy is the single anchor cell")
        end,
    },
}
