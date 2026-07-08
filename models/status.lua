-- Status effects: timed effects applied to a unit in combat, measured in *ticks* (the
-- initiative reduced when a new turn triggers -- i.e. the amount models/combat.lua's rebase
-- subtracts and folds into combat.clock). Pure logic (no love.graphics), so it loads under
-- the headless tests, mirroring models/combat.lua.
--
-- Blueprints live in data/status/<id>.lua and expose optional hook functions the combat
-- model calls at the right moments:
--   * onApply(ctx)        -- when the status is first applied / re-applied (stun bumps init)
--   * onExpire(ctx)       -- when its remaining ticks hit 0
--   * onTurnStart(ctx)    -- at the top of the affected unit's turn (e.g. poison damage)
--   * onTurnEnd(ctx)      -- as the affected unit's turn ends
--   * blocksMove = true   -- the unit cannot move on its turn (root)
--   * turnEndMoveCost(ctx)-> a move cost the unit pays at end of turn even if it stayed put
--                            (root: as if it had moved max spaces)
--
-- `ctx` carries { combat, unit, status, magnitude, moveBudget } plus bound, headless-safe
-- helpers (damage / applyStatus / unitsNear) so a data-file hook composes effects without
-- requiring this module or models/combat.lua directly. Combat helpers are pulled through a
-- LAZY require so there is no load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")

local Status = {}

Status.defs = Registry.load("data/status", "data.status")

-- Build the effect context handed to a status def's hooks. Combat is required lazily
-- (at call time, not load time) so combat.lua -> status.lua stays a one-way dependency.
local function ctxFor(combat, unit, status)
    local Combat = require("models.combat")
    return {
        combat = combat,
        unit = unit,
        status = status,
        magnitude = status.magnitude,
        moveBudget = Combat.moveBudget(unit),
        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, status.name or status.id)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
    }
end

-- Build a fresh status instance from a blueprint id. `opts` may override duration/magnitude.
function Status.instantiate(id, opts)
    opts = opts or {}
    local def = Status.defs[id]
    assert(def, "unknown status id: " .. tostring(id))
    return {
        id = id,
        name = def.name,
        remaining = opts.duration or def.duration or 0,
        magnitude = opts.magnitude or def.magnitude,
        def = def,
    }
end

-- The active status of `id` on `unit`, or nil.
function Status.get(unit, id)
    for _, s in ipairs(unit.statuses or {}) do
        if s.id == id then return s end
    end
    return nil
end

function Status.has(unit, id)
    return Status.get(unit, id) ~= nil
end

-- Apply status `id` to `unit`. One instance per id: re-applying refreshes the remaining
-- duration to the longer of old/new and re-runs onApply (so re-stunning bumps again). Runs
-- the def's onApply hook. Returns the (possibly refreshed) status instance.
function Status.apply(combat, unit, id, opts)
    opts = opts or {}
    local def = Status.defs[id]
    assert(def, "unknown status id: " .. tostring(id))
    unit.statuses = unit.statuses or {}

    local status = Status.get(unit, id)
    local isNew = status == nil
    if status then
        status.remaining = math.max(status.remaining, opts.duration or def.duration or 0)
        if opts.magnitude then status.magnitude = opts.magnitude end
    else
        status = Status.instantiate(id, opts)
        unit.statuses[#unit.statuses + 1] = status
    end
    if def.onApply then def.onApply(ctxFor(combat, unit, status)) end
    -- Log only a fresh application (a refresh of an existing status would just spam the panel).
    if isNew then
        local Combat = require("models.combat")
        Combat.logEvent(combat, "status",
            string.format("%s is afflicted with %s.", (unit.char and unit.char.name) or "Unit", def.name or id))
    end
    return status
end

-- Count every status down by `elapsed` ticks; expire (and fire onExpire for) any that reach 0.
-- Called from Combat.rebase with the rebase amount (the ticks that just elapsed).
function Status.tick(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, unit in ipairs(combat.units) do
        local list = unit.statuses
        if list then
            for i = #list, 1, -1 do
                local s = list[i]
                s.remaining = s.remaining - elapsed
                if s.remaining <= 0 then
                    table.remove(list, i)
                    local Combat = require("models.combat")
                    Combat.logEvent(combat, "status",
                        string.format("%s's %s wears off.", (unit.char and unit.char.name) or "Unit", s.name or s.id))
                    if s.def.onExpire then s.def.onExpire(ctxFor(combat, unit, s)) end
                end
            end
        end
    end
end

-- Run a named per-turn hook ("onTurnStart" / "onTurnEnd") for every status on `unit`. Iterates
-- a snapshot so a hook that mutates the status list can't corrupt the walk.
local function runTurnHook(combat, unit, hook)
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if s.def[hook] then s.def[hook](ctxFor(combat, unit, s)) end
    end
end

function Status.onTurnStart(combat, unit)
    runTurnHook(combat, unit, "onTurnStart")
end

function Status.onTurnEnd(combat, unit)
    runTurnHook(combat, unit, "onTurnEnd")
end

-- Does any active status forbid this unit from moving this turn (root)?
function Status.blocksMove(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.blocksMove then return true end
    end
    return false
end

-- The largest end-of-turn move cost any active status forces on the unit even if it stayed
-- put (root: the full movement budget). 0 when no status charges one.
function Status.forcedMoveCost(combat, unit)
    local cost = 0
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.turnEndMoveCost then
            cost = math.max(cost, s.def.turnEndMoveCost(ctxFor(combat, unit, s)) or 0)
        end
    end
    return cost
end

return Status
