-- Turn-based combat logic. Pure model (no love.graphics; not even love.math), so it
-- loads under the headless tests, mirroring models/arena.lua and models/overworld.lua.
-- The battle state (states/battle.lua) and its renderer drive this module; all rules
-- live here.
--
-- Combat runs on an *initiative countdown*. Each unit has an `initiative` >= 0; the living
-- unit with the LOWEST initiative acts next, and the unit whose turn it is always sits at 0.
-- A unit's starting initiative is the average `speed` of its ability items (items with an
-- activeAbility) MINUS its `speed` stat, so faster kit and a higher speed stat both act
-- sooner; the whole field is then rebased so the fastest unit is at 0. Ties (equal
-- initiative) are broken by `speed` (higher acts first).
--
-- A *turn* spans an optional move (once) plus one terminating action. `Combat.startTurn`
-- opens the current unit's turn; `Combat.moveUnit` repositions it WITHOUT ending the turn
-- (it just records the terrain-weighted move cost); then either `Combat.useItem` or
-- `Combat.wait` ends the turn. Ending a turn sets the actor's initiative to its cost and then
-- REBASES: subtract the new minimum initiative from every unit, so the next unit drops to 0.
--   * item action -> initiative = moveCost + ability.speed
--   * wait (delay) -> initiative = max(moveCost, nextUnit.initiative + 1): land one tick after
--     the next unit in line, but never before the move you took is paid for.
-- `moveCost` is the Dijkstra path cost (rough terrain costs more), so difficult ground both
-- shortens reach and costs more time. `combat.clock` accumulates the elapsed initiative (the
-- amount subtracted each rebase) so the `survive N turns` objective still works.
--
--   local combat = Combat.new(arena, partyUnits, enemyUnits)  -- units: { { char, x, y }, ... }
--   local unit = Combat.startTurn(combat)                     -- open the current unit's turn
--   Combat.moveUnit(combat, unit, x, y)                       -- optional; doesn't end the turn
--   Combat.useItem(combat, unit, item, targetX, targetY)      -- or Combat.wait(combat, unit)
--   local result = Combat.evaluate(combat)                    -- "win" | "loss" | nil
--
-- Item abilities carry an `effect(fx)` FUNCTION (see data/items/*.lua). useItem builds an
-- `fx` context with bound helpers (fx.damage / fx.heal / fx.unitsNear) so a data file
-- composes effects without requiring this module. All the damage/heal math lives in the
-- helpers (Combat.dealDamage / Combat.applyHeal).

local Combat = {}

-- Ability-speed fallback for a unit that carries no ability item at all.
Combat.DEFAULT_SPEED = 5

-- Fallback wait cost when there is no other living unit to delay past (the battle is
-- effectively already decided, but this keeps the clock advancing).
Combat.WAIT_COST = Combat.DEFAULT_SPEED

-- Deterministic tie-break when two units share an initiative AND a speed: party before
-- enemy, then spawn order. (Speed is the primary tie-break; see orderBy.)
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

-- The character's `speed` stat (0 if unset), used as the primary tie-break and folded into
-- the starting initiative.
function Combat.speed(char)
    return (char.stats and char.stats.speed) or 0
end

-- Starting initiative = the average speed of the character's ability items (DEFAULT_SPEED if
-- it has none) MINUS its `speed` stat, so a higher speed stat acts sooner. Lower acts sooner;
-- Combat.new rebases the field (which may go negative here) so the fastest unit begins at 0.
function Combat.initiative(char)
    local items = Combat.abilityItems(char)
    local avg
    if #items == 0 then
        avg = Combat.DEFAULT_SPEED
    else
        local sum = 0
        for _, item in ipairs(items) do
            sum = sum + (item.activeAbility.speed or Combat.DEFAULT_SPEED)
        end
        avg = sum / #items
    end
    return avg - Combat.speed(char)
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
        clock = 0,      -- accumulated elapsed initiative (drives `survive`)
        turnCount = 0,  -- number of actions taken
        turn = nil,     -- the in-progress turn: { unit, moved, moveCost } (see startTurn)
    }

    local function addSide(list, side)
        for _, u in ipairs(list or {}) do
            local unit = {
                char = u.char, side = side,
                x = u.x, y = u.y,
                initiative = Combat.initiative(u.char),
                speed = Combat.speed(u.char), -- primary tie-break
                alive = true,
            }
            unit.index = #combat.units + 1
            combat.units[unit.index] = unit
        end
    end
    addSide(partyUnits, "party")
    addSide(enemyUnits, "enemy")

    -- Rebase so the fastest unit starts at initiative 0 (the current-actor convention). The
    -- initial offset isn't elapsed battle time, so reset the clock to 0 afterwards.
    Combat.rebase(combat)
    combat.clock = 0
    Combat.applyPassives(combat)
    return combat
end

-- Subtract the lowest living initiative from every living unit so the next actor sits at 0,
-- and add that amount to the elapsed clock. Called at construction and after each turn ends.
function Combat.rebase(combat)
    local minInit
    for _, u in ipairs(combat.units) do
        if u.alive and (not minInit or u.initiative < minInit) then minInit = u.initiative end
    end
    if not minInit then return end
    for _, u in ipairs(combat.units) do
        if u.alive then u.initiative = u.initiative - minInit end
    end
    combat.clock = combat.clock + minInit
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

-- Order living units by turn using `initOf(unit)` for each unit's initiative: lowest first,
-- then higher `speed` (the faster unit wins a tie), then the deterministic tie-break (party
-- before enemy, then index). `initOf` lets previewOrder substitute a hypothetical initiative
-- for one unit without mutating.
local function orderBy(combat, initOf)
    local order = {}
    for _, u in ipairs(combat.units) do
        if u.alive then order[#order + 1] = u end
    end
    table.sort(order, function(a, b)
        local ia, ib = initOf(a), initOf(b)
        if ia ~= ib then return ia < ib end
        if a.speed ~= b.speed then return a.speed > b.speed end
        if a.side ~= b.side then return SIDE_RANK[a.side] < SIDE_RANK[b.side] end
        return a.index < b.index
    end)
    return order
end

-- Living units ordered by turn: lowest initiative first, then the deterministic tie-break.
function Combat.turnOrder(combat)
    return orderBy(combat, function(u) return u.initiative end)
end

-- Turn order computed as if `unit.initiative == newInit`, without mutating any unit. Drives
-- the UI's hover preview: newInit is `moveCost` for a move or `moveCost + speed` for an item.
function Combat.previewOrder(combat, unit, newInit)
    return orderBy(combat, function(u)
        if u == unit then return newInit end
        return u.initiative
    end)
end

-- Like the live turn order, but with an extra GHOST copy of `unit` inserted where it would
-- land if it acted (newTime). The actor keeps its real slot AND gains a preview slot, so the
-- UI can show "you are here now / you would move to here". Returns a list of
-- { unit, preview } entries in turn order (soonest first); the real entry sorts before the
-- ghost on a tie so the live one stays lower in a bottom-anchored strip.
function Combat.previewTimeline(combat, unit, newInit)
    local entries = {}
    for _, u in ipairs(combat.units) do
        if u.alive then entries[#entries + 1] = { unit = u, preview = false, initiative = u.initiative } end
    end
    entries[#entries + 1] = { unit = unit, preview = true, initiative = newInit }
    -- Order by initiative, matching Combat.turnOrder's tie-breaks so the strip agrees with the
    -- board's turn numbers; a preview ghost sorts AFTER real entries at an exact tie. Every
    -- branch is guarded so comparing an entry with itself returns false (a valid weak order --
    -- an unguarded `return not a.preview` here would assert x < x and corrupt table.sort).
    table.sort(entries, function(a, b)
        if a.initiative ~= b.initiative then return a.initiative < b.initiative end
        if a.preview ~= b.preview then return b.preview end -- real before ghost at a tie
        if a.unit.speed ~= b.unit.speed then return a.unit.speed > b.unit.speed end
        if a.unit.side ~= b.unit.side then return SIDE_RANK[a.unit.side] < SIDE_RANK[b.unit.side] end
        return a.unit.index < b.unit.index
    end)
    return entries
end

function Combat.currentUnit(combat)
    return Combat.turnOrder(combat)[1]
end

-- Open the current unit's turn: a fresh { unit, moved, moveCost } record the move/action
-- calls read and end. Returns the unit whose turn it is (nil if none are left alive).
function Combat.startTurn(combat)
    local unit = Combat.currentUnit(combat)
    combat.turn = unit and { unit = unit, moved = false, moveCost = 0 } or nil
    return unit
end

-- Has the active unit already spent its (once-per-turn) move?
function Combat.hasMoved(combat)
    return combat.turn ~= nil and combat.turn.moved
end

-- The next living unit to act (the one a wait would delay past), or nil if `unit` is the last
-- one standing. `unit` sits at initiative 0 during its turn, so this is the second in order.
local function nextUnit(combat, unit)
    for _, u in ipairs(Combat.turnOrder(combat)) do
        if u ~= unit then return u end
    end
    return nil
end

-- End the active unit's turn: set its initiative to (moveCost spent this turn) + the action
-- cost, then rebase so the next unit drops to 0. Shared by useItem and passing.
local function endTurn(combat, unit, actionCost)
    local moveCost = (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    unit.initiative = unit.initiative + moveCost + actionCost
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.rebase(combat)
end

-- Wait (delay): the acting unit sits at initiative 0, so end the turn by setting its
-- initiative to (next unit's initiative + 1) -- act one tick after them -- but never below the
-- move cost it spent this turn, so a move is still paid. Rebasing then drops the next unit to
-- 0 and the waiter lands just behind it. Falls back to moveCost + WAIT_COST when no other unit
-- is alive. The player's deliberate "delay my turn" action.
function Combat.wait(combat, unit)
    if not unit.alive then return false, "dead" end
    local moveCost = (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    local nxt = nextUnit(combat, unit)
    unit.initiative = nxt and math.max(moveCost, nxt.initiative + 1) or (moveCost + Combat.WAIT_COST)
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.rebase(combat)
    return true
end

-- Pass: end the turn without acting, paying the normal timeline cost (this turn's move cost,
-- or WAIT_COST if the unit also stayed put so it can never stall). Unlike wait it does NOT
-- delay past the next unit -- used by enemy AI and the auto-pass so terrain still slows them.
function Combat.pass(combat, unit)
    if not unit.alive then return false, "dead" end
    local moved = combat.turn ~= nil and combat.turn.unit == unit and combat.turn.moved
    endTurn(combat, unit, moved and 0 or Combat.WAIT_COST)
    return true
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Tiles a unit can reach this turn: a Dijkstra over the arena weighted by tile
-- `moveCost`, budget = the unit's `movement`, blocked by non-walkable tiles and cells
-- occupied by other units. Returns `{ [key]= { x, y, cost, steps } }`, keyed by "x,y".
-- `cost` is the terrain-weighted path cost: it spends the movement budget AND is the
-- initiative the move costs at end-of-turn (so rough terrain is slower to cross in both
-- reach and time). `steps` is the raw tile count, used only by the enemy AI's pathing.
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

-- Move a unit to (x, y) if reachable this turn. A unit may move once per turn and moving
-- does NOT end the turn: it just repositions and records the terrain-weighted path cost
-- (node.cost), which endTurn later folds into the timeline (move cost + action cost).
function Combat.moveUnit(combat, unit, x, y)
    if not unit.alive then return false, "dead" end
    if not combat.turn or combat.turn.unit ~= unit then return false, "not this unit's turn" end
    if combat.turn.moved then return false, "already moved" end
    local node = Combat.reachable(combat, unit)[key(x, y)]
    if not node then return false, "unreachable" end

    unit.x, unit.y = x, y
    combat.turn.moved = true
    combat.turn.moveCost = node.cost
    return true, node.cost
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

    -- Using an item ends the turn: advance by (this turn's move cost) + the ability speed.
    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)

    if ab.consumesItem then
        for i, it in ipairs(unit.char.inventory) do
            if it == item then table.remove(unit.char.inventory, i); break end
        end
    end

    return true, result
end

-- ---------------------------------------------------------------------------
-- Enemy AI
-- ---------------------------------------------------------------------------

-- Enemy plan for a whole turn (move once, then act). Returns a descriptor the battle state
-- executes as an optional move followed by an item use or a wait:
--   { move = { x, y } | nil, item = <item>, tx, ty }   -- attack (optionally after moving)
--   { move = { x, y } }                                -- reposition only
--   { wait = true }                                    -- nothing useful to do
-- Priority: attack from the current tile > move to a tile that lets an ability hit a party
-- unit > step toward the nearest foe > wait. Pure (no love, no mutation) so it stays testable.
function Combat.planEnemyAction(combat, unit)
    -- Nearest living party unit (the foe we path toward / attack).
    local target, bestDist
    for _, u in ipairs(combat.units) do
        if u.alive and u.side ~= unit.side then
            local d = manhattan(unit.x, unit.y, u.x, u.y)
            if not bestDist or d < bestDist then target, bestDist = u, d end
        end
    end
    if not target then return { wait = true } end

    -- Only consider abilities the unit can currently pay for (else the plan would waste the
    -- turn on an item useItem rejects).
    local items = {}
    for _, item in ipairs(Combat.abilityItems(unit.char)) do
        local ab = item.activeAbility
        if not ab.cost or resourceValue(unit.char, ab.cost.stat) >= ab.cost.amount then
            items[#items + 1] = item
        end
    end

    -- 1. Attack from where we stand, if any ability already reaches a foe (nearest target).
    for _, item in ipairs(items) do
        local hit, hitDist
        for _, t in ipairs(Combat.abilityTargets(combat, unit, item)) do
            if t.side ~= unit.side then
                local d = manhattan(unit.x, unit.y, t.x, t.y)
                if not hitDist or d < hitDist then hit, hitDist = t, d end
            end
        end
        if hit then return { item = item, tx = hit.x, ty = hit.y } end
    end

    -- 2. Move to a reachable tile from which an ability can hit a foe. Prefer the fewest
    -- steps, then the nearest foe from that tile.
    local reachable = Combat.reachable(combat, unit)
    local best
    for _, node in pairs(reachable) do
        for _, item in ipairs(items) do
            local range = (item.activeAbility and item.activeAbility.range) or 1
            for _, p in ipairs(combat.units) do
                if p.alive and p.side ~= unit.side
                    and manhattan(node.x, node.y, p.x, p.y) <= range then
                    local d = manhattan(node.x, node.y, p.x, p.y)
                    if not best or node.steps < best.steps
                        or (node.steps == best.steps and d < best.dist) then
                        best = { x = node.x, y = node.y, item = item, tx = p.x, ty = p.y,
                                 steps = node.steps, dist = d }
                    end
                end
            end
        end
    end
    if best then
        return { move = { x = best.x, y = best.y }, item = best.item, tx = best.tx, ty = best.ty }
    end

    -- 3. No attack possible: step to the reachable tile closest to the target (ties -> fewer
    -- steps). Only move if it strictly closes the gap, to avoid pacing in place.
    local dest
    for _, node in pairs(reachable) do
        local d = manhattan(node.x, node.y, target.x, target.y)
        if not dest or d < dest.dist or (d == dest.dist and node.steps < dest.steps) then
            dest = { x = node.x, y = node.y, dist = d, steps = node.steps }
        end
    end
    if dest and dest.dist < bestDist then
        return { move = { x = dest.x, y = dest.y } }
    end
    return { wait = true }
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
