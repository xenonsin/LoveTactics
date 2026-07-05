-- Turn-based combat logic. Pure model (no love.graphics; not even love.math), so it
-- loads under the headless tests, mirroring models/arena.lua and models/overworld.lua.
-- The battle state (states/battle.lua) and its renderer drive this module; all rules
-- live here.
--
-- Combat runs on a *timeline*. Each unit has a `time` (its position on the timeline);
-- the living unit with the LOWEST time acts next. A unit's starting time is its
-- initiative = the average `speed` of its ability items (items with an activeAbility).
-- Taking an action pushes the actor back down the timeline: a move costs the number of
-- tiles stepped, an item action costs its ability's `speed`. Lower time = acts sooner,
-- so light/fast kit acts more often.
--
--   local combat = Combat.new(arena, partyUnits, enemyUnits)  -- units: { { char, x, y }, ... }
--   local unit = Combat.currentUnit(combat)                   -- whose turn it is
--   Combat.moveUnit(combat, unit, x, y)                       -- or:
--   Combat.useItem(combat, unit, item, targetX, targetY)
--   local result = Combat.evaluate(combat)                    -- "win" | "loss" | nil
--
-- Item abilities carry an `effect(fx)` FUNCTION (see data/items/*.lua). useItem builds an
-- `fx` context with bound helpers (fx.damage / fx.heal / fx.unitsNear) so a data file
-- composes effects without requiring this module. All the damage/heal math lives in the
-- helpers (Combat.dealDamage / Combat.applyHeal).

local Combat = {}

-- Initiative fallback for a unit that carries no ability item at all.
Combat.DEFAULT_SPEED = 5

-- Deterministic tie-break when two units share a time: party before enemy, then order.
local SIDE_RANK = { party = 0, enemy = 1 }

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function key(x, y) return x .. "," .. y end

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Items in a character's inventory that define an active ability (the ones that feed
-- initiative and can be used as an action).
function Combat.abilityItems(char)
    local list = {}
    for _, item in ipairs(char.inventory or {}) do
        if item.activeAbility then list[#list + 1] = item end
    end
    return list
end

-- Initiative = average speed of the character's ability items (DEFAULT_SPEED if none).
function Combat.initiative(char)
    local items = Combat.abilityItems(char)
    if #items == 0 then return Combat.DEFAULT_SPEED end
    local sum = 0
    for _, item in ipairs(items) do
        sum = sum + (item.activeAbility.speed or Combat.DEFAULT_SPEED)
    end
    return sum / #items
end

-- Effective flat stat for a unit: the character's base plus aggregated item bonuses
-- (armor). Resource stats ({max,current}) are never read through here.
local function flatStat(unit, name)
    local base = unit.char.stats[name] or 0
    return base + ((unit.bonus and unit.bonus[name]) or 0)
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- Fold passive armor into each unit: aggregate `item.bonus` (flat stat bonuses) and
-- `item.resist` (tag -> flat damage reduction) onto the unit WITHOUT mutating the shared
-- character instance, so a member's base stats never drift battle-to-battle.
function Combat.applyPassives(combat)
    for _, unit in ipairs(combat.units) do
        unit.bonus, unit.resist = {}, {}
        for _, item in ipairs(unit.char.inventory or {}) do
            for stat, amount in pairs(item.bonus or {}) do
                unit.bonus[stat] = (unit.bonus[stat] or 0) + amount
            end
            for tag, amount in pairs(item.resist or {}) do
                unit.resist[tag] = (unit.resist[tag] or 0) + amount
            end
        end
    end
end

-- Build combat state. partyUnits/enemyUnits are lists of { char = <instance>, x, y }
-- (exactly what states/battle.lua keeps as partyUnits/enemyUnits).
function Combat.new(arena, partyUnits, enemyUnits)
    local combat = {
        arena = arena,
        objective = (arena and arena.objective) or { type = "killAll" },
        units = {},
        clock = 0,      -- highest time any unit has reached (drives `survive`)
        turnCount = 0,  -- number of actions taken
    }

    local function addSide(list, side)
        for _, u in ipairs(list or {}) do
            local unit = {
                char = u.char, side = side,
                x = u.x, y = u.y,
                time = Combat.initiative(u.char),
                alive = true,
            }
            unit.index = #combat.units + 1
            combat.units[unit.index] = unit
        end
    end
    addSide(partyUnits, "party")
    addSide(enemyUnits, "enemy")

    Combat.applyPassives(combat)
    return combat
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function Combat.unitAt(combat, x, y)
    for _, u in ipairs(combat.units) do
        if u.alive and u.x == x and u.y == y then return u end
    end
    return nil
end

function Combat.unitsNear(combat, x, y, radius)
    radius = radius or 0
    local out = {}
    for _, u in ipairs(combat.units) do
        if u.alive and manhattan(x, y, u.x, u.y) <= radius then out[#out + 1] = u end
    end
    return out
end

function Combat.aliveCount(combat, side)
    local n = 0
    for _, u in ipairs(combat.units) do
        if u.alive and (not side or u.side == side) then n = n + 1 end
    end
    return n
end

-- Living units ordered by turn: lowest time first, then the deterministic tie-break.
function Combat.turnOrder(combat)
    local order = {}
    for _, u in ipairs(combat.units) do
        if u.alive then order[#order + 1] = u end
    end
    table.sort(order, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        if a.side ~= b.side then return SIDE_RANK[a.side] < SIDE_RANK[b.side] end
        return a.index < b.index
    end)
    return order
end

function Combat.currentUnit(combat)
    return Combat.turnOrder(combat)[1]
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Tiles a unit can reach this turn: a Dijkstra over the arena weighted by tile
-- `moveCost`, budget = the unit's `movement`, blocked by non-walkable tiles and cells
-- occupied by other units. Returns `{ [key]= { x, y, cost, steps } }`, keyed by "x,y".
-- `cost` spends the movement budget (rough terrain costs more); `steps` is the tile count
-- of that path and is the TIME the move costs (the "1 time per tile" rule).
function Combat.reachable(combat, unit)
    local arena = combat.arena
    local budget = flatStat(unit, "movement")

    local best = {}
    local origin = { x = unit.x, y = unit.y, cost = 0, steps = 0 }
    best[key(unit.x, unit.y)] = origin
    local frontier = { origin }

    while #frontier > 0 do
        -- Pop the lowest-cost frontier node.
        local bi = 1
        for i = 2, #frontier do
            if frontier[i].cost < frontier[bi].cost then bi = i end
        end
        local cur = table.remove(frontier, bi)

        -- Skip stale entries (a cheaper path to this cell was found later).
        if best[key(cur.x, cur.y)] == cur then
            for _, d in ipairs(DIRS) do
                local nx, ny = cur.x + d[1], cur.y + d[2]
                if nx >= 1 and nx <= arena.cols and ny >= 1 and ny <= arena.rows then
                    local cell = arena.tiles[ny][nx]
                    if cell.walkable and not Combat.unitAt(combat, nx, ny) then
                        local ncost = cur.cost + cell.moveCost
                        if ncost <= budget then
                            local nk = key(nx, ny)
                            local existing = best[nk]
                            if not existing or ncost < existing.cost then
                                local node = { x = nx, y = ny, cost = ncost, steps = cur.steps + 1 }
                                best[nk] = node
                                frontier[#frontier + 1] = node
                            end
                        end
                    end
                end
            end
        end
    end

    best[key(unit.x, unit.y)] = nil -- the origin isn't a "move" target
    return best
end

-- Move a unit to (x, y) if reachable this turn; advances its timeline by the path length.
function Combat.moveUnit(combat, unit, x, y)
    if not unit.alive then return false, "dead" end
    local node = Combat.reachable(combat, unit)[key(x, y)]
    if not node then return false, "unreachable" end

    unit.x, unit.y = x, y
    unit.time = unit.time + node.steps
    combat.turnCount = combat.turnCount + 1
    combat.clock = math.max(combat.clock, unit.time)
    return true, node.steps
end

-- ---------------------------------------------------------------------------
-- Item actions + damage/heal helpers
-- ---------------------------------------------------------------------------

-- Every tag that applies to an attack from `item`: the item's own tags, any ability-level
-- tags, and per-cast tags passed by the effect (opts.tags).
local function collectTags(item, opts)
    local tags = {}
    for _, t in ipairs(item.tags or {}) do tags[#tags + 1] = t end
    local ab = item.activeAbility
    if ab and ab.tags then
        for _, t in ipairs(ab.tags) do tags[#tags + 1] = t end
    end
    if opts and opts.tags then
        for _, t in ipairs(opts.tags) do tags[#tags + 1] = t end
    end
    return tags
end

-- Apply tag-driven damage from `user` to `target`. The `magical` tag routes scaling to
-- magicDamage/magicDefense (else damage/defense); armor `resist` for each matching tag is
-- subtracted. Damage floors at 1. Drops the target to `alive = false` at 0 HP. Returns
-- the amount dealt. Reached through `fx.damage` inside an ability effect.
function Combat.dealDamage(combat, user, target, item, opts)
    opts = opts or {}
    local tags = collectTags(item, opts)
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local defStat = magical and "magicDefense" or "defense"

    local base = flatStat(user, atkStat) * (opts.power or 1.0)
    local defense = flatStat(target, defStat)
    local resist = 0
    for _, t in ipairs(tags) do
        resist = resist + ((target.resist and target.resist[t]) or 0)
    end

    local dmg = math.max(1, math.floor(base - defense - resist + 0.5))
    local hp = target.char.stats.health
    hp.current = hp.current - dmg
    if hp.current <= 0 then
        hp.current = 0
        target.alive = false
    end
    return dmg
end

-- Restore health to `target`, capped at its max. Returns the amount actually healed.
-- Reached through `fx.heal` inside an ability effect.
function Combat.applyHeal(_, target, amount)
    local hp = target.char.stats.health
    local before = hp.current
    hp.current = math.min(hp.max, hp.current + (amount or 0))
    return hp.current - before
end

-- Living units a unit may target with `item`'s ability, by range + target kind.
function Combat.abilityTargets(combat, unit, item)
    local ab = item.activeAbility
    if not ab then return {} end
    local out = {}
    for _, other in ipairs(combat.units) do
        if other.alive and manhattan(unit.x, unit.y, other.x, other.y) <= (ab.range or 1) then
            local valid = false
            if ab.target == "enemy" then valid = other.side ~= unit.side
            elseif ab.target == "ally" then valid = other.side == unit.side -- includes self
            elseif ab.target == "self" then valid = other == unit end
            if valid then out[#out + 1] = other end
        end
    end
    return out
end

local function resourceValue(char, stat)
    local res = char.stats[stat]
    if type(res) == "table" then return res.current end
    return res or 0
end

local function spendResource(char, stat, amount)
    local res = char.stats[stat]
    if type(res) == "table" then res.current = res.current - amount
    else char.stats[stat] = (res or 0) - amount end
end

-- Perform an item action: validate range + target kind + resource cost, spend the cost,
-- run the ability's effect(fx), push the actor back by the ability speed, and consume the
-- item if it's a consumable. Returns (true, result) or (false, reason). `result` is
-- { damageDealt, healed } aggregated across the effect's helper calls.
function Combat.useItem(combat, unit, item, tx, ty)
    if not unit.alive then return false, "dead" end
    local ab = item.activeAbility
    if not ab then return false, "no ability" end

    if manhattan(unit.x, unit.y, tx, ty) > (ab.range or 1) then
        return false, "out of range"
    end

    local target = Combat.unitAt(combat, tx, ty)
    if target then
        if ab.target == "enemy" and target.side == unit.side then return false, "invalid target" end
        if ab.target == "ally" and target.side ~= unit.side then return false, "invalid target" end
        if ab.target == "self" and target ~= unit then return false, "invalid target" end
    end

    if ab.cost and resourceValue(unit.char, ab.cost.stat) < ab.cost.amount then
        return false, "insufficient " .. ab.cost.stat
    end
    if ab.cost then spendResource(unit.char, ab.cost.stat, ab.cost.amount) end

    -- Effect context: bound helpers let a data-file effect compose damage/heal/AoE
    -- without touching this module. Results are accumulated for the caller/UI.
    local result = { damageDealt = 0, healed = 0 }
    local fx = {
        user = unit, target = target, item = item, combat = combat,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        damage = function(tgt, opts)
            if not tgt then return 0 end
            local d = Combat.dealDamage(combat, unit, tgt, item, opts)
            result.damageDealt = result.damageDealt + d
            return d
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local h = Combat.applyHeal(combat, tgt, amount)
            result.healed = result.healed + h
            return h
        end,
    }
    if ab.effect then ab.effect(fx) end

    unit.time = unit.time + (ab.speed or Combat.DEFAULT_SPEED)
    combat.turnCount = combat.turnCount + 1
    combat.clock = math.max(combat.clock, unit.time)

    if ab.consumesItem then
        for i, it in ipairs(unit.char.inventory) do
            if it == item then table.remove(unit.char.inventory, i); break end
        end
    end

    return true, result
end

-- ---------------------------------------------------------------------------
-- Objective evaluation
-- ---------------------------------------------------------------------------

-- Resolve the arena objective to "win" / "loss" / nil. A total party wipe is always a
-- loss. Called after each action so the battle state can fire onWin/onLoss.
function Combat.evaluate(combat)
    if Combat.aliveCount(combat, "party") == 0 then return "loss" end

    local obj = combat.objective or { type = "killAll" }
    if obj.type == "assassinate" then
        for _, u in ipairs(combat.units) do
            if u.alive and u.side == "enemy" and u.char.id == obj.target then
                return nil -- target still standing
            end
        end
        return "win"
    elseif obj.type == "survive" then
        if combat.clock >= (obj.turns or math.huge) then return "win" end
        return nil
    else -- killAll (default)
        if Combat.aliveCount(combat, "enemy") == 0 then return "win" end
        return nil
    end
end

return Combat
