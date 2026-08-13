-- PATROLS: the fights that walk.
--
-- An encounter used to be a field on a cell -- placed at generation and still exactly there an hour
-- later. Once the fog was lifted the whole board was solved, and executing the route was holding a
-- direction. A patrol is the same fight with a beat under it, and three things fall out of that:
--
--   * the fog is worth having, because what you can see is a SCHEDULE rather than a map;
--   * the walk is priced, because every step you take is a step something else takes (P1);
--   * how you handled the approach becomes a tactical input to the battle, because the side a patrol
--     touches you on is the side it deploys from (P10, Arena.fromGrid).
--
-- ONE PLAYER STEP IS ONE PATROL STEP. Not `dt`. It keeps the board a thing you can stand still and read,
-- it keeps a run reproducible enough to spec and to resume, and it means "the map locks during combat"
-- needs no code at all: nothing here moves except on your step, and during a fight you are not stepping.
--
-- A PATROL IS AN ACTOR, NOT A PROPERTY OF A CELL. The fight travels on the patrol; `cell.encounter`
-- keeps only what genuinely does not move. Rewriting cell.encounter onto a new cell each tick is the
-- wrong shape -- `cleared`, `seen` and `guards` are all keyed by cell, so a moving fight would smear its
-- state across the board and a cleared one would come back the moment something else stepped where it
-- had been.

local Patrol = {}

-- The three states a patrol is ever in.
--   beat    walking its circuit
--   alert   has seen the party, closing on them
--   return_ lost them, walking back to the beat
--
-- `return_` and not `return`, which is a Lua keyword; the UI says "Return".
Patrol.BEAT, Patrol.ALERT, Patrol.RETURN = "beat", "alert", "return_"

-- A PATROL IS NEVER FASTER THAN THE PARTY. This one cap is what keeps the board's whole contract
-- intact: a company that keeps walking away cannot be caught in open corridor, so the only place a
-- patrol can corner you is a dead end you chose to enter. The fight is still the price of the spur,
-- which is what guardBoons has always been about.
--
-- Rank buys REACH, not speed. An elite sees further and follows longer; an ordinary road fight moves
-- every second step and is dodgeable in a corridor. Pace is a divisor on the tick, so 1 is every step
-- and 2 is every other -- never below 1.
Patrol.PACE_ORDINARY, Patrol.PACE_ELITE = 2, 1
Patrol.SIGHT_ORDINARY, Patrol.SIGHT_ELITE = 4, 6
Patrol.LEASH_ORDINARY, Patrol.LEASH_ELITE = 6, 10

-- Build a patrol standing on `cell`, walking `beat`. `beat` is a list of {x,y} the generator produced;
-- `guards` is the boon this patrol is standing in front of, if any (see Overworld:guardBoons).
function Patrol.new(cell, beat, opts)
    opts = opts or {}
    local elite = opts.kind == "elite"
    return {
        encounter = cell.encounter,
        x = cell.x, y = cell.y,
        beat = beat or { { x = cell.x, y = cell.y } },
        i = 1, dir = 1, tick = 0,
        state = Patrol.BEAT,
        alert = 0,
        home = { x = cell.x, y = cell.y },
        guards = opts.guards,
        pace = opts.pace or (elite and Patrol.PACE_ELITE or Patrol.PACE_ORDINARY),
        sight = opts.sight or (elite and Patrol.SIGHT_ELITE or Patrol.SIGHT_ORDINARY),
        leash = opts.leash or (elite and Patrol.LEASH_ELITE or Patrol.LEASH_ORDINARY),
        cleared = false,
    }
end

-- Can `p` see (tx, ty)? Straight lines only, within `sight`, with nothing solid between.
--
-- Deliberately not a radius: a patrol two tiles away round a corner has not seen you, and a corridor is
-- exactly where sight SHOULD carry. It also makes the rule legible from the map -- if you can trace a
-- clear line to it, it can trace one to you.
function Patrol.sees(p, grid, tx, ty)
    if p.x ~= tx and p.y ~= ty then return false end
    local d = math.abs(p.x - tx) + math.abs(p.y - ty)
    if d == 0 or d > p.sight then return false end
    local sx = (tx > p.x and 1) or (tx < p.x and -1) or 0
    local sy = (ty > p.y and 1) or (ty < p.y and -1) or 0
    local x, y = p.x + sx, p.y + sy
    while x ~= tx or y ~= ty do
        if not grid:typeWalkable((grid:get(x, y) or {}).tile) then return false end
        x, y = x + sx, y + sy
    end
    return true
end

-- One step of `p` toward (tx, ty), by breadth-first distance so it rounds corners rather than pressing
-- into walls. Returns nil when there is no route (a gated board can produce one).
local function stepToward(grid, p, tx, ty)
    local dist = grid:bfsDistances(grid:get(tx, ty))
    local here = dist[ty * 100000 + tx] and dist[(p.y) * 100000 + p.x]
    if not here then return nil end
    local best, bestD
    for _, n in ipairs(grid:pathNeighbors(p.x, p.y)) do
        local d = dist[n.y * 100000 + n.x]
        if d and d < here and (not bestD or d < bestD) then best, bestD = n, d end
    end
    return best
end

-- ADVANCE EVERY PATROL ONE TICK, because the party took a step. `party` is {x, y}; `onContact` is
-- called with the patrol that reached the party, and stops the pass -- the map locks, so nothing else
-- moves this tick either.
--
-- Sight is checked EVERY tick regardless of pace: a slow patrol still notices you when you walk past
-- its nose, it is simply slower to do anything about it.
function Patrol.tick(grid, party, onContact)
    for _, p in ipairs(grid.patrols or {}) do
        if not p.cleared then
            p.tick = p.tick + 1
            if Patrol.sees(p, grid, party.x, party.y) then
                p.state, p.alert = Patrol.ALERT, p.leash
            end
            if p.tick % p.pace == 0 then
                local nx, ny = Patrol.nextTile(grid, p, party)
                -- Contact from its side. The party stepping onto IT is handled at the walking seam,
                -- which is the same event told from the other end.
                -- Remember where it came FROM before it moves. That tile is the side it deploys on when
                -- it catches the party (P10, Arena.fromGrid): caught from behind, it stands between the
                -- company and the way out.
                p.prevX, p.prevY = p.x, p.y
                if nx == party.x and ny == party.y then
                    if onContact then onContact(p) end
                    return p
                end
                p.x, p.y = nx, ny
            end
        end
    end
end

-- Where `p` would stand after this tick, without moving it. Also drives the telegraph: the UI draws
-- this tile so the exchange is legible before the player commits their own step (P7).
function Patrol.nextTile(grid, p, party)
    if p.state == Patrol.ALERT then
        p.alert = p.alert - 1
        if p.alert <= 0 then p.state = Patrol.RETURN end
        local s = party and stepToward(grid, p, party.x, party.y)
        if s then return s.x, s.y end
        return p.x, p.y
    end

    if p.state == Patrol.RETURN then
        local home = p.beat[p.i] or p.home
        if p.x == home.x and p.y == home.y then
            p.state = Patrol.BEAT
        else
            local s = stepToward(grid, p, home.x, home.y)
            if s then return s.x, s.y end
        end
        return p.x, p.y
    end

    -- Beat: walk the circuit, reversing at each end. A beat of one tile is a sentry and never moves,
    -- which is what a guard on a single-tile cut set is (P5).
    if #p.beat < 2 then return p.x, p.y end
    local i = p.i + p.dir
    if i > #p.beat then i, p.dir = #p.beat - 1, -1 end
    if i < 1 then i, p.dir = 2, 1 end
    p.i = i
    local t = p.beat[i]
    return t.x, t.y
end

-- The tile a patrol will occupy next, for the telegraph -- WITHOUT advancing it. `nextTile` mutates
-- (it is the step), so the preview walks a shallow copy: an intent preview must never move the board,
-- which is the same rule the enemy-intent telegraph in battle already follows.
function Patrol.preview(grid, p, party)
    if p.cleared then return nil end
    if (p.tick + 1) % p.pace ~= 0 then return p.x, p.y end
    local copy = { x = p.x, y = p.y, beat = p.beat, i = p.i, dir = p.dir,
                   state = p.state, alert = p.alert, home = p.home,
                   sight = p.sight, leash = p.leash, pace = p.pace }
    return Patrol.nextTile(grid, copy, party)
end

-- The patrol standing on (x, y), if any is left standing.
function Patrol.at(grid, x, y)
    for _, p in ipairs(grid.patrols or {}) do
        if not p.cleared and p.x == x and p.y == y then return p end
    end
    return nil
end

return Patrol
