-- THE MARCH: one free step toward the nearest foe (2026-09-26, "The Orcs of Wrath"). Two things take it:
--
--   the War-Drummer   every other turn its drum sounds and every orc on its side steps
--                     (data/traits/trait_the_march.lua)
--   Marching Drum     its drop: every ally steps, and the drum chooses the way, not the player
--                     (data/items/ability/ability_marching_drum.lua; Keno's round-2 note, "have the step be
--                     forced")
--
-- March.stepTile is a pure read -- where the step would land, or nil -- so a cast can hand it to fx.teleport and
-- the hover preview moves nobody.
local March = {}

local ORTHO = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

-- The nearest living foe of `unit` that stands on the board, or nil.
function March.nearestFoe(combat, unit)
    local Combat = require("models.combat")
    local best, bestD
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other.side ~= unit.side and not Combat.isOffTile(other) then
            local d = Combat.unitGap(unit, other)
            if not bestD or d < bestD then best, bestD = other, d end
        end
    end
    return best, bestD
end

-- The open orthogonal tile one step nearer `unit`'s nearest foe, or nil: already beside it, rooted, a large
-- body, or hemmed in. A step never lands farther away, and never on a body.
function March.stepTile(combat, unit)
    local Combat = require("models.combat")
    local Status = require("models.status")
    if not (unit and unit.alive) or Combat.isOffTile(unit) then return nil end
    local fp = unit.char and unit.char.footprint
    if (fp and ((fp.w or 1) > 1 or (fp.h or 1) > 1)) or Status.has(unit, "status_root") then return nil end
    local foe, gap = March.nearestFoe(combat, unit)
    if not foe or gap <= 1 then return nil end
    local best, bestD
    for _, d in ipairs(ORTHO) do
        local nx, ny = unit.x + d[1], unit.y + d[2]
        if Combat.footprintFree(combat, 1, 1, nx, ny, unit) then
            local nd = Combat.cellGap(nx, ny, foe)
            if nd < gap and (not bestD or nd < bestD) then best, bestD = { x = nx, y = ny }, nd end
        end
    end
    return best
end

-- Step every living body in `bodies`, in order, so a step frees the tile the next one wants. `move(unit, x, y)`
-- does the moving (fx.teleport from a cast, Combat.teleportUnit from a trait). Returns how many stepped.
function March.stepAll(combat, bodies, move)
    local n = 0
    for _, u in ipairs(bodies) do
        local tile = March.stepTile(combat, u)
        if tile then
            move(u, tile.x, tile.y)
            n = n + 1
        end
    end
    return n
end

return March
