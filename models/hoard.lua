-- THE HOARD: Avaritia's machinery that more than one file reads (data/characters/character_general_greed.lua).
-- Reviewed over three rounds on 2026-09-25 ("Avaritia, the Unspent"); every rule here is one a line approved.
--
-- TWO HALVES. The per-save half is what the LEAD-INS on her floor leave behind (models/descent.lua's
-- floorObjectives lays them beside her stair):
--
--   * THE BURGLARY  a side passage into her treasury. The treasury holds TREASURY heaps for the life of the
--                   save and nothing refills it; each trip in raises an ALARM that never falls, and at
--                   ALARM_SEAL the passage is sealed. Every heap carried out is one fewer on her hoard at the
--                   stair -- and one more stack of Every Coin Counted when she meets you, on every trip after.
--                   Once she has fallen, what is left is yours, unguarded.
--   * THE SHRINE    the kobolds' temple to her. Break it and her procession is halved and one of her two
--                   eggs is gone.
--
-- The board half is geometry a 2x2 body needs and the engine does not have: a ring of every cell touching
-- the footprint (Tail Sweep, Wing Buffet), a cone off the FACE of the body rather than its anchor
-- (Dragonfire), and a whole row or column (her strafe, Fire from the Sky). Measured off the footprint, as
-- The Breath's band is (data/items/ability/ability_the_breath.lua), because Combat.aoeCells aims from the
-- anchor and a 2x2 body aimed from its top-left corner fans the wrong way.
local Hoard = {}

Hoard.TREASURY = 8     -- heaps in her treasury, for the whole save
Hoard.ALARM_SEAL = 3   -- trips into the treasury before the passage is sealed
Hoard.STAIR_HEAPS = 8  -- heaps on her hoard at the stair, before the Burglary takes any
Hoard.GONG_TURN = 4    -- the turn the wardens sound the gong on a first trip; one earlier per alarm
Hoard.VENDOR = "undercroft" -- Greed's house: player.standing[VENDOR] > 0 once she has fallen

-- ---------------------------------------------------------------------------
-- Per-save state
-- ---------------------------------------------------------------------------

-- The save's record of her hoard, created on first ask. `taken` counts heaps ever carried out of the
-- treasury; `alarm` counts trips in; `shrine` is true once the Shrine is broken.
function Hoard.state(player)
    if not player then return { taken = 0, alarm = 0, shrine = false } end
    player.greedHoard = player.greedHoard or { taken = 0, alarm = 0, shrine = false }
    return player.greedHoard
end

-- The live company, for the fight's own rules (Player.active is the save being played).
local function activePlayer()
    local ok, Player = pcall(require, "models.player")
    return ok and Player.active or nil
end

function Hoard.activeState()
    local p = activePlayer()
    if not p then return { taken = 0, alarm = 0, shrine = false } end
    return Hoard.state(p)
end

function Hoard.fallen(player)
    return ((player and player.standing or {})[Hoard.VENDOR] or 0) > 0
end

-- Heaps still in the treasury.
function Hoard.remaining(player)
    return math.max(0, Hoard.TREASURY - (Hoard.state(player).taken or 0))
end

-- Is the passage open? While she lives it closes at the alarm's seal; after her death only an empty
-- treasury closes it.
function Hoard.burglaryOpen(player)
    local s = Hoard.state(player)
    if Hoard.remaining(player) <= 0 then return false end
    if Hoard.fallen(player) then return true end
    return (s.alarm or 0) < Hoard.ALARM_SEAL
end

-- A won trip: `looted` heaps carried out. The alarm rises only while she lives -- after her death
-- nobody is left to sound it.
function Hoard.recordBurglary(player, looted)
    local s = Hoard.state(player)
    s.taken = math.min(Hoard.TREASURY, (s.taken or 0) + math.max(0, looted or 0))
    if not Hoard.fallen(player) then s.alarm = (s.alarm or 0) + 1 end
    return s
end

function Hoard.recordShrine(player)
    Hoard.state(player).shrine = true
end

-- Heaps on her hoard at the stair: what the treasury has not lost.
function Hoard.stairHeaps(player)
    return math.max(0, Hoard.STAIR_HEAPS - (Hoard.state(player).taken or 0))
end

-- The turn the gong sounds on the next trip in: GONG_TURN on a first trip, one earlier per alarm, never
-- before the second turn.
function Hoard.gongTurn(player)
    return math.max(2, Hoard.GONG_TURN - (Hoard.state(player).alarm or 0))
end

-- ---------------------------------------------------------------------------
-- The lead-ins (laid beside her stair by Descent.floorObjectives)
-- ---------------------------------------------------------------------------

local TURN = 5 -- Status.TICKS_PER_TURN, written out so this module loads without models.status

-- The Burglary's wardens: a skulker a firing, and one more per point of alarm.
local function wardens(player)
    local n = 1 + (Hoard.state(player).alarm or 0)
    local out = {}
    for i = 1, n do out[i] = "character_kobold_skulker" end
    return out
end

local BUILDERS = {
    -- THE BURGLARY: a side passage into her treasury, held by kobold hoard-wardens. The board is heaped
    -- with what is left in the treasury, and the way out is the far edge (a `reach` win). The wardens
    -- sound a gong on turn GONG_TURN (earlier per alarm), and more pour in every turn after -- loot fast
    -- and get out. Once she has fallen nobody guards it: no wardens, no gong.
    burglary = function(player, floorLevel)
        local fallen = Hoard.fallen(player)
        local waves = {}
        if not fallen then
            waves[1] = { at = Hoard.gongTurn(player) * TURN, every = TURN, from = "random", maxAlive = 8,
                composition = function() return wardens(Hoard.activePlayer()) end }
        end
        return {
            name = "The Treasury",
            composition = function()
                if Hoard.fallen(Hoard.activePlayer()) then return {} end
                return { "character_kobold_skulker", "character_kobold_trapwright" }
            end,
            scatter = { { id = "hazard_coin_heap", count = Hoard.remaining(player) } },
            enemyCap = false,
            win = { type = "reach", waves = waves },
            floorLevel = floorLevel,
        }
    end,
    -- THE SHRINE: the kobolds' temple to her, the procession mustering. Break it and her waves are halved
    -- and one of her two eggs is gone (models/descent.lua's Greed guardian reads Hoard.state().shrine).
    shrine = function(_, floorLevel)
        return {
            name = "The Shrine",
            composition = {
                "character_kobold_broodkeeper", "character_kobold_scale_priest", "character_kobold_scale_priest",
                "character_dragon_egg", "character_kobold_skulker", "character_kobold_skulker",
            },
            enemyCap = false,
            win = { type = "killAll" },
            floorLevel = floorLevel,
        }
    end,
}

function Hoard.activePlayer() return activePlayer() end

-- The objective spec for lead-in `id` on her floor, or nil for an id nobody wrote.
function Hoard.leadInSpec(id, player, floorLevel)
    local build = BUILDERS[id]
    return build and build(player, floorLevel) or nil
end

-- Is lead-in `id` still worth stepping onto for this save? The Burglary closes when the treasury is empty
-- or sealed; the Shrine once it is broken.
function Hoard.leadInOpen(id, player)
    if id == "burglary" then return Hoard.burglaryOpen(player) end
    if id == "shrine" then return not Hoard.state(player).shrine end
    return false
end

-- A lead-in won: write what it changed onto the save. `combat` is the fight just won (its heapsLooted is
-- what the Burglary carried out). Returns the line the floor screen toasts.
function Hoard.recordLeadIn(id, player, combat)
    if id == "burglary" then
        local looted = (combat and combat.heapsLooted) or 0
        local s = Hoard.recordBurglary(player, looted)
        if Hoard.remaining(player) <= 0 then
            return string.format("%d heaps carried out. Her treasury is empty.", looted)
        elseif not Hoard.fallen(player) and (s.alarm or 0) >= Hoard.ALARM_SEAL then
            return string.format("%d heaps carried out. The wardens seal the passage.", looted)
        end
        return string.format("%d heaps carried out of her treasury. She will know.", looted)
    elseif id == "shrine" then
        Hoard.recordShrine(player)
        return "The Shrine is broken. Her procession will be thin."
    end
end

-- ---------------------------------------------------------------------------
-- Footprint geometry
-- ---------------------------------------------------------------------------

-- Every cell touching the footprint, corners included: what a body that size is standing against.
function Hoard.ring(unit)
    local w, h = unit.w or 1, unit.h or 1
    local out = {}
    for y = unit.y - 1, unit.y + h do
        for x = unit.x - 1, unit.x + w do
            local inside = x >= unit.x and x <= unit.x + w - 1 and y >= unit.y and y <= unit.y + h - 1
            if not inside then out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- Which face of the body the aimed tile lies off, as a unit step (The Breath's own `facing`).
function Hoard.facing(unit, tx, ty)
    local w, h = unit.w or 1, unit.h or 1
    local dx = (tx < unit.x and -1) or (tx > unit.x + w - 1 and 1) or 0
    local dy = (ty < unit.y and -1) or (ty > unit.y + h - 1 and 1) or 0
    if dx ~= 0 and dy ~= 0 then
        local ox = dx > 0 and tx - (unit.x + w - 1) or unit.x - tx
        local oy = dy > 0 and ty - (unit.y + h - 1) or unit.y - ty
        if ox >= oy then dy = 0 else dx = 0 end
    end
    if dx == 0 and dy == 0 then dy = 1 end -- aimed inside the body: breathe south rather than nowhere
    return dx, dy
end

-- A cone `length` deep off the face the aim lies off. It opens a tile to each side every second row, so a
-- 2-wide face breathes 2, 4, 4, 6, 6 across -- wider than the Godling's point-born cone and never a net.
function Hoard.cone(unit, tx, ty, length)
    local w, h = unit.w or 1, unit.h or 1
    local dx, dy = Hoard.facing(unit, tx, ty)
    local out = {}
    for i = 0, (length or 5) - 1 do
        local spread = math.floor((i + 1) / 2)
        if dx ~= 0 then
            local x = (dx > 0 and unit.x + w or unit.x - 1) + dx * i
            for y = unit.y - spread, unit.y + h - 1 + spread do out[#out + 1] = { x = x, y = y } end
        else
            local y = (dy > 0 and unit.y + h or unit.y - 1) + dy * i
            for x = unit.x - spread, unit.x + w - 1 + spread do out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- A whole row or column of the board through the aimed tile: the row when the aim lies more to the side
-- of the caster than above or below it, the column otherwise.
function Hoard.line(combat, unit, tx, ty)
    local arena = combat and combat.arena
    local cols = (arena and arena.cols) or 16
    local rows = (arena and arena.rows) or 12
    local out = {}
    local horizontal = true
    if unit then
        local cx = unit.x + ((unit.w or 1) - 1) / 2
        local cy = unit.y + ((unit.h or 1) - 1) / 2
        horizontal = math.abs(tx - cx) >= math.abs(ty - cy)
    end
    if horizontal then
        for x = 1, cols do out[#out + 1] = { x = x, y = ty } end
    else
        for y = 1, rows do out[#out + 1] = { x = tx, y = y } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The ground
-- ---------------------------------------------------------------------------

-- Live coin heaps within `radius` of the body's footprint (Combat.cellGap, Manhattan off the box).
function Hoard.heapsNear(combat, unit, radius)
    if not (combat and unit) then return 0 end
    local Combat = require("models.combat")
    local n = 0
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive ~= false and h.id == "hazard_coin_heap" and Combat.cellGap(h.x, h.y, unit) <= (radius or 2) then
            n = n + 1
        end
    end
    return n
end

-- Lay `n` coin heaps on open ground within `radius` of the body, nearest first and spread round it: cells
-- are taken in order of distance, and within one distance in an order hashed off the board's seed so two
-- fights do not ring her identically. A tile with a body, an object or a zone on it is passed over.
function Hoard.placeHeaps(combat, unit, n, radius)
    if not (combat and unit and combat.arena and n and n > 0) then return 0 end
    local Combat = require("models.combat")
    local Hazard = require("models.hazard")
    local tiles = combat.arena.tiles
    local seed = (combat.arena.seed or combat.seed or 0) % 9973
    local cand = {}
    for y = unit.y - radius, unit.y + (unit.h or 1) - 1 + radius do
        for x = unit.x - radius, unit.x + (unit.w or 1) - 1 + radius do
            local cell = tiles[y] and tiles[y][x]
            local gap = Combat.cellGap(x, y, unit)
            if cell and cell.walkable and gap >= 1 and gap <= radius and not Combat.unitAt(combat, x, y)
                and not Combat.objectAt(combat, x, y) and #Hazard.allAt(combat, x, y) == 0 then
                cand[#cand + 1] = { x = x, y = y, gap = gap, key = (x * 7919 + y * 104729 + seed) % 997 }
            end
        end
    end
    table.sort(cand, function(a, b)
        if a.gap ~= b.gap then return a.gap < b.gap end
        if a.key ~= b.key then return a.key < b.key end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    local placed = 0
    for _, c in ipairs(cand) do
        if placed >= n then break end
        if Hazard.place(combat, c.x, c.y, "hazard_coin_heap", {}) then placed = placed + 1 end
    end
    return placed
end

-- Her fire over the ground: a coin heap under the flame melts to Molten Gold, anything else takes Fire.
-- Called from inside an effect through `fx`, so a forecast's dry run lays nothing.
function Hoard.burnCells(fx, cells, fireAmount, fireDuration)
    for _, c in ipairs(cells) do
        local melted = false
        for _, z in ipairs(fx.hazardsAt(c.x, c.y) or {}) do
            if z.id == "hazard_coin_heap" then
                fx.consumeHazard(z)
                fx.placeHazard(c.x, c.y, "hazard_molten_gold", {})
                melted = true
            elseif z.id == "hazard_molten_gold" then
                melted = true
            end
        end
        if not melted then
            fx.placeHazard(c.x, c.y, "hazard_fire", { amount = fireAmount, duration = fireDuration })
        end
    end
end

return Hoard
