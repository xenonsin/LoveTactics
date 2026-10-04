-- THE SANDMAN: Sloth's mini boss, on floor 9's stair ("Sloth's Bestiary", slice G, 2026-10-04; every rule approved
-- on review). A tall dream-thing who pours sand from his own hands and puts the world to bed. He is the general's
-- herald -- Desidia's sleep is the circle's word, and his sleep is the first taste of it -- so every one of his
-- rules is about WHERE A BODY STANDS when the sand comes due, and every answer to it is a step.
--
--   SAND IN THE EYES   at the end of each of his turns he sows sand on a pattern of tiles, cycling a cross, a ring
--                      and a row (hazard_sown_sand, on the board a turn early). At the start of his next turn
--                      everything standing on it falls Asleep, on either side, and the sand is gone.
--   RUN THROUGH THE    a foe that ends its turn beside him sends him out as sand: he reforms on the tile his
--   GLASS              hourglass has marked (hazard_hourglass_mark -- the counter is that the mark is shown), and
--                      the tile he left is a sand patch (hazard_sand_patch) that sleeps whoever ends a turn on it.
--   BAD DREAMS         a body put under by HIS sleep and woken by a blow is Rattled until the end of its next turn.
--                      Woken by a Cure, or left to wake on its own, it is not. The rule lives on the sleep itself
--                      (status_sleep's `badDreams` stamp), because the wake is the sleep's own event.
--
-- THERE ARE NO ROUNDS IN THIS ENGINE, so "each turn" and "his next turn" are his own turns (Leviathan reads it the
-- same way). The patterns are aimed where they catch the most of his foes as he sows them, which is exactly what
-- a company that keeps moving walks out of.
--
-- The drops call the same seams: the Hourglass is Run Through the Glass with a reach of 4 instead of a mark, and
-- the Sandman's Pouch sows its 3x3 through a wind-up that ends in Sandman.sleep.
--
-- Pure logic, headless-safe. Combat is reached lazily, as every model the combat core calls back into does.

local Status = require("models.status")

local Sandman = {}

Sandman.SOWN = "hazard_sown_sand"
Sandman.PATCH = "hazard_sand_patch"
Sandman.MARK = "hazard_hourglass_mark"
-- The three shapes he cycles through, in the order the review named them.
Sandman.PATTERNS = { "cross", "ring", "row" }
-- How far the cross reaches from its heart: a plus of nine tiles.
Sandman.CROSS_REACH = 2
-- "For the rest of the fight", in the zone clock's own units (Leviathan's 9999).
Sandman.FOREVER = 9999

local function C() return require("models.combat") end
local function Trait() return require("models.trait") end

local function name(u) return (u and u.char and u.char.name) or "The Sandman" end

local function state(unit)
    unit.sandman = unit.sandman or { cycle = 0, sown = {}, patches = {} }
    return unit.sandman
end

local function dims(combat)
    local a = combat.arena or {}
    local rows = a.rows or (a.tiles and #a.tiles) or 0
    local cols = a.cols or (a.tiles and a.tiles[1] and #a.tiles[1]) or 0
    return cols, rows
end

local function walkable(combat, x, y)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    return cell ~= nil and cell.walkable == true
end

-- ------------------------------------------------------------------------------------------- the sleep

-- PUT `body` UNDER, as `by`'s sleep. The one place the line's sleep is laid, so Bad Dreams is stamped wherever it
-- comes from -- the sown sand, a patch, the Pouch. The stamp rides the SLEEP INSTANCE (status_sleep reads it on
-- the blow that wakes it), and only when the sower carries the rule: the Pouch in a company's hands sleeps plainly.
function Sandman.sleep(combat, body, by)
    if not (body and body.alive) then return nil end
    local s = Status.apply(combat, body, "status_sleep", { applier = by })
    if s and by and Trait().flag(by, "badDreams") then s.badDreams = true end
    return s
end

-- ------------------------------------------------------------------------------------- sand in the eyes

-- The tiles of `shape` around (cx, cy). A row is the whole row of the board: his last shape, and the one Desidia
-- sweeps in, a floor early.
function Sandman.cells(combat, shape, cx, cy)
    local cols = dims(combat)
    local out = {}
    local function add(x, y) if walkable(combat, x, y) then out[#out + 1] = { x = x, y = y } end end
    if shape == "cross" then
        add(cx, cy)
        for r = 1, Sandman.CROSS_REACH do
            add(cx + r, cy); add(cx - r, cy); add(cx, cy + r); add(cx, cy - r)
        end
    elseif shape == "ring" then
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then add(cx + dx, cy + dy) end
            end
        end
    else
        for x = 1, cols do add(x, cy) end
    end
    return out
end

-- How many of `unit`'s foes (and, against it, how many of its own side) stand on `cells`. A body is counted once
-- however many of its cells the shape covers.
local function score(combat, unit, cells)
    local seen, foes, friends = {}, 0, 0
    for _, c in ipairs(cells) do
        local u = C().unitAt(combat, c.x, c.y)
        if u and u ~= unit and not seen[u] then
            seen[u] = true
            if u.side ~= unit.side then foes = foes + 1 else friends = friends + 1 end
        end
    end
    return foes * 2 - friends
end

-- Where this shape catches the most: every centre on the board is tried, the best kept, ties to the lowest row and
-- column so a seed replays. A row is tried once per row.
function Sandman.aim(combat, unit, shape)
    local cols, rows = dims(combat)
    local best, bestScore
    for y = 1, rows do
        for x = 1, (shape == "row") and 1 or cols do
            local cells = Sandman.cells(combat, shape, x, y)
            if #cells > 0 then
                local s = score(combat, unit, cells)
                if not bestScore or s > bestScore then best, bestScore = { x = x, y = y, cells = cells }, s end
            end
        end
    end
    return best
end

-- SOW: lay `cells` with sand that comes due at the start of the sower's next turn.
function Sandman.sow(combat, unit, cells)
    local Hazard = require("models.hazard")
    local st = state(unit)
    for _, c in ipairs(cells) do
        local h = Hazard.place(combat, c.x, c.y, Sandman.SOWN, { side = unit.side, duration = Sandman.FOREVER })
        if h then st.sown[#st.sown + 1] = h end
    end
end

-- The end of his turn: the next shape in the cycle, where it catches the most.
function Sandman.sowNext(combat, unit)
    local st = state(unit)
    st.cycle = st.cycle % #Sandman.PATTERNS + 1
    local shape = Sandman.PATTERNS[st.cycle]
    local aim = Sandman.aim(combat, unit, shape)
    if not aim then return nil end
    Sandman.sow(combat, unit, aim.cells)
    C().logEvent(combat, "action", string.format("%s pours sand from his hands in a %s.", name(unit), shape), unit)
    return shape, aim
end

-- The start of his turn: the sand sown last turn comes due. Every body on it but his own falls Asleep, and the
-- sand is gone.
function Sandman.reap(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    local slept, seen = {}, {}
    for _, h in ipairs(st.sown) do
        if h.alive then
            local u = C().unitAt(combat, h.x, h.y)
            if u and u ~= unit and not seen[u] then
                seen[u] = true
                if Sandman.sleep(combat, u, unit) then slept[#slept + 1] = u end
            end
            Hazard.consume(combat, h)
        end
    end
    st.sown = {}
    return slept
end

-- ------------------------------------------------------------------------------- run through the glass

-- The open tile farthest from (x, y): where the hourglass marks, across the board. Ties to the lowest row and
-- column, so a seed replays.
local function farthestFrom(combat, x, y, mover)
    local cols, rows = dims(combat)
    local best, bestD
    for ty = 1, rows do
        for tx = 1, cols do
            if C().footprintFree(combat, 1, 1, tx, ty, mover) then
                local d = math.abs(tx - x) + math.abs(ty - y)
                if not bestD or d > bestD then best, bestD = { x = tx, y = ty }, d end
            end
        end
    end
    return best
end

-- LAY THE MARK: the tile he will reform on, shown. Not OWNED by him -- owned ground walks with its owner
-- (Hazard.carry), and a mark that followed him would not be where he said he would go.
function Sandman.markFrom(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    if st.mark and st.mark.alive then Hazard.consume(combat, st.mark) end
    st.mark = nil
    local at = farthestFrom(combat, unit.x, unit.y, unit)
    if not at then return nil end
    st.mark = Hazard.place(combat, at.x, at.y, Sandman.MARK, { side = unit.side, duration = Sandman.FOREVER })
    return st.mark
end

-- Where a run with `reach` (nil: the mark) sets him down. With a reach, the open tile within it farthest from the
-- foe that sent him; with the mark, the mark, or the nearest open tile to it when somebody is standing there.
function Sandman.destination(combat, unit, foe, reach)
    if reach then
        local best, bestD
        for dy = -reach, reach do
            for dx = -reach, reach do
                local n = math.abs(dx) + math.abs(dy)
                local tx, ty = unit.x + dx, unit.y + dy
                if n >= 1 and n <= reach and C().footprintFree(combat, 1, 1, tx, ty, unit) then
                    local d = math.abs(tx - foe.x) + math.abs(ty - foe.y)
                    if not bestD or d > bestD then best, bestD = { x = tx, y = ty }, d end
                end
            end
        end
        return best
    end
    local m = state(unit).mark
    if not (m and m.alive) then return nil end
    if C().footprintFree(combat, 1, 1, m.x, m.y, unit) then return { x = m.x, y = m.y } end
    local x, y = C().openBlockNear(combat, m.x, m.y, 1, 1, { ignore = unit })
    return x and { x = x, y = y } or nil
end

-- THE RUN: out as sand, back together at the destination, a patch left where he stood.
function Sandman.run(combat, unit, foe, reach)
    local Hazard = require("models.hazard")
    local dest = Sandman.destination(combat, unit, foe, reach)
    if not dest then return false end
    local fromX, fromY = unit.x, unit.y
    if not C().teleportUnit(combat, unit, dest.x, dest.y, { silent = true }) then return false end
    local st = state(unit)
    local patch = Hazard.place(combat, fromX, fromY, Sandman.PATCH, { side = unit.side, duration = Sandman.FOREVER })
    if patch then st.patches[#st.patches + 1] = patch end
    C().logEvent(combat, "action", string.format("%s runs out as sand, and is somewhere else.", name(unit)), unit)
    if not reach then Sandman.markFrom(combat, unit) end
    return true
end

-- Is any cell of `u` on one of `unit`'s sand patches?
local function onPatch(combat, unit, u)
    local st = state(unit)
    for _, c in ipairs(C().unitCells(u)) do
        for _, h in ipairs(st.patches) do
            if h.alive and h.x == c.x and h.y == c.y then return true end
        end
    end
    return false
end

-- Somebody else's turn just ended (the Glass's trait, onAnyTurnEnd): a body ending it on a patch falls Asleep, and
-- a foe ending it beside him sends him out. A run is a reflex -- a stunned or sleeping Sandman stays put.
function Sandman.turnEnded(combat, unit, actor, reach)
    if not (unit.alive and actor and actor.alive) then return end
    if actor ~= unit and onPatch(combat, unit, actor) then Sandman.sleep(combat, actor, unit) end
    if actor.side ~= unit.side and actor.alive and not Status.disablesReactions(unit)
        and C().unitGap(unit, actor) == 1 then
        Sandman.run(combat, unit, actor, reach)
    end
end

-- His death takes his sand and his mark with him; the patches already on the ground stay where they lie.
function Sandman.onDeath(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    for _, h in ipairs(st.sown) do Hazard.consume(combat, h) end
    st.sown = {}
    if st.mark and st.mark.alive then Hazard.consume(combat, st.mark) end
    st.mark = nil
end

-- BAD DREAMS, read by status_sleep on the blow that wakes a stamped sleeper: Rattled until the end of its next
-- turn. Its next turn is `initiative` ticks away once the sleep has handed back what it had not served, and a
-- status with one tick left when that turn comes expires on the first beat after it ends.
function Sandman.badDreams(combat, body, by)
    if not (body and body.alive) then return nil end
    local ticks = math.max(1, math.floor(body.initiative or 0) + 1)
    C().logEvent(combat, "status", string.format("%s wakes from a bad dream.",
        (body.char and body.char.name) or "Unit"), body)
    return Status.apply(combat, body, "status_rattled", { applier = by, duration = ticks })
end

return Sandman
