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
--   * onStatusApplied(ctx) -- a status landed and the bearer was on one side of it; ctx.role is
--                            "recipient" (the bearer gained it) or "applier" (the bearer inflicted
--                            it), plus ctx.status (the landed instance; ctx.status.def for its
--                            blueprint), ctx.applier and ctx.recipient. Note ctx.def is still the
--                            reacting TRAIT's own blueprint, not the status's.
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

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Are `unit`'s reflexes shut down by a hard-control status (Stun, Frozen, and any future Sleep)? A
-- disabled unit cannot REACT -- no counter, no thorns, no dodge, no smoke-blink -- so every triggered
-- reaction path below bails on it and the unit simply eats the blow it would otherwise answer. Status
-- is pulled lazily (like Combat below) so trait.lua -> status.lua stays a call-time edge.
local function reactionsSuppressed(unit)
    return unit and require("models.status").disablesReactions(unit)
end

-- Pay `def`'s reflex cost out of `unit`, or report that it cannot be paid. Every triggered reflex in
-- the game is priced the same way -- a `cost = { stat, amount }` on the trait def, paid on each firing,
-- on top of the `magnitude` cooldown that follows it -- so a defender answers only while their pool
-- lasts, and only as often as their guard recovers. A def with no cost is free and always "pays".
--
-- The two gates are deliberately different levers and every reflex wants both: the cooldown paces
-- answers WITHIN an exchange (you cannot parry twice in one flurry), while the cost bounds them ACROSS
-- a battle (a swordsman who spends the fight countering has nothing left to swing with). Free reflexes
-- on a timer alone made standing in a doorway strictly correct; this is what prices that choice.
--
-- Mutates on success, so it must be the LAST gate a reflex checks -- never call it before the cheap
-- refusals (suppression, range, cooldown), or a reflex that then declines has quietly billed its
-- bearer for nothing. Callers: Trait.tryRiposte/tryPreempt below, and `ctx.pay` for a hook-driven
-- reflex (data/traits/parry.lua) that prices itself from its own data file.
local function payCost(unit, def)
    local cost = def and def.cost
    if not cost then return true end
    local Combat = require("models.combat")
    if Combat.resource(unit.char, cost.stat) < cost.amount then return false end
    Combat.drainResource(unit.char, cost.stat, cost.amount)
    return true
end

-- Does a standing evade reflex (the Dodge trait) let `unit` slip a would-be PHYSICAL hit? Mirrors
-- Status.barrierAgainst in shape and role: Combat.dealFlatDamage consults it BEFORE mitigation and,
-- when it fires, deals 0. Unlike a barrier (a consumed status) this is a passive gated by a cooldown
-- keyed on the trait's id -- the first physical blow is evaded, then the reflex recharges for
-- `magnitude` ticks before it can void another, so a dodger can't stand permanently untouchable. Only a
-- physical (non-magical) hit is evaded; a spell passes through. Mutates (starts the cooldown, logs), so
-- it must run on a REAL hit only -- never the damage preview, which reads mitigatedDamage instead.
function Trait.tryEvade(combat, unit, tags)
    if not unit or not unit.traits or hasTag(tags, "magical") then return false end
    if reactionsSuppressed(unit) then return false end -- a stunned/frozen unit can't dodge
    local Combat = require("models.combat")
    for _, t in ipairs(unit.traits) do
        if t.def.evadesPhysical and not Combat.onCooldown(unit, t.id) then
            Combat.setCooldown(unit, t.id, t.def.magnitude or 0)
            Combat.logEvent(combat, "action",
                string.format("%s dodges the blow!", (unit.char and unit.char.name) or "Unit"))
            return true
        end
    end
    return false
end

-- Does a carried smoke charge (a `blocksNextHit` trait) let `unit` slip an incoming ATTACK -- negating
-- it and blinking the bearer clear -- the way Trait.tryEvade voids a blow? Consulted in
-- Combat.dealFlatDamage BEFORE mitigation, beside tryEvade: when it fires the hit deals 0 and the
-- bearer is shoved `blink` tiles straight away from its attacker (Combat.knockback from the attacker's
-- side). Unlike the passive Dodge this is a once-per-battle charge, latched on `stacks` like Second
-- Wind, so a smoke bomb saves its bearer exactly once. Only a real ATTACK triggers it (an `attacker` is
-- known) -- a poison tick or a trap, which passes none, neither fires it nor wastes the charge. Mutates
-- (spends the charge, moves the unit, logs), so it must run on a REAL hit only, never the damage preview.
function Trait.trySmoke(combat, unit, attacker)
    if not unit or not unit.traits or not attacker then return false end
    if reactionsSuppressed(unit) then return false end -- a stunned/frozen unit can't blink clear
    local Combat = require("models.combat")
    for _, t in ipairs(unit.traits) do
        if t.def.blocksNextHit and t.stacks == 0 then
            t.stacks = 1 -- spend the one charge FIRST, so the blink's own trap/hazard entries can't re-fire it
            Combat.logEvent(combat, "action",
                string.format("%s vanishes in a burst of smoke!", (unit.char and unit.char.name) or "Unit"))
            Combat.knockback(combat, attacker, unit, t.def.blink or 2)
            return true
        end
    end
    return false
end

-- Does a duelist's blade (a `deflectsMelee` trait) turn an incoming MELEE blow aside AND answer it?
-- The fencer's riposte proper: the parry and the counter are one motion, so unlike the ordinary
-- data/traits/parry.lua -- which answers a hit it has already taken -- this one costs the bearer
-- nothing at all. Consulted in Combat.dealFlatDamage BEFORE mitigation, beside Trait.tryEvade and
-- Trait.trySmoke: when it fires the blow deals 0 and the attacker eats the bearer's weapon.
--
-- Deliberately narrower than the Dodge reflex it sits next to, which voids ANY physical hit from any
-- range: a blade can only turn aside something within its reach, and only something material. A spell,
-- an arrow, a poison tick, or a trap all pass straight through -- you cannot parry what you cannot
-- touch. `magnitude` is the cooldown length in ticks.
--
-- Mutates (spends the cooldown, deals the counter, logs), so it must run on a REAL hit only, never the
-- damage preview -- which never reaches this path, since previews read Combat.mitigatedDamage instead.
function Trait.tryRiposte(combat, unit, attacker, tags)
    if not unit or not unit.traits or not attacker or not attacker.alive then return false end
    if hasTag(tags, "magical") then return false end -- a spell is not something a blade can turn
    if reactionsSuppressed(unit) then return false end -- a stunned/frozen unit holds no guard
    if attacker.side == unit.side then return false end -- never answer a friendly or self source
    local dist = math.abs(attacker.x - unit.x) + math.abs(attacker.y - unit.y)
    if dist ~= 1 then return false end -- melee only: an archer stands beyond the blade
    -- Answer attacks, not answers: never riposte something that is itself a reaction, or two duelists
    -- would trade parries forever (see Trait.isReacting).
    if Trait.isReacting(attacker) then return false end
    local Combat = require("models.combat")
    for _, t in ipairs(unit.traits) do
        -- Cost last, so a blade already on cooldown is never billed for the guard it cannot raise.
        if t.def.deflectsMelee and not Combat.onCooldown(unit, t.id) and payCost(unit, t.def) then
            Combat.setCooldown(unit, t.id, t.def.magnitude or 0)
            Combat.logEvent(combat, "action",
                string.format("%s turns the blow aside and ripostes!",
                    (unit.char and unit.char.name) or "Unit"))
            -- Flag our own counter as a reaction for its whole flight, so the attacker's parry reads it
            -- as an answer and lets it through rather than answering back. Saved/restored rather than
            -- cleared, so a riposte reached THROUGH another reflex can't unset that one's flag.
            unit._reacting = unit._reacting or {}
            local was = unit._reacting.riposte
            unit._reacting.riposte = true
            -- A beat later than the blow it turned aside, so the answer animates after it (see
            -- Combat.beginBeat). Set here rather than in `dispatch`, since a riposte fires from the
            -- pre-mitigation path rather than through a hook -- the same reason `_reacting` is local.
            Combat.beginBeat(combat)
            local weapon = Combat.defaultWeapon(unit.char)
            if weapon then Combat.dealDamage(combat, unit, attacker, weapon) end
            Combat.endBeat(combat)
            unit._reacting.riposte = was
            return true
        end
    end
    return false
end

-- Does a preternatural reflex (a `preemptsAttack` trait -- Keen Senses) let `unit` answer an incoming
-- attack BEFORE it lands? The one reflex in the game that changes the ORDER of an exchange rather than
-- its arithmetic: consulted in Combat.dealFlatDamage beside tryEvade/trySmoke/tryRiposte, it throws the
-- bearer's counter first and only then lets the blow through.
--
-- The return value is what the blow does NEXT, not whether the counter fired: true only when the
-- counter FELLED the attacker, in which case the swing dies with them and deals nothing. A counter that
-- merely wounds returns false -- the answer landed first, and the attack still lands after it. That
-- asymmetry is the reflex's whole appeal and its whole cost: it saves the bearer outright only when it
-- kills, and it is paid for either way.
--
-- Unlike its neighbors this one is gated by a RESOURCE rather than a cooldown -- it answers every attack
-- it can afford (see data/traits/keen_senses.lua) -- and it answers any attack, magical or not, since
-- what it senses is the intent and not the steel. It still needs to REACH the attacker: no default
-- weapon, or a foe standing beyond that weapon's range, and the sense goes unanswered.
--
-- Mutates (spends stamina, deals the counter, logs), so it must run on a REAL hit only, never the
-- damage preview -- which never reaches this path, since previews read Combat.mitigatedDamage instead.
function Trait.tryPreempt(combat, unit, attacker)
    if not unit or not unit.traits or not attacker or not attacker.alive then return false end
    if reactionsSuppressed(unit) then return false end -- a stunned/frozen unit senses nothing in time
    if attacker.side == unit.side then return false end -- never answer a friendly or self source
    -- Answer attacks, not answers (see Trait.isReacting) -- otherwise two of these would preempt each
    -- other until one pool ran dry.
    if Trait.isReacting(attacker) then return false end
    local Combat = require("models.combat")
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return false end -- nothing in hand to answer with
    local dist = math.abs(attacker.x - unit.x) + math.abs(attacker.y - unit.y)
    if dist > Combat.abilityRange(combat, unit, ab) then return false end -- sensed, but out of reach
    for _, t in ipairs(unit.traits) do
        -- Cost last, so a sense already spent is never billed for the answer it cannot throw.
        if t.def.preemptsAttack and not Combat.onCooldown(unit, t.id) and payCost(unit, t.def) then
            Combat.setCooldown(unit, t.id, t.def.magnitude or 0)
            Combat.logEvent(combat, "action",
                string.format("%s sees it coming and strikes first!",
                    (unit.char and unit.char.name) or "Unit"))
            -- Flagged a reaction for the counter's whole flight, so the attacker's own parry reads
            -- it as an answer and lets it through rather than answering back. Saved/restored rather
            -- than cleared, so a preempt reached THROUGH another reflex can't unset that one's flag.
            unit._reacting = unit._reacting or {}
            local was = unit._reacting.preempt
            unit._reacting.preempt = true
            -- Deliberately NO beginBeat, unlike every other reflex: those answer a blow and so
            -- animate a beat after it, while this one PRECEDES the blow. Staying on the current beat
            -- is what makes the view play it first (see Combat.pushFx).
            Combat.dealDamage(combat, unit, attacker, weapon)
            unit._reacting.preempt = was
            return not attacker.alive -- felled them: the blow they were throwing never arrives
        end
    end
    return false
end

-- Does a once-per-battle Second Wind reflex (a `revivesOnLethal` trait) catch a blow that would drop
-- `unit`, standing it back up at half its (unreserved) max health? Mirrors Trait.tryEvade in shape:
-- Combat.dealFlatDamage consults it at the moment a hit reaches 0 HP and, if it fires, keeps the unit
-- alive and skips the kill. The trait's own `stacks` latch spends the one charge, so it saves the
-- bearer exactly once a battle. Mutates (restores HP, latches, logs), so it must run on a REAL lethal
-- hit only -- never the damage preview, which never reaches the death path.
function Trait.trySurvive(combat, unit)
    if not unit or not unit.traits then return false end
    local Combat = require("models.combat")
    for _, t in ipairs(unit.traits) do
        if t.def.revivesOnLethal and t.stacks == 0 then
            t.stacks = 1
            local hp = unit.char.stats.health
            hp.current = math.max(1, math.floor(Combat.unreservedMax(unit.char, "health") * 0.5 + 0.5))
            Combat.logEvent(combat, "action",
                string.format("%s catches a second wind and rises!", (unit.char and unit.char.name) or "Unit"))
            return true
        end
    end
    return false
end

-- A trait hook that deals damage re-enters Combat.dealFlatDamage, which dispatches onDamaged again.
-- Two guards, because they catch different shapes of the same bug: `unit._reacting` stops a trait
-- retriggering *itself* (a retaliation that wounds its own bearer), and the depth cap stops two
-- retaliators volleying into each other forever. A hook that hits a DIFFERENT unit is legitimate
-- and terminates on its own; neither guard interferes with it.
Trait.MAX_DEPTH = 8

-- Is `unit` in the middle of answering something right now -- a counter, a parry, a riposte? True
-- between the moment a reflex begins and the moment it finishes, which is exactly when the blow it is
-- throwing is a REACTION rather than an attack of its own. The retaliation traits read this off their
-- attacker to answer attacks but not answers ("you swung at me" vs "you were only answering me"),
-- which is what keeps two swordsmen from volleying counters at each other on every exchange.
-- `dispatch` maintains the flag for the hook-driven reflexes; Trait.tryRiposte sets its own, since it
-- fires from the pre-mitigation path rather than through a hook.
function Trait.isReacting(unit)
    local reacting = unit and unit._reacting
    if not reacting then return false end
    for _, active in pairs(reacting) do
        if active then return true end
    end
    return false
end

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

        -- Is that unit mid-reaction (see Trait.isReacting)? A retaliation hook reads it off its
        -- attacker to tell a real swing from an answer, and decline to answer the latter.
        isReacting = function(u) return Trait.isReacting(u) end,

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
        -- Strip one status by id (a ward shrugging off the debuff that just landed on its bearer).
        clearStatus = function(tgt, id)
            if tgt then Status.remove(combat, tgt, id) end
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
        -- Strike `target` with the bearer's default weapon, weapon-scaled (unlike the flat `damage`
        -- above) -- what a counter throws back. Free: it spends no resource and ends no turn, so a
        -- reaction can retaliate without paying a cast's price. The blow re-enters dealFlatDamage and
        -- so can provoke the target's OWN counter; the dispatch guards (unit._reacting + MAX_DEPTH)
        -- stop that from looping.
        basicAttack = function(target)
            if not target then return 0 end
            local weapon = Combat.defaultWeapon(unit.char)
            if not weapon then return 0 end
            return Combat.dealDamage(combat, unit, target, weapon)
        end,
        -- The effective reach of the bearer's default weapon from where it stands (base range plus any
        -- high-ground field bonus). A ranged counter reads this to tell a bow (>1) from a blade, and to
        -- check the attacker is within answering distance. 0 for a unit with no weapon at all.
        weaponRange = function()
            local weapon = Combat.defaultWeapon(unit.char)
            local ab = weapon and weapon.activeAbility
            if not ab then return 0 end
            return Combat.abilityRange(combat, unit, ab)
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
        -- A cooldown keyed on the bearer, so a triggered reaction (a counter) can gate its own
        -- re-fire without the data file reaching into the combat module. Measured in ticks; it
        -- recharges from Combat.rebase alongside status durations.
        onCooldown = function(key) return Combat.onCooldown(unit, key) end,
        setCooldown = function(key, ticks) Combat.setCooldown(unit, key, ticks) end,
        -- Pay this trait's own declared `cost` (see payCost), returning false when the bearer cannot
        -- afford it -- at which point the hook must decline and answer nothing. Call it LAST, after
        -- every free refusal (cooldown, range, friendly fire), so a reflex that declines is never
        -- billed. Free for a def that declares no cost.
        pay = function() return payCost(unit, trait.def) end,
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
    -- Anything a hook does is an ANSWER to whatever fired it, so its animation cues belong to a later
    -- beat than the blow itself -- the view plays them after it rather than on top of it.
    local Combat = require("models.combat")
    Combat.beginBeat(combat)
    local snapshot = {}
    for _, t in ipairs(unit.traits) do snapshot[#snapshot + 1] = t end
    for _, t in ipairs(snapshot) do
        if t.def[hook] then t.def[hook](ctxFor(combat, unit, t, event)) end
    end
    Combat.endBeat(combat)
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
-- A hard-controlled bearer (Stun, Frozen) is too rattled to answer: its counters, thorns and other
-- on-hit reactions are suppressed, so the blow lands unanswered. (onStatusApplied is deliberately NOT
-- gated -- a cleansing ward must still be able to shrug off the very stun/freeze that just landed.)
function Trait.onDamaged(combat, unit, info)
    if reactionsSuppressed(unit) then return end
    dispatch(combat, unit, "onDamaged", info)
end

-- The bearer finished resolving an item's ability. Fired from Combat.useItem.
function Trait.onCast(combat, unit, info)
    dispatch(combat, unit, "onCast", info)
end

-- A status just landed, and `unit` was on one side of it (recipient or applier). Fired from
-- Status.apply, once per side that carries traits.
function Trait.onStatusApplied(combat, unit, info)
    dispatch(combat, unit, "onStatusApplied", info)
end

-- The bearer dropped. Fired from killUnit, before its summons are dismissed.
function Trait.onDeath(combat, unit, info)
    dispatch(combat, unit, "onDeath", info)
end

return Trait
