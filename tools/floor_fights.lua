-- Floor fight ledger: run with
--
--     & "E:\LOVE\lovec.exe" . floor-fights [n] [prowl=N] [deep=N]
--
-- HOW MANY FIGHTS A FLOOR CROSSING COSTS, measured by walking it. The ordinary fight is not seated on a
-- descent floor -- it is dealt off the prowl meter as the company walks (Descent.PROWL_STEPS) -- so a
-- floor's fight count is a property of the ROUTE, and no constant in models/descent.lua can state it.
-- `. board-report` counts what the generator seated and cannot see the walk; this walks it.
--
-- For each floor 1..15, `n` boards (default 12) are rolled exactly as states/game.lua rolls them -- the
-- floor's own descriptor, its reweighted pool, every feature key -- from a nil player, so the ends are
-- the stair alone (a companion posting or an errand adds one more on the floor that carries it). Each
-- board is then walked two ways, with the real meter (Descent.stepProwl / calmProwl) ticking per tile:
--
--   tour     greedy nearest-unvisited over every stop and cache, the stair last. The figure the
--            FLOOR_FIGHTS header has always quoted: a company that empties the floor before going down.
--   direct   the shortest walk from the way in to the stair, fighting only the stair. The floor's floor.
--
-- Fights counted: the stair, every seated elite (tour only), every mimic (tour only -- a sprung chest is
-- a fight), and whatever the meter deals. A camp's fire (Descent.lightFire) is optional and is NOT in the
-- total; it is printed beside it. Seeds are sequential from a fixed base, so two runs agree exactly.

local Descent = require("models.descent")
local Overworld = require("models.overworld")

local M = {}

local SEED_BASE = 20261024

local function key(c) return c.y * 100000 + c.x end

-- One rolled floor, as the game rolls it. Returns the grid.
local function rollFloor(floor, i)
    local run = Descent.new(nil, SEED_BASE + i * 31 + floor)
    run.floor = floor
    local dq = Descent.floorQuest(run)
    local mp = dq.map
    local pool = Descent.floorPool({ biome = mp.biome, prestige = 10, quest = dq, depth = floor })
    local params = {
        biome = mp.biome,
        cols = mp.cols, rows = mp.rows,
        encounterCount = mp.encounters,
        encounters = pool,
        houseMaterial = "material_salt_iron",
        cacheCount = mp.cacheCount,
        combatShare = mp.combatShare,
        combatBudget = mp.combatBudget,
        eliteShare = mp.eliteShare,
        guaranteeKinds = mp.guaranteeKinds,
        guarantee = mp.guarantee,
        exitAtStart = mp.exitAtStart,
        secrets = mp.secrets,
        ascent = mp.ascent,
        keyCount = 0,
        objective = mp.objective,
        objectives = mp.objectives,
        seed = require("models.seed").mix(run.seed, floor),
    }
    Descent.applyFloorFeatures(params, mp)
    return Overworld.generate(params), run
end

-- Walk `legs` (a list of { steps, fight }) with a fresh meter; returns { prowl, seated }.
local function walk(run, legs)
    run.prowl, run.leg, run.stairBeaten = 0, 0, nil
    local prowl, seated = 0, 0
    for _, leg in ipairs(legs) do
        for _ = 1, leg.steps do
            if Descent.stepProwl(run) then
                prowl = prowl + 1
                Descent.calmProwl(run)
            end
        end
        if leg.fight then
            seated = seated + 1
            Descent.calmProwl(run)
        end
    end
    return prowl, seated
end

local function measure(grid, run)
    local start = grid:startCell()
    local stair
    if grid.objective then stair = grid.cells[grid.objective.y][grid.objective.x] end
    local targets, camps = {}, 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            if c ~= start and c ~= stair and (e or c.cache) then targets[#targets + 1] = c end
            if e and e.kind == "rest" then camps = camps + 1 end
        end
    end

    -- THE TOUR. Nearest unvisited first; anything the walk cannot reach (behind a lock) is skipped.
    local legs, steps, elites, mimics = {}, 0, 0, 0
    local at, left = start, {}
    for _, c in ipairs(targets) do left[#left + 1] = c end
    while #left > 0 do
        local dist = grid:bfsDistances(at)
        local best, bestD
        for j, c in ipairs(left) do
            local d = dist[key(c)]
            if d and (not bestD or d < bestD) then best, bestD = j, d end
        end
        if not best then break end
        local c = table.remove(left, best)
        local e = c.encounter
        local fight = e and (e.kind == "elite" or e.mimic or (e.kind == "combat")) or false
        if e and e.kind == "elite" then elites = elites + 1 end
        if e and e.mimic then mimics = mimics + 1 end
        legs[#legs + 1] = { steps = bestD, fight = fight }
        steps = steps + bestD
        at = c
    end
    local toStair = stair and grid:bfsDistances(at)[key(stair)] or 0
    legs[#legs + 1] = { steps = toStair, fight = true }
    steps = steps + toStair
    local tProwl, tSeated = walk(run, legs)

    -- THE DIRECT CROSSING.
    local direct = stair and grid:bfsDistances(start)[key(stair)] or 0
    local dProwl, dSeated = walk(run, { { steps = direct, fight = true } })

    return {
        tourSteps = steps, tourProwl = tProwl, tourSeated = tSeated,
        elites = elites, mimics = mimics, camps = camps,
        directSteps = direct, directProwl = dProwl, directSeated = dSeated,
    }
end

function M.run(args)
    args = args or {}
    local n = tonumber(args[1]) or 12
    for _, a in ipairs(args) do
        local p = tostring(a):match("^prowl=(%d+)$"); if p then Descent.PROWL_STEPS = tonumber(p) end
        local d = tostring(a):match("^deep=(%d+)$"); if d then Descent.PROWL_STEPS_DEEP = tonumber(d) end
    end
    print(string.format("FLOOR FIGHTS -- %d rolled floors per depth, prowl %d-%d steps (jitter %d)",
        n, Descent.prowlSteps(1), Descent.prowlSteps(Descent.FLOORS), Descent.PROWL_JITTER))
    print("")
    print(string.format("  %5s %6s %6s %6s %6s %6s %7s | %6s %6s %6s | %5s",
        "floor", "steps", "prowl", "elite", "mimic", "stair", "TOUR", "steps", "prowl", "DIRECT", "camp"))
    local all = { tour = 0, direct = 0 }
    local bands = { { 1, 5, 0, 0 }, { 6, 10, 0, 0 }, { 11, 15, 0, 0 } }
    for floor = 1, Descent.FLOORS do
        local s = { tourSteps = 0, tourProwl = 0, tourSeated = 0, elites = 0, mimics = 0, camps = 0,
                    directSteps = 0, directProwl = 0, directSeated = 0 }
        for i = 1, n do
            local grid, run = rollFloor(floor, i)
            local r = measure(grid, run)
            for k, v in pairs(r) do s[k] = s[k] + v end
        end
        local function per(v) return v / n end
        local tour = per(s.tourProwl + s.tourSeated)
        local direct = per(s.directProwl + s.directSeated)
        all.tour, all.direct = all.tour + tour, all.direct + direct
        for _, b in ipairs(bands) do
            if floor >= b[1] and floor <= b[2] then b[3], b[4] = b[3] + tour, b[4] + direct end
        end
        print(string.format("  %5d %6.1f %6.2f %6.2f %6.2f %6.2f %7.2f | %6.1f %6.2f %6.2f | %5.2f",
            floor, per(s.tourSteps), per(s.tourProwl), per(s.elites), per(s.mimics), 1,
            tour, per(s.directSteps), per(s.directProwl), direct, per(s.camps)))
    end
    print("")
    for _, b in ipairs(bands) do
        local k = b[2] - b[1] + 1
        print(string.format("  floors %2d-%2d   tour %5.2f a floor   direct %5.2f a floor",
            b[1], b[2], b[3] / k, b[4] / k))
    end
    print(string.format("  the run       tour %5.1f fights      direct %5.1f fights", all.tour, all.direct))
end

return M
