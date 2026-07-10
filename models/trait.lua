-- Traits: innate combat *reactions*. Where a status is a timed effect that ticks down and wears
-- off, a trait is a standing rule that fires when something happens to its bearer. Pure logic (no
-- love.graphics), so it loads under the headless tests, mirroring models/status.lua -- and like that
-- module it pulls models/combat.lua through a LAZY require inside its functions, so
-- combat.lua -> trait.lua stays a one-way dependency with no load-time cycle.
--
-- The split is worth stating: a trait is the RULE, a status is the stacking EFFECT it applies. Wrath's
-- general reacts to being struck (trait) by deepening its rage (status). Reaching for a permanent
-- status instead would mean a duration of math.huge, a suppressed badge, and a thing that must survive
-- Status.tick -- fighting every invariant that module is built on.
--
-- Blueprints live in data/traits/<id>.lua and expose optional hook functions:
--   * onCombatStart(ctx) -- once, after every unit, passive, trap and hazard is in place
--   * onDamaged(ctx)     -- the bearer was hit and SURVIVED; ctx.amount is post-mitigation
--   * onCast(ctx)        -- the bearer finished using an item; ctx.item / ctx.tx / ctx.ty
--   * onDeath(ctx)       -- the bearer dropped
--
-- Two things carry traits, and both flow through Trait.attach:
--   * a character blueprint  -- `traits = { "wrath_rising" }` on data/characters/<id>.lua
--   * an ITEM in the 3x3 grid -- `traits = { ... }` on the item blueprint
-- The second is what makes a general's relic worth taking: the mail lifted off Wrath's body carries
-- Wrath's own rule, so the knight who wears it hits harder the more they are hit. Drop it in the
-- stash and the rule goes with it. A unit's traits are collected once, when it joins the battle, so
-- an item leaving the grid mid-fight is not a case this module has to answer -- the grid is fixed
-- for the duration of a battle.
--
-- `ctx` carries { combat, unit, trait, def } plus the event's own fields and bound, headless-safe
-- helpers (damage / heal / applyStatus / addBonus / summon / copyOf / unitsNear / log), so a
-- data-file hook composes effects without requiring combat.lua directly.

local Registry = require("models.registry")
local Character = require("models.character")

local Trait = {}

Trait.defs = Registry.load("data/traits", "data.traits")

-- A trait hook that deals damage re-enters Combat.dealFlatDamage, which dispatches onDamaged again.
-- Two guards, because they catch different shapes of the same bug: `unit._reacting` stops a trait
-- retriggering *itself* (a retaliation that wounds its own bearer), and the depth cap stops two
-- retaliators volleying into each other forever. A hook that hits a DIFFERENT unit is legitimate
-- and terminates on its own; neither guard interferes with it.
Trait.MAX_DEPTH = 8

-- Build the effect context handed to a trait def's hooks. Combat is required lazily (at call time,
-- not load time) so combat.lua -> trait.lua stays one-way. `event` carries the hook's own fields.
local function ctxFor(combat, unit, trait, event)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local Summon = require("models.summon")

    local ctx = {
        combat = combat,
        unit = unit,
        trait = trait,
        def = trait.def,
        -- The item this trait came off, or nil when the character itself declares it. A relic's
        -- hook can read its own blueprint (name, magnitude) without a registry lookup.
        item = trait.item,

        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, trait.name or trait.id)
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            return Combat.applyHeal(combat, tgt, amount)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        -- Raise (or lower) a flat stat on the bearer for the rest of the battle. `unit.bonus` is the
        -- per-unit table applyUnitPassives builds from the grid's passive items -- writing here never
        -- touches the shared character instance, so a boss's accumulated rage does not follow the
        -- blueprint into the next battle, and a party member's does not follow them back to the hub.
        addBonus = function(stat, amount)
            unit.bonus = unit.bonus or {}
            unit.bonus[stat] = (unit.bonus[stat] or 0) + amount
            return unit.bonus[stat]
        end,
        summon = function(charId, px, py, opts)
            return Summon.spawn(combat, unit, charId, px, py, opts)
        end,
        -- Take the shape of another unit: a copy of `target` on the bearer's side (Envy).
        copyOf = function(target, px, py, opts)
            return Summon.copyOf(combat, unit, target, px, py, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        -- A free tile beside (x, y), or nil when the spot is hemmed in. What a hook calls before it
        -- summons or copies, because a body needs ground to stand on.
        openTileNear = function(x, y) return Combat.openTileNear(combat, x, y) end,
        log = function(kind, text) return Combat.logEvent(combat, kind, text) end,
    }

    for key, value in pairs(event or {}) do ctx[key] = value end
    return ctx
end

-- Build a fresh trait instance. `item` is the grid item that granted it, or nil for an innate one.
function Trait.instantiate(id, item)
    local def = Trait.defs[id]
    assert(def, "unknown trait id: " .. tostring(id))
    return {
        id = id,
        name = def.name or id,
        def = def,
        item = item,
        stacks = 0, -- free counter for a hook that accumulates (wrath_rising, hollow_crown phases)
    }
end

-- Collect `unit.traits` from the character blueprint and from every item in its 3x3 grid. Idempotent
-- and hook-free: call it the moment a unit joins the field, and fire onCombatStart separately (a
-- summon arriving mid-battle did not start the battle).
function Trait.attach(unit)
    local list = {}
    for _, id in ipairs((unit.char and unit.char.traits) or {}) do
        list[#list + 1] = Trait.instantiate(id, nil)
    end
    if unit.char then
        for _, item in ipairs(Character.eachItem(unit.char)) do
            for _, id in ipairs(item.traits or {}) do
                list[#list + 1] = Trait.instantiate(id, item)
            end
        end
    end
    unit.traits = list
    return list
end

function Trait.has(unit, id)
    for _, t in ipairs(unit.traits or {}) do
        if t.id == id then return true end
    end
    return false
end

-- Run `hook` for every trait on `unit`. Iterates a snapshot, so a hook that mutates the trait list
-- cannot corrupt the walk (the same guard runTurnHook applies in models/status.lua).
local function dispatch(combat, unit, hook, event)
    if not unit or not unit.traits or #unit.traits == 0 then return end

    -- Keyed by hook, not a single flag: a retaliation that kills its own bearer must still be able
    -- to fire onDeath from inside onDamaged. Only re-entering the SAME hook is the runaway.
    unit._reacting = unit._reacting or {}
    if unit._reacting[hook] then return end

    combat._traitDepth = (combat._traitDepth or 0) + 1
    if combat._traitDepth > Trait.MAX_DEPTH then
        combat._traitDepth = combat._traitDepth - 1
        return
    end

    unit._reacting[hook] = true
    local snapshot = {}
    for _, t in ipairs(unit.traits) do snapshot[#snapshot + 1] = t end
    for _, t in ipairs(snapshot) do
        if t.def[hook] then t.def[hook](ctxFor(combat, unit, t, event)) end
    end
    unit._reacting[hook] = false
    combat._traitDepth = combat._traitDepth - 1
end

-- Attach every unit's traits and fire onCombatStart. Called once, at the end of Combat.new, after
-- passives, traps and hazards are in place -- a trait that reads the field must find it finished.
function Trait.setup(combat)
    for _, unit in ipairs(combat.units) do Trait.attach(unit) end
    -- A separate pass, so an opener that spawns or copies sees every OTHER unit already attached.
    for _, unit in ipairs(combat.units) do
        if unit.alive then dispatch(combat, unit, "onCombatStart", {}) end
    end
end

-- The bearer took `info.amount` post-mitigation damage and lived. Fired from Combat.dealFlatDamage.
function Trait.onDamaged(combat, unit, info)
    dispatch(combat, unit, "onDamaged", info)
end

-- The bearer finished resolving an item's ability. Fired from Combat.useItem.
function Trait.onCast(combat, unit, info)
    dispatch(combat, unit, "onCast", info)
end

-- The bearer dropped. Fired from killUnit, before its summons are dismissed.
function Trait.onDeath(combat, unit, info)
    dispatch(combat, unit, "onDeath", info)
end

return Trait
