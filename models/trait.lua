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
--   * a character blueprint  -- `traits = { "trait_wrath_rising" }` on data/characters/<id>.lua
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

-- Pay a resolved `cost = { stat, amount }` out of `unit`, or report that it cannot be paid. A nil
-- cost is free and always "pays".
--
-- Mutates on success, so it must be the LAST gate a reflex checks -- never call it before the cheap
-- refusals (suppression, reach, friendly fire), or a reflex that then declines has quietly billed its
-- bearer for nothing. Callers: Trait.tryRiposte/tryPreempt below, and `ctx.pay` for a hook-driven
-- reflex (data/traits/trait_parry.lua).
--
-- Split in two so the counter PREVIEW (Trait.counterPreview) can ask the same question without
-- spending anything: canPay answers it, payCost answers it and bills. A reflex canPay says yes to is
-- one payCost will let through, so what the tooltip promises is what the exchange delivers.
-- Both take a cost in EITHER shape -- a lone `{ stat, amount }` (a trait def's own price) or a list
-- of them (what Trait.answerCost quotes, since the weapon being thrown back may draw on two pools).
-- Normalized through Item.costList so the shapes are unpacked in one place, and an answer is all-or
-- -nothing: a reflex that cannot cover every pool declines rather than paying for part of a swing.
local function canPay(unit, cost)
    local Combat = require("models.combat")
    for _, c in ipairs(require("models.item").costList(cost)) do
        if Combat.resource(unit.char, c.stat) < c.amount then return false end
    end
    return true
end

local function payCost(unit, cost)
    if not canPay(unit, cost) then return false end
    local Combat = require("models.combat")
    for _, c in ipairs(require("models.item").costList(cost)) do
        Combat.drainResource(unit.char, c.stat, c.amount)
    end
    return true
end

-- Manhattan distance between two units -- how every reflex below measures a blow, since a counter's
-- whole question is "could they reach me, and can I reach back?".
local function distance(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- The effective reach of `unit`'s longest weapon from where it stands, or 0 with nothing in hand.
-- Reported for display and for the AI's threat math; the live gate is Combat.answeringWeapon, which
-- also honours each weapon's dead zone.
local function weaponReach(combat, unit)
    local Combat = require("models.combat")
    local best = 0
    local function consider(item)
        local ab = item and item.activeAbility
        if ab then best = math.max(best, Combat.abilityRange(combat, unit, ab)) end
    end
    for _, item in ipairs(require("models.character").eachItem(unit.char)) do
        if item.type == "weapon" then consider(item) end
    end
    if best == 0 then consider(unit.char.unarmed) end
    return best
end

-- How steeply an answer's price climbs with each one already thrown since the bearer last acted:
-- 1st at price, 2nd at double, 3rd at quadruple, capped so the number stays a number. This is the
-- whole of what paces answers WITHIN an exchange now that the per-trait cooldowns are gone -- and it
-- does the job in a currency the player can see draining, rather than a hidden timer. The tally is
-- cleared in Combat.startTurn.
Trait.ANSWER_ESCALATION_CAP = 8

-- What answering a blow from `dist` tiles away costs `unit`, or nil when the answer is free.
--
-- The rule is "an answer is a swing, and a swing costs what a swing costs": a reflex that throws the
-- bearer's own weapon back is billed that weapon's own `activeAbility.cost`, so a dagger answers for
-- 4 and a greatsword for 16 without anyone hand-tuning a second table. That is also what keeps
-- docs/weapons.md's "a greatsword must not also parry" true by economics rather than by exception.
--
-- A reflex that does NOT swing -- thorns throwing a share of the blow back off its spikes, a shield
-- bash landing a stun -- is billed whatever its own def declares instead, which is usually nothing:
-- there is no weapon in the motion to price.
--
-- Either way the tally of answers already thrown this round doubles it (see above).
--
-- Returns a LIST of `{ stat, amount }` (nil when the answer is free), because the weapon thrown back
-- may draw on more than one pool -- a crescent blade answers in mana AND stamina, and the escalation
-- falls on both, so the pools it drains are the pools its answer costs.
function Trait.answerCost(combat, unit, trait, dist)
    local Combat = require("models.combat")
    local rule = trait and trait.def and trait.def.counter
    local base
    if rule and (rule.reflect or rule.applies) then
        base = trait.def.cost -- not a swing: it costs what it says it costs, if anything
    else
        local weapon = Combat.answeringWeapon(combat, unit, dist)
        base = weapon and weapon.activeAbility and weapon.activeAbility.cost
    end
    local costs = require("models.item").costList(base)
    if #costs == 0 then return nil end
    local thrown = unit.answersThisRound or 0
    local multiplier = math.min(2 ^ thrown, Trait.ANSWER_ESCALATION_CAP)
    for _, c in ipairs(costs) do c.amount = math.floor(c.amount * multiplier) end
    return costs
end

-- Record that `unit` has thrown an answer, so the next one this round costs double (Trait.answerCost).
local function tallyAnswer(unit)
    unit.answersThisRound = (unit.answersThisRound or 0) + 1
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
-- an arrow, a poison tick, a trap, or an area blast (`area`, the flag every reflex in this file shares
-- -- see Trait.mayCounter) all pass straight through: you cannot parry what you cannot touch, and a
-- blast is not a swing aimed at anyone. `magnitude` is the cooldown length in ticks.
--
-- Mutates (spends the cooldown, deals the counter, logs), so it must run on a REAL hit only, never the
-- damage preview -- which never reaches this path, since previews read Combat.mitigatedDamage instead.
--
-- The gates live in `riposteTrait` -- a pure predicate naming the blade that would answer -- so that
-- the hover preview (Trait.counterPreview) can ask "would this be riposted?" through the very same
-- rules the live blow runs, and the two can never drift apart.
local function riposteTrait(combat, unit, attacker, tags, area)
    if not unit or not unit.traits or not attacker or not attacker.alive then return nil end
    if area then return nil end -- a blast is not a blow: there is no swing to turn aside
    if hasTag(tags, "magical") then return nil end -- a spell is not something a blade can turn
    if reactionsSuppressed(unit) then return nil end -- a stunned/frozen unit holds no guard
    if attacker.side == unit.side then return nil end -- never answer a friendly or self source
    if distance(attacker, unit) ~= 1 then return nil end -- melee only: an archer stands beyond the blade
    -- Answer attacks, not answers: never riposte something that is itself a reaction, or two duelists
    -- would trade parries forever (see Trait.isReacting).
    if Trait.isReacting(attacker) then return nil end
    for _, t in ipairs(unit.traits) do
        -- Cost last, so a blade that couldn't answer anyway is never weighed against a pool it
        -- needn't spend.
        if t.def.deflectsMelee and canPay(unit, Trait.answerCost(combat, unit, t, 1)) then
            return t
        end
    end
    return nil
end

function Trait.tryRiposte(combat, unit, attacker, tags, area)
    local t = riposteTrait(combat, unit, attacker, tags, area)
    if not t then return false end
    local Combat = require("models.combat")
    payCost(unit, Trait.answerCost(combat, unit, t, 1)) -- the predicate already checked it can be paid
    tallyAnswer(unit)
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
    local weapon = Combat.answeringWeapon(combat, unit, 1)
    if weapon then Combat.dealDamage(combat, unit, attacker, weapon) end
    Combat.endBeat(combat)
    unit._reacting.riposte = was
    return true
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
--
-- Like the riposte above it, the gates live in a pure predicate (`preemptTrait`), so the hover
-- preview can ask whether a blow would be answered first without spending the bearer's stamina to
-- find out -- and so it asks through the very rules the live blow runs.
local function preemptTrait(combat, unit, attacker, area)
    if not unit or not unit.traits or not attacker or not attacker.alive then return nil end
    if area then return nil end -- a blast is not a swing to sense coming (see Trait.mayCounter)
    if reactionsSuppressed(unit) then return nil end -- a stunned/frozen unit senses nothing in time
    if attacker.side == unit.side then return nil end -- never answer a friendly or self source
    -- Answer attacks, not answers (see Trait.isReacting) -- otherwise two of these would preempt each
    -- other until one pool ran dry.
    if Trait.isReacting(attacker) then return nil end
    local Combat = require("models.combat")
    local dist = distance(attacker, unit)
    -- Sensed, but nothing in hand that reaches back from here (a bow's dead zone counts: an archer
    -- cannot answer a foe standing on top of it).
    if not Combat.answeringWeapon(combat, unit, dist) then return nil end
    for _, t in ipairs(unit.traits) do
        -- Cost last, so a sense that couldn't answer anyway is never weighed against a pool it
        -- needn't spend.
        if t.def.preemptsAttack and canPay(unit, Trait.answerCost(combat, unit, t, dist)) then
            return t
        end
    end
    return nil
end

function Trait.tryPreempt(combat, unit, attacker, area)
    local t = preemptTrait(combat, unit, attacker, area)
    if not t then return false end
    local Combat = require("models.combat")
    local dist = distance(attacker, unit)
    payCost(unit, Trait.answerCost(combat, unit, t, dist)) -- the predicate already checked it can be paid
    tallyAnswer(unit)
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
    Combat.dealDamage(combat, unit, attacker, Combat.answeringWeapon(combat, unit, dist))
    unit._reacting.preempt = was
    return not attacker.alive -- felled them: the blow they were throwing never arrives
end

-- Does a counterspell reflex (a `countersSpell` trait -- Counter Magic) unravel an incoming
-- SINGLE-TARGET spell outright? Consulted from Combat.dealDamage (never the flat path: a Burn tick and
-- a trap are not spells anyone can unweave), it negates the cast completely -- no damage, no rider
-- status, nothing -- for the price of the bearer's own mana and a cooldown.
--
-- The trait's economy is the whole point, and it is the counterspell's classic bargain: it is not
-- gated on the spell being SMALL, so it eats a meteor as happily as a spark -- but it costs a flat
-- price to do so and then goes quiet for `magnitude` ticks. Answering a cantrip with it is a poor
-- trade the bearer chose to make; catching the big one is what it was carried for. Unlike a barrier,
-- nothing about it is spent by being aimed at, so a mage who bluffs at it wastes only their own turn.
--
-- Mutates (spends mana, starts the cooldown, logs), so it must run on a REAL cast only -- never the
-- damage preview, which reads Combat.computeDamage and never reaches dealDamage's ward path.
function Trait.tryCounterMagic(combat, unit, attacker, tags)
    if not unit or not unit.traits or not attacker then return false end
    if not hasTag(tags, "magical") then return false end -- it unweaves spells, not swords
    if reactionsSuppressed(unit) then return false end   -- a stunned/frozen unit weaves nothing
    if attacker.side == unit.side then return false end  -- never answer a friendly or self cast
    local Combat = require("models.combat")
    for _, t in ipairs(unit.traits) do
        -- Cost last, so a counter already on cooldown is never weighed against mana it needn't spend.
        if t.def.countersSpell and not Combat.onCooldown(unit, t.id) and canPay(unit, t.def.cost) then
            payCost(unit, t.def.cost)
            Combat.setCooldown(unit, t.id, t.def.magnitude or 0)
            Combat.logEvent(combat, "action", string.format("%s unravels %s's spell!",
                (unit.char and unit.char.name) or "Unit", (attacker.char and attacker.char.name) or "the caster"))
            return true
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

-- The gates every RETALIATION reflex shares, read off the trait's declarative `counter` rule. A def
-- that answers a blow it has already taken (data/traits/parry.lua, melee_counter, thorns, ...) declares
-- what provokes it as data and calls `ctx.mayCounter()` as the first line of its onDamaged hook,
-- instead of spelling the same five conditions out again. The rule:
--
--   counter = {
--     reach = "melee",          -- OPTIONAL: adjacent only, whatever the bearer's weapons reach.
--                               -- For a reflex that is adjacent by its nature -- spikes on armor,
--                               -- a shield shoved into someone. Omit it and the default applies:
--                               -- you answer whatever a weapon in your grid can reach back at.
--     requiresTag = "physical", -- optional: only that school of blow provokes it
--     requiresStatus = "status_defending", -- optional: only while the bearer holds that status
--     requiresArmed = true,     -- optional: only when the trait armed itself at combat start
--     answersReactions = true,  -- optional: it answers even a blow that is itself an answer
--     reflect = true,           -- optional: it throws `magnitude`% of the blow back, not a weapon swing
--     applies = "status_stun",         -- optional: it lands this status rather than damage
--   }
--
-- Free gates only: it never spends the reflex's `cost` (the hook calls ctx.pay() last for that, and
-- Trait.counterPreview asks canPay). Cost aside, a true here means the reflex fires -- which is what
-- lets the hover preview promise a counter and be right, since it walks these same gates.
--
-- `area` flags a blow that came out of an AREA ability -- a bomb, a fireball, a cleave -- rather than a
-- blow aimed at this bearer (Combat.dealDamage sets it off Combat.isSingleTarget). None of them answer
-- one, and for the same reason the mirror wards don't: a blast is nobody's duel. It is thrown at GROUND,
-- and everything standing on that ground catches the same burst -- there is no swing aimed at you to
-- turn aside, and no thread back to the thrower to answer along. Without this a bomb lobbed into a
-- huddle is answered once per body caught, which prices the cheapest consumable in the game as if it
-- were five duels at once -- and reads as nonsense besides, a swordsman parrying an explosion.
-- `at` carries what was true at the MOMENT OF THE HIT, for an answer that is thrown later (a held one
-- -- see Combat.beginAnswers): `at.answering` is the Trait.isReacting(attacker) read, which cannot be
-- taken afterwards because the flag only stands for the flight of the swing that set it; `at.ux/uy` and
-- `at.ax/ay` are the two tiles the blow was struck across, which a REFLECTING reflex is judged by (see
-- below). nil asks the board as it stands, which is what the hover preview wants: it weighs a blow
-- nobody has thrown yet.
function Trait.mayCounter(combat, unit, trait, attacker, tags, area, at)
    local rule = trait and trait.def and trait.def.counter
    if not rule or not unit or not attacker or not attacker.alive then return false end
    if area then return false end
    if attacker.side == unit.side then return false end -- never answer a friendly or self source
    if reactionsSuppressed(unit) then return false end -- a stunned/frozen unit answers nothing
    if rule.requiresArmed and not trait.armed then return false end
    if rule.requiresTag and not hasTag(tags, rule.requiresTag) then return false end
    if rule.requiresStatus and not require("models.status").has(unit, rule.requiresStatus) then
        return false
    end
    -- A reflex that answers ATTACKS but not ANSWERS: without this, two swordsmen volley counters at
    -- each other on every exchange (see Trait.isReacting). The hungrier reflexes opt out by declaring
    -- answersReactions -- a shorter cooldown buys a wider guard.
    local answering = at and at.answering
    if answering == nil then answering = Trait.isReacting(attacker) end
    if not rule.answersReactions and answering then return false end
    local Combat = require("models.combat")
    -- Reach is the gate, and the only one. Can the bearer reach back at the tile the blow came from?
    -- Then you answer it; otherwise you don't, and the reason is a fact on the board rather than a
    -- timer nobody can see. A swordsman answers the foe beside them and not the archer four tiles off;
    -- the archer answers the bowman across the field and not the brawler in their face.
    --
    -- WHICH weapon's reach that is depends on where the reflex came from:
    --   * A counter carried by a WEAPON (Parry, on the sword itself) answers only within THAT weapon's
    --     band. Parry is the sword's reach and the sword's alone -- a bow sharing the grid does not lend
    --     the blade two tiles ("how can the bow parry?"). A spear's Parry reaches its two, a knife's its
    --     one, because the reach is the granting weapon's, not the longest thing in the grid.
    --   * A counter granted by a UTILITY owns no weapon of its own (the Reprisal Quiver's Ranged
    --     Counter), so it answers with whatever weapon in the grid can reach back -- which is the whole
    --     point of that item. Combat.answeringWeapon honours each weapon's dead zone for it.
    --
    -- Asked of the board as it stands when the answer is actually thrown, which for an on-hit reflex is
    -- once the whole action has resolved (Combat.beginAnswers) -- so a blow that wounds and then SHOVES
    -- is measured from where it left its target, and a brawler knocked out of melee answers nothing.
    --
    -- With one exception, and it is the exception that says what the rule is really about: a REFLECTING
    -- reflex is not a swing thrown back, it is the CONTACT itself. Spikes bite the fist that struck them
    -- at the instant it struck, so they are judged by the two tiles the blow was struck across, and a
    -- shove that comes afterwards cannot carry their bearer out of a bite already taken. Everything else
    -- here answers by MOVING -- reaching, swinging, shoving a shield forward -- and needs somewhere to
    -- reach from and something still in reach.
    local dist
    if rule.reflect and at and at.ux then
        dist = math.abs((at.ax or attacker.x) - at.ux) + math.abs((at.ay or attacker.y) - at.uy)
    else
        dist = distance(attacker, unit)
    end
    if rule.reach == "melee" then return dist == 1 end
    -- A weapon-borne reflex is bound to its own weapon's reach; only a reflex with no weapon of its own
    -- falls back to "whatever in the grid reaches" (see the note above).
    local weapon = trait.item
    local ab = weapon and weapon.type == "weapon" and weapon.activeAbility
    if ab then
        return dist >= Combat.abilityMinRange(ab)
            and dist <= Combat.abilityRange(combat, unit, ab)
    end
    return Combat.answeringWeapon(combat, unit, dist) ~= nil
end

-- What `target` would throw BACK at `attacker` for a blow struck right now, as an ordered list of
--   { name, damage, lethal, status, deflects, first }
-- (empty when nothing answers). Pure -- it spends no cooldown, no stamina and no HP -- so the hover
-- preview can warn the player that the swing they are lining up will be answered, and by what.
--
-- `opts` describes the blow being weighed: `tags` (its school), `damage` (what it would deal, which is
-- what a reflecting reflex throws back a share of), `area` (whether it is a blast rather than a blow
-- aimed at this target -- see Trait.mayCounter; nothing answers one) and `lethal`. Lethality matters:
-- the hook-driven reflexes fire from Trait.onDamaged, which a killing blow never reaches, so a strike
-- that fells its target is answered by nothing. The two model-side reflexes are the exception -- both
-- fire BEFORE the blow lands, so they answer even a lethal one.
--
-- `opts.fromX/fromY` weighs the blow as if thrown from that tile rather than the one the attacker
-- stands on, for a strike that walks into reach first (see Combat.previewCounters). `opts.toX/toY` is
-- the mirror of it on the other side: the tile the blow LEAVES its target on, for one that shoves as
-- well as wounds.
function Trait.counterPreview(combat, target, attacker, opts)
    opts = opts or {}
    local out = {}
    if not target or not target.alive or not attacker then return out end
    local Combat = require("models.combat")
    local Status = require("models.status")
    -- Every gate below reads the attacker's POSITION (melee or not, within our reach or not). To weigh
    -- a blow thrown from somewhere the attacker hasn't walked to yet, stand in for it with a table that
    -- reads through to the real unit for everything but where it stands.
    if opts.fromX and (opts.fromX ~= attacker.x or opts.fromY ~= attacker.y) then
        attacker = setmetatable({ x = opts.fromX, y = opts.fromY }, { __index = attacker })
    end
    -- ...and the same for the TARGET, for a blow that also SHOVES the one it hits (a mace, a Water
    -- Ball). An on-hit answer waits for the whole action to finish before it is thrown
    -- (Combat.beginAnswers), so it is thrown from wherever the shove left its bearer standing -- and a
    -- brawler driven two tiles back has nothing in reach to answer with. Only the on-hit reflexes move:
    -- the two model-side ones below fire BEFORE the blow lands, and so before anything has shoved
    -- anyone, which is why `target` itself stays where it stands.
    local held = target
    if opts.toX and (opts.toX ~= target.x or opts.toY ~= target.y) then
        held = setmetatable({ x = opts.toX, y = opts.toY }, { __index = target })
    end

    -- The distance the answer is thrown across: which weapon answers, and so what it does and what
    -- it costs, both hang off it. Two of them, for the two moments an answer can come at: as the blow
    -- lands (the model-side reflexes) and after it has fully resolved (everything held).
    local function spanTo(u) return math.abs(attacker.x - u.x) + math.abs(attacker.y - u.y) end
    local dist, heldDist = spanTo(target), spanTo(held)

    -- What the weapon that can reach back would do to the attacker, post-mitigation: the answer every
    -- reflex but a reflecting one throws (ctx.basicAttack / the model-side counters all swing it).
    local function weaponBack(from, span)
        local weapon = Combat.answeringWeapon(combat, from or target, span or dist)
        if not weapon then return 0 end
        return Combat.computeDamage(combat, from or target, attacker, weapon)
    end
    local function entry(name, damage, extra)
        local e = extra or {}
        e.name, e.damage = name, damage
        -- Worth calling out on its own: an answer that kills is a reason not to swing at all.
        e.lethal = (damage or 0) > 0 and damage >= (attacker.char.stats.health.current or 0)
        out[#out + 1] = e
        return e
    end

    local rt = riposteTrait(combat, target, attacker, opts.tags, opts.area)
    if rt then
        entry(rt.name, weaponBack(), { deflects = true, cost = Trait.answerCost(combat, target, rt, dist) })
    end
    local pt = preemptTrait(combat, target, attacker, opts.area)
    if pt then
        entry(pt.name, weaponBack(), { first = true, cost = Trait.answerCost(combat, target, pt, dist) })
    end

    -- A riposte turns the blow aside entirely, and a blow that never lands provokes no on-hit hook --
    -- nor does one that kills (Trait.onDamaged is not called on the killing blow). Nor does one that
    -- lands hard control (`opts.suppressed`: a hammer's stun, an ice bolt's freeze), which arrives
    -- with the wound and rattles the target out of answering it -- the same order the live hit runs in
    -- (Combat.dealFlatDamage). Deliberately BELOW the two model-side reflexes and not above them: both
    -- fire before the blow lands, so a stun that only exists once it has landed cannot pre-empt them.
    if rt or opts.lethal or opts.suppressed then return out end
    for _, t in ipairs(target.traits or {}) do
        -- A reflecting reflex is the contact and not a swing, so it is weighed where the blow LANDED;
        -- everything else answers by moving, and is weighed from wherever the action left its bearer
        -- standing (see Trait.mayCounter, which draws the same line on the live blow).
        local reflects = t.def.counter and t.def.counter.reflect
        local from, span = held, heldDist
        if reflects then from, span = target, dist end
        local cost = Trait.answerCost(combat, from, t, span)
        if Trait.mayCounter(combat, from, t, attacker, opts.tags, opts.area) and canPay(target, cost) then
            local rule = t.def.counter
            if rule.applies then
                local def = Status.defs[rule.applies]
                entry(t.name, 0, { status = (def and def.name) or rule.applies, cost = cost })
            elseif rule.reflect then
                local share = math.floor((opts.damage or 0) * (t.def.magnitude or 0) / 100)
                -- Below a full point of reflection the spikes don't bite at all (data/traits/thorns.lua).
                if share >= 1 then
                    entry(t.name, Combat.mitigatedDamage(attacker, share, { "physical" }), { cost = cost })
                end
            else
                entry(t.name, weaponBack(from, span), { cost = cost })
            end
        end
    end
    return out
end

-- Build the effect context handed to a trait def's hooks. Combat is required lazily (at call time,
-- not load time) so combat.lua -> trait.lua stays one-way. `event` carries the hook's own fields.
local function ctxFor(combat, unit, trait, event)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local Summon = require("models.summon")

    -- Stamp a live conjuration onto the item that granted this trait (see ctx.summon below).
    local function claim(summoned)
        if trait.item and summoned and summoned.alive then trait.item.activeSummon = summoned end
        return summoned
    end

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

        -- Does the blow that just landed provoke this reflex (see Trait.mayCounter)? A retaliation
        -- hook opens with it and answers only if it says yes -- every free gate its `counter` rule
        -- declares, in one call, and the same call the hover preview asks. Costs nothing: a priced
        -- reflex still calls ctx.pay() last.
        mayCounter = function()
            local e = event or {}
            return Trait.mayCounter(combat, unit, trait, e.attacker, e.tags, e.area, e.at)
        end,

        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, trait.name or trait.id)
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            return Combat.applyHeal(combat, tgt, amount)
        end,
        -- Take `amount` of a resource straight out of a unit, returning what was actually taken.
        -- Deliberately not `damage` when the resource is health: a drain is a toll, not a blow -- no
        -- armor softens it, no barrier eats it, no dodge slips it, and it cannot kill (it floors at 0).
        -- What a price paid in flesh runs through (data/traits/blood_price.lua).
        drain = function(tgt, stat, amount)
            if not tgt then return 0 end
            return Combat.drainResource(tgt.char, stat, amount)
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
            -- Whichever weapon in the grid reaches THAT far, not whichever sorts first: a counter
            -- thrown across four tiles is a bowshot even when a sword sits in the top-left slot.
            local weapon = Combat.answeringWeapon(combat, unit, distance(unit, target))
            if not weapon then return 0 end
            return Combat.dealDamage(combat, unit, target, weapon)
        end,
        -- The effective reach of the bearer's longest weapon from where it stands (base range plus any
        -- high-ground field bonus). 0 for a unit with no weapon at all. Reported for display; the live
        -- gate a reflex runs is Combat.answeringWeapon, which also honours each weapon's dead zone.
        weaponRange = function() return weaponReach(combat, unit) end,
        -- Summon a creature, sustained by the bearer -- and, when the trait came off an ITEM, hold that
        -- item's `activeSummon` claim with it, exactly as `fx.summon` does for an ability's own cast
        -- (see Combat.useItem). One rule, however the item summons: while the creature a relic put on
        -- the field still stands, the relic's own call is refused (Combat.itemBlockReason). That is what
        -- keeps the Wolfsong Horn silent while the companion it opened the battle with is alive -- the
        -- archer buys the Spirit by outliving her wolf, not by blowing the horn over its head.
        --
        -- Claimed only for a creature that drew breath: one that dies on the tile it was called to
        -- (a trap, a fire) holds nothing, the same as an ability's summon. A trait on an item with no
        -- active ability of its own (the Hollow Crown) stamps a claim nothing ever reads.
        -- `opts.noClaim` skips stamping the granting item's one-summon claim: a companion that must
        -- NOT lock the item's own active out (the Wolfsong Horn's howl fires WHILE its wolf stands, the
        -- opposite of a summon ability's one-at-a-time rule). The summoned unit is returned either way.
        summon = function(charId, px, py, opts)
            local summoned = Summon.spawn(combat, unit, charId, px, py, opts)
            if not (opts and opts.noClaim) then claim(summoned) end
            return summoned
        end,
        -- Take the shape of another unit: a copy of `target` on the bearer's side (Envy). Held like
        -- the summon above.
        copyOf = function(target, px, py, opts)
            return claim(Summon.copyOf(combat, unit, target, px, py, opts))
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        -- A cooldown keyed on the bearer, so a triggered reaction (a counter) can gate its own
        -- re-fire without the data file reaching into the combat module. Measured in ticks; it
        -- recharges from Combat.rebase alongside status durations.
        onCooldown = function(key) return Combat.onCooldown(unit, key) end,
        setCooldown = function(key, ticks) Combat.setCooldown(unit, key, ticks) end,
        -- The bearer's running count of an in-battle event (blows landed, hits taken, ...): what a
        -- REACTIVE signature gates its payoff on. A trait-driven ultimate declares its own `unlock` on
        -- its def and opens its hook with `if not ctx.unlockMet() then return end`, then calls
        -- `ctx.unlockConsume()` once it fires -- the reaction-side mirror of the active signature's
        -- Combat.itemBlockReason gate and Combat.unlockConsume. Keyed by the trait, so its baseline
        -- never collides with an item signature's (Combat.unlockReady / unlockSpend).
        tally = function(event) return Combat.tallyCount(unit, event) end,
        unlockMet = function() return Combat.unlockReady(unit, trait.def.unlock, trait, combat) end,
        unlockConsume = function() return Combat.unlockSpend(unit, trait.def.unlock, trait) end,
        -- Pay for this firing, returning false when the bearer cannot afford it -- at which point the
        -- hook must decline and answer nothing. Call it LAST, after every free refusal (reach,
        -- friendly fire), so a reflex that declines is never billed.
        --
        -- A RETALIATION (one with a `counter` rule, answering a known attacker) is priced by
        -- Trait.answerCost: what the swing that answers costs, doubled for each answer already thrown
        -- this round. Everything else pays its own declared `cost`, which is usually nothing.
        -- Tallying the answer is part of paying for it, so the next one this round costs more.
        pay = function()
            local e = event or {}
            local isAnswer = trait.def.counter ~= nil and e.attacker ~= nil
            local cost = isAnswer
                and Trait.answerCost(combat, unit, trait, distance(e.attacker, unit))
                or trait.def.cost
            if not payCost(unit, cost) then return false end
            if isAnswer then tallyAnswer(unit) end
            return true
        end,
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
