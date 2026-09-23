-- The grove: what counts as a PLANT on a fight board, for the Dryad line's kit.
--
-- A fight board is eight by eight with a few blockers scattered on it, so a line whose spells were
-- written against the building's walls ("step into the timber at any wall") would have had almost
-- nothing to stand beside. The Dryad line grows its own cover instead, and every spell that moves a body
-- "through the grain" asks this file where the grain is:
--
--   * a PLANT BODY -- a sapling the Nymph's Seedfall planted, the Hamadryad's Heartwood Tree, or a
--     Mandrake. Any body whose blueprint declares `plant = true`;
--   * a HEDGE -- any living conjured wall tagged `nature` (data/walls/hedge.lua, Quickset's);
--   * a THORN FLOOR -- any live zone tagged `nature` that the board is carrying (Briarfloor).
--
-- Pure logic with lazy requires, as models/hazard.lua and models/wall.lua are, so it loads under the
-- headless suite and never sits in a require cycle with models/combat.lua.
local Grove = {}

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Is `unit` a plant body -- a living thing the grain runs through?
function Grove.isPlant(unit)
    return unit ~= nil and unit.alive and unit.char ~= nil and unit.char.plant == true
end

-- Every tile on the board a plant stands on: plant bodies, nature-tagged walls, nature-tagged zones.
-- `side`, when given, keeps only what belongs to that side -- a Nymph steps into her own grove, not the
-- company's.
function Grove.cells(combat, side)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if Grove.isPlant(u) and (not side or u.side == side) then out[#out + 1] = { x = u.x, y = u.y } end
    end
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and hasTag(w.tags or (w.def and w.def.tags), "nature") and (not side or w.side == side) then
            out[#out + 1] = { x = w.x, y = w.y }
        end
    end
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and hasTag(h.def and h.def.tags, "nature") and (not side or h.side == side) then
            out[#out + 1] = { x = h.x, y = h.y }
        end
    end
    return out
end

-- Is (x, y) beside a plant -- or ON one, for a thorn floor a body can stand in?
function Grove.besidePlant(combat, x, y, side)
    for _, c in ipairs(Grove.cells(combat, side)) do
        if math.max(math.abs(c.x - x), math.abs(c.y - y)) <= 1 then return true end
    end
    return false
end

-- Every free tile a body could step out of the grain onto: free ground (Combat.footprintFree) beside a
-- plant of `side`, within `range` of (fromX, fromY) when a range is given.
function Grove.exits(combat, side, fromX, fromY, range)
    local Combat = require("models.combat")
    local seen, out = {}, {}
    for _, c in ipairs(Grove.cells(combat, side)) do
        for dy = -1, 1 do
            for dx = -1, 1 do
                local x, y = c.x + dx, c.y + dy
                local key = x .. "," .. y
                if not seen[key] then
                    seen[key] = true
                    local inRange = not range
                        or math.max(math.abs(x - fromX), math.abs(y - fromY)) <= range
                    if inRange and Combat.footprintFree(combat, 1, 1, x, y) then
                        out[#out + 1] = { x = x, y = y }
                    end
                end
            end
        end
    end
    return out
end

-- The exit farthest from every body of `awayFrom`'s side -- the tile that puts the most ground between
-- a body and whoever it is running from (the Nymph's Greenstep), or that strands a body farthest from
-- its own friends (the Hamadryad's Through the Grain). Ties go to board order, so it is deterministic.
function Grove.farthestFrom(combat, exits, awayFrom)
    local best, bestScore
    for _, e in ipairs(exits) do
        local nearest = math.huge
        for _, u in ipairs(combat.units or {}) do
            if u.alive and awayFrom(u) then
                local d = math.max(math.abs(u.x - e.x), math.abs(u.y - e.y))
                if d < nearest then nearest = d end
            end
        end
        if not bestScore or nearest > bestScore then best, bestScore = e, nearest end
    end
    return best
end

return Grove
