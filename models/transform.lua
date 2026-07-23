-- Transformation: exchanging the BODY a unit fights in, mid-battle, for another character
-- blueprint's. Pure logic (no love.graphics), so it loads under the headless tests, mirroring
-- models/status.lua and models/summon.lua -- and like them it pulls models/combat.lua through a LAZY
-- require inside its functions, so combat.lua -> transform.lua stays a one-way dependency.
--
-- The distinction worth stating, because the codebase already has two things that look like this one:
--
--   * a SUMMON (models/summon.lua) puts a NEW unit on the board beside you. Two bodies, two turns.
--   * a COPY (Summon.copyOf) puts a new unit wearing SOMEONE ELSE's shape on the board. Still two.
--   * a TRANSFORM is the same unit, in a different body. One body, one turn, one initiative slot,
--     one health bar. `unit` never changes identity: it keeps its tile, its side, its control, its
--     statuses, its cooldowns and its place in the turn order. Only `unit.char` is exchanged.
--
-- That identity is the whole reason this is a model and not a summon with extra steps. A pigged
-- knight is still the knight -- kill the pig and the knight is dead, cure the pig and the knight
-- walks back with the wounds it took as a pig -- and none of that needs writing down anywhere,
-- because there was only ever one unit.
--
-- WHAT THE SHAPE TAKES OVER, and what it emphatically does not:
--
--   * TAKEN FROM THE SHAPE -- the kit and the body: name, sprite, inventory (a bear has claws, not
--     your chainmail), and every flat stat (damage, defense, movement, speed, magicDefense).
--   * KEPT FROM THE ORIGINAL -- the CONTINUITY: the resource pools (health, mana, stamina), and the
--     reservations that constrain their ceilings. See carryContinuity.
--
-- The pools rule is load-bearing and deliberately not negotiable per-caller. If a shape brought its
-- own health, polymorph would not be control -- it would be an execute: a 20-HP pig is four seconds
-- of work, so turning the enemy champion into one would be strictly better than any damage spell in
-- the game, and turning YOURSELF into a bear would hand you a free second health bar. Carrying the
-- pools across means a transform can only ever change what a unit can DO, never how much killing it
-- takes. Every shape in the game is then balanced on one axis (its kit) instead of two.
--
-- UPKEEP. A SELF-transform is sustained, and it is priced exactly like a summon: the ability declares
-- `reserve = { stat = "mana", percent = ... }` and the shape holds that reservation for as long as it
-- is worn (see `opts.reserve` on Transform.apply). The parallel is not a coincidence -- wearing a
-- bear and having a bear are the same commitment made from different ends, so they cost the same
-- thing. What differs is only WHO holds it: a summon's reservation is held by the creature and
-- released when it falls; a shape's is held by the shape and released when it ends.
--
-- An inflicted transform (a pig) reserves nothing. It is a debuff with a duration on the victim, not
-- a commitment by the caster -- the caster already paid, in mana, at cast time.
--
-- One shape at a time: Transform.apply refuses a unit that is already transformed, so a pig cannot be
-- turned into a bear and nothing has to unwind a stack of nested bodies. The status that granted the
-- shape owns the reversion (its onExpire calls Transform.revert), exactly as Charm's status owns
-- putting a charmed unit back on its own side -- so however the shape ends (countdown, Cure, dispel),
-- it ends the same way, and the upkeep it held comes back with it.

local Character = require("models.character")

local Transform = {}

-- Is `unit` currently wearing a shape that isn't its own?
function Transform.isTransformed(unit)
    return unit ~= nil and unit._shape ~= nil
end

-- The character this unit will return to, or nil when it is already in its own body.
function Transform.originalChar(unit)
    return unit and unit._shape and unit._shape.char
end

-- Move the CONTINUOUS state from `from`'s char onto `to`'s -- everything that is a property of the
-- being rather than of the body it is wearing:
--
--   * the resource pools ({max, current}), by reference. The same table object travels, so anything
--     already holding a reference to the unit's health -- a heal mid-resolution, a status ticking
--     poison into it -- keeps pointing at the pool that matters.
--   * `reservations`, because a reservation is not a fact about a body, it is a lien on a pool: it is
--     what Combat.unreservedMax subtracts to find a ceiling, and it reads that list off whichever
--     char the unit is currently wearing. Leaving the list behind on the stashed original would
--     silently hand a transformed caster its full mana ceiling back for the duration of the shape --
--     the wolf still standing, its upkeep quietly refunded.
--
-- Carrying the liens with the pools they constrain also means an ordinary summon needs no special
-- casing here at all: a hunter who wild-shapes while its wolf stands keeps paying for the wolf, the
-- wolf's reservation stays bound to the wolf, and killing the wolf releases it as it always would --
-- whatever shape the hunter happens to be wearing at the time.
local function carryContinuity(from, to)
    for _, stat in ipairs(Character.RESOURCE_STATS) do
        if from.stats[stat] ~= nil then to.stats[stat] = from.stats[stat] end
    end
    to.reservations = from.reservations
    from.reservations = nil
end

-- Drop every reservation on `char` sustained by `holder`. The char-scoped twin of
-- Combat.releaseHeldBy (which sweeps the whole field to find a dead summon's liens); a shape knows
-- exactly which char carries its own, so it needs no sweep and no `combat`.
local function releaseHeldOn(char, holder)
    local list = char and char.reservations
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].holder == holder then table.remove(list, i) end
    end
end

-- Put `unit` into `charId`'s body. Returns the new char, or nil when it refuses (already transformed,
-- or an unknown blueprint -- a data typo should not take a unit off the board).
--
-- `opts.reserve = { stat, amount }` (what Combat.abilityReserve computed for the granting ability)
-- makes the shape SUSTAINED: the amount is spent and its ceiling locked away for exactly as long as
-- the shape is worn, and released by Transform.revert. Omit it for an inflicted shape, which costs
-- its victim nothing to wear.
--
-- Everything that reads a unit's grid is rebuilt for the new body: its passives are re-folded
-- (Combat.refreshPassives -- a bear wears no chainmail) and its traits re-attached (Trait.attach --
-- the shape's own reactions, and none of the ones the original's relics granted).
function Transform.apply(combat, unit, charId, opts)
    opts = opts or {}
    if not unit or not unit.alive then return nil end
    if Transform.isTransformed(unit) then return nil end -- one shape at a time; never nest bodies
    if not Character.defs[charId] then return nil end

    local Combat = require("models.combat")
    local Trait = require("models.trait")

    local original = unit.char
    local shape = Character.instantiate(charId)
    carryContinuity(original, shape)

    -- The token that owns the shape's upkeep. `unit._shape` is a fresh table that exists for exactly
    -- the lifetime of this transformation, which makes it the honest holder for a reservation whose
    -- release condition is "the shape ended" -- no summon to hang it on, and no way for it to outlive
    -- what sustains it.
    unit._shape = { char = original }
    unit.char = shape
    Combat.refreshPassives(unit)
    Trait.attach(unit)

    -- Reserved AFTER the swap, so the lien lands on the list the unit is now actually wearing (the
    -- one carryContinuity just moved onto the shape) and Combat.unreservedMax sees it immediately.
    local reserve = opts.reserve
    if reserve then
        Combat.reserve(unit.char, reserve.stat, reserve.amount, unit._shape)
    end

    Combat.logEvent(combat, "status", string.format("%s takes the shape of %s.",
        original.name or "Unit", shape.name or charId), unit)
    return shape
end

-- Put `unit` back in its own body, releasing whatever upkeep the shape held. No-op (returns false)
-- for a unit that was never transformed, so every removal path can call it blindly -- which is
-- exactly what a status's onExpire does, and it fires on a countdown, a Cure, and a dispel alike.
--
-- Wounds stay: the pools travelled by reference into the shape and travel back the same way, so a
-- bear that spent its shape being beaten reverts to a hunter who has been beaten. What the shape was
-- paying for comes back the way a lapsed summon's does -- the ceiling is freed, but the mana that was
-- spent to commit is not refunded (see Combat.releaseHeldBy).
function Transform.revert(combat, unit)
    if not Transform.isTransformed(unit) then return false end
    local Combat = require("models.combat")
    local Trait = require("models.trait")

    local token = unit._shape
    local original = token.char
    carryContinuity(unit.char, original)
    releaseHeldOn(original, token) -- the shape's own upkeep ends with the shape

    unit.char = original
    unit._shape = nil
    Combat.refreshPassives(unit)
    Trait.attach(unit)

    -- A body that reverts while dead is a corpse changing shape, which is a real thing that happens
    -- (a pig cut down turns back into the knight it was) but not a thing to announce as a recovery.
    if unit.alive then
        Combat.logEvent(combat, "status", string.format("%s returns to its own shape.",
            original.name or "Unit"), unit)
    end
    return true
end

return Transform
