-- THE GOLEMS OF GREED: the rules the Earth Golem and the Gold Golem share with the pieces that drop off
-- them. Reviewed over two rounds on 2026-09-25 ("The Golems of Greed" artifact). They are the MOUNTAIN'S
-- golems: nobody built them, they are the rock the gold grew in, stood up.
--
-- One model and not a block per file, because the same five acts are asked of seven blueprints:
--   the VEIN     a golem that Delves (the Delver's own ability_delve) breaks the rock it sank through,
--                and the hole it leaves is a coin heap -- or, one time in three, a lava pit (round 2's
--                reading of "chance to spawn lava"). The dwarf's third dive is still the only cave-in.
--   the PLATE    a slab knocked off by a blow of weight lands on the tile beside it, as rubble or as gold
--   the HEAP     a Gold Golem eats one to heal and plate itself (Regild), and heaps within 4 slide
--                toward it at the start of its turn (Gold Calls to Gold)
--   the TAKE     Heart of Gold heals whoever takes gold or goods off a foe, once a turn
--   the MINE     Veinfinder turns an obstacle into a coin heap (the fx.mine verb, models/combat.lua)
--
-- Every act that touches the board is reached from a live hook -- a trait, a status, a resolved channel,
-- or the fx.mine verb -- and never from an item effect's own body, because a preview replays that body
-- against the real board.
local Status = require("models.status")

-- Combat and Hazard reached LAZILY, as models/stoop.lua does: item and trait blueprints require this
-- file while models/combat.lua is itself still being required.
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })
local Hazard = setmetatable({}, { __index = function(_, k) return require("models.hazard")[k] end })

local Golem = {}

-- What a heap a golem breaks open is worth: the floor's own heap (hazard_coin_heap's HEAP_GOLD).
Golem.HEAP_GOLD = 10
-- One surfacing in LAVA_ODDS strikes lava instead of gold.
Golem.LAVA_ODDS = 3
-- A Gold Golem that eats a heap, and a Heart of Gold that takes something, each heal this share of max.
Golem.HEAL_SHARE = 0.15
-- How far Gold Calls to Gold reaches, and how many heaps the Hoard spills.
Golem.CALL_REACH = 4
Golem.HOARD_HEAPS = 4
-- The terrain a Veinfinder may break: solid rock and what grows as a wall, never water and never lava.
Golem.MINEABLE = { rock = true, mountain = true, thicket = true }

local RING = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }

local function name(u) return (u and u.char and u.char.name) or "It" end

local function cellAt(combat, x, y)
    local tiles = combat and combat.arena and combat.arena.tiles
    return tiles and tiles[y] and tiles[y][x]
end

function Golem.hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

-- Nothing standing on it, nothing built on it, no ground laid on it, and it can be walked on.
function Golem.clear(combat, x, y)
    local cell = cellAt(combat, x, y)
    return cell ~= nil and cell.walkable and not Combat.unitAt(combat, x, y)
        and not Combat.objectAt(combat, x, y) and #Hazard.allAt(combat, x, y) == 0
end

-- The clear tile beside (x, y) furthest from `away` (a body or a point) -- where a shed slab lands, "away
-- from the attacker". With no `away`, the first clear tile in a fixed order. nil when all eight are taken.
function Golem.tileBeside(combat, x, y, away)
    local best, bestD
    for _, d in ipairs(RING) do
        local nx, ny = x + d[1], y + d[2]
        if Golem.clear(combat, nx, ny) then
            local dist = away and (math.abs(nx - away.x) + math.abs(ny - away.y)) or 0
            if not bestD or dist > bestD then best, bestD = { x = nx, y = ny }, dist end
        end
    end
    return best
end

function Golem.heap(combat, x, y, amount)
    return Hazard.place(combat, x, y, "hazard_coin_heap", { amount = amount or Golem.HEAP_GOLD })
end

-- Turn a clear tile to lava: the cave's own impassable tile (status_cave_in lays it the same way).
function Golem.lava(combat, x, y)
    local cell = cellAt(combat, x, y)
    if not (cell and Golem.clear(combat, x, y)) then return false end
    local lava = require("models.terrain").get("lava")
    cell.type = "lava"
    cell.moveCost = lava.moveCost
    cell.walkable = lava.walkable
    cell.sightCost = lava.sightCost or 0
    cell.bonus = lava.bonus
    cell.tags = lava.tags
    cell.swim, cell.drowns = nil, nil
    return true
end

-- STRIKE THE VEIN: the hole a delving golem left at (x, y). Gold, or one time in three, lava.
function Golem.strikeVein(combat, unit, x, y)
    if not (x and y and Golem.clear(combat, x, y)) then return nil end
    if Combat.roll(combat, Golem.LAVA_ODDS) == 1 and Golem.lava(combat, x, y) then
        Combat.logEvent(combat, "action",
            string.format("%s broke into something hot: the hole behind it runs molten.", name(unit)), unit)
        return "lava"
    end
    Golem.heap(combat, x, y)
    Combat.logEvent(combat, "action",
        string.format("%s struck a vein: gold spills out of the hole behind it.", name(unit)), unit)
    return "heap"
end

-- REGILD: a Gold Golem eats a heap. It heals, and the gold goes back on as a plate.
function Golem.eat(combat, unit, heap)
    local hp = unit.char.stats.health
    Combat.applyHeal(combat, unit, math.ceil(hp.max * Golem.HEAL_SHARE))
    Status.apply(combat, unit, "status_gold_plate", { magnitude = 1 })
    if heap then Hazard.consume(combat, heap) end
    Combat.logEvent(combat, "action", string.format("%s eats the gold and is gilded again.", name(unit)), unit)
end

-- HEART OF GOLD: `unit` took gold or goods off a foe (a heap, a theft, gold chipped off a golem). A
-- bearer heals once a turn; everyone else is untouched. Called from each seam that pays a taker.
function Golem.took(combat, unit)
    if not (combat and unit and unit.alive and unit.char) then return false end
    local Trait = require("models.trait")
    if not Trait.flag(unit, "healsOnTake") or Status.has(unit, "status_heart_fed") then return false end
    local hp = unit.char.stats.health
    local healed = Combat.applyHeal(combat, unit, math.ceil(hp.max * Golem.HEAL_SHARE))
    Status.apply(combat, unit, "status_heart_fed")
    Combat.logEvent(combat, "action", string.format("%s's Heart of Gold warms it.", name(unit)), unit)
    return healed
end

-- GOLD CALLS TO GOLD: every heap within CALL_REACH of `unit` slides one tile toward it. A heap that
-- slides onto the golem is eaten; a heap never slides onto another body, a wall, or other ground.
function Golem.callGold(combat, unit)
    local moved = 0
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.id == "hazard_coin_heap" then
            local dx, dy = unit.x - h.x, unit.y - h.y
            if math.max(math.abs(dx), math.abs(dy)) <= Golem.CALL_REACH and (dx ~= 0 or dy ~= 0) then
                local nx = h.x + (dx > 0 and 1 or dx < 0 and -1 or 0)
                local ny = h.y + (dy > 0 and 1 or dy < 0 and -1 or 0)
                if nx == unit.x and ny == unit.y then
                    Golem.eat(combat, unit, h)
                    moved = moved + 1
                elseif Golem.clear(combat, nx, ny) then
                    h.x, h.y = nx, ny
                    moved = moved + 1
                end
            end
        end
    end
    if moved > 0 then
        Combat.logEvent(combat, "action", string.format("The gold on the floor creeps toward %s.", name(unit)), unit)
    end
    return moved
end

-- THE HOARD FALLS OUT: HOARD_HEAPS heaps on the clear tiles around where `unit` fell, nearest first.
function Golem.spillHoard(combat, unit)
    local placed = 0
    for radius = 1, 3 do
        for dy = -radius, radius do
            for dx = -radius, radius do
                if placed < Golem.HOARD_HEAPS and math.max(math.abs(dx), math.abs(dy)) == radius then
                    local x, y = unit.x + dx, unit.y + dy
                    if Golem.clear(combat, x, y) and Golem.heap(combat, x, y) then placed = placed + 1 end
                end
            end
        end
    end
    if placed > 0 then
        Combat.logEvent(combat, "action",
            string.format("%s breaks apart, and its hoard spills across the floor.", name(unit)), unit)
    end
    return placed
end

-- Is there something on (x, y) a Veinfinder could mine: a standing object, or solid rock, with no body
-- on it? Asked by Combat.useItem and the battle screen's aim for an `aimsObstacle` cast.
function Golem.mineable(combat, x, y)
    local cell = cellAt(combat, x, y)
    if not cell or Combat.unitAt(combat, x, y) then return false end
    if Combat.objectAt(combat, x, y) then return true end
    return not cell.walkable and Golem.MINEABLE[cell.type] == true
end

-- VEINFINDER, live half: mine the obstacle on (x, y) -- a wall, a standing object, or solid rock -- and
-- leave a coin heap where it stood. False when there is nothing there to mine.
function Golem.mine(combat, unit, x, y)
    local cell = cellAt(combat, x, y)
    if not cell then return false end
    local obj, kind = Combat.objectAt(combat, x, y)
    if obj then
        Combat.damageObject(combat, obj, kind, 9999, unit)
        if obj.alive then obj.alive = false; obj.health = 0 end
    elseif not cell.walkable and Golem.MINEABLE[cell.type] then
        local rough = require("models.terrain").get("rough")
        cell.type = "rough"
        cell.moveCost = rough.moveCost
        cell.walkable = rough.walkable
        cell.sightCost = rough.sightCost or 0
        cell.bonus = rough.bonus
        cell.tags = rough.tags
    else
        return false
    end
    if not Combat.unitAt(combat, x, y) then Golem.heap(combat, x, y) end
    Combat.logEvent(combat, "action", string.format("%s mines the rock open: there is gold in it.", name(unit)), unit)
    return true
end

return Golem
