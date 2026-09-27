-- RAMPAGE: a body that swings at whoever is nearest, friend or foe. Two orc-line rules land here (2026-09-26,
-- "The Orcs of Wrath"):
--
--   BLOOD UP     the Berserker (data/traits/trait_blood_up.lua): once it has struck it must strike every turn,
--                and with no foe in reach it hits the nearest body, orc included
--   UNCHAINED    the War Ogre (data/traits/trait_the_chain.lua): its Handler dead, it attacks the nearest body
--                each turn, whichever side it is on
--
-- AI.preempt asks Rampage.plan; Combat.useItem asks Rampage.aimsAnyone to waive its side check, the way it
-- already does for a body Seeing Red. Neither binds a body the player drives -- an AI rule binds nobody the
-- player drives -- so both are read for the enemy side only.
local Status = require("models.status")

local Rampage = {}

local function bloodUp(unit)
    return Status.has(unit, "status_blood_up") and require("models.trait").flag(unit, "bloodUp")
end

-- Does `unit` swing at anyone at all right now?
function Rampage.aimsAnyone(unit)
    if not unit or unit.side == "party" then return false end
    return Status.has(unit, "status_unchained") or bloodUp(unit)
end

-- The nearest living body to `unit` other than itself, either side, that stands on the board.
local function nearestBody(combat, unit)
    local Combat = require("models.combat")
    local best, bestD
    for _, other in ipairs(combat.units or {}) do
        if other ~= unit and other.alive and not Combat.isOffTile(other) then
            local d = Combat.unitGap(unit, other)
            if not bestD or d < bestD then best, bestD = other, d end
        end
    end
    return best
end

-- Every tile `unit` could strike from this turn: where it stands, and every tile it can walk to
-- (Combat.reachableList leaves the origin out -- it is not a move).
local function stands(combat, unit)
    local out = { { x = unit.x, y = unit.y, steps = 0 } }
    for _, node in ipairs(require("models.combat").reachableList(combat, unit)) do out[#out + 1] = node end
    return out
end

-- Can `unit`'s default weapon reach a FOE this turn, from here or a tile it can walk to?
local function foeInReach(combat, unit)
    local Combat = require("models.combat")
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return false end
    for _, node in ipairs(stands(combat, unit)) do
        local range = Combat.abilityRange(combat, unit, ab, node.x, node.y) + Combat.adjacencyRangeBonus(unit.char, weapon)
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other.side ~= unit.side and not Combat.isOffTile(other) then
                if Combat.reachFrom(unit, node.x, node.y, other) <= range then return true end
            end
        end
    end
    return false
end

-- Strike `tt` with the default weapon, walking first if it must; nil when it cannot be reached this turn.
local function strikeAt(combat, unit, tt, reason)
    local Combat = require("models.combat")
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return nil end
    local minRange = Combat.abilityMinRange(ab)
    local best
    for _, node in ipairs(stands(combat, unit)) do
        local range = Combat.abilityRange(combat, unit, ab, node.x, node.y) + Combat.adjacencyRangeBonus(unit.char, weapon)
        local d, cx, cy = Combat.reachFrom(unit, node.x, node.y, tt)
        if d <= range and d >= minRange and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
    end
    if not best then return nil end
    local plan = { item = weapon, tx = best.tx, ty = best.ty, reason = reason }
    if best.x ~= unit.x or best.y ~= unit.y then plan.move = { x = best.x, y = best.y } end
    return plan
end

-- The rampage's turn, or nil to let the ordinary planner run. A Berserker with a foe in reach goes on with an
-- ordinary turn (it will swing at the foe); only the one with nothing else to hit turns on its own side.
function Rampage.plan(combat, unit)
    if not Rampage.aimsAnyone(unit) then return nil end
    if not Status.has(unit, "status_unchained") and foeInReach(combat, unit) then return nil end
    return Rampage.hitNearest(combat, unit, Status.has(unit, "status_unchained") and "unchained" or "blood up")
end

-- Strike the nearest body, either side, walking first if it must, or close on it; nil with nobody on the board.
-- Shared with a vampire's Bloodlust (models/thirst.lua), which bites whoever is nearest on EVERY turn rather than
-- only when no foe is in reach -- so the vampires read it without the Berserker's gate above.
function Rampage.hitNearest(combat, unit, reason)
    local tt = nearestBody(combat, unit)
    if not tt then return nil end
    local plan = strikeAt(combat, unit, tt, reason)
    if plan then return plan end
    -- Out of reach: close on it.
    local Combat = require("models.combat")
    local dest
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        local d = Combat.cellGap(node.x, node.y, tt)
        if not dest or d < dest.dist then dest = { x = node.x, y = node.y, dist = d } end
    end
    if dest and dest.dist < Combat.cellGap(unit.x, unit.y, tt) then
        return { move = { x = dest.x, y = dest.y }, reason = reason }
    end
    return nil
end

return Rampage
