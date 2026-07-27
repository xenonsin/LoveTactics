-- Tests for ui/footprint_diagram.lua's geometry -- the preview picture of an ability's area shape.
-- It mirrors the shape math in Combat.aoeCells (caster facing north), so these cases pin the cell
-- sets and catch drift if the combat geometry ever changes underneath the preview. Headless: only the
-- pure `.cells` builder is exercised, never the love.graphics `.draw`.

local FootprintDiagram = require("ui.footprint_diagram")

-- A set membership test over the returned cells, keyed "x:y".
local function asSet(cells)
    local set = {}
    for _, c in ipairs(cells) do set[c.x .. ":" .. c.y] = c.role end
    return set
end

local function count(cells, role)
    local n = 0
    for _, c in ipairs(cells) do if c.role == role then n = n + 1 end end
    return n
end

return {
    {
        name = "a line grows from the aimed cell straight along the facing, plus the caster tile",
        fn = function()
            local cells = FootprintDiagram.cells({ shape = "line", length = 3 })
            local set = asSet(cells)
            assert(set["0:0"] == "caster", "the caster's own tile is marked")
            -- Facing north (dy = -1): aimed cell (0,-1), then (0,-2), (0,-3).
            assert(set["0:-1"] == "hit" and set["0:-2"] == "hit" and set["0:-3"] == "hit", "three tiles deep")
            assert(count(cells, "hit") == 3, "a length-3 line strikes exactly three tiles")
        end,
    },
    {
        name = "a cone fans one tile wider each row out",
        fn = function()
            local cells = FootprintDiagram.cells({ shape = "cone", length = 3 })
            local set = asSet(cells)
            -- Row 0 (i=0): just (0,-1). Row 1 (i=1): (-1,-2),(0,-2),(1,-2). Row 2 (i=2): x in -2..2 at y=-3.
            assert(set["0:-1"] == "hit", "the tip")
            assert(set["-1:-2"] and set["0:-2"] and set["1:-2"], "the middle row spans three")
            assert(set["-2:-3"] and set["2:-3"], "the back row reaches two either side")
            assert(count(cells, "hit") == 1 + 3 + 5, "a depth-3 cone is 1+3+5 tiles")
        end,
    },
    {
        name = "a front is a width-wide line perpendicular to the facing, centred on the aimed cell",
        fn = function()
            local cells = FootprintDiagram.cells({ shape = "front", width = 3 })
            local set = asSet(cells)
            -- Aimed cell (0,-1); perpendicular axis is x, so width 3 -> x in -1..1 at y=-1.
            assert(set["-1:-1"] and set["0:-1"] and set["1:-1"], "three tiles wide across the front")
            assert(count(cells, "hit") == 3, "width 3 strikes three tiles")
        end,
    },
    {
        name = "a diamond is a Manhattan blast centred on the aimed tile; a square fills its box",
        fn = function()
            local diamond = FootprintDiagram.cells({ shape = "diamond", radius = 1 })
            assert(count(diamond, "hit") == 5, "a radius-1 diamond is the plus of five tiles")
            local square = FootprintDiagram.cells({ shape = "square", radius = 1 })
            assert(count(square, "hit") == 9, "a radius-1 square fills the whole 3x3")
            local center = asSet(diamond)
            assert(center["0:0"] == "hit", "a centred blast has no separate caster tile")
        end,
    },
}
