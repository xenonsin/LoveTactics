-- Cover ledger: run with
--
--     & "E:\LOVE\lovec.exe" . terrain-report [n] [move=N] [biome=ID]
--
-- Rolls `n` battle boards per biome and reports HOW MUCH COVER A COMPANY CAN ACTUALLY GET TO ON ITS
-- FIRST TURN. It exists because the question "is there enough cover" cannot be answered from the
-- generator's constants, and answering it from them is exactly how the hole this tool was written to
-- find got there in the first place.
--
-- WHAT THE CONSTANTS SAY: Arena.generateLayout scatters a fill (2-5 tiles), a rise (1-3) and a blocker
-- (1-3) onto a neutral middle band. Read off that, every biome looks the same and a board looks well
-- supplied. WHAT THE BOARDS SAID, the first time anybody rolled them: only the FILL is ever cover, and
-- it was cover in two biomes out of eight -- a desert filled with sand and a tundra with ice, neither
-- worth a point of anybody's aim, leaving 1-3 hills on 64 squares as the entire positional decision on
-- those boards. Pride's circle and Greed's were not in the palette table at all and rolled woodland.
--
-- THE COLUMN THAT MATTERS IS `reach`, NOT `cover`. A count of cover tiles on a board is a supply
-- figure, and supply is not the thing the player experiences: what they experience is whether stepping
-- into cover was an option on the turn they wanted it. Those two come apart whenever the blocker
-- scatter walls a wood off, or the fill lands in the far corner, or the entry edge is wrong -- and the
-- fix for a supply problem (scatter more) is not the fix for a seating problem (scatter it nearer),
-- so one number cannot tell them apart. Same lesson tools/board_report.lua learned twice, and the
-- same rule from docs/roadmap.md: do not hand-derive a count, roll the boards and read what they say.
--
-- Reachability is measured rather than read, which is the other half of it -- the same clause
-- docs/drops.md keeps for its own pool. The walk is a real Dijkstra over the tiles' own move costs from
-- the company's spawn block, not a radius, so a forest behind a mountain correctly does not count.
--
-- WHAT IS COUNTED, and why these:
--
--     cover     walkable tiles worth a POSITIVE avoid. The supply.
--     reach     how many of those a body with `move` points can get to from a party spawn. The take.
--     none      the share of boards on which the answer is ZERO -- a board with no positional decision
--               on it at all. This is the headline number and the one a re-tune should be read against.
--     best      the median, across boards, of the best avoid a company could reach on turn one. A
--               board whose only reachable cover is a mire reads NEGATIVE here, which is the honest
--               answer and not a bug.
--     exposed   walkable tiles worth a negative avoid (the mire). Ground the player must be able to
--               see and route around, reported so a biome cannot quietly become all bog.
--
-- Read-only: it drives Arena directly and touches no save. Seeds are sequential from a fixed base, so
-- two runs of this tool agree exactly.

local Arena = require("models.arena")
local Terrain = require("models.terrain")

local M = {}

local SEED_BASE = 20260918
local DEFAULT_N = 200
-- The band a real body walks in. Base movement is 4 (see models/ai.lua's STANDOFF note, which cites the
-- raise); a first turn spends the whole budget and nothing else, which is the turn this tool is about.
local DEFAULT_MOVE = 4
-- The eight ids Arena.BIOME_TERRAIN answers for, in the order a reader wants them: the wilderness
-- first, then the two that were missing entirely, then the bowl that is bare on purpose.
local BIOMES = { "default", "desert", "tundra", "volcanic", "swamp", "castle", "underworld", "colosseum" }

local function key(x, y) return x .. "," .. y end

-- What the ground at `t` is worth to whoever stands on it, and whether they can stand there at all.
local function avoidOf(t)
    local def = Terrain.get(t)
    if not def.walkable then return nil end
    return (def.bonus and def.bonus.avoid) or 0
end

-- Every tile a body with `budget` move points can END its turn on, starting from any of `spawns`.
-- A plain Dijkstra over Terrain move costs -- the same currency Combat.reachable spends -- rather than
-- a Manhattan radius, because the whole point of the column it feeds is that a wood behind a mountain
-- is not cover you can get to. Enemies are not placed for this: the company moves first on its own
-- turn, and a tile another body happens to be standing on is a seating question, not a terrain one.
local function reachable(layout, spawns, budget)
    local dist, frontier = {}, {}
    for _, s in ipairs(spawns) do
        local k = key(s.x, s.y)
        if not dist[k] then
            dist[k] = 0
            frontier[#frontier + 1] = { x = s.x, y = s.y, d = 0 }
        end
    end
    -- Dial-style: budgets are tiny (a handful of points over a 3-cost worst tile), so a plain repeated
    -- sweep of the frontier is both correct and faster than standing up a heap for eight rows.
    while #frontier > 0 do
        local next_ = {}
        for _, node in ipairs(frontier) do
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = node.x + d[1], node.y + d[2]
                if nx >= 1 and ny >= 1 and nx <= layout.cols and ny <= layout.rows then
                    local t = layout.tiles[ny] and layout.tiles[ny][nx]
                    local def = t and Terrain.get(t)
                    if def and def.walkable then
                        local cost = node.d + def.moveCost
                        local k = key(nx, ny)
                        if cost <= budget and (dist[k] == nil or cost < dist[k]) then
                            dist[k] = cost
                            next_[#next_ + 1] = { x = nx, y = ny, d = cost }
                        end
                    end
                end
            end
        end
        frontier = next_
    end
    return dist
end

-- One board's worth of counts.
local function measure(layout, budget)
    local r = { cover = 0, exposed = 0, reach = 0, best = nil }
    local within = reachable(layout, layout.partySpawns or {}, budget)
    for y = 1, layout.rows do
        for x = 1, layout.cols do
            local avoid = avoidOf(layout.tiles[y] and layout.tiles[y][x])
            if avoid then
                if avoid > 0 then r.cover = r.cover + 1
                elseif avoid < 0 then r.exposed = r.exposed + 1 end
                if within[key(x, y)] then
                    if avoid > 0 then r.reach = r.reach + 1 end
                    -- The best ground on offer, INCLUDING the bad kind: a board whose only reachable
                    -- tile with any character at all is a bog should report the bog, not report zero
                    -- and read as ordinary open field.
                    if avoid ~= 0 and (r.best == nil or avoid > r.best) then r.best = avoid end
                end
            end
        end
    end
    r.best = r.best or 0
    return r
end

local function median(list)
    if #list == 0 then return 0 end
    table.sort(list)
    local mid = math.floor(#list / 2)
    if #list % 2 == 1 then return list[mid + 1] end
    return (list[mid] + list[mid + 1]) / 2
end

function M.run(args)
    local n, budget, only = DEFAULT_N, DEFAULT_MOVE, nil
    for _, a in ipairs(args or {}) do
        local num = tonumber(a)
        local move = tostring(a):match("^move=(%d+)$")
        local biome = tostring(a):match("^biome=(.+)$")
        if move then budget = tonumber(move)
        elseif biome then only = biome
        elseif num then n = math.floor(num) end
    end

    print(string.format("Cover on a rolled board -- %d boards per biome, %d move points, %dx%d",
        n, budget, Arena.COLS, Arena.ROWS))
    print("")
    print(string.format("%-11s %7s %7s %7s %7s %7s", "biome", "cover", "reach", "none", "best", "exposed"))
    print(string.rep("-", 51))

    local worst = {}
    for _, biome in ipairs(BIOMES) do
        if not only or only == biome then
            local cover, reach, exposed, none, bests = 0, 0, 0, 0, {}
            for i = 1, n do
                -- Four party, four enemies: the company the descent fields (docs/the-count.md) against
                -- a plain opposing line, so the spawn block this measures reach from is the real one.
                local layout = Arena.generateLayout({
                    biome = biome, seed = SEED_BASE + i, party = 4, enemies = 4,
                })
                local r = measure(layout, budget)
                cover = cover + r.cover
                reach = reach + r.reach
                exposed = exposed + r.exposed
                if r.reach == 0 then none = none + 1 end
                bests[#bests + 1] = r.best
            end
            local pct = none / n * 100
            print(string.format("%-11s %7.1f %7.1f %6.0f%% %7.0f %7.1f",
                biome, cover / n, reach / n, pct, median(bests), exposed / n))
            worst[#worst + 1] = { biome = biome, pct = pct, supply = cover / n,
                                  take = cover > 0 and (reach / cover) or 0 }
        end
    end

    print("")
    -- THE READING, spelled out rather than left to the reader, because the whole purpose of the tool is
    -- that the raw columns were being mis-read: a healthy `cover` beside a dead `reach` is a SEATING
    -- problem and wants the scatter moved, not enlarged.
    -- A BARE BIOME IS NOT A FAILING BIOME, and the verdict has to be able to tell them apart or it
    -- reads out the colosseum every time and buries the one line worth having. The distinction is the
    -- SUPPLY column: a biome with no cover on the board at all was authored that way (the arena floor
    -- is swept on purpose -- Arena.BIOME_TERRAIN), while a biome carrying cover that a company cannot
    -- get to has a seating problem, and those want opposite fixes.
    local bare, seated = {}, {}
    for _, b in ipairs(worst) do
        if b.supply < 0.5 then bare[#bare + 1] = b.biome else seated[#seated + 1] = b end
    end
    table.sort(seated, function(a, b) return a.pct > b.pct end)
    local top = seated[1]
    if top then
        -- WHICH OF THE TWO PROBLEMS IT IS, decided by the TAKE -- the share of a board's cover a
        -- company can actually reach -- rather than by `none` alone. A biome can post a bad `none`
        -- two entirely different ways, and reading the wrong one sends the fix to the wrong knob:
        --
        --   * its cover is walled off or lands too far from the entry edge, and the take collapses
        --     while the supply looks fine -- SEATING, and a wider scatter makes it no better;
        --   * it simply has less cover than everybody else and takes its ordinary share of it --
        --     SUPPLY, and moving the band buys nothing.
        --
        -- The peer median is what tells them apart, and it has to be a peer comparison: there is no
        -- absolute take that is "right", only a biome getting a worse deal than the others do.
        local takes = {}
        for _, b in ipairs(seated) do takes[#takes + 1] = b.take end
        local peerTake = median(takes)
        print(string.format("Worst seated biome: %s -- no reachable cover on %.0f%% of boards.",
            top.biome, top.pct))
        print(string.format("It seats %.0f%% of its own cover (peer median %.0f%%).",
            top.take * 100, peerTake * 100))
        if top.take < peerTake * 0.7 then
            print("A take well under its peers is a SEATING problem: the cover is on the board and")
            print("the company cannot get to it. Move the scatter band toward the entry edge -- a")
            print("bigger count fixes the wrong half of this.")
        elseif top.pct >= 35 then
            print("It takes its ordinary share, so this is a SUPPLY problem: that biome simply grows")
            print("less cover than the rest. Widen its scatter, or give its fill a cover tile.")
        else
            print("A company that has to spend a turn reaching cover is making a decision, not going")
            print("without one. Re-tune the scatter counts only if this climbs past ~35%.")
        end
    end
    if #bare > 0 then
        print(string.format("Bare by design (no cover in the palette at all): %s.",
            table.concat(bare, ", ")))
        print("Any biome here that was NOT meant to be bare is the bug this tool exists to find.")
    end
end

return M
