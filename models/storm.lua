-- WRATH'S ELEMENTALS: the Blaze, the Arc, and the Thunderhead they fuse into (reviewed over two rounds, 2026-09-27/28,
-- "Fire, Lightning, and Dirty Thunder"). The rules the three bodies and their nine drops are made of, in one place:
--
--   OF THE FLOWS  a body carrying the `lavawalk` tag walks lava as ground (Combat.isLavaborn); the Blaze also
--                 mends at the end of a turn it stands in it (trait_of_the_flows). Flowwalker's Soles are the
--                 walking half alone.
--   WILDFIRE      at the end of the bearer's turn every fire within 2 of it creeps one tile into plain ground,
--                 toward the bearer's nearest foe (Storm.wildfire). Unsided, as fire always is.
--   KINDLE        a weapon blow that lands sets the struck tile alight (Storm.kindle; Coal in the Fist).
--   DOUSED        water put out the Blaze: none of the above, and its fists lose `fire` (status_doused).
--   FORKING       a bolt forks to the nearest other body within 2 of the one it struck, FRIEND OR FOE, for half,
--                 and forks again from there (Storm.fork; the Arc's bolt forks twice, the Forked Rod once).
--   THUNDERCLAP   the first body a bearer's lightning strikes in a turn is Blinded (trait_thunderclap; Flashpan).
--   STATIC        every tile walked stores a charge, to 5; the next lightning cast spends them at +3 each; Root,
--                 Stun or being Grounded wastes them (status_static; Static Coil).
--   FUSION        a Blaze and an Arc that end ANY turn next to each other fuse into the Thunderhead, whose health
--                 is its own bar filled to the share the two of them had left (Storm.fuse). Brought below half
--                 -- or dealt a blow that would fell it from above half -- it TEARS once back into the two, each
--                 at a quarter of its bar (Storm.tear); they may fuse again, and the second storm does not tear.
--   CONDUCTION    while a Thunderhead stands, every fire on the board conducts lightning (Storm.fireConducts,
--                 read by Combat.tileHasTag) -- its fire carries its lightning.
--   ASHFALL       at the end of its turn it drops ash on 3 tiles near it toward its nearest foe: sight-sealing
--                 ground that Blinds whoever stands in it (hazard_ash).
--   ERUPTION      once, below a third: every tile next to it becomes lava (Combat.openChasm at gap 1) and every
--                 body standing in fire is struck by a bolt (Storm.erupt). The Eruption Stone is the lava half.
--
-- WHERE THE TWO GO WHILE FUSED, AND WHERE THE STORM GOES WHILE TORN. The swarm's seam (models/swarm.lua): a body
-- held inside another is off its tile and out of the turn order, alive, so a `killAll` waits on it. The torn
-- Thunderhead is held the same way inside its Blaze, so a second fusion brings back the SAME body -- its statuses,
-- its spent eruption and its one tear all kept -- and killing both halves while it is held fells it with them.
--
-- Pure logic, no love.graphics. Combat, Status, Trait, Hazard and Character are required lazily: combat.lua reaches
-- this module from its movement, tile-tag and turn-end paths.
local Storm = {}

Storm.LORD = "character_thunderhead"
Storm.BLAZE = "character_blaze"
Storm.ARC = "character_arc"
Storm.FORK_REACH = 2        -- how far a fork jumps from the body it left
Storm.FORK_SHARE = 0.5      -- ...and the share of the bolt it carries
Storm.WILDFIRE_REACH = 2    -- the fires a Wildfire bearer feeds
Storm.STATIC_MAX = 5
Storm.STATIC_PER = 3        -- damage per stored charge
Storm.FLOWS_MEND = 0.13     -- the share of its bar the Blaze mends on lava (6 of 46 at the blueprint)
Storm.ASH_TILES = 3
Storm.ASH_REACH = 2
Storm.ERUPT_STRIKE = 6      -- the eruption's bolt: this plus the storm's Magic Damage

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end

local function cellAt(combat, x, y)
    local tiles = combat and combat.arena and combat.arena.tiles
    return tiles and tiles[y] and tiles[y][x]
end

local function isLava(combat, x, y)
    local cell = cellAt(combat, x, y)
    return cell ~= nil and cell.type == "lava"
end
Storm.isLava = isLava

-- Is `u` standing on the board (alive, on its own tile)?
local function onBoard(u)
    return u and u.alive and not Combat().isOffTile(u)
end

local function isFire(h)
    for _, t in ipairs(h.tags or {}) do if t == "fire" then return true end end
    return false
end

local function fireAt(combat, x, y)
    for _, h in ipairs(require("models.hazard").allAt(combat, x, y) or {}) do
        if isFire(h) then return h end
    end
    return nil
end
Storm.fireAt = fireAt

-- The nearest foe of `unit` on the board, board order breaking a tie.
local function nearestFoe(combat, unit)
    local best, bestD
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= unit.side then
            local d = Combat().unitGap(unit, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

-- Of `cells`, the `n` nearest `goal` (reading order breaks a tie). With no goal, the first `n`.
local function nearestTo(cells, goal, n)
    if goal then
        table.sort(cells, function(a, b)
            local da = math.abs(a.x - goal.x) + math.abs(a.y - goal.y)
            local db = math.abs(b.x - goal.x) + math.abs(b.y - goal.y)
            if da ~= db then return da < db end
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)
    end
    local out = {}
    for i = 1, math.min(n, #cells) do out[i] = cells[i] end
    return out
end

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

-- ------------------------------------------------------------------------------------------------ doused

function Storm.doused(unit)
    return unit ~= nil and Status().has(unit, "status_doused")
end

-- ------------------------------------------------------------------------------------------------ wildfire

-- WILDFIRE: every fire within WILDFIRE_REACH of `unit` creeps one tile into plain ground -- walkable, not lava,
-- not already burning -- the neighbour nearest the bearer's nearest foe. Read off the board BEFORE anything is laid,
-- so a fire this pass lights does not spread again in the same pass. Returns how many tiles caught.
function Storm.wildfire(combat, unit)
    if not (combat and onBoard(unit)) or Storm.doused(unit) then return 0 end
    local Hazard = require("models.hazard")
    local sources = {}
    for _, h in ipairs(combat.hazards or {}) do
        if isFire(h) and (h.remaining or 1) > 0 and Combat().cellGap(h.x, h.y, unit) <= Storm.WILDFIRE_REACH then
            sources[#sources + 1] = h
        end
    end
    local goal = nearestFoe(combat, unit)
    local lit, taken = 0, {}
    for _, h in ipairs(sources) do
        local open = {}
        for _, d in ipairs(DIRS) do
            local nx, ny = h.x + d[1], h.y + d[2]
            local cell = cellAt(combat, nx, ny)
            if cell and cell.walkable and not taken[ny * 100000 + nx] and not fireAt(combat, nx, ny) then
                open[#open + 1] = { x = nx, y = ny }
            end
        end
        local pick = nearestTo(open, goal, 1)[1]
        if pick then
            taken[pick.y * 100000 + pick.x] = true
            if Hazard.place(combat, pick.x, pick.y, h.id, { side = h.side, amount = h.amount }) then lit = lit + 1 end
        end
    end
    if lit > 0 then
        Combat().logEvent(combat, "action", string.format("The fire round %s spreads (%d tile%s).",
            (unit.char and unit.char.name) or "it", lit, lit == 1 and "" or "s"), unit)
    end
    return lit
end

-- KINDLE: a landed weapon blow sets the struck tile alight. `info` is the onCast event (item, tx, ty, damageDealt).
function Storm.kindle(combat, unit, info)
    if not (combat and unit and info and info.tx) or Storm.doused(unit) then return nil end
    if not (info.item and info.item.type == "weapon") or (info.damageDealt or 0) <= 0 then return nil end
    return require("models.hazard").place(combat, info.tx, info.ty, "hazard_fire", { side = unit.side })
end

-- ------------------------------------------------------------------------------------------------ forking

-- FORKING, from inside a bolt's effect: from `first` (already struck), jump to the nearest other body within
-- FORK_REACH -- friend or foe, never the caster, never a body this bolt already struck -- for FORK_SHARE of the bolt,
-- and again from there, `hops` times in all. Through fx.damage, so the dry-run preview prices it without dealing it.
function Storm.fork(fx, first, hops)
    if not (fx and first) then return 0 end
    local struck = { [first] = true }
    local from, dealt = first, 0
    local share = math.max(1, math.floor((fx.amount or 0) * Storm.FORK_SHARE))
    for _ = 1, hops or 1 do
        local best, bestD
        for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
            if onBoard(u) and u ~= fx.user and not struck[u] then
                local d = Combat().unitGap(from, u)
                if d <= Storm.FORK_REACH and (not bestD or d < bestD) then best, bestD = u, d end
            end
        end
        if not best then break end
        struck[best] = true
        dealt = dealt + (fx.damage(best, { amount = share }) or 0)
        from = best
    end
    return dealt
end

-- ------------------------------------------------------------------------------------------------ static

-- A step walked (Combat.stepMove): a Static bearer stores a charge, to STATIC_MAX, worn as status_static.
function Storm.stepped(combat, unit)
    if not (combat and unit) or not Trait().flag(unit, "static") then return end
    local S = Status()
    local st = S.get(unit, "status_static") or S.apply(combat, unit, "status_static", { magnitude = 0 })
    if st then st.magnitude = math.min(Storm.STATIC_MAX, (st.magnitude or 0) + 1) end
end

function Storm.charges(unit)
    local st = unit and Status().get(unit, "status_static")
    return (st and st.magnitude) or 0
end

-- ------------------------------------------------------------------------------------------------ conduction

-- Does fire conduct lightning right now? While a Thunderhead (`fireConducts`) stands on the board.
function Storm.fireConducts(combat)
    for _, u in ipairs((combat and combat.units) or {}) do
        if onBoard(u) and u.traits and #u.traits > 0 and Trait().flag(u, "fireConducts") then return true end
    end
    return false
end

-- ------------------------------------------------------------------------------------------------ ash + eruption

-- ASHFALL: ASH_TILES open tiles within ASH_REACH of `unit`, the ones nearest its nearest foe, take hazard_ash.
function Storm.ashfall(combat, unit)
    if not (combat and onBoard(unit)) then return 0 end
    local cells = {}
    for y = unit.y - Storm.ASH_REACH, unit.y + Storm.ASH_REACH do
        for x = unit.x - Storm.ASH_REACH, unit.x + Storm.ASH_REACH do
            local cell = cellAt(combat, x, y)
            local g = Combat().cellGap(x, y, unit)
            if cell and cell.walkable and g >= 1 and g <= Storm.ASH_REACH then cells[#cells + 1] = { x = x, y = y } end
        end
    end
    local laid = 0
    for _, c in ipairs(nearestTo(cells, nearestFoe(combat, unit), Storm.ASH_TILES)) do
        if require("models.hazard").place(combat, c.x, c.y, "hazard_ash", { side = unit.side }) then laid = laid + 1 end
    end
    return laid
end

-- ERUPTION: every tile next to `unit` becomes lava; with `strike`, every body standing in fire takes a bolt.
function Storm.erupt(combat, unit, strike)
    if not (combat and onBoard(unit)) then return end
    local C = Combat()
    C.logEvent(combat, "action", string.format("%s erupts!", (unit.char and unit.char.name) or "It"), unit)
    C.openChasm(combat, unit, 1)
    if not strike then return end
    local base = Storm.ERUPT_STRIKE + C.flatStat(unit, "magicDamage")
    local victims = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u ~= unit and fireAt(combat, u.x, u.y) then victims[#victims + 1] = u end
    end
    for _, u in ipairs(victims) do
        if u.alive then C.dealFlatDamage(combat, u, base, { "lightning", "magical" }, "Eruption", unit) end
    end
end

-- ------------------------------------------------------------------------------------------------ fusion

local function isKin(u, id)
    return onBoard(u) and u.char and u.char.id == id and not u.fusedInto
end

-- Held inside `lord` (off its tile, out of the turn order); the swarm's seam.
local function holdIn(combat, part, lord)
    require("models.swarm").takeIn(part, lord)
    part.fusedInto = lord
end

-- The storm's bar, filled to the share the two halves have left.
local function fusedHealth(lord, parts)
    local cur, max = 0, 0
    for _, p in ipairs(parts) do
        cur = cur + p.char.stats.health.current
        max = max + p.char.stats.health.max
    end
    local bar = lord.char.stats.health.max
    if max <= 0 then return bar end
    return math.max(1, math.min(bar, math.floor(bar * cur / max + 0.5)))
end

-- FUSE `blaze` and `arc` into a Thunderhead on the Blaze's tile. A torn storm held inside either comes back; else
-- a new one is made at the higher of their levels. Returns the storm.
function Storm.fuse(combat, blaze, arc)
    local C = Combat()
    local x, y, side = blaze.x, blaze.y, blaze.side
    local lord = (blaze.stormLord and blaze.stormLord.alive and blaze.stormLord)
        or (arc.stormLord and arc.stormLord.alive and arc.stormLord)
    local parts = { blaze, arc }
    for _, p in ipairs(parts) do holdIn(combat, p, { x = x, y = y }) end
    if lord then
        require("models.swarm").letOut(combat, lord, x, y)
        lord.stormHeld = nil
    else
        local Character = require("models.character")
        local char = Character.instantiate(Storm.LORD)
        require("models.growth").resolve(char, math.max(blaze.char.level or 1, arc.char.level or 1))
        lord = C.addUnit(combat, char, side, x, y, {})
    end
    lord.stormParts = parts
    for _, p in ipairs(parts) do
        p.swallowedBy, p.fusedInto, p.stormLord = lord, lord, lord
    end
    local hp = fusedHealth(lord, parts)
    lord.char.stats.health.current = hp
    C.logEvent(combat, "action", string.format("%s and %s fuse into %s.", blaze.char.name, arc.char.name,
        lord.char.name or "a storm"), lord)
    C.enterTile(combat, lord, x, y)
    return lord
end

-- AT THE END OF ANY TURN: every Blaze standing next to an Arc of its side fuses with it (board order pairs them).
function Storm.turnEnd(combat)
    if not combat then return end
    local used = {}
    for _, b in ipairs(combat.units or {}) do
        if isKin(b, Storm.BLAZE) and not used[b] then
            for _, a in ipairs(combat.units) do
                if isKin(a, Storm.ARC) and not used[a] and a.side == b.side and Combat().unitGap(a, b) == 1 then
                    used[a], used[b] = true, true
                    Storm.fuse(combat, b, a)
                    break
                end
            end
        end
    end
end

-- Put `part` back on the board beside (x, y) at `hp`. Returns true if it found ground.
local function release(combat, part, x, y, hp)
    local C = Combat()
    local lx, ly
    if C.footprintFree(combat, 1, 1, x, y, part) then lx, ly = x, y
    else lx, ly = C.openBlockNear(combat, x, y, 1, 1, { radius = 4 }) end
    if not lx then return false end
    require("models.swarm").letOut(combat, part, lx, ly)
    part.fusedInto = nil
    part.char.stats.health.current = math.max(1, math.min(part.char.stats.health.max, hp))
    C.enterTile(combat, part, lx, ly)
    return true
end

-- TEAR the storm back into its halves, each at a quarter of its bar; the storm is held inside the Blaze until they
-- fuse again. Once: `torn` is kept on the body. Returns true if it tore.
function Storm.tear(combat, lord)
    if not (combat and lord and lord.alive and lord.stormParts) or lord.stormTorn then return false end
    local C = Combat()
    local x, y = lord.x, lord.y
    local quarter = math.floor(lord.char.stats.health.max / 4)
    local parts = lord.stormParts
    lord.stormTorn = true
    lord.stormParts = nil
    local out = {}
    for _, p in ipairs(parts) do
        if p.alive and release(combat, p, x, y, quarter) then out[#out + 1] = p end
    end
    if #out == 0 then return false end
    holdIn(combat, lord, out[1])
    lord.stormHeld = true
    C.logEvent(combat, "action", string.format("%s tears apart.", lord.char.name or "The storm"), out)
    return true
end

-- THE STORM FALLS (trait_the_thunderhead's onDeath): the halves inside it fall with it, leaving no corpses.
function Storm.fallen(combat, lord)
    if not (combat and lord and lord.stormParts) then return end
    local x, y = lord.x, lord.y
    local parts = lord.stormParts
    lord.stormParts = nil
    for _, p in ipairs(parts) do
        if p.alive and p.fusedInto == lord then
            require("models.swarm").letOut(combat, p, x, y)
            p.fusedInto = nil
            Combat().fell(combat, p)
            p.corpse, p.incapacitated = false, false
            Status().remove(combat, p, "status_downed")
        end
    end
end

-- A HALF FALLS while the storm is held (trait_storm_kin's onDeath): with no half of it left standing, it falls too.
function Storm.halfFallen(combat, part)
    local lord = part and part.stormLord
    if not (lord and lord.alive and lord.stormHeld) then return end
    for _, u in ipairs(combat.units or {}) do
        if u ~= part and u.alive and u.stormLord == lord and not u.fusedInto then return end
    end
    require("models.swarm").letOut(combat, lord, part.x, part.y)
    lord.stormHeld = nil
    Combat().fell(combat, lord)
    lord.corpse = false
end

-- The other half this body walks to (AI.POSTURES.gather): the nearest free Arc for a Blaze, Blaze for an Arc.
function Storm.partner(combat, unit)
    local want = (unit.char and unit.char.id == Storm.BLAZE) and Storm.ARC
        or (unit.char and unit.char.id == Storm.ARC) and Storm.BLAZE or nil
    if not want then return nil end
    local best, bestD
    for _, u in ipairs(combat.units or {}) do
        if isKin(u, want) and u.side == unit.side then
            local d = Combat().unitGap(unit, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

return Storm
