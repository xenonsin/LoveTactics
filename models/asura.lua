-- THE ASURA: monks who turned their discipline to war (Wrath's general and his line, reviewed over two rounds
-- on 2026-09-27/28, "The Asura of Wrath"). They fight with the monk's own shelf -- the fists, Flurry, Asura
-- Strike, the Centering Charm, Keen Senses -- and the monk's own chi pool (Combat.chi). What they lost is the
-- discipline over it:
--
--   PAIN FEEDS IT   every blow that lands ON an asura banks chi as well as every blow it lands (its vow piece
--                   declares `charge = { key = "chi", from = { "hitTaken" } }`, which merges into the body's
--                   built-in unarmed pool -- Combat.chargeDef).
--   IT WILL NOT KEEP  a turn in which the asura neither struck nor was struck drains 1 chi
--                   (trait_the_broken_vow's onTurnEnd). Wrath cannot be banked, so the counterplay the whole
--                   line teaches is DON'T FEED IT: leave one alone and it cools.
--   IT BURSTS       at a full pool (Combat.CHI_MAX) the next action is not chosen: Bursting lands, and the
--                   asura throws its Burst -- the Asura Strike, every point of chi in one blow -- at the
--                   NEAREST FOE (picked on review over "the nearest body", which is the vampires' Bloodlust).
--                   On a company body the game takes that turn, the way Bloodlust does.
--   WRATH SPREADS   a Burst hands CONTAGION chi to every asura of the same side within CONTAGION_RADIUS, so a
--                   pack running hot goes off in a chain. Enemy only: the company's vow is its own.
--   TAPAS           a piece declaring `gatherCharge` banks that much chi on a Gather (the Centering Charm's
--                   coil), and a coiled turn is not an idle one -- stillness HEATS an asura.
--   ARMS ARE HITS   each pair of arms is one more landing on every bare-handed strike: the Adept's four arms
--                   and the Three-Faced's six are organs raising `unarmedBonus.hits`, the field Swift Fist
--                   raises, so they stack with it. Furor's arms GROW with his chi (`armsGrow`), read here.
--                   Arms are never lost (the author, twice: "Don't lose arms", "Don't cut arms").
--   THE SHRINE      a shrine tile (hazard_shrine, the Meditation Hall) is ground where chi does not drain.
--
-- Pure logic, no love.graphics. Combat, Status, Trait and Hazard are required lazily, since combat.lua reaches
-- this module from inside Combat.gather and the unarmed strike.
-- Character is required lazily too: item blueprints reach this module (the unarmed strike), and models.item
-- loads them.
local function Character() return require("models.character") end

local Asura = {}

Asura.KEY = "chi"
Asura.BURSTING = "status_bursting"
Asura.SHRINE = "hazard_shrine"
Asura.DRAIN = 1              -- chi lost on an idle turn
Asura.CONTAGION_RADIUS = 2   -- a Burst heats every asura this close...
Asura.CONTAGION_CHI = 2      -- ...by this much

-- Does `unit` live under the broken vow (the race's organ, or the Broken Vow worn by a company monk)?
function Asura.hasVow(unit)
    return require("models.trait").flag(unit, "brokenVow") ~= nil
end

-- Is `unit` an asura by race -- the kin a Burst heats? The company's own vow-bearer is not.
function Asura.isAsura(unit)
    return unit ~= nil and unit.char ~= nil and unit.char.race == "asura"
end

function Asura.chi(unit)
    return require("models.combat").chi(unit)
end

-- The pool's ceiling on this body (Combat.CHI_MAX unless a piece deepens it).
function Asura.max(unit)
    local def = require("models.combat").chargeDef(unit, Asura.KEY)
    return (def and def.max) or require("models.combat").CHI_MAX
end

function Asura.full(unit)
    return Asura.chi(unit) >= Asura.max(unit)
end

-- Bank `n` chi on `unit` from outside its tallies (Tapas, a kinsman's Burst, the Niō's inheritance), and let
-- a pool that filled say so. Returns what went in.
function Asura.grant(combat, unit, n)
    local got = require("models.combat").grantCharge(unit, Asura.KEY, n)
    if got > 0 then Asura.checkBurst(combat, unit) end
    return got
end

-- Lay Bursting on a vow-bearer whose pool is full. Called after anything that can fill it: a blow taken, a
-- blow landed, a grant, a turn's end. Idempotent.
function Asura.checkBurst(combat, unit)
    if not (combat and unit and unit.alive and Asura.hasVow(unit)) then return end
    local Status = require("models.status")
    if Asura.full(unit) then
        if not Status.has(unit, Asura.BURSTING) then Status.apply(combat, unit, Asura.BURSTING, { applier = unit }) end
    elseif Status.has(unit, Asura.BURSTING) then
        Status.remove(combat, unit, Asura.BURSTING)
    end
end

-- Does `unit` stand on a shrine, where its chi will not drain?
function Asura.onShrine(combat, unit)
    if not (combat and unit) then return false end
    return require("models.hazard").at(combat, unit.x, unit.y, Asura.SHRINE) ~= nil
end

-- The extra landings `unit`'s GROWN arms give a bare-handed strike: for every threshold in an `armsGrow`
-- list its chi has reached, one more hit (a pair of arms). Zero for everybody but Furor. Pure -- the damage
-- preview runs the unarmed strike too.
function Asura.grownHits(unit)
    if not (unit and unit.char) then return 0 end
    local n = 0
    for _, item in ipairs(Character().eachItem(unit.char)) do
        local grow = item.armsGrow
        if grow then
            local chi = Asura.chi(unit)
            for _, at in ipairs(grow) do
                if chi >= at then n = n + 1 end
            end
        end
    end
    return n
end

-- How many arms `unit` shows: two, plus two for every extra landing its organs and its growth give it. The
-- readout the sprite and the tooltip are named by; the rule itself is the hit count.
function Asura.arms(unit)
    local fixed = 0
    if unit and unit.char then
        for _, item in ipairs(Character().eachItem(unit.char)) do
            if item.arms then fixed = math.max(fixed, item.arms) end
        end
    end
    return math.max(2, fixed) + 2 * Asura.grownHits(unit)
end

-- TAPAS: `unit` just gathered. Bank what its pieces declare, and mark the turn as not idle.
function Asura.onGather(combat, unit)
    if not (unit and unit.char) then return end
    local n = 0
    for _, item in ipairs(Character().eachItem(unit.char)) do
        n = n + (item.gatherCharge or 0)
    end
    unit._asuraActive = true
    if n > 0 then
        local got = Asura.grant(combat, unit, n)
        if got > 0 then
            require("models.combat").logEvent(combat, "action",
                string.format("%s's stillness burns: +%d chi.", (unit.char and unit.char.name) or "It", got), unit)
        end
    end
end

-- The turn `unit` just ended: drain it if it was idle -- no blow landed by it or on it since its last turn
-- ended, no coil, and no shrine underfoot. Then re-read the pool.
function Asura.onTurnEnd(combat, unit)
    if not (unit and unit.alive) then return end
    local Combat = require("models.combat")
    local seen = Combat.tallyCount(unit, "hitDealt") + Combat.tallyCount(unit, "hitTaken")
    local idle = unit._asuraSeen ~= nil and seen == unit._asuraSeen and not unit._asuraActive
    unit._asuraSeen, unit._asuraActive = seen, nil
    if idle and not Asura.onShrine(combat, unit) and Asura.chi(unit) > 0 then
        Combat.spendCharge(unit, Asura.KEY, Asura.DRAIN)
        Combat.logEvent(combat, "action",
            string.format("%s cools.", (unit.char and unit.char.name) or "It"), unit)
    end
    Asura.checkBurst(combat, unit)
end

-- WRATH SPREADS: `unit` just burst. Every asura of its side within the radius takes the heat.
function Asura.spread(combat, unit)
    if not (combat and unit) then return end
    local Combat = require("models.combat")
    for _, kin in ipairs(Combat.unitsNear(combat, unit.x, unit.y, Asura.CONTAGION_RADIUS)) do
        if kin ~= unit and kin.alive and kin.side == unit.side and Asura.isAsura(kin) and Asura.hasVow(kin) then
            local got = Asura.grant(combat, kin, Asura.CONTAGION_CHI)
            if got > 0 then
                Combat.logEvent(combat, "action",
                    string.format("%s catches the heat: +%d chi.", (kin.char and kin.char.name) or "It", got), kin)
            end
        end
    end
end

-- The piece `unit` bursts WITH: its signature if it carries one (Furor's Every Arm), else the Burst on its vow.
function Asura.burstItem(unit)
    local best
    for _, item in ipairs(Character().eachItem(unit.char)) do
        local ab = item.activeAbility
        if ab and ab.asuraBurst then
            if not best or (ab.asuraBurst == "signature") then best = item end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------------------------- the planner

local function nearestFoe(combat, unit)
    local Combat = require("models.combat")
    local best, bestD
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not Combat.isOffTile(u) then
            local d = Combat.unitGap(unit, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

-- A Bursting body's turn (AI.preempt): throw the Burst at the nearest foe, closing on it first if it must.
-- Nil for any body that is not Bursting, so the ordinary planner runs.
function Asura.plan(combat, unit)
    local Status = require("models.status")
    if not Status.has(unit, Asura.BURSTING) then return nil end
    local item = Asura.burstItem(unit)
    local tt = nearestFoe(combat, unit)
    if not (item and tt) then return nil end
    local Combat = require("models.combat")
    local ab = item.activeAbility
    local minRange = Combat.abilityMinRange(ab)
    local best
    -- Where it stands, then everywhere it can walk (Combat.reachableList leaves the origin out).
    local stands = { { x = unit.x, y = unit.y, steps = 0 } }
    for _, node in ipairs(Combat.reachableList(combat, unit)) do stands[#stands + 1] = node end
    for _, node in ipairs(stands) do
        local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
        local d, cx, cy = Combat.reachFrom(unit, node.x, node.y, tt)
        if d <= range and d >= minRange and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
    end
    if best then
        local plan = { item = item, tx = best.tx, ty = best.ty, reason = "bursting" }
        if best.x ~= unit.x or best.y ~= unit.y then plan.move = { x = best.x, y = best.y } end
        return plan
    end
    -- Out of reach even after moving: close on it, and burst next turn.
    local dest
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        local d = Combat.cellGap(node.x, node.y, tt)
        if not dest or d < dest.dist then dest = { x = node.x, y = node.y, dist = d } end
    end
    if dest and dest.dist < Combat.cellGap(unit.x, unit.y, tt) then
        return { move = { x = dest.x, y = dest.y }, reason = "bursting" }
    end
    return { wait = true, reason = "bursting, nothing near" }
end

return Asura
