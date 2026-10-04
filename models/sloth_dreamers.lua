-- SLOTH'S DREAMERS (slice E of "Sloth's Bestiary", 2026-10-04): the shared machinery of the seat's sleep-and-root
-- bodies -- the Poppy-Moth's cloud, Baku's meal and the Old Spruce's roots, and the three trophies that carry each
-- rule out of the fight.
--
--   Poppy Dust     a moth that is struck, or felled, bursts: every body beside it falls Asleep, either side
--   Dream-Eating   at the top of Baku's turn it feeds on every Asleep or Dormant body within 3, either side
--   Roots          at the end of the Spruce's turn its roots spread one tile; a body that ends a turn beside
--                  it is Rooted
--
-- ONE SLEEP, AND IT IS SLEEP'S OWN. Nothing here coins a second word for it: the cloud lays status_sleep, so the
-- answer is the one the whole game already teaches -- hit it, or Cure it -- and Baku counts status_sleep and the
-- foundation's status_dormant, the circle's two ways of being under.
--
-- THE ROOTS ARE A WALL (data/walls/roots.lua), because a wall is already the thing every path, reach, shove and
-- blink in the engine asks about (Combat.objectBlocksAt) -- and a wall bars a flier too, so "neither side
-- crosses" holds for the moths without a word of its own. They can be cut down like any wall.
--
-- Pure logic with lazy requires, like models/wall.lua, so it loads headless and sits in no require cycle.
local Dreamers = {}

-- The statuses Baku eats: the ordinary sleep and the circle's sleep with no countdown.
Dreamers.SLEEPS = { "status_sleep", "status_dormant" }

Dreamers.CLOUD_RADIUS = 1  -- "every body beside it"
Dreamers.FEED_RADIUS = 3   -- "within 3"
Dreamers.FEED_HEAL = 0.1   -- "a tenth of its health" for each
Dreamers.ROOT_WALL = "roots"
-- A Root laid at the END of a turn has to outlast the time before that body's next one, or it is a badge that
-- wears off unseen. Two turns' worth of ticks; status_root's own 6 is sized for a Root laid mid-turn.
Dreamers.ROOT_HOLD = 10

local function asleep(u)
    local Status = require("models.status")
    for _, id in ipairs(Dreamers.SLEEPS) do
        if Status.has(u, id) then return true end
    end
    return false
end
Dreamers.asleep = asleep

-- POPPY DUST: every living body beside `source` falls Asleep -- both sides, the moth's own cloud included. `onlyFoes`
-- narrows it to `source`'s foes (the Poppy Censer, which is a charm in a company's hand and not a moth).
function Dreamers.burst(combat, source, onlyFoes)
    local Combat = require("models.combat")
    local Status = require("models.status")
    Combat.spawnBurst(combat, source.x, source.y, { "magical" })
    local n = 0
    for _, u in ipairs(Combat.unitsNear(combat, source.x, source.y, Dreamers.CLOUD_RADIUS)) do
        if u ~= source and u.alive and (not onlyFoes or u.side ~= source.side) then
            if Status.apply(combat, u, "status_sleep", { applier = source }) then n = n + 1 end
        end
    end
    return n
end

-- DREAM-EATING: how many bodies within 3 of `unit`, on either side, are Asleep or Dormant. Never itself.
function Dreamers.sleepersNear(combat, unit)
    local Combat = require("models.combat")
    local n = 0
    for _, u in ipairs(Combat.unitsNear(combat, unit.x, unit.y, Dreamers.FEED_RADIUS)) do
        if u ~= unit and u.alive and asleep(u) then n = n + 1 end
    end
    return n
end

-- Feed: heal a tenth of its health per sleeper and wear exactly that many stacks of Dream-Fed (+2 damage each),
-- read fresh every turn. Waking the sleepers starves it on the very next turn. Returns the count.
function Dreamers.feed(combat, unit)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local n = Dreamers.sleepersNear(combat, unit)
    Status.remove(combat, unit, "status_dream_fed")
    if n <= 0 then return 0 end
    local max = Combat.unreservedMax(unit.char, "health")
    Combat.applyHeal(combat, unit, math.max(1, math.floor(max * Dreamers.FEED_HEAL)) * n)
    local cap = Status.defs["status_dream_fed"].stacks or n
    Status.apply(combat, unit, "status_dream_fed", { applier = unit, magnitude = math.min(n, cap) })
    Combat.logEvent(combat, "status", string.format("%s feeds on %d dreamer%s.",
        (unit.char and unit.char.name) or "It", n, n == 1 and "" or "s"), unit)
    return n
end

-- ---------------------------------------------------------------- roots

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

-- Can a root rise on (x, y)? Walkable ground, inside the board, with no body and no standing object on it.
local function open(combat, x, y)
    local Combat = require("models.combat")
    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if not (cell and cell.walkable) then return false end
    if Combat.unitAt(combat, x, y) or Combat.objectAt(combat, x, y) then return false end
    return true
end

-- The nearest living foe of `owner` to (x, y), as a Manhattan gap; math.huge on a board with none.
local function foeGap(combat, owner, x, y)
    local Combat = require("models.combat")
    local best = math.huge
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= owner.side and not Combat.isOffTile(u) then
            local d = Combat.cellGap(x, y, u)
            if d < best then best = d end
        end
    end
    return best
end

-- The roots a body has grown so far (walls stamped `rootOf`), still standing.
function Dreamers.rootsOf(combat, owner)
    local out = {}
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and w.rootOf == owner then out[#out + 1] = w end
    end
    return out
end

-- Raise ONE root for `owner` on an open tile orthogonally beside any of `cells`, the one nearest the owner's
-- nearest foe (ties to the top-left, so a board replays). Returns the wall, or nil when there is no room.
function Dreamers.growRoot(combat, owner, cells)
    local best, bestGap
    for _, c in ipairs(cells) do
        for _, d in ipairs(DIRS) do
            local x, y = c.x + d[1], c.y + d[2]
            if open(combat, x, y) then
                local gap = foeGap(combat, owner, x, y)
                if not best or gap < bestGap or (gap == bestGap and (y < best.y or (y == best.y and x < best.x))) then
                    best, bestGap = { x = x, y = y }, gap
                end
            end
        end
    end
    if not best then return nil end
    local Wall = require("models.wall")
    local wall = Wall.place(combat, best.x, best.y, Dreamers.ROOT_WALL, { side = owner.side })
    if wall then
        wall.rootOf = owner
        require("models.combat").logEvent(combat, "trap", string.format("A root rises beside %s.",
            (owner.char and owner.char.name) or "it"))
    end
    return wall
end

-- WILL NOT BE HURRIED: the Spruce's roots spread one tile, outward from the tree or any root it has already grown.
function Dreamers.spreadRoots(combat, tree)
    local cells = { { x = tree.x, y = tree.y } }
    for _, w in ipairs(Dreamers.rootsOf(combat, tree)) do cells[#cells + 1] = { x = w.x, y = w.y } end
    return Dreamers.growRoot(combat, tree, cells)
end

-- A body that ended its turn beside the tree is Rooted (either side; never the tree itself).
function Dreamers.rootBeside(combat, tree, actor)
    if not (actor and actor.alive and actor ~= tree) then return nil end
    local Combat = require("models.combat")
    if Combat.unitGap(tree, actor) ~= 1 then return nil end
    return require("models.status").apply(combat, actor, "status_root",
        { applier = tree, duration = Dreamers.ROOT_HOLD })
end

return Dreamers
