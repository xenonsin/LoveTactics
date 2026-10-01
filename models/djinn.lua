-- The djinn of Pride's spire, and the Wishmaker's lamp: the rules both carry, in one place. Reviewed 2026-09-30
-- ("Pride's Bestiary"). Pure logic (no love.graphics), so it loads under the headless tests, and like
-- models/transform.lua it pulls models/combat.lua through a LAZY require, so combat.lua -> djinn.lua stays a
-- one-way edge.
--
-- WILL NOT STOOP (Djinn.willNotStoop, called from Combat.startTurn on the `willNotStoop` flag). A djinn has no
-- master in this world, and it will not trade blows with anyone. When its turn opens with a foe beside it, it
-- Blinks -- free, the Blink's own teleport (Combat.teleportCells / Combat.teleportUnit) -- to the open tile within
-- 4 that puts the most ground between it and the company. If there is nowhere to go (every tile in reach is
-- taken, walled, or beside another foe), or it is rooted, it is SHAMED and loses the turn. So the spire's rooms
-- and doorways are the answer: a djinn backed into a corner is a djinn that does nothing.
--
-- "Farthest" is read from the FOES, not from the djinn: it lands where the nearest foe is farthest away, and
-- only a tie is broken by how far the jump carries it. A djinn that blinked four tiles straight past a second
-- swordsman would have obeyed the letter of the rule and lost the point of it.
--
-- THE WISHES (Djinn.onWounded / Djinn.onLethal, from trait_three_wishes and Trait.trySurvive). The Wishmaker's
-- Lamp grants three, in order, at each third of her health -- 2/3, 1/3 and the last at 0 -- and only while it
-- stands (any body of her side whose grid carries the `grantsWishes` flag):
--   1. she heals fully
--   2. she takes the company's strongest boon onto herself
--   3. she becomes a Great Djinn (models/transform.lua), held at 1 health by Lamp-Bound until the Lamp breaks
-- A blow that crosses more than one line still grants them in order and stops at the one that saves her: from
-- above two-thirds straight to nothing is the first wish, a full heal, never a skip to the djinn.

local Djinn = {}

-- How far a djinn blinks (the approved "within 4"), and the shape it becomes on the third wish.
Djinn.BLINK_RANGE = 4
Djinn.GREAT_DJINN = "character_great_djinn"

local function name(unit) return (unit and unit.char and unit.char.name) or "Unit" end

-- The living bodies that count as `unit`'s foes for standing beside it: the other side, standing, and a BODY --
-- a lamp or an egg next to a djinn is furniture, not somebody it would have to fight.
local function foesOf(combat, unit)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if u ~= unit and u.alive and not u.incapacitated and u.side ~= unit.side
            and not (u.char and u.char.kind == "object") then
            out[#out + 1] = u
        end
    end
    return out
end

-- Is a foe standing next to `unit` (orthogonally, as every melee reach in the game is measured)?
function Djinn.foeAdjacent(combat, unit)
    local Combat = require("models.combat")
    for _, f in ipairs(foesOf(combat, unit)) do
        if Combat.unitGap(unit, f) == 1 then return true end
    end
    return false
end

-- The tile `unit` would blink to, or nil when there is nowhere: every tile the Blink could reach within
-- `range` that is NOT itself beside a foe, scored by the gap to the nearest foe (largest wins), then by the
-- length of the jump, then by position so a seeded fight replays.
function Djinn.escapeTile(combat, unit, range)
    local Combat = require("models.combat")
    local foes = foesOf(combat, unit)
    local best, bx, by, bjump
    for _, c in pairs(Combat.teleportCells(combat, unit, range or Djinn.BLINK_RANGE)) do
        local near = math.huge
        for _, f in ipairs(foes) do
            local g = Combat.cellGap(c.x, c.y, f)
            if g < near then near = g end
        end
        if near > 1 then
            local jump = math.abs(c.x - unit.x) + math.abs(c.y - unit.y)
            local better = not best or near > best
                or (near == best and (jump > bjump
                    or (jump == bjump and (c.y < by or (c.y == by and c.x < bx)))))
            if better then best, bx, by, bjump = near, c.x, c.y, jump end
        end
    end
    return bx, by
end

-- Blink `unit` clear of the foes beside it, free. True when it moved. Root holds a djinn as it holds a walker:
-- a blink is a move, and Combat.blink refuses it rooted for the same reason.
function Djinn.escape(combat, unit, line)
    local Combat = require("models.combat")
    local Status = require("models.status")
    if not (unit and unit.alive) or Status.blocksMove(unit) then return false end
    local x, y = Djinn.escapeTile(combat, unit)
    if not x then return false end
    Combat.teleportUnit(combat, unit, x, y, { silent = true })
    Combat.logEvent(combat, "move", string.format(line or "%s will not stoop, and blinks to (%d, %d).",
        name(unit), x, y), unit)
    return true
end

-- The family rule, at the top of the djinn's turn. Nothing beside it: nothing happens. Somewhere to go: it goes,
-- and still has its whole turn. Nowhere: Shamed, and the turn is lost.
function Djinn.willNotStoop(combat, unit)
    if not (unit and unit.alive) or not Djinn.foeAdjacent(combat, unit) then return nil end
    if Djinn.escape(combat, unit) then return "blinked" end
    require("models.status").apply(combat, unit, "status_shamed")
    require("models.combat").logEvent(combat, "status",
        string.format("%s is cornered, and will not stoop to fight.", name(unit)), unit)
    return "shamed"
end

-- ---------------------------------------------------------------------------------------------- the wishes

-- Does a Lamp of `unit`'s side still stand?
function Djinn.lampStands(combat, unit)
    local Trait = require("models.trait")
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u.side == unit.side and Trait.flag(u, "grantsWishes") then return u end
    end
    return nil
end

-- How much a boon is worth taking: the sum of what it lifts (scaled by its stacks where the lift scales). A
-- debuff, a status with no stat lift, and one that lifts nothing on balance are not boons.
local function boonWorth(s)
    if s.def.debuff then return nil end
    local sb = s.statBonus or s.def.statBonus
    if type(sb) ~= "table" then return nil end
    local total = 0
    for _, v in pairs(sb) do if type(v) == "number" then total = total + v end end
    if s.def.statBonusScales then total = total * (s.magnitude or 1) end
    if total <= 0 then return nil end
    return total
end

-- The company's strongest boon, as (body, status), or nil. Ties go to the one with longer left to run.
function Djinn.strongestBoon(combat, unit)
    local bestU, bestS, bestW
    for _, u in ipairs(foesOf(combat, unit)) do
        for _, s in ipairs(u.statuses or {}) do
            local w = boonWorth(s)
            if w and (not bestW or w > bestW or (w == bestW and (s.remaining or 0) > (bestS.remaining or 0))) then
                bestU, bestS, bestW = u, s, w
            end
        end
    end
    return bestU, bestS
end

-- Grant wish `n` (1, 2 or 3) to `unit`. Returns true when it was granted.
function Djinn.grantWish(combat, unit, n)
    local Combat = require("models.combat")
    local Status = require("models.status")
    unit.wishes = n
    if n == 1 then
        -- A wish, not a heal: nothing that refuses healing refuses it.
        unit.char.stats.health.current = Combat.unreservedMax(unit.char, "health")
        Combat.logEvent(combat, "action", string.format("The Lamp grants %s's first wish: she is whole again.",
            name(unit)), unit)
    elseif n == 2 then
        local victim, s = Djinn.strongestBoon(combat, unit)
        if victim then
            local id, remaining, magnitude, statBonus = s.id, s.remaining, s.magnitude, s.statBonus
            Status.remove(combat, victim, id)
            Status.apply(combat, unit, id, { duration = remaining, magnitude = magnitude, statBonus = statBonus,
                applier = unit })
            Combat.logEvent(combat, "action", string.format("The Lamp grants %s's second wish: she takes %s from %s.",
                name(unit), s.def.name or id, name(victim)), { unit, victim })
        else
            Combat.logEvent(combat, "action", string.format("%s's second wish finds nothing worth taking.",
                name(unit)), unit)
        end
    elseif n == 3 then
        local Transform = require("models.transform")
        local boss = unit.char and unit.char.boss
        unit.char.stats.health.current = math.max(1, unit.char.stats.health.current or 0)
        local shape = Transform.apply(combat, unit, Djinn.GREAT_DJINN, { level = unit.char and unit.char.level })
        if not shape then return false end
        if boss then shape.boss = true end
        Status.apply(combat, unit, "status_lamp_bound", { applier = unit })
        Combat.logEvent(combat, "action", string.format("The Lamp grants %s's last wish, and she is a djinn.",
            (Transform.originalChar(unit) or {}).name or name(unit)), unit)
    end
    return true
end

-- She was wounded and stood (trait_three_wishes' onDamaged): grant the next wish if its line has been crossed.
function Djinn.onWounded(combat, unit)
    if not (unit and unit.alive) or not Djinn.lampStands(combat, unit) then return end
    local Combat = require("models.combat")
    local hp = unit.char.stats.health.current or 0
    local max = Combat.unreservedMax(unit.char, "health")
    local w = unit.wishes or 0
    if w == 0 and hp * 3 <= max * 2 then
        Djinn.grantWish(combat, unit, 1)
    elseif w == 1 and hp * 3 <= max then
        Djinn.grantWish(combat, unit, 2)
    end
end

-- A blow would fell her (Trait.trySurvive): the outstanding wishes in order, stopping at the one that saves her.
-- False -- she falls -- when the Lamp is broken or the third wish is spent.
function Djinn.onLethal(combat, unit)
    if not Djinn.lampStands(combat, unit) then return false end
    local w = unit.wishes or 0
    if w >= 3 then return false end
    if w == 0 then return Djinn.grantWish(combat, unit, 1) end
    if w == 1 then Djinn.grantWish(combat, unit, 2) end
    return Djinn.grantWish(combat, unit, 3)
end

-- The Lamp broke (trait_the_lamp's onDeath): every Lamp-Bound body of its side can fall again.
function Djinn.lampBroken(combat, lamp)
    local Status = require("models.status")
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u.side == lamp.side and Status.has(u, "status_lamp_bound") then
            Status.remove(combat, u, "status_lamp_bound")
        end
    end
    require("models.combat").logEvent(combat, "action", "The Lamp breaks. There are no more wishes.", lamp)
end

-- Set the Lamp down beside its Wishmaker at the bell, wherever the band dealt it (trait_three_wishes'
-- onCombatStart). A lamp across the room is a lamp nobody reads as hers.
function Djinn.seatLamp(combat, unit)
    local lamp = Djinn.lampStands(combat, unit)
    if not lamp then return end
    local Combat = require("models.combat")
    if Combat.unitGap(unit, lamp) == 1 then return end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local x, y = unit.x + d[1], unit.y + d[2]
        if Combat.footprintFree(combat, 1, 1, x, y, lamp) then
            lamp.x, lamp.y = x, y
            return
        end
    end
end

return Djinn
