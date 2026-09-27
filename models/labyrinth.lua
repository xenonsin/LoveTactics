-- THE LABYRINTH: the Minotaur's fight (data/characters/character_minotaur.lua; reviewed over four rounds on
-- 2026-09-26/27, "The Minotaur"). One mythical beast, fought alone as an elite on Wrath's second floor. It is
-- not a race and it has no clan: the author struck both.
--
--   THE LABYRINTH      the fight opens in a maze. The Minotaur is set down at the heart of the board and stone
--                      is laid around it in one-tile corridors (the golems' rubble: it bars a step, screens a
--                      line and stops a shove). A fight board has almost no walls of its own, so this one
--                      brings them.
--   THROUGH THE WALLS  its move goes through the maze. A wall on its route breaks as it arrives, and the walk
--                      goes on (Combat.enterTile). The company goes round. Every wall it breaks is one fewer for
--                      the rest of the fight, so the maze is spent as it is used.
--   THE MAZE SHIFTS    every third turn of its own, the unbroken walls slide one tile. The tiles they will slide
--                      onto are marked a turn ahead (hazard_shifting_stone), so a corridor closing is never a
--                      surprise, only a clock.
--   THE RUN            (data/traits/trait_the_run.lua, on Bull's Brow) a straight approach drives the body it
--                      strikes back one tile for every two run, up to 3. This file plans the approach.
--   HEAD DOWN          below a third of its health -- or on the blow that would have felled it from above that
--                      -- it puts its head down and goes into FURY (data/status/status_fury.lua): 1 health,
--                      cannot die for about four turns, heals half of what it deals when the window closes.
--                      With its head down it runs straight at the NEAREST body through every wall, a step
--                      further, and the Run drives back one tile per tile.
--
-- AN AI RULE BINDS NOBODY THE PLAYER DRIVES: every plan here is for the enemy side only.
--
-- CONNECTIVITY IS OWNED HERE. Every wall the maze lays or slides is checked against one question -- can every
-- living body on the board still reach every other, walls barring and bodies not -- and a wall that would cut
-- the board in two is not laid, or slides back. A maze that sealed the healer in a closet would be a fight
-- nobody could play, and the generator does not get to assume the board it was handed.
local Status = require("models.status")

local Labyrinth = {}

Labyrinth.WALL = "rubble"          -- the golems' slab: 14 health, bars a step and a line
Labyrinth.SHIFT_EVERY = 3          -- its own turns between slides
Labyrinth.HEAD_DOWN_AT = 1 / 3     -- the share of its health it puts its head down under
Labyrinth.RUN_CAP = 3              -- the most tiles the Run drives a body back
Labyrinth.HEAD_DOWN_RUN_CAP = 5    -- ...and with its head down, one tile per tile, up to this

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

local function Combat() return require("models.combat") end
local function Trait() return require("models.trait") end
local function Wall() return require("models.wall") end

local function key(x, y) return x .. "," .. y end

local function cell(combat, x, y)
    local arena = combat.arena
    return arena and arena.tiles and arena.tiles[y] and arena.tiles[y][x]
end

-- Is (x, y) ground a body could stand on, with no standing object barring it? Bodies do not count: the
-- question is whether the BOARD is connected, not whether anyone is currently in the way.
local function open(combat, x, y)
    local c = cell(combat, x, y)
    return c ~= nil and c.walkable and not Combat().objectBlocksAt(combat, x, y)
end

-- Can every living body reach every other across open ground? A flood from the first body, then every other
-- body's footprint must be touched by it.
function Labyrinth.connected(combat)
    local bodies = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and not Combat().isOffTile(u) then bodies[#bodies + 1] = u end
    end
    if #bodies < 2 then return true end
    local seen, queue = {}, {}
    local function push(x, y)
        local k = key(x, y)
        if not seen[k] and open(combat, x, y) then seen[k] = true; queue[#queue + 1] = { x, y } end
    end
    -- A body stands on open ground by definition, so seed from its own tile even if a wall was just laid
    -- beside it; the tile it stands on is never a wall (Wall.place refuses an occupied tile).
    local first = bodies[1]
    seen[key(first.x, first.y)] = true
    queue[1] = { first.x, first.y }
    local head = 1
    while head <= #queue do
        local x, y = queue[head][1], queue[head][2]
        head = head + 1
        for _, d in ipairs(DIRS) do push(x + d[1], y + d[2]) end
    end
    for i = 2, #bodies do
        local b, touched = bodies[i], false
        for _, c in ipairs(Combat().cellsAt(b.w or 1, b.h or 1, b.x, b.y)) do
            if seen[key(c.x, c.y)] then touched = true break end
        end
        if not touched then return false end
    end
    return true
end

-- Is (x, y) within a tile of any body? The maze never walls a body in at the opening bell: the company
-- keeps the ground it spawned on and the beast keeps its heart.
local function besideABody(combat, x, y)
    for _, u in ipairs(combat.units or {}) do
        if u.alive and not Combat().isOffTile(u) then
            for _, c in ipairs(Combat().cellsAt(u.w or 1, u.h or 1, u.x, u.y)) do
                if math.max(math.abs(c.x - x), math.abs(c.y - y)) <= 1 then return true end
            end
        end
    end
    return false
end

-- Lay one maze wall at (x, y), keeping it only if the board stays connected. Returns the wall or nil.
local function tryLay(combat, beast, x, y)
    if not open(combat, x, y) or Combat().unitAt(combat, x, y) or besideABody(combat, x, y) then return nil end
    local w = Wall().place(combat, x, y, Labyrinth.WALL, { side = beast.side })
    if not w then return nil end
    if not Labyrinth.connected(combat) then
        w.alive = false -- quietly unlaid: it was never there
        return nil
    end
    w.maze = true
    return w
end

-- THE LABYRINTH, laid as the fight opens (trait_the_labyrinth's onCombatStart). The beast is set at the heart
-- first, then a pillar maze: a stone on every other tile of every other row, each thrown one tile further in a
-- seeded direction. That is the classic way to cut a grid into one-tile corridors, and every stone is kept
-- only if the board is still one board. Returns how many stones were laid.
function Labyrinth.lay(combat, beast)
    local arena = combat and combat.arena
    if not (arena and arena.cols and arena.rows and beast and beast.alive) then return 0 end
    -- The heart. Basin.center's move: at the opening bell nobody has acted, so the body is simply set down.
    local cx, cy = math.floor((arena.cols + 1) / 2), math.floor((arena.rows + 1) / 2)
    if beast.x ~= cx or beast.y ~= cy then
        local x, y
        if Combat().footprintFree(combat, 1, 1, cx, cy, beast) then x, y = cx, cy
        else x, y = Combat().openBlockNear(combat, cx, cy, 1, 1, { ignore = beast, radius = 3 }) end
        if x then beast.x, beast.y = x, y end
    end
    local laid = 0
    for y = 2, arena.rows - 1, 2 do
        for x = 2, arena.cols - 1, 2 do
            if tryLay(combat, beast, x, y) then
                laid = laid + 1
                local d = DIRS[Combat().roll(combat, 4)]
                if tryLay(combat, beast, x + d[1], y + d[2]) then laid = laid + 1 end
            end
        end
    end
    if laid > 0 then
        Combat().logEvent(combat, "action", "Stone rises in corridors. The fight is in a maze.", beast)
    end
    return laid
end

-- Every maze wall still standing.
local function mazeWalls(combat)
    local out = {}
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and w.maze then out[#out + 1] = w end
    end
    return out
end

-- THE MAZE SHIFTS, half one: choose which way the walls will go and mark where they will land. The direction
-- turns a quarter each time (seeded start), so the maze does not drift off one edge of the board.
function Labyrinth.markShift(combat, beast)
    local Hazard = require("models.hazard")
    local st = combat.labyrinth or {}
    combat.labyrinth = st
    st.turn = ((st.turn or Combat().roll(combat, 4)) % 4) + 1
    local d = DIRS[st.turn]
    st.pending = { dx = d[1], dy = d[2], marks = {} }
    for _, w in ipairs(mazeWalls(combat)) do
        local nx, ny = w.x + d[1], w.y + d[2]
        local c = cell(combat, nx, ny)
        if c and c.walkable and not Combat().objectBlocksAt(combat, nx, ny) then
            local h = Hazard.place(combat, nx, ny, "hazard_shifting_stone", { side = beast.side })
            if h then st.pending.marks[#st.pending.marks + 1] = h end
        end
    end
    Combat().logEvent(combat, "action", "The walls of the maze grind. They will move.", beast)
end

-- THE MAZE SHIFTS, half two: every maze wall slides the marked way. A wall whose landing tile holds a body,
-- another wall or ground nothing stands on stays where it is -- and so does one whose slide would cut the
-- board in two. Returns how many moved.
function Labyrinth.shift(combat, beast)
    local Hazard = require("models.hazard")
    local st = combat.labyrinth
    local pending = st and st.pending
    if not pending then return 0 end
    st.pending = nil
    for _, h in ipairs(pending.marks) do
        if h.alive then Hazard.consume(combat, h) end
    end
    local moved = 0
    for _, w in ipairs(mazeWalls(combat)) do
        local fx, fy = w.x, w.y
        local nx, ny = fx + pending.dx, fy + pending.dy
        local c = cell(combat, nx, ny)
        if c and c.walkable and not Combat().unitAt(combat, nx, ny) and not Combat().objectAt(combat, nx, ny) then
            w.x, w.y = nx, ny
            if Labyrinth.connected(combat) then moved = moved + 1
            else w.x, w.y = fx, fy end
        end
    end
    if moved > 0 then
        Combat().logEvent(combat, "action", "The maze shifts. The corridors are not where they were.", beast)
    end
    return moved
end

-- The beast's own turn ended (trait_the_labyrinth's onTurnEnd): count it, mark the slide the turn before it
-- lands, and land it on every third.
function Labyrinth.onTurnEnd(combat, beast)
    if not (beast and beast.alive) then return end
    beast.mazeTurns = (beast.mazeTurns or 0) + 1
    local n = beast.mazeTurns % Labyrinth.SHIFT_EVERY
    if n == Labyrinth.SHIFT_EVERY - 1 then Labyrinth.markShift(combat, beast)
    elseif n == 0 then Labyrinth.shift(combat, beast) end
end

-- THROUGH THE WALLS: does `unit` walk through a maze wall rather than round it? A flag on the beast's organ.
function Labyrinth.walksThrough(unit)
    return unit ~= nil and Trait().flag(unit, "throughTheWalls") and true or false
end

-- Does a standing object bar `unit` from (x, y)? Combat.objectBlocksAt, less the WALLS a wall-walker breaks
-- through (a prop is furniture, not the maze, and still bars it).
function Labyrinth.blocks(combat, unit, x, y)
    if not Combat().objectBlocksAt(combat, x, y) then return false end
    if Labyrinth.walksThrough(unit) and Wall().at(combat, x, y) and not require("models.prop").at(combat, x, y) then
        return false
    end
    return true
end

-- A wall-walker arrived on (x, y) by its own feet: the wall there breaks (Combat.enterTile).
function Labyrinth.breakThrough(combat, unit, x, y)
    if not Labyrinth.walksThrough(unit) then return false end
    local w = Wall().at(combat, x, y)
    if not w then return false end
    Wall().damage(combat, w, w.health)
    return true
end

-- HEAD DOWN. Once a fight: Fury (1 health, cannot die, heals half of what it deals when the window closes) and
-- the Head Down badge (+1 movement, the straight run at the nearest body). Returns true the time it fires.
function Labyrinth.headDown(combat, beast)
    if not (beast and beast.alive) or beast.headDown then return false end
    beast.headDown = true
    Status.apply(combat, beast, "status_head_down")
    Status.apply(combat, beast, "status_fury")
    Combat().logEvent(combat, "action", string.format("%s puts its head down. It will not fall now.",
        (beast.char and beast.char.name) or "The beast"), beast)
    return true
end

-- Below the line? Read against the unreserved ceiling, as every health share is.
function Labyrinth.belowHeadDown(beast)
    local hp = beast and beast.char and beast.char.stats.health
    if not hp then return false end
    local max = Combat().unreservedMax(beast.char, "health")
    return max > 0 and hp.current < max * Labyrinth.HEAD_DOWN_AT
end

-- THE RUN'S DISTANCE for a straight approach of `run` tiles: one per two, up to 3; one per tile with its head
-- down, up to 5. Zero under two tiles -- a single step is not a run.
function Labyrinth.runDistance(unit, run)
    if not run or run < 2 then return 0 end
    if Status.has(unit, "status_head_down") then return math.min(run, Labyrinth.HEAD_DOWN_RUN_CAP) end
    return math.min(math.floor(run / 2), Labyrinth.RUN_CAP)
end

-- ---------------------------------------------------------------------------
-- The beast's turn (AI.preempt)
-- ---------------------------------------------------------------------------

local function itemById(unit, id)
    for _, item in ipairs(require("models.character").eachItem(unit.char)) do
        if item.id == id then return item end
    end
    return nil
end

local function usable(unit, item)
    return item ~= nil and not Combat().itemBlockReason(unit, item)
end

-- Every straight approach open to `unit` this turn: for each of the four directions, each tile it can reach
-- and stop on in an unbroken line, with the tile beyond it (where the Run lands its blow). Straight along a
-- row or column is the only Manhattan-shortest route to such a tile, so the walk taken IS the line.
local function straightStands(combat, unit)
    local reach = Combat().reachable(combat, unit)
    local out = {}
    for _, d in ipairs(DIRS) do
        local k = 1
        while true do
            local x, y = unit.x + d[1] * k, unit.y + d[2] * k
            local node = reach[key(x, y)]
            if not node or node.stopsShort then break end
            out[#out + 1] = { x = x, y = y, run = k, ax = x + d[1], ay = y + d[2] }
            k = k + 1
        end
    end
    return out
end

-- The best straight run at a body: `pick(body)` says whether that body is a fair target. Longest run first,
-- then the body with the least health left. nil when no straight approach of two or more ends on one.
local function bestRun(combat, unit, pick)
    local best
    for _, s in ipairs(straightStands(combat, unit)) do
        if s.run >= 2 then
            local tt = Combat().unitAt(combat, s.ax, s.ay)
            if tt and tt ~= unit and tt.alive and pick(tt) then
                local hp = tt.char.stats.health.current
                if not best or s.run > best.run or (s.run == best.run and hp < best.hp) then
                    best = { x = s.x, y = s.y, tx = s.ax, ty = s.ay, run = s.run, hp = hp, target = tt }
                end
            end
        end
    end
    return best
end

-- The beast's turn, or nil to let the ordinary planner run.
--   * its first turn: Reckless Stance (the opening race)
--   * head down: a straight run at the NEAREST body, either side, Desperate Strike if it can pay for it;
--     failing a straight line, the nearest body the ordinary way (models/rampage.lua)
--   * otherwise: a straight run at a foe when one is open, with the labrys; failing that, nil -- and the
--     ordinary planner picks the Culling Stroke, Desperate Strike or a plain swing as any barbarian would
function Labyrinth.plan(combat, unit)
    if not unit or unit.side == "party" or not Trait().flag(unit, "labyrinth") then return nil end
    if Status.stopsMovement(unit) then return nil end
    local weapon = Combat().defaultWeapon(unit.char)
    if not unit.openedReckless then
        unit.openedReckless = true
        local reckless = itemById(unit, "ability_reckless_stance")
        if usable(unit, reckless) and not Status.has(unit, "status_reckless") then
            return { item = reckless, tx = unit.x, ty = unit.y, reason = "reckless" }
        end
    end
    if Status.has(unit, "status_head_down") then
        local nearest, nd
        for _, u in ipairs(combat.units or {}) do
            if u ~= unit and u.alive and not Combat().isOffTile(u) then
                local d = Combat().unitGap(unit, u)
                if not nd or d < nd then nearest, nd = u, d end
            end
        end
        if not nearest then return nil end
        local run = bestRun(combat, unit, function(tt) return tt == nearest end)
        if run then
            local desperate = itemById(unit, "ability_desperate_strike")
            local item = usable(unit, desperate) and desperate or weapon
            local plan = { item = item, tx = run.tx, ty = run.ty, reason = "head down" }
            if run.x ~= unit.x or run.y ~= unit.y then plan.move = { x = run.x, y = run.y } end
            return plan
        end
        return require("models.rampage").hitNearest(combat, unit, "head down")
    end
    if not usable(unit, weapon) then return nil end
    local run = bestRun(combat, unit, function(tt) return tt.side ~= unit.side end)
    if not run then return nil end
    return { move = { x = run.x, y = run.y }, item = weapon, tx = run.tx, ty = run.ty, reason = "the run" }
end

return Labyrinth
