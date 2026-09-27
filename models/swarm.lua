-- THE THOUSAND-WINGED: eight familiars and no body (Wrath's vampires, round 3, "The Vampires of Wrath"; an elite
-- on Wrath's approach, data/encounters/encounter_wrath_the_thousand_winged.lua). The rules the fight is made of:
--
--   GATHERING   the swarm's bats (character_swarm_familiar, trait_the_swarm) fly to each other. A bat standing in
--               a group of 3 or more wears Gathering, with the group's size on the badge -- the board's telegraph
--               of which bats are about to fuse (status_gathering).
--   FUSION      at the end of ANY turn in which 4 or more of them stand next to each other (orthogonally, the
--               board's own adjacency, Combat.unitGap == 1), the whole group fuses into the Thousand-Winged
--               (character_thousand_winged): a vampire, with the Thirst, whose bite Bleeds, and whose health is
--               12 x the bats in it (12 at the blueprint's scale, grown with the bats' level: Swarm.perBat). It
--               stands on the tile of the bat at the group's heart.
--   SCATTER     strike it to 0 and it comes apart (trait_scatter): HALF the bats in it (rounded down) fly out
--               again, the healthiest first, each with the health it had when it went in; the rest are dead.
--               Survivors are Scattered for a turn (status_scattered) and cannot fuse until it lapses.
--
-- WHERE THE BATS GO WHILE FUSED. They are not killed and not removed: they stay in combat.units, alive, so a
-- `killAll` never resolves while the lord still carries them. They are taken OFF THEIR TILES through the seam a
-- swallowed body already stands on (`swallowedBy` -- Combat.isOffTile, which every tile query, the planner and the
-- renderer already pass over), their position read through the lord's, and out of the TURN ORDER through the one
-- a banner stands on (`timeless` -- Combat.inTimeline). Nothing new had to learn either state.
--
-- Pure logic, no love.graphics. Combat, Status, Trait, Character and Growth are required lazily: combat.lua reaches
-- this module through the traits that fire inside its turn-end and death paths.
local Swarm = {}

Swarm.FUSE_AT = 4          -- bats standing together at a turn's end that fuse
Swarm.WARN_AT = 3          -- ...and the group size at which the board starts to show it
Swarm.HEALTH_PER_BAT = 12  -- the lord's health, per bat in it
Swarm.LORD = "character_thousand_winged"
Swarm.GATHERING = "status_gathering"
Swarm.SCATTERED = "status_scattered"
Swarm.FORM_REACH = 6       -- Swarm Form's flight (ability_swarm_form)

local POS = { x = true, y = true }

-- Is `u` one of the swarm's bats (the `swarms` flag, trait_the_swarm)?
function Swarm.isBat(u)
    return u ~= nil and require("models.trait").flag(u, "swarms") ~= nil
end

-- Is `u` a free bat: alive, on its own tile, and not inside a lord?
local function free(u)
    return u.alive and not u.fusedInto and not require("models.combat").isOffTile(u) and Swarm.isBat(u)
end

-- The free bats of `side`, in board order. `ready` leaves out the Scattered.
local function batsOf(combat, side, ready)
    local Status = require("models.status")
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if free(u) and u.side == side and not (ready and Status.has(u, Swarm.SCATTERED)) then
            out[#out + 1] = u
        end
    end
    return out
end

-- The connected groups among `bats` (standing next to each other, chained), each in board order.
function Swarm.groups(bats)
    local Combat = require("models.combat")
    local seen, out = {}, {}
    for _, b in ipairs(bats) do
        if not seen[b] then
            local group, queue = {}, { b }
            seen[b] = true
            while #queue > 0 do
                local cur = table.remove(queue, 1)
                group[#group + 1] = cur
                for _, o in ipairs(bats) do
                    if not seen[o] and Combat.unitGap(cur, o) == 1 then
                        seen[o] = true
                        queue[#queue + 1] = o
                    end
                end
            end
            table.sort(group, function(a, c) return a.index < c.index end)
            out[#out + 1] = group
        end
    end
    return out
end

-- The sides that field a swarm, so one turn end checks each once.
local function swarmSides(combat)
    local sides, order = {}, {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if free(u) and not sides[u.side] then sides[u.side] = true; order[#order + 1] = u.side end
    end
    return order
end

-- Take `bat` off its tile and out of the turn order. `holder` is the lord it is inside -- or, for the beat between
-- the tile being freed and the lord standing on it, a stand-in holding the heart's tile, so nothing that measures
-- a gap to every living body in that beat reads a bat with no position.
local function takeIn(bat, holder)
    bat.swallowedBy = holder
    rawset(bat, "fusedInto", holder)
    bat.timeless = true
    for k in pairs(POS) do rawset(bat, k, nil) end
    setmetatable(bat, {
        __index = function(t, k)
            if POS[k] then
                local lord = rawget(t, "fusedInto")
                return lord and lord[k]
            end
        end,
        __newindex = function(t, k, v) if not POS[k] then rawset(t, k, v) end end,
    })
end

-- Put `bat` back on the board at (x, y), in the turn order at its own natural initiative.
local function letOut(combat, bat, x, y)
    local Combat = require("models.combat")
    setmetatable(bat, nil)
    bat.swallowedBy, bat.timeless, bat.fusedInto = nil, nil, nil
    rawset(bat, "x", x)
    rawset(bat, "y", y)
    bat.initiative = math.max(0, Combat.initiative(bat.char))
    Combat.stampField(combat, bat)
end

-- The bat at a group's heart: the one nearest all the others (board order breaks a tie).
local function heartOf(group)
    local Combat = require("models.combat")
    local best, bestSum
    for _, b in ipairs(group) do
        local sum = 0
        for _, o in ipairs(group) do sum = sum + Combat.unitGap(b, o) end
        if not bestSum or sum < bestSum then best, bestSum = b, sum end
    end
    return best
end

-- THE LORD'S HEALTH PER BAT IN IT: 12 -- the review's number, written against the Familiar's blueprint of 14 --
-- grown by the same factor the bat's own health has grown with its level. A floor-7 bat stands at level ~22 on
-- ~98 health, and a flat 12 there would make four bats worth 392 into a lord worth 48: fusing would be a gift.
-- Scaled, the lord keeps the ratio the author set (12 of every 14), on every floor.
function Swarm.perBat(bat)
    local def = bat and bat.char and require("models.character").defs[bat.char.id]
    local base = def and def.stats and def.stats.health
    local grown = bat and bat.char and bat.char.stats.health.max
    if not (base and base > 0 and grown) then return Swarm.HEALTH_PER_BAT end
    return math.max(Swarm.HEALTH_PER_BAT, math.floor(Swarm.HEALTH_PER_BAT * grown / base + 0.5))
end

-- FUSE `group` into the Thousand-Winged. Returns the lord.
function Swarm.fuse(combat, group)
    local Combat = require("models.combat")
    local Character = require("models.character")
    local heart = heartOf(group)
    local x, y, side = heart.x, heart.y, heart.side
    local level = 1
    for _, b in ipairs(group) do
        level = math.max(level, (b.char and b.char.level) or 1)
        require("models.status").remove(combat, b, Swarm.GATHERING)
        takeIn(b, { x = x, y = y })
    end
    local char = Character.instantiate(Swarm.LORD)
    require("models.growth").resolve(char, level)
    local health = Swarm.perBat(heart) * #group
    char.stats.health.max, char.stats.health.current = health, health
    local lord = Combat.addUnit(combat, char, side, x, y, {})
    lord.swarm = {}
    for _, b in ipairs(group) do
        b.swallowedBy = lord
        rawset(b, "fusedInto", lord)
        lord.swarm[#lord.swarm + 1] = b
    end
    Combat.logEvent(combat, "action", string.format("%d familiars fuse into %s.", #group, char.name or "a lord"),
        lord)
    Combat.enterTile(combat, lord, x, y)
    return lord
end

-- REFRESH THE TELEGRAPH for `side`: every ready bat in a group of WARN_AT or more wears Gathering, with the
-- group's size as its count; every other bat wears none.
function Swarm.mark(combat, side)
    local Status = require("models.status")
    local marked = {}
    for _, group in ipairs(Swarm.groups(batsOf(combat, side, true))) do
        if #group >= Swarm.WARN_AT then
            for _, b in ipairs(group) do
                local st = Status.get(b, Swarm.GATHERING) or Status.apply(combat, b, Swarm.GATHERING)
                if st then st.magnitude = #group end
                marked[b] = true
            end
        end
    end
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.side == side and not marked[u] and Status.has(u, Swarm.GATHERING) then
            Status.remove(combat, u, Swarm.GATHERING)
        end
    end
end

-- THE END OF A TURN (trait_the_swarm, on every bat): every group of FUSE_AT or more ready bats fuses, then the
-- telegraph is redrawn. Safe to call any number of times in one turn end -- a fused bat is off the board.
function Swarm.turnEnd(combat)
    if not combat then return end
    for _, side in ipairs(swarmSides(combat)) do
        for _, group in ipairs(Swarm.groups(batsOf(combat, side, true))) do
            if #group >= Swarm.FUSE_AT then Swarm.fuse(combat, group) end
        end
        Swarm.mark(combat, side)
    end
end

-- How many of `n` fused bats fly out of a scatter.
function Swarm.survivorsOf(n)
    return math.floor((n or 0) / 2)
end

-- THE LORD FALLS (trait_scatter's onDeath): half the bats in it fly out, healthiest first, and are Scattered;
-- the rest die where it stood. It leaves no corpse -- there was never a body, only bats.
function Swarm.scatter(combat, lord)
    if not (combat and lord and lord.swarm) then return end
    local Combat = require("models.combat")
    local Status = require("models.status")
    local x, y = lord.x, lord.y
    local inside = {}
    for _, b in ipairs(lord.swarm) do
        if b.alive and b.fusedInto == lord then inside[#inside + 1] = b end
    end
    lord.swarm = nil
    lord.corpse = false
    table.sort(inside, function(a, b)
        local ha, hb = a.char.stats.health.current, b.char.stats.health.current
        if ha ~= hb then return ha > hb end
        return a.index < b.index
    end)
    local keep = Swarm.survivorsOf(#inside)
    local out, lost = {}, {}
    for i, b in ipairs(inside) do
        if i <= keep then out[#out + 1] = b else lost[#lost + 1] = b end
    end
    local landed = 0
    for _, b in ipairs(out) do
        local lx, ly
        if Combat.footprintFree(combat, 1, 1, x, y, b) then lx, ly = x, y
        else lx, ly = Combat.openBlockNear(combat, x, y, 1, 1, { radius = 4 }) end
        if lx then
            letOut(combat, b, lx, ly)
            Status.apply(combat, b, Swarm.SCATTERED)
            Combat.enterTile(combat, b, lx, ly)
            landed = landed + 1
        else
            lost[#lost + 1] = b -- hemmed in on every side: nowhere to fly out to
        end
    end
    Combat.logEvent(combat, "action", string.format("%s scatters: %d bat%s fly out, %d fall.",
        (lord.char and lord.char.name) or "It", landed, landed == 1 and "" or "s", #lost), lord)
    for _, b in ipairs(lost) do
        letOut(combat, b, x, y)
        Combat.fell(combat, b)
        b.corpse, b.incapacitated = false, false
        Status.remove(combat, b, "status_downed")
    end
    Swarm.mark(combat, lord.side)
end

-- ------------------------------------------------------------------------------------------------ the planner

-- WHERE A BAT FLIES (AI.POSTURES.gather, for a body carrying `swarms`): to the biggest group of its kin that is
-- bigger than its own -- a tie goes to the group standing first on the board -- and it holds where it is when its
-- own group is the one the others are coming to. Returns (goal, hold).
function Swarm.gatherGoal(combat, unit)
    local Combat = require("models.combat")
    local groups = Swarm.groups(batsOf(combat, unit.side, false))
    local mine
    for _, g in ipairs(groups) do
        for _, b in ipairs(g) do if b == unit then mine = g end end
    end
    if not mine then return nil, false end
    local best
    for _, g in ipairs(groups) do
        if g ~= mine then
            if not best or #g > #best or (#g == #best and g[1].index < best[1].index) then best = g end
        end
    end
    if best and (#best > #mine or (#best == #mine and best[1].index < mine[1].index)) then
        local goal, d
        for _, b in ipairs(best) do
            local gap = Combat.unitGap(unit, b)
            if not d or gap < d then goal, d = b, gap end
        end
        return goal, false
    end
    -- Its own group is where the others are coming. Alone and with nobody to come, it goes for the fight.
    if #mine > 1 or best then return nil, true end
    return nil, false
end

-- ------------------------------------------------------------------------------------------------ swarm form

-- Ground a flight of bats may cross or come down on: on the board, standable, and not under a wall or a prop.
-- Bodies are not asked about -- the bats go straight through them.
local function ground(combat, x, y)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    return cell ~= nil and cell.walkable and not require("models.combat").objectBlocksAt(combat, x, y)
end

-- SWARM FORM's flight (ability_swarm_form): the route from `unit` to (tx, ty), at most `reach` steps over open
-- ground, through bodies. Of the shortest routes it takes the one over the MOST foes of `unit` -- the bats go
-- where the blood is -- with a fixed step order breaking any tie, so the painted route is the route flown.
-- Returns the cells after the start (the landing included), or nil when no such route exists.
function Swarm.formPath(combat, unit, tx, ty, reach)
    if not (combat and combat.arena and unit and unit.x) then return nil end
    reach = reach or Swarm.FORM_REACH
    if not ground(combat, tx, ty) then return nil end
    local Combat = require("models.combat")
    local STEPS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
    local function key(x, y) return x .. "," .. y end
    local function foeAt(x, y)
        local u = Combat.unitAt(combat, x, y)
        return (u and u ~= unit and u.alive and u.side ~= unit.side) and 1 or 0
    end
    local dist, score, parent = { [key(unit.x, unit.y)] = 0 }, { [key(unit.x, unit.y)] = 0 }, {}
    local frontier = { { x = unit.x, y = unit.y } }
    for d = 1, reach do
        local nextFrontier, seenNext = {}, {}
        for _, c in ipairs(frontier) do
            for _, s in ipairs(STEPS) do
                local nx, ny = c.x + s[1], c.y + s[2]
                local k = key(nx, ny)
                if (dist[k] == nil or dist[k] == d) and ground(combat, nx, ny) then
                    local sc = score[key(c.x, c.y)] + foeAt(nx, ny)
                    if dist[k] == nil then
                        dist[k], score[k], parent[k] = d, sc, c
                        if not seenNext[k] then
                            seenNext[k] = true
                            nextFrontier[#nextFrontier + 1] = { x = nx, y = ny }
                        end
                    elseif sc > score[k] then
                        score[k], parent[k] = sc, c
                    end
                end
            end
        end
        frontier = nextFrontier
        if dist[key(tx, ty)] then break end
    end
    if not dist[key(tx, ty)] or (tx == unit.x and ty == unit.y) then return nil end
    local path, c = {}, { x = tx, y = ty }
    while c and not (c.x == unit.x and c.y == unit.y) do
        table.insert(path, 1, { x = c.x, y = c.y })
        c = parent[key(c.x, c.y)]
    end
    return path
end

return Swarm
