-- THE ELF COURT: the second axis of Pride's elves, beside the race's Unblemished. Built 2026-11-19 on the creature
-- identity pass, which found the court's whole answer was "a wide or unavoidable first hit" and asked for a second
-- one. Two rules, one model, because both read the same fact -- whether an elf is still Unblemished
-- (data/status/status_unblemished.lua) -- and decide what happens around the blow that would end it.
--
--   THE RETAINER'S OATH   a Retainer beside an Unblemished elf takes the blows meant for that elf (Combat.tryRedirect's
--                         declared Oathward, re-sworn at every turn's edge). The elf it covers wears Retained. So a
--                         wide first hit that lands on a retainer's charge marks the retainer instead, and the court
--                         is answered in ORDER: break the retainers, then mark the court.
--   WOUNDED PRIDE         the blow that marks a court elf Taunts it onto whoever struck it (status_taunt, the existing
--                         compulsion in AI.preempt). So who draws first blood decides where the court walks: let the
--                         body you can afford to have rushed strike first.
--
-- WHY THE OATH IS A DECLARED OATHWARD AND NOT A NEW GUARD KIND. Combat.tryRedirect already carries a guard that
-- covers one named ally with no cooldown (data/traits/trait_oathward_declared.lua, models/court.lua), and its
-- redirected blow re-enters the damage funnel on the guardian -- so the retainer's own hide, wards and wound all
-- apply, and its Unblemished goes instead. The one thing the oath adds is a condition: it holds only while its charge
-- is still Unblemished. That is read LIVE through the guard's `kind` (a metatable, below), because the blow that
-- marks an elf -- a burn tick, an interposed blow that missed the retainer -- can land between two turn edges, and a
-- guard re-sworn only at the edges would go on soaking blows for an elf that has nothing left to protect.
--
-- A RETAINER NEVER SWEARS TO A RETAINER. Two retainers sworn to each other would bounce one blow between them; the
-- charge is always an elf that carries no oath of its own.

local ElfCourt = {}

ElfCourt.BADGE = "status_retained"
ElfCourt.UNBLEMISHED = "status_unblemished"

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end

local function isElf(u) return u ~= nil and u.char ~= nil and u.char.race == "elf" end

-- Does `u` carry the oath? A retainer is whatever wears the trait, so a summon or a hire carrying the organ would be
-- one too. Read off the trait list directly rather than through Trait.flag, which a Sunder gags: a sundered retainer
-- is still a retainer, and must not become some other retainer's charge.
function ElfCourt.isRetainer(u)
    for _, t in ipairs((u and u.traits) or {}) do
        if t.def and t.def.retainsTheCourt then return true end
    end
    return false
end

-- The elf a retainer would swear to right now: an Unblemished elf of its side, standing, one step away, carrying no
-- oath of its own. The highest tier wins (a retainer serves the house, not the pageboy beside it), then the most
-- health; a tie keeps scan order, so a seed replays the same oath.
function ElfCourt.chargeFor(combat, retainer)
    if not (combat and retainer and retainer.alive) then return nil end
    local C = Combat()
    local best
    for _, u in ipairs(combat.units or {}) do
        if u ~= retainer and u.alive and u.side == retainer.side and isElf(u) and not ElfCourt.isRetainer(u)
            and Status().has(u, ElfCourt.UNBLEMISHED) and C.unitGap(u, retainer) == 1 then
            local tier = (u.char and u.char.tier) or 0
            local hp = (u.char.stats and u.char.stats.health and u.char.stats.health.max) or 0
            if not best or tier > best.tier or (tier == best.tier and hp > best.hp) then
                best = { unit = u, tier = tier, hp = hp }
            end
        end
    end
    return best and best.unit or nil
end

-- A guard whose `kind` is asked at the moment of the blow: an Oathward while its charge is still Unblemished, and
-- nothing at all after (Combat.tryRedirect passes over a guard with no kind it knows).
local function oath(charge)
    local guard = { cooldown = 0, ward = charge, retainersOath = true }
    return setmetatable(guard, { __index = function(_, key)
        if key ~= "kind" then return nil end
        if charge.alive and Status().has(charge, ElfCourt.UNBLEMISHED) then return "oathward" end
        return nil
    end })
end

-- Is this retainer's oath live right now, and to whom? Nil when it covers nobody.
function ElfCourt.sworn(retainer)
    local g = retainer and retainer.alive and retainer.guard
    if not (g and rawget(g, "retainersOath")) then return nil end
    if g.kind ~= "oathward" then return nil end
    return g.ward
end

-- Lay Retained on every elf a live oath covers, and lift it off every elf none does. The badge is the readout only;
-- the redirect reads the guard, so a badge stripped by a Dispel changes nothing and is laid again at the next edge.
function ElfCourt.badges(combat)
    if not combat then return end
    local covered = {}
    for _, r in ipairs(combat.units or {}) do
        local charge = ElfCourt.sworn(r)
        if charge then covered[charge] = covered[charge] or r end
    end
    for _, u in ipairs(combat.units or {}) do
        local has = Status().has(u, ElfCourt.BADGE)
        if covered[u] and u.alive and not has then
            Status().apply(combat, u, ElfCourt.BADGE, { applier = covered[u] })
        elseif has and not covered[u] then
            Status().remove(combat, u, ElfCourt.BADGE)
        end
    end
end

-- Swear (or re-swear) one retainer to the charge beside it, then square the badges. Asked at the bell and at every
-- turn's edge, because every one of those can have moved a retainer, its charge or the blow that marked it. A
-- retainer that already carries some OTHER guard (a Consort's borrowed oath) is left alone.
function ElfCourt.swear(combat, retainer)
    if not (combat and retainer) then return end
    if retainer.guard and not rawget(retainer.guard, "retainersOath") then return end
    local charge = retainer.alive and ElfCourt.chargeFor(combat, retainer) or nil
    local current = retainer.guard and rawget(retainer.guard, "ward")
    if charge ~= current then
        retainer.guard = charge and oath(charge) or nil
        if charge then
            Combat().logEvent(combat, "status", string.format("%s stands at %s's side.",
                retainer.char.name or "The Retainer", charge.char.name or "the elf"), { retainer, charge })
        end
    end
    ElfCourt.badges(combat)
end

-- ------------------------------------------------------------------------------------------------ WOUNDED PRIDE
-- A court elf carrying the rule took a wound. If it was still Unblemished -- this is the blow that marks it, and
-- Trait.onDamaged runs before the status's own hook takes the lift away -- it is Taunted onto the striker. A blow
-- with no striker (a burn, a trap) marks it and compels nothing: there is nobody to answer.
function ElfCourt.affronted(combat, elf, attacker, amount, trait)
    if not (combat and elf and elf.alive) then return false end
    if (amount or 0) <= 0 then return false end
    if not Status().has(elf, ElfCourt.UNBLEMISHED) then return false end
    if not (attacker and attacker.alive and attacker ~= elf and attacker.side ~= elf.side) then return false end
    local turns = trait and Trait().param(trait, "tauntTicks", 10) or 10
    Status().apply(combat, elf, "status_taunt", { applier = attacker, duration = turns })
    Combat().logEvent(combat, "status", string.format("%s will not forgive %s.",
        elf.char.name or "The elf", (attacker.char and attacker.char.name) or "it"), { elf, attacker })
    return true
end

return ElfCourt
