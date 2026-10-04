-- THE GLASS PALACE: the Snow Queen's second rule, on her organ (utility_glass_palace). "Sloth's Bestiary",
-- 2026-10-04, approved: "each round she raises a 3-tile ice wall, telegraphed a turn ahead, cutting the board into
-- rooms; fire melts a wall."
--
-- AT THE END OF EACH OF HER TURNS she marks three tiles in a line with Rising Ice (hazard_rising_ice), which rises a
-- turn later as Ice Walls (data/walls/ice_wall.lua). THE LINE IS LAID THROUGH THE COMPANY: through the middle of the
-- foes she faces, across the way they are spread out -- so it falls between them and cuts the board into rooms
-- rather than walling an empty corner. With one foe left she cuts between it and herself.
--
-- Fire puts the telegraph out and melts a risen wall (Hazard.douse, Wall.meltIn). `notAReaction`: a stunned queen's
-- palace still grows.
local LENGTH = 3

local function round(v) return math.floor(v + 0.5) end

-- The tiles the next wall will stand on: three in a line through the company's middle, across its longer spread.
local function plan(combat, queen)
    local Combat = require("models.combat")
    local pts = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= queen.side and not Combat.isOffTile(u) then pts[#pts + 1] = u end
    end
    if #pts == 0 then return {} end
    if #pts < 2 then pts[#pts + 1] = queen end
    local sx, sy = 0, 0
    local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
    for _, u in ipairs(pts) do
        sx, sy = sx + u.x, sy + u.y
        minx, maxx = math.min(minx, u.x), math.max(maxx, u.x)
        miny, maxy = math.min(miny, u.y), math.max(maxy, u.y)
    end
    local cx, cy = round(sx / #pts), round(sy / #pts)
    -- Spread wider than tall: a wall standing up and down cuts the left from the right.
    local upright = (maxx - minx) >= (maxy - miny)
    local cells, half = {}, math.floor(LENGTH / 2)
    for i = -half, LENGTH - 1 - half do
        cells[#cells + 1] = upright and { x = cx, y = cy + i } or { x = cx + i, y = cy }
    end
    return cells
end

return {
    name = "The Glass Palace",
    description = "At the end of its turn, marks 3 tiles in a line through its foes; a turn later they become Ice Walls.",
    notAReaction = true,
    plan = plan,
    onTurnEnd = function(ctx)
        local combat, queen = ctx.combat, ctx.unit
        if not (combat and queen and queen.alive) then return end
        local tiles = combat.arena and combat.arena.tiles
        local Combat = require("models.combat")
        local laid = 0
        for _, c in ipairs(plan(combat, queen)) do
            local cell = tiles and tiles[c.y] and tiles[c.y][c.x]
            if cell and cell.walkable and not Combat.objectAt(combat, c.x, c.y) then
                ctx.placeHazard(c.x, c.y, "hazard_rising_ice", { side = queen.side })
                laid = laid + 1
            end
        end
        if laid > 0 then
            ctx.log("action", string.format("The ice gathers where %s means to build.",
                (queen.char and queen.char.name) or "the Queen"), queen)
        end
    end,
}
