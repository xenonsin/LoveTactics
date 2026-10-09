-- WHERE A CAST WHOSE MARK IS THE FLOOR IS WORTH AIMING (models/ai.lua's `aiAims`). The planner offers a
-- tile-targeted cast only the cells a body stands on, which is right for a blow and blind to a verb that
-- leaves something on EMPTY ground: a summon, a sentry, a totem, a buried charge, a snare stake. Each such
-- ability names the cells worth trying through `aiAims = function(combat, unit)`; these are the three
-- shapes the adventurer bodies need ("The Rift's Adventurers", slice C, 2026-10-09). Small lists on
-- purpose: every cell is previewed from every stand tile.
--
-- Requires nothing at file scope: an item blueprint names these, and models/combat.lua requires the
-- item registry, so the combat module is asked for lazily, inside each call.

local Aims = {}

local ORTHO = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function openAt(combat, x, y)
    local Combat = require("models.combat")
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    return cell ~= nil and cell.walkable ~= false and Combat.unitAt(combat, x, y) == nil
end

-- Open ground orthogonally beside each body in `bodies`, without repeats.
local function besideAll(combat, bodies)
    local out, seen = {}, {}
    for _, b in ipairs(bodies) do
        for _, d in ipairs(ORTHO) do
            local x, y = b.x + d[1], b.y + d[2]
            local key = x .. "," .. y
            if not seen[key] and openAt(combat, x, y) then
                seen[key] = true
                out[#out + 1] = { x = x, y = y }
            end
        end
    end
    return out
end

-- Open ground beside the caster: where a sentry is set down or a spirit called.
function Aims.beside(combat, unit)
    return besideAll(combat, { unit })
end

-- Open ground beside a foe within `reach` of the caster: the square it steps onto next, which is where
-- a charge or a snare is buried.
function Aims.besideFoes(combat, unit, reach)
    local foes = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side
            and math.abs(u.x - unit.x) + math.abs(u.y - unit.y) <= (reach or 6) then
            foes[#foes + 1] = u
        end
    end
    return besideAll(combat, foes)
end

-- Open ground beside the caster's own side, the caster included: where a totem's zone covers the line.
function Aims.besideAllies(combat, unit)
    local own = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == unit.side and not u.summoned then own[#own + 1] = u end
    end
    return besideAll(combat, own)
end

return Aims
