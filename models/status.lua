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
        heal = function(tgt, amount)
            if not tgt then return 0 end
            return Combat.applyHeal(combat, tgt, amount)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- End this status now (e.g. Defending self-expiring at the owner's next turn start).
        expire = function() Status.remove(combat, unit, status.id) end,
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
        -- The hazard that granted this status, if any (e.g. "hazard_heal"). An "aura" status lasts
        -- only while its unit stands on a live hazard of this id: Combat.updateAuras drops it on the
        -- beat the unit leaves the zone. nil for a status applied by anything else (a spell, a
        -- potion), which just counts down normally.
        source = opts.source,
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

-- Remove status `id` from `unit` (no-op if absent), firing the def's onExpire teardown as it leaves.
-- A status that unwinds unit state on its way out (Charm restoring the side it flipped) therefore
-- reverts on EVERY removal path -- a Cure, a barrier consumed, a self-expire -- not only a natural
-- countdown. The instance is pulled from the list BEFORE onExpire runs, so a hook that itself calls
-- remove/expire for the same id can't double-fire. Needs `combat` to build the hook's context.
function Status.remove(combat, unit, id)
    local list = unit.statuses
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].id == id then
            local s = table.remove(list, i)
            if s.def.onExpire then s.def.onExpire(ctxFor(combat, unit, s)) end
        end
    end
end

-- Strip every DEBUFF from `unit` (a status whose def sets `debuff = true`: Burn, Wet, Stun, Root,
-- Silenced, Frozen, Mired). Buffs (Regeneration, Aegis, a barrier) are left untouched. Returns the
-- number removed. Backs Cure (data/items/ability/ability_cure.lua) through Combat.cleanse; an aura
-- debuff simply re-applies next entry if the unit is still standing in what caused it.
function Status.cleanse(combat, unit)
    local list = unit.statuses
    if not list then return 0 end
    local removed = 0
    for i = #list, 1, -1 do
        if list[i].def.debuff then
            local s = table.remove(list, i)
            removed = removed + 1
            -- Fire the teardown so a cleansed debuff unwinds its unit-state (Charm reverts the side it
            -- flipped) exactly as a natural expiry would.
            if s.def.onExpire then s.def.onExpire(ctxFor(combat, unit, s)) end
        end
    end
    return removed
end

-- Sum the flat `statBonus[name]` contributed by every active status on `unit` (0 if none). Lets a
-- buff/debuff status modify a flat stat; folded into combat's flatStat (e.g. Defending's +defense).
function Status.statBonus(unit, name)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        local bonus = s.def.statBonus
        if bonus and bonus[name] then total = total + bonus[name] end
    end
    return total
end

-- Reduction to `unit`'s ability RANGE, summed from every active status's `rangeMalus` (0 if none).
-- Range is per-ability, not a flat stat, so a range-cutting status (Blind) can't ride statBonus the
-- way a movement cut (Cripple) does; Combat.abilityRange subtracts this and floors the reach at 1, so
-- a blinded unit can still strike an adjacent foe. The single reader keeps targeting, the range
-- highlights and the enemy AI's planning all honouring the shortened sight at once.
function Status.rangeMalus(unit)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.rangeMalus then total = total + s.def.rangeMalus end
    end
    return total
end

-- Extra pre-mitigation damage `unit` takes from a hit carrying `tags`, summed from every active
-- status's `vulnerable = { tag = N }` bag (0 if none). Folded into Combat.mitigatedDamage so a
-- vulnerability lands on both real hits and the damage preview alike (e.g. Wet -> +lightning damage).
function Status.vulnerability(unit, tags)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        local vuln = s.def.vulnerable
        if vuln then
            for _, t in ipairs(tags or {}) do total = total + (vuln[t] or 0) end
        end
    end
    return total
end

-- Multiplier applied to every ability cost the unit pays, from each active status's
-- `costMultiplier` (1 when none). Multiplicative so two haste-like buffs compound rather than
-- cancel. Folded into Combat.abilityCost, the single source of truth for what an ability costs.
function Status.costMultiplier(unit)
    local m = 1
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.costMultiplier then m = m * s.def.costMultiplier end
    end
    return m
end

-- Can the opposing side pick this unit as a target? False while any active status sets
-- `untargetable` (Invisible). Read by Combat.abilityTargets and the enemy AI's target scans;
-- friendly and self casts ignore it, so an ally can still heal an invisible friend.
function Status.untargetable(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.untargetable then return true end
    end
    return false
end

-- The barrier status on `unit` that would negate an incoming hit of the given school (`magical`
-- true -> a magical barrier, false -> a physical one), or nil. A barrier def carries
-- `negates = "physical"|"magical"`; the first matching one is returned so Combat.dealFlatDamage can
-- consume it and the damage preview can read the negation. Mirrors Status.untargetable in shape --
-- a single flag scanned across the unit's active statuses.
function Status.barrierAgainst(unit, magical)
    local want = magical and "magical" or "physical"
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.negates == want then return s end
    end
    return nil
end

-- Does any active status keep this unit on its feet through a blow that would kill it? True while
-- any active status sets `preventsDeath` (Fury's berserk window). Read by Combat.dealFlatDamage,
-- which floors the survivor at 1 HP instead of dropping it. Mirrors Status.silenced in shape.
function Status.preventsDeath(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.preventsDeath then return true end
    end
    return false
end

-- Is this unit silenced -- unable to spend mana on an ability? True while any active status sets
-- `silencesMana`. Read by Combat.itemBlockReason, the single gate for a refused mana cast.
function Status.silenced(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.silencesMana then return true end
    end
    return false
end

-- Is this unit disarmed -- unable to use a crafted weapon? True while any active status sets
-- `disablesWeapon`. Read by Combat.itemBlockReason, the single gate for a refused weapon, exactly as
-- Status.silenced gates a refused mana cast. The bare `unarmed` fallback is exempt there, so a
-- disarmed unit can still punch.
function Status.disarmed(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.disablesWeapon then return true end
    end
    return false
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
    -- A `hideLog` status announces nothing at all: Invisible would otherwise write the very line
    -- the Decoy that granted it is trying to keep out of the log.
    if isNew and not def.hideLog then
        local Combat = require("models.combat")
        Combat.logEvent(combat, "status",
            string.format("%s is afflicted with %s.", (unit.char and unit.char.name) or "Unit", def.name or id))
    end

    -- Fire the standing-reaction hook for a status landing (Trait.onStatusApplied), on BOTH sides of
    -- the event: the RECIPIENT (a ward that cleanses a debuff the moment it lands) and, when the cast
    -- carried its caster through `opts.applier`, the APPLIER (a relic that rewards inflicting a debuff).
    -- Pulled lazily so status.lua -> trait.lua stays a call-time edge with no load cycle. Guarded on
    -- `combat` so a dry run (which never passes one) can't reach the reaction machinery.
    if combat then
        -- `def` is deliberately NOT threaded as an event field: the trait ctx already binds ctx.def to
        -- the reacting TRAIT's blueprint, and a hook reads the landed status through ctx.status(.def).
        local Trait = require("models.trait")
        Trait.onStatusApplied(combat, unit,
            { status = status, applier = opts.applier, recipient = unit, role = "recipient" })
        local applier = opts.applier
        if applier and applier ~= unit and applier.alive then
            Trait.onStatusApplied(combat, applier,
                { status = status, applier = applier, recipient = unit, role = "applier" })
        end

        -- A hard-control or forced-movement status shatters a channel the recipient was winding up.
        -- `interruptsChannel = true` always breaks it (Stun, Freeze); `"mana"` breaks only a mana-cost
        -- channel (Silence gags the incantation but leaves a stamina channel alone). The onApply above
        -- already fired, so a stun's own initiative shove still lands even as the channel it cancels goes.
        local ic = def.interruptsChannel
        if ic and unit.channel then
            local Combat = require("models.combat")
            if ic == true or (ic == "mana" and unit.channel.ab.cost and unit.channel.ab.cost.stat == "mana") then
                Combat.interruptChannel(combat, unit, def.name or id)
            end
        end
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
                    if not s.def.hideLog then
                        local Combat = require("models.combat")
                        Combat.logEvent(combat, "status",
                            string.format("%s's %s wears off.", (unit.char and unit.char.name) or "Unit", s.name or s.id))
                    end
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

-- The bearer just DEALT `amount` post-mitigation damage to someone. Fired from Combat.dealDamage
-- (where the attacker is known), so a status can record what its bearer does while it is active --
-- the general "accumulate state, resolve on expiry" mechanism (Fury banks damage dealt, then heals
-- a share of it in onExpire). The hook receives the same ctx as the others, plus `ctx.amount`.
-- Iterates a snapshot so a hook that mutates the status list can't corrupt the walk.
function Status.onDealDamage(combat, unit, amount)
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if s.def.onDealDamage then
            local ctx = ctxFor(combat, unit, s)
            ctx.amount = amount
            s.def.onDealDamage(ctx)
        end
    end
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
