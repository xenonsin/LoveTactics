-- FIGHT CONDITIONS: the weather and the ground a whole fight is fought in -- Darkness, Rain, Fog, Burning
-- Ground, Tremors, Deep Water (approved 2026-10-24, "variety in the fight itself"). One per fight at most,
-- rolled with the rest of the fight's dressing (models/dressing.lua) and stamped on the cell, so the map,
-- the deploy screen and the board all name the same one.
--
-- FOUR SEAMS, each one an existing mechanic worn by the whole board rather than a new rule:
--   rules   a rule bag every body wears (Fog and Darkness are the Long Shadow's horizon, `longShadow`,
--           which Status.concealedAt and Combat.abilityRange already enforce for both sides and the AI's
--           stand-tile search reads). Folded in Combat's applyUnitPassives off `unit.fieldCondition`,
--           which Combat.applyPassives and Combat.addUnit stamp -- so a wave walking on in fog is in fog.
--   soak    a status every body is kept in (Rain keeps everyone Wet), applied at the bell and each turn.
--   ignite / rubble   a hazard or a wall set down on empty ground each turn (Burning Ground, Tremors).
--   band    terrain laid across the board when it is cut (Deep Water's ford), in Arena.build.
--
-- "Each turn" is a turn's worth of the fight's clock (Status.TICKS_PER_TURN), asked at every turn start
-- (Combat.startTurn -> Condition.tick). Draws come off the condition's own generator, seeded from the
-- arena, so it never moves the accuracy stream and one seed still reproduces the fight.
--
-- Pure: no love.graphics, so it loads under the headless tests.
local Registry = require("models.registry")

local Condition = {}

Condition.defs = Registry.load("data/conditions", "data.conditions")

function Condition.ids()
    local ids = {}
    for id in pairs(Condition.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- HOW OFTEN A FIGHT IS FOUGHT IN ONE: a quarter of eligible fights.
Condition.CHANCE = 0.25

Condition.SALT = 6911

function Condition.of(combat)
    local id = combat and combat.condition
    return id and Condition.defs[id] or nil, id
end

-- The rule bag a body in this fight wears, or nil.
function Condition.rules(unit)
    local def = unit and unit.fieldCondition and Condition.defs[unit.fieldCondition]
    return def and def.rules or nil
end

-- Fold the condition's rules into a unit's already-merged rule bag. The horizon is a CEILING, so where a
-- body already wears one (the Long Shadow relic) the nearer of the two holds; everything else merges the
-- way gear and relics do (Item.mergeRules: summed rules sum, first-wins for the rest).
function Condition.foldRules(unit, rules)
    local add = Condition.rules(unit)
    if not add then return rules end
    local horizon = rules and rules.longShadow
    rules = require("models.item").mergeRules(rules or {}, add)
    if type(horizon) == "number" and type(add.longShadow) == "number" then
        rules.longShadow = math.min(horizon, add.longShadow)
    end
    return rules
end

-- ---------------------------------------------------------------------------
-- The board
-- ---------------------------------------------------------------------------

-- Lay a condition's terrain band on a layout before it is hydrated (Arena.build). `layout.tiles` is
-- COPIED row by row first: a curated layout's tiles belong to its blueprint, and writing water into them
-- would flood every later fight on that board. Only plain ground strictly between the two sides' mean rows
-- is turned, never a tile somebody is seated on or a prop stands on. Returns the tiles turned.
function Condition.layBand(id, layout, party, enemies, taken)
    local def = id and Condition.defs[id]
    local band = def and def.band
    if not (band and layout and layout.tiles) then return {} end
    local function meanY(list)
        local s, n = 0, 0
        for _, u in ipairs(list or {}) do s, n = s + u.y, n + 1 end
        return n > 0 and s / n or nil
    end
    local py = meanY(party) or meanY(layout.partySpawns) or layout.rows
    local ey = meanY(enemies) or meanY(layout.enemySpawns) or 1
    local mid = math.floor((py + ey) / 2 + 0.5)
    local lo, hi = math.min(py, ey), math.max(py, ey)
    local rows = {}
    for k = 0, (band.rows or 1) - 1 do
        local y = mid + k
        if y > lo and y < hi and y >= 1 and y <= layout.rows then rows[#rows + 1] = y end
    end
    if #rows == 0 and mid >= 1 and mid <= layout.rows then rows[1] = mid end

    local copy = {}
    for y = 1, layout.rows do
        copy[y] = {}
        for x = 1, layout.cols do copy[y][x] = layout.tiles[y] and layout.tiles[y][x] or "ground" end
    end
    layout.tiles = copy
    local key = function(x, y) return x .. "," .. y end
    local turned = {}
    for _, y in ipairs(rows) do
        for x = 1, layout.cols do
            if copy[y][x] == "ground" and not (taken and taken[key(x, y)]) then
                copy[y][x] = band.terrain or "water"
                turned[#turned + 1] = { x = x, y = y }
            end
        end
    end
    return turned
end

-- ---------------------------------------------------------------------------
-- The fight
-- ---------------------------------------------------------------------------

local function rng(combat)
    if not combat.conditionRng then
        local Combat = require("models.combat")
        combat.conditionRng = Combat.newRandom(((combat.arena and combat.arena.seed) or 1) + Condition.SALT)
    end
    return combat.conditionRng
end

-- Empty ground: walkable, nobody on it, no wall, no prop, no hazard, and not ground the objective is
-- decided on -- a fire or a slab on the hold tile would rewrite the fight's own win.
local function emptyTiles(combat)
    local Combat = require("models.combat")
    local Hazard = require("models.hazard")
    local Wall = require("models.wall")
    local marked = {}
    for _, t in ipairs(Combat.objectiveGround(combat) or {}) do marked[t.x .. "," .. t.y] = true end
    for _, t in ipairs((combat.objective and combat.objective.escapeTiles) or {}) do marked[t.x .. "," .. t.y] = true end
    local tiles = combat.arena and combat.arena.tiles or {}
    local out = {}
    for y = 1, #tiles do
        for x = 1, #(tiles[y] or {}) do
            local cell = tiles[y][x]
            if cell and cell.walkable and not marked[x .. "," .. y]
                and not Combat.unitAt(combat, x, y) and not Wall.at(combat, x, y)
                and not Combat.objectBlocksAt(combat, x, y)
                and #(Hazard.allAt(combat, x, y) or {}) == 0 then
                out[#out + 1] = { x = x, y = y }
            end
        end
    end
    return out
end

local function draw(combat, list)
    if #list == 0 then return nil end
    return table.remove(list, rng(combat)(#list))
end

local function soak(combat, def)
    if not def.soak then return end
    local Status = require("models.status")
    for _, u in ipairs(combat.units or {}) do
        if u.alive and not Status.has(u, def.soak) then Status.apply(combat, u, def.soak) end
    end
end

-- At the bell (Combat.openBattle): soak the board, and name the condition in the log.
function Condition.open(combat)
    local def = Condition.of(combat)
    if not def then return end
    combat.conditionNextAt = require("models.status").TICKS_PER_TURN
    require("models.combat").logEvent(combat, "system", def.name .. ": " .. def.description)
    soak(combat, def)
end

-- Once a turn's worth of clock has passed: the rain re-soaks, the ground catches, the roof comes down.
-- Asked at every turn start; acts at most once per call, so a long clock jump never drops three fires.
function Condition.tick(combat)
    local def = Condition.of(combat)
    if not (def and combat.opened) then return false end
    local Status = require("models.status")
    combat.conditionNextAt = combat.conditionNextAt or Status.TICKS_PER_TURN
    if (combat.clock or 0) < combat.conditionNextAt then return false end
    combat.conditionNextAt = (combat.clock or 0) + Status.TICKS_PER_TURN
    combat.conditionTicks = (combat.conditionTicks or 0) + 1

    soak(combat, def)
    if def.ignite then
        local Hazard = require("models.hazard")
        local open = emptyTiles(combat)
        for _ = 1, def.ignite.count or 1 do
            local t = draw(combat, open)
            if not t then break end
            Hazard.place(combat, t.x, t.y, def.ignite.hazard or "hazard_fire", {})
        end
    end
    if def.rubble then
        local Wall = require("models.wall")
        combat.conditionRubble = combat.conditionRubble or 0
        if combat.conditionRubble < (def.rubble.max or 6) then
            local open = emptyTiles(combat)
            for _ = 1, def.rubble.count or 1 do
                local t = draw(combat, open)
                if not t then break end
                if Wall.place(combat, t.x, t.y, def.rubble.wall or "rubble", { side = "neutral" }) then
                    combat.conditionRubble = combat.conditionRubble + 1
                end
            end
        end
    end
    return true
end

-- What the deploy screen and the HUD say: "Fog: Nothing can be aimed at from more than 3 tiles away."
function Condition.line(id)
    local def = id and Condition.defs[id]
    if not def then return nil end
    return def.name .. ": " .. def.description
end

return Condition
