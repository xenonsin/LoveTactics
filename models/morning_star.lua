-- SUPERBIA, THE MORNING STAR: Pride's general (reviewed over three rounds, "Pride's Generals"). The rules her
-- organs carry, in one place so the trait files stay short and the spec has one module to pin. Several of them
-- also ride on her drops, at a smaller number, so each is written against `trait` params rather than her.
--
--   NON SERVIAM     a debuff a foe lays on her REBOUNDS onto whoever laid it, at the length it was laid, and
--                   never touches her. It differs from Incorruptible, which refuses, and from a reflect, which
--                   returns damage: the debuff is not stopped, it is SENT BACK. A debuff with nobody to send it
--                   to (ground nobody of her side laid, a laid-by who has since died) is refused outright. Her
--                   relic, the Morning Star, is the same rule once per turn and without the refusal. Answered in
--                   Status.apply, ahead of every wall, because a debuff that rebounds never reaches the walls.
--   LIGHT-BEARER    a foe whose turn opens with a line of sight to her is Blinded until that turn ends
--                   (Combat.unitsSighted, the same line `requiresSight` asks). Out of her sight, it is not.
--   FLAWLESS FORM   no single wound takes more than a tenth of her max health (Combat.woundCap, asked from
--                   Combat.dealFlatDamage past the crit and from Combat.computeDamage, so the hover agrees).
--   THE HOST        at two-thirds health two Reflections of the Morning are called beside her, and two more at
--                   the end of each of her turns, until...
--   THE FALL        ...one-third: every Reflection she called shatters, she can no longer fly (`unit.grounded`,
--                   read by Combat.isFlying), and the ground around her breaks into Black Ice -- the first ring
--                   out from where she fell, then one ring further at the end of each of her turns. She gains +2
--                   Damage for every ring the ice has reached. A body that ends two turns running on the ice is
--                   Frozen. Both stages fire on the blow that crosses them (trait_boss_phases' threshold rule).
--
-- Pure logic, no love.graphics. Combat, Status, Trait, Summon and Hazard are required lazily: combat.lua and
-- status.lua both reach this module.
local MorningStar = {}

MorningStar.REFLECTION = "character_reflection_of_the_morning"
MorningStar.HOST_AT = 2 / 3      -- the Host descends
MorningStar.FALL_AT = 1 / 3      -- the Fall
MorningStar.HOST_CALL = 2        -- Reflections per wave
MorningStar.ICE = "hazard_black_ice"
MorningStar.ICE_DURATION = 999   -- the Fall's ice does not thaw while the fight lasts
MorningStar.ICE_DAMAGE = 2       -- Damage per ring the ice has reached
MorningStar.FREEZE_AFTER = 2     -- turns ended on the ice, in a row, before a body is Frozen
MorningStar.FREEZE = "status_freeze"
MorningStar.BLIND = "status_blind"

local function name(u) return (u and u.char and u.char.name) or "Unit" end

local function fraction(unit)
    local Combat = require("models.combat")
    local max = Combat.unreservedMax(unit.char, "health")
    if not max or max <= 0 then return 1 end
    return (unit.char.stats.health.current or 0) / max
end

-- ----------------------------------------------------------------------------------------- non serviam

-- The body a debuff `id` laid on `unit` by `applier` rebounds onto, or nil when it does not rebound. A
-- rebound already sent back (`opts.rebounded`) never rebounds again, so two bearers cannot volley one
-- debuff between them forever. A once-per-turn bearer that has spent its rebound lets the debuff land.
function MorningStar.reboundTarget(unit, id, opts)
    local Status = require("models.status")
    local def = Status.defs[id]
    if not (def and def.debuff and unit) or (opts and opts.rebounded) then return nil end
    local t = require("models.trait").flag(unit, "nonServiam")
    if not t then return nil end
    local applier = opts and opts.applier
    if not (applier and applier ~= unit and applier.alive and applier.side ~= nil
        and applier.side ~= unit.side) then return nil end
    local Trait = require("models.trait")
    if Trait.param(t, "oncePerTurn") and unit.reboundSpent then return nil end
    return applier, t
end

-- Does `unit` refuse a debuff outright (her own rule: nothing from outside her side touches her)? Asked from
-- Status.isImmune, so the tooltip and the blow read one answer. Never true for the once-per-turn relic.
function MorningStar.refuses(unit, applier)
    local t = require("models.trait").flag(unit, "nonServiam")
    if not (t and require("models.trait").param(t, "refusesAll")) then return false end
    return not (applier and applier.side ~= nil and applier.side == unit.side)
end

-- Send the debuff back. `opts` is copied, never written: it may be a table an item blueprint owns.
function MorningStar.rebound(combat, unit, id, opts, target, trait)
    local Status = require("models.status")
    if require("models.trait").param(trait, "oncePerTurn") then unit.reboundSpent = true end
    local sent = {}
    for k, v in pairs(opts or {}) do sent[k] = v end
    sent.applier = unit
    sent.rebounded = true
    if combat then
        require("models.combat").logEvent(combat, "status", string.format("%s will not serve: %s rebounds onto %s.",
            name(unit), (Status.defs[id] and Status.defs[id].name) or id, name(target)), { unit, target })
    end
    return Status.apply(combat, target, id, sent)
end

-- ---------------------------------------------------------------------------------------- light-bearer

-- `actor`'s turn opened: if it is `bearer`'s foe and can see it, it is Blinded until that turn ends.
function MorningStar.dazzle(combat, bearer, actor)
    local Combat = require("models.combat")
    if not (bearer and bearer.alive and actor and actor.alive and actor.side ~= bearer.side) then return nil end
    if Combat.isOffTile(actor) or Combat.isOffTile(bearer) then return nil end
    if not Combat.unitsSighted(combat, actor, bearer) then return nil end
    local s = require("models.status").apply(combat, actor, MorningStar.BLIND, { applier = bearer })
    if s then s.lightBearer = true end
    return s
end

-- `actor`'s turn ended: a Blind the light laid lifts with it.
function MorningStar.undazzle(combat, actor)
    local Status = require("models.status")
    local s = actor and Status.get(actor, MorningStar.BLIND)
    if s and s.lightBearer then Status.remove(combat, actor, MorningStar.BLIND) end
end

-- ---------------------------------------------------------------------------------------- flawless form

-- `dmg` clamped to the bearer's wound cap: the largest share of its max health one blow may take. Unchanged
-- for a body that carries no cap.
function MorningStar.woundCap(target, dmg)
    if not (target and target.char and dmg and dmg > 0) then return dmg end
    local t = require("models.trait").flag(target, "woundCap")
    if not t then return dmg end
    local share = require("models.trait").param(t, "woundCap")
    local max = require("models.combat").unreservedMax(target.char, "health")
    if not (share and max and max > 0) then return dmg end
    return math.min(dmg, math.max(1, math.floor(max * share)))
end

-- ---------------------------------------------------------------------------------------------- the host

-- Call `count` Reflections onto open ground beside `unit`, on its side, each felled by any blow. Returns the
-- list called.
function MorningStar.callReflections(combat, unit, count)
    local Combat = require("models.combat")
    local Summon = require("models.summon")
    local out = {}
    for _ = 1, count or MorningStar.HOST_CALL do
        local x, y = Combat.openTileNear(combat, unit.x, unit.y)
        if not x then x, y = Combat.openBlockNear(combat, unit.x, unit.y, 1, 1) end
        if not x then break end
        local r = Summon.spawn(combat, unit, MorningStar.REFLECTION, x, y, { fragile = true, announce = false })
        if r and r.alive then
            r.reflection = true
            out[#out + 1] = r
        end
    end
    if #out > 0 then
        Combat.logEvent(combat, "action", string.format("The Host descends: %d Reflection%s of the Morning.",
            #out, #out == 1 and "" or "s"), unit)
    end
    return out
end

-- ---------------------------------------------------------------------------------------------- the fall

-- Every open tile exactly `ring` steps (Chebyshev) out from the footprint `origin` = { x, y, w, h }.
function MorningStar.ringCells(combat, origin, ring)
    local tiles = combat.arena and combat.arena.tiles
    local out = {}
    if not tiles then return out end
    local x0, y0 = origin.x - ring, origin.y - ring
    local x1, y1 = origin.x + (origin.w or 1) - 1 + ring, origin.y + (origin.h or 1) - 1 + ring
    for y = y0, y1 do
        for x = x0, x1 do
            if x == x0 or x == x1 or y == y0 or y == y1 then
                local cell = tiles[y] and tiles[y][x]
                if cell and cell.walkable then out[#out + 1] = { x = x, y = y } end
            end
        end
    end
    return out
end

-- Lay the next ring of ice. Returns how many tiles froze; a ring that reaches no open ground adds nothing.
function MorningStar.spread(combat, unit, trait)
    local Hazard = require("models.hazard")
    trait.rings = (trait.rings or 0) + 1
    local laid = 0
    for _, c in ipairs(MorningStar.ringCells(combat, trait.origin, trait.rings)) do
        if Hazard.place(combat, c.x, c.y, MorningStar.ICE, { side = unit.side, duration = MorningStar.ICE_DURATION }) then
            laid = laid + 1
        end
    end
    if laid > 0 then
        unit.bonus = unit.bonus or {}
        unit.bonus.damage = (unit.bonus.damage or 0) + MorningStar.ICE_DAMAGE
        trait.iceDamage = (trait.iceDamage or 0) + MorningStar.ICE_DAMAGE
    else
        trait.rings = trait.rings - 1
    end
    return laid
end

-- The Fall: the Host shatters, she lands, and the first ring freezes.
function MorningStar.fall(combat, unit, trait)
    local Combat = require("models.combat")
    trait.fallen = true
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.reflection and u.summoner == unit then
            Combat.dismiss(combat, u, string.format("%s shatters.", name(u)))
        end
    end
    unit.grounded = true
    -- A flier can be over ground nobody stands on (the spire's drop) when she falls. She lands on the nearest
    -- ground that holds her, rather than hanging over the void unable to move.
    if not Combat.footprintFree(combat, unit.w or 1, unit.h or 1, unit.x, unit.y, unit) then
        local x, y = Combat.openBlockNear(combat, unit.x, unit.y, unit.w or 1, unit.h or 1, { ignore = unit })
        if x then Combat.teleportUnit(combat, unit, x, y) end
    end
    trait.origin = { x = unit.x, y = unit.y, w = unit.w or 1, h = unit.h or 1 }
    Combat.logEvent(combat, "action", string.format("%s falls, and the ground beneath her freezes.", name(unit)), unit)
    MorningStar.spread(combat, unit, trait)
end

-- A wound landed and she lived: cross whatever stages the blow reached, in order.
function MorningStar.onWound(combat, unit, trait)
    local f = fraction(unit)
    if not trait.host and f <= MorningStar.HOST_AT then
        trait.host = true
        MorningStar.callReflections(combat, unit, MorningStar.HOST_CALL)
    end
    if trait.host and not trait.fallen and f <= MorningStar.FALL_AT then
        MorningStar.fall(combat, unit, trait)
    end
end

-- Her own turn ended: the Host sends another wave, or the ice spreads a ring.
function MorningStar.onOwnTurnEnd(combat, unit, trait)
    if not unit.alive then return end
    if trait.fallen then
        MorningStar.spread(combat, unit, trait)
    elseif trait.host then
        MorningStar.callReflections(combat, unit, MorningStar.HOST_CALL)
    end
end

-- Is any cell of `u`'s body on the ice?
function MorningStar.onIce(combat, u)
    local Combat = require("models.combat")
    local Hazard = require("models.hazard")
    for _, c in ipairs(Combat.unitCells(u)) do
        if Hazard.at(combat, c.x, c.y, MorningStar.ICE) then return true end
    end
    return false
end

-- `actor`'s turn ended. After the Fall, a body that has now ended FREEZE_AFTER turns in a row on the ice is
-- Frozen, laid by her; one that ended this turn off it starts the count again. She is the cold and does
-- not count.
function MorningStar.iceTurn(combat, unit, trait, actor)
    if not (trait.fallen and actor and actor.alive and actor ~= unit) then return nil end
    if not MorningStar.onIce(combat, actor) then
        actor.iceTurns = 0
        return nil
    end
    actor.iceTurns = (actor.iceTurns or 0) + 1
    if actor.iceTurns < MorningStar.FREEZE_AFTER then return nil end
    actor.iceTurns = 0
    return require("models.status").apply(combat, actor, MorningStar.FREEZE, { applier = unit })
end

-- --------------------------------------------------------------------------------------------- the mirror

-- The Mirror of the Morning (a summoner's piece): the first time each fight the bearer is wounded below
-- two-thirds, two Reflections join it.
function MorningStar.mirror(combat, unit, trait)
    if trait.called or fraction(unit) > MorningStar.HOST_AT then return nil end
    trait.called = true
    return MorningStar.callReflections(combat, unit, MorningStar.HOST_CALL)
end

return MorningStar
