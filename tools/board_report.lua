-- Board ledger: run with
--
--     & "E:\LOVE\lovec.exe" . board-report [n] [tiers]
--
-- Rolls `n` overworld boards (default 200) with the campaign's own default map params and reports
-- WHAT THE GENERATOR ACTUALLY LAID DOWN. It exists because every knob that shapes a run's offer --
-- `cacheTarget`, `combatShare`, `GUARDED_BOON_SHARE`, `GUARANTEE.rest` -- is a fraction of a fraction,
-- and the composition they produce together is not readable from any one of them.
--
-- That is not a hypothetical failure. docs/overworld.md's guarded-boon knob was carried for a whole
-- pass as "roughly two and a half boons per fight", a figure derived by multiplying the constants; the
-- boards say something else, because a boon is only guardable when a fight can actually be seated on a
-- cut vertex beside it, and no constant knows how many of those a braided maze has. THE RULE IS THE
-- SAME ONE docs/roadmap.md STATES: do not hand-derive a count, roll the boards and read what they say.
--
-- WHAT IS COUNTED, and why these:
--
--     fights      combat + elite. The cost side of every offer on the board.
--     boons       cache tiles + treasure/relic_cache stops -- exactly Overworld's GUARDABLE_KINDS plus
--                 the cache tile property. The payout side. A shrine is NOT a boon (it sells, it does
--                 not give) and neither is a rest or a merchant: those are services, and the guard rule
--                 deliberately never stands a fight in front of one.
--     guarded     boons that ended up behind a fight. The ratio of this to `boons` is the only honest
--                 read on whether the pairing pass can do its job.
--     rest        the run's one refund. Reported per board AND per fight, because what matters is how
--                 much attrition a camp is being asked to hand back, not how many camps there are.
--     tier arc    mean encounter tier by fifth of the board, walked by BFS distance from the start.
--                 A generator that means to escalate should show a rising column here; a flat column
--                 means the ramp is being swamped by its own noise term.
--
-- Read-only, and it drives Overworld directly rather than a game state, so no save is touched. Seeds
-- are sequential from a fixed base, so two runs of this tool agree exactly.

local Overworld = require("models.overworld")
local Encounter = require("models.encounter")

local M = {}

-- The campaign's default board, lifted from states/game.lua's `enter`. Kept in one place here so a
-- change to the real defaults shows up as a diff in this file rather than as a silently stale report.
local DEFAULT_ENCOUNTERS = { min = 8, max = 11 }
local DEFAULT_DAY = 20 -- mid-campaign: past every encounter's minDay gate, so the pool is full
local SEED_BASE = 20260811

local FIGHT = { combat = true, elite = true }
local BOON_KINDS = { treasure = true, relic_cache = true }

-- WHAT THE FIGHTABILITY LEDGER COUNTS, which is deliberately NOT the same set as `FIGHT`. An objective
-- is not a fight for the COMPOSITION census -- it is the day's work, not a stop the pool dealt -- but it
-- is absolutely a fight for the question "is there room to have it", and it is the one fight on the
-- board the player cannot decline.
--
-- It was outside this set for as long as the set existed, and that is how a floor's guardian came to be
-- fought in a dead-end corridor with nobody noticing: placeObjectiveAndGates picks the deepest STRICT
-- dead end (a spur is what makes an end gateable), the seat floor was never asked about it, and the
-- ledger that would have said so was reading combat and elite only. Every figure in this block moved
-- when `objective` was added to it, which is the report agreeing that it had been measuring the easy
-- half of the board.
local SEATED = { combat = true, elite = true, objective = true }

-- WHAT COUNTS AS A PLACE A FIGHT COULD BE SEATED, for the `sites` count only. Deliberately above
-- Overworld.BOX_OK: BOX_OK is the floor a seat must CLEAR, while a *site* is somewhere a fight would be
-- good rather than merely legal, and the gap between the two is what tells a cramped board from a
-- comfortable one. Report-only, so it lives here rather than on the model. Declared with the other
-- constants and not beside the pass that reads it: a local declared further down would be invisible to
-- `measure` and resolve to a nil global instead, which compiles and loads and only fails on the board
-- where the branch is finally taken.
local SITE_SCORE = 44

-- Is a patrol standing here? Walked rather than indexed: a board holds a handful of them, and a lookup
-- table would have to be rebuilt every time one moves.
local function patrolAt(grid, x, y)
    for _, p in ipairs(grid.patrols or {}) do
        if not p.cleared and p.x == x and p.y == y then return p end
    end
    return nil
end

-- One board's worth of counts. Walks every cell once; the tier arc needs a BFS, which Overworld
-- already exposes for its own placement passes.
local function measure(grid)
    local r = {
        fights = 0, boons = 0, guarded = 0, rest = 0, stops = 0,
        caches = 0, services = 0, tierSum = 0, tierN = 0,
        craftStock = 0, houseStock = 0,
        byKind = {},
        depthTierSum = { 0, 0, 0, 0, 0 },
        depthTierN = { 0, 0, 0, 0, 0 },
    }

    local dist = grid:bfsDistances(grid:startCell())
    local maxD = 1
    for _, d in pairs(dist) do if d > maxD then maxD = d end end

    -- WHY a boon went unguarded. `guardBoons` gives up on a boon for one of two entirely different
    -- reasons and reports neither, which is what let the knob be mis-diagnosed as a supply problem:
    --   no approach  -- no neighbour of the boon is a cut vertex, so nothing CAN gate it. Geometry.
    --   no fight     -- there was an approach but no loose fight left to move onto it. Supply.
    -- Recomputed here rather than exported from the generator: this is a diagnostic, and threading a
    -- reason code through a placement pass to serve a report would be the report leaking into the model.
    r.deadEnds, r.cacheOnDeadEnd, r.boonsWithApproach = 0, 0, 0
    -- ENDS THE BOARD COULD NOT SEAT ON A SPUR. A day buys a whole ground now and every piece of work
    -- posted there wants its own dead end (models/overworld.lua). When the board runs out, the extra
    -- end takes the farthest open tile instead -- which still WORKS, and still reads as one place with
    -- two doors rather than two places. Counted rather than left silent because a board that keeps
    -- doing it is a board whose sizing rule has stopped keeping up with what a ground can hold.
    r.crowdedEnds = grid.crowdedEnds or 0
    r.ends = grid.objectives and #grid.objectives or (grid.objective and 1 or 0)
    local function reachableWithout(goal, blocked)
        local start = grid:startCell()
        if not start or start == goal then return true end
        local seen, q, qi = { [start.y * 100000 + start.x] = true }, { start }, 1
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, nb in ipairs(grid:pathNeighbors(c.x, c.y)) do
                if nb == goal then return true end
                local k = nb.y * 100000 + nb.x
                if not seen[k] and nb ~= blocked then seen[k] = true; q[#q + 1] = nb end
            end
        end
        return false
    end

    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local leaf = grid:typeWalkable(c.tile) and #grid:pathNeighbors(x, y) == 1
            if leaf then r.deadEnds = r.deadEnds + 1 end
            local isBoon = c.cache or (c.encounter and BOON_KINDS[c.encounter.kind])
            if isBoon then
                for _, nb in ipairs(grid:pathNeighbors(x, y)) do
                    if not grid.spineKeys[nb.y * 100000 + nb.x] and not nb.cache
                        and not reachableWithout(c, nb) then
                        r.boonsWithApproach = r.boonsWithApproach + 1
                        break
                    end
                end
            end
            if c.cache then
                r.caches = r.caches + 1; r.boons = r.boons + 1
                if leaf then r.cacheOnDeadEnd = r.cacheOnDeadEnd + 1 end
                -- What the board actually pays in forging stock. Counted by walking the placed caches
                -- rather than derived from cacheTarget, because the payload is scaled per tile by the
                -- detour it cost AND bumped again if the tile ended up guarded -- so the constant that
                -- looks responsible for material income is never the one that sets it.
                for mat, qty in pairs(c.cache.materials or {}) do
                    if mat == "material_salt_iron" then
                        r.houseStock = (r.houseStock or 0) + qty
                    else
                        r.craftStock = (r.craftStock or 0) + qty
                    end
                end
            end
            local e = c.encounter
            if e then
                r.stops = r.stops + 1
                r.byKind[e.kind] = (r.byKind[e.kind] or 0) + 1
                if FIGHT[e.kind] then
                    r.fights = r.fights + 1
                    if e.tier then
                        r.tierSum = r.tierSum + e.tier
                        r.tierN = r.tierN + 1
                        -- Fifth of the board by distance from the start. maxD is the far corner rather
                        -- than the objective (which sits at ~80% of it by design), so the last fifth is
                        -- genuinely the deep end and not merely "past the boss".
                        local d = dist[y * 100000 + x] or 0
                        local b = math.max(1, math.min(5, math.floor(d / maxD * 5) + 1))
                        r.depthTierSum[b] = r.depthTierSum[b] + e.tier
                        r.depthTierN[b] = r.depthTierN[b] + 1
                    end
                elseif BOON_KINDS[e.kind] then
                    r.boons = r.boons + 1
                elseif e.kind == "rest" then
                    r.rest = r.rest + 1
                    r.services = r.services + 1
                elseif e.kind ~= "objective" then
                    r.services = r.services + 1
                end
                if c.guards then r.guarded = r.guarded + 1 end
            end
        end
    end

    -- THE FIGHTS THAT WALK. A patrol carries its encounter off the cell (Overworld:placePatrols), so a
    -- census that only reads `cell.encounter` stops seeing most of the board's combat -- measured at 1.85
    -- fights a board against 4.25, which is not a change in the board, it is a change in the instrument.
    -- Counted here at wherever the patrol currently stands, which is where a report on a freshly rolled
    -- board means: its beat has not run yet.
    r.patrols, r.beatSum = 0, 0
    for _, p in ipairs(grid.patrols or {}) do
        if not p.cleared then
            local e = p.encounter or {}
            r.stops = r.stops + 1
            r.fights = r.fights + 1
            r.patrols = r.patrols + 1
            r.beatSum = r.beatSum + #(p.beat or {})
            r.byKind[e.kind] = (r.byKind[e.kind] or 0) + 1
            if p.guards then r.guarded = r.guarded + 1 end
            if e.tier then
                r.tierSum = r.tierSum + e.tier
                r.tierN = r.tierN + 1
                local d = dist[p.y * 100000 + p.x] or 0
                local b = math.max(1, math.min(5, math.floor(d / maxD * 5) + 1))
                r.depthTierSum[b] = r.depthTierSum[b] + e.tier
                r.depthTierN[b] = r.depthTierN[b] + 1
            end
        end
    end

    -- ---------------------------------------------------------------------
    -- FIGHTABILITY: can a battle actually happen here?
    -- ---------------------------------------------------------------------
    --
    -- A fight is taken on THIS MAP -- the board locks an 8x8 window of these tiles and walls its ring
    -- (Overworld.BOX) -- so "is there room to fight" becomes a property of the generator, and a silent
    -- one. A layout can be connected, well-braided, correctly gated and completely unable to host a
    -- battle, and nothing but this figure will say so. It is measured here first precisely because it
    -- is the number most likely to be assumed rather than read.
    --
    --   fightable  share of trail standing in a window with at least BOX_OK tiles it can cross to
    --   seat score what the fights ACTUALLY got: mean, worst, and how many were seated under the floor
    --   open       ...and the same seats measured for SHAPE, against BOX_OPEN
    --   sites      distinct non-overlapping windows good enough to be a board, which is the number the
    --              board's fight count has to fit inside
    local sums = grid:walkableSums()
    -- ...and the same window measured for SHAPE rather than for space (Overworld.isOpen). A warren and a
    -- chamber score alike on the first and nothing alike on the second.
    local openSums = grid:openSums()
    r.walkTiles, r.fightTiles = 0, 0
    r.seatSum, r.seatN, r.seatMin, r.seatBelow = 0, 0, math.huge, 0
    r.openSum, r.openMin, r.openBelow = 0, math.huge, 0
    -- THE END, MEASURED ON ITS OWN. The mean over every seat hides the one seat that is not optional:
    -- a board can seat its five loose fights in clearings and still put the objective in a defile, and
    -- the average will read fine. So the mandatory fight is counted twice -- once in the ledger with
    -- everything else, once here by itself.
    r.endSeatSum, r.endOpenSum, r.endN, r.endBelow = 0, 0, 0, 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if grid:typeWalkable(c.tile) then
                r.walkTiles = r.walkTiles + 1
                local ox, oy, score = grid:bestBox(x, y, sums)
                local open = openSums(ox, oy)
                if score >= Overworld.BOX_OK and open >= Overworld.BOX_OPEN then
                    r.fightTiles = r.fightTiles + 1
                end
                -- A tile holds a fight if a stop was seated on it OR a patrol is standing on it: the
                -- fightability floor governs both, and a beat that walks its fight onto ground too thin
                -- to fight on is the same failure as seating one there.
                local fightHere = (c.encounter and SEATED[c.encounter.kind]) or patrolAt(grid, x, y)
                if fightHere then
                    r.seatSum, r.seatN = r.seatSum + score, r.seatN + 1
                    r.openSum = r.openSum + open
                    if score < r.seatMin then r.seatMin = score end
                    if open < r.openMin then r.openMin = open end
                    if score < Overworld.BOX_OK then r.seatBelow = r.seatBelow + 1 end
                    if open < Overworld.BOX_OPEN then r.openBelow = r.openBelow + 1 end
                end
                if c.encounter and c.encounter.kind == "objective" then
                    r.endSeatSum, r.endOpenSum = r.endSeatSum + score, r.endOpenSum + open
                    r.endN = r.endN + 1
                    if score < Overworld.BOX_OK or open < Overworld.BOX_OPEN then
                        r.endBelow = r.endBelow + 1
                    end
                end
            end
        end
    end
    if r.seatMin == math.huge then r.seatMin = 0 end
    if r.openMin == math.huge then r.openMin = 0 end

    -- Greedy, highest-scoring first, suppressing anything that overlaps one already taken. Walked in a
    -- fixed order with ties broken by position so the count reproduces from the seed like everything
    -- else here.
    local cands = {}
    for y = 1, grid.rows - Overworld.BOX + 1 do
        for x = 1, grid.cols - Overworld.BOX + 1 do
            local s = sums(x, y)
            if s >= SITE_SCORE then cands[#cands + 1] = { s, x, y } end
        end
    end
    table.sort(cands, function(a, b)
        if a[1] ~= b[1] then return a[1] > b[1] end
        if a[3] ~= b[3] then return a[3] < b[3] end
        return a[2] < b[2]
    end)
    local taken = {}
    r.sites = 0
    for _, c in ipairs(cands) do
        local clear = true
        for _, t in ipairs(taken) do
            if math.abs(t[1] - c[2]) < Overworld.BOX and math.abs(t[2] - c[3]) < Overworld.BOX then
                clear = false
                break
            end
        end
        if clear then
            taken[#taken + 1] = { c[2], c[3] }
            r.sites = r.sites + 1
        end
    end

    return r
end

-- THE POOL, IN A FIXED ORDER -- without which this whole tool is untrustworthy.
--
-- `Encounter.pool` builds its list with `pairs` over the registry, and `Overworld:pickEncounter` walks
-- that list to turn a random draw into an encounter. So the SEED fixes the number and the TABLE ORDER
-- fixes which entry the number lands on, and two runs of this report at the same seeds were quietly
-- disagreeing about where the fights went -- which moved every figure that depends on which tile got a
-- fight (seat scores, guarded share) while the pure-geometry ones stayed put.
--
-- That is a bad failure for an instrument whose entire justification is "do not hand-derive a count,
-- roll the boards and read what they say": a number that will not reproduce cannot be read. Sorting by
-- id fixes it here. It does NOT fix it for the game -- models/overworld.lua's own header notes the same
-- unspecified order is why a board cannot be regenerated from its seed on load, and the save serializes
-- every cell to work around it. Sorting inside Encounter.pool would close that too, and would change
-- which boards players get, so it is a decision rather than a cleanup.
function M.stablePool(day)
    local pool = Encounter.pool({ day = day })
    table.sort(pool, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return pool
end

-- EVERY GROUND, SIDE BY SIDE. One row per biome, holding only the columns that decide whether a layout
-- can carry a run at all -- fightability first, because it is the new contract and the one a beautiful
-- board can fail silently.
--
-- Rolls its own boards rather than sharing the full ledger's loop, deliberately: the ledger below prints
-- a dozen framings of one ground and this prints one framing of every ground, and folding them together
-- would make each harder to read than it is apart. The seeds are the same sequence, so a biome's row
-- here and its ledger below describe the same boards.
function M.compare(biomes, n, pool)
    print(string.format("BOARD REPORT -- %d boards per ground, %d-%d stops, day %d",
        n, DEFAULT_ENCOUNTERS.min, DEFAULT_ENCOUNTERS.max, DEFAULT_DAY))
    print("")
    print(string.format("  %-11s %9s %7s %6s %6s %6s %7s %7s %7s %8s",
        "ground", "fightable", "sites", "seat", "open", "ends", "worst", "under", "walk", "guarded"))
    print("  " .. string.rep("-", 86))
    -- A DAY'S GROUND, AS THE CAMPAIGN ACTUALLY ROLLS IT. Three pieces of work is the middle of the
    -- range a ground carries (models/quest.lua's Quest.trip), and it is what this has to measure --
    -- with one end the board is smaller and every fight has more room than it will really get. The
    -- specs are bare: nothing here fights them, they exist so three dead ends are asked for.
    local trip = { { name = "end 1" }, { name = "end 2" }, { name = "end 3" } }
    local crowded = 0
    for _, biome in ipairs(biomes) do
        local t = { walk = 0, fight = 0, sites = 0, seatSum = 0, seatN = 0, below = 0,
                    dead = 0, guarded = 0, boons = 0, cells = 0, openSum = 0,
                    endOpen = 0, endN = 0 }
        local worst = math.huge
        for i = 1, n do
            local grid = Overworld.generate({
                biome = biome,
                encounterCount = DEFAULT_ENCOUNTERS,
                encounters = pool,
                objectives = trip,
                houseMaterial = "material_salt_iron",
                patrols = true, -- the board as the campaign actually rolls it
            seed = SEED_BASE + i,
            })
            crowded = crowded + (grid.crowdedEnds or 0)
            local r = measure(grid)
            t.walk = t.walk + r.walkTiles
            t.cells = t.cells + grid.cols * grid.rows
            t.fight = t.fight + r.fightTiles
            t.sites = t.sites + r.sites
            t.seatSum, t.seatN = t.seatSum + r.seatSum, t.seatN + r.seatN
            -- Either floor missed is a seat under the floor. Space and shape are both requirements, so
            -- reporting only the first would keep hiding exactly what it hid before.
            t.below = t.below + math.max(r.seatBelow, r.openBelow)
            t.openSum = t.openSum + r.openSum
            t.endOpen, t.endN = t.endOpen + r.endOpenSum, t.endN + r.endN
            t.dead = t.dead + r.deadEnds
            t.guarded, t.boons = t.guarded + r.guarded, t.boons + r.boons
            if r.seatN > 0 and r.openMin < worst then worst = r.openMin end
        end
        if worst == math.huge then worst = 0 end
        local function ratio(a, b) return b > 0 and (a / b) or 0 end
        print(string.format("  %-11s %8.1f%% %7.1f %6.1f %6.1f %6.1f %7d %7.1f %6.1f%% %7.1f%%",
            biome,
            100 * ratio(t.fight, t.walk),
            t.sites / n,
            ratio(t.seatSum, t.seatN),
            ratio(t.openSum, t.seatN),
            ratio(t.endOpen, t.endN),
            worst,
            t.below / n,
            100 * ratio(t.walk, t.cells),
            100 * ratio(t.guarded, t.boons)))
    end
    print("")
    -- SAID OUT LOUD RATHER THAN LEFT IN THE ARITHMETIC. Every board above was asked for three ends;
    -- this is how often one of them could not be given a spur of its own and took open trail instead.
    -- A rising number here is the sizing rule falling behind what a ground can hold.
    if crowded > 0 then
        print(string.format("  NOTE  %d of %d ends had no dead end left and took open trail (%.1f%%)",
            crowded, #biomes * n * #trip, 100 * crowded / (#biomes * n * #trip)))
        print("")
    end
    print(string.format("  fightable  share of trail in an %dx%d window holding >= %d crossable and >= %d open",
        Overworld.BOX, Overworld.BOX, Overworld.BOX_OK, Overworld.BOX_OPEN))
    print(string.format("  sites      distinct non-overlapping windows scoring >= %d -- places a fight could go",
        SITE_SCORE))
    print(string.format("  seat       mean box score the fights were ACTUALLY seated on, of %d",
        Overworld.BOX * Overworld.BOX))
    print("  open       ...and how much of that was OPEN ground (a full 3x3 of trail around it).")
    print("             This is the column that matters: space is not shape. A warren scores well on")
    print("             `seat` and zero on `open` -- room for four bodies, no room for a decision.")
    print("  ends       the same open figure for the OBJECTIVES alone -- the one fight nobody may skip,")
    print("             seated on a strict dead end by rule, and therefore the seat most likely to be a")
    print("             defile. A board can seat its loose fights well and still fail here.")
    print(string.format("  under      fights a board seated below either floor (%d crossable, %d open)"
        .. " -- these must reach 0", Overworld.BOX_OK, Overworld.BOX_OPEN))
end

function M.run(args)
    args = args or {}
    local n = tonumber(args[1]) or 200
    local wantTiers, braid, cacheDiv, combatWeight = false, nil, nil, nil
    local wantContracts, wantXp, wantDescent = false, false, false
    local descentFloor = 1
    -- Which ground(s). `all` walks every blueprint in data/biomes; `biome=x` reports one; the bare
    -- default stays forest, so every figure recorded in docs/overworld.md still reproduces exactly.
    local biome, wantAll = "forest", false
    local perBoard = {} -- one row per board, for the distribution questions a mean cannot answer
    for _, a in ipairs(args) do
        if a == "tiers" then wantTiers = true end
        if a == "contracts" then wantContracts = true end
        if a == "xp" then wantXp = true end
        if a == "all" then wantAll = true end
        local bi = tostring(a):match("^biome=(%w+)$"); if bi then biome = bi end
        -- Override knobs for a tuning sweep, so a candidate value is measured before it is committed to
        -- the model: `. board-report 200 braid=0.25 cachediv=3`.
        local b = tostring(a):match("^braid=([%d%.]+)$"); if b then braid = tonumber(b) end
        local d = tostring(a):match("^cachediv=([%d%.]+)$"); if d then cacheDiv = tonumber(d) end
        local w = tostring(a):match("^cw=([%d%.]+)$"); if w then combatWeight = tonumber(w) end
        -- `descent` measures a FLOOR rather than a campaign ground: the dungeon carve at its own
        -- spacing, the floor's stop count and cache pins, its reweighted pool and its guarantees.
        -- Without this the instrument could only ever report on the half of the game that is parked.
        if a == "descent" then wantDescent = true end
        -- WHICH floor, because a floor's board is no longer one size: it widens a tile a floor
        -- (Descent.floorDims), so "a descent floor" is a question that needs a depth to answer. Defaults
        -- to the first, so every figure recorded against the bare `descent` still reproduces.
        local f = tostring(a):match("^floor=(%d+)$"); if f then descentFloor = tonumber(f) end
    end

    local pool = M.stablePool(DEFAULT_DAY)
    -- Sweep the ordinary-fight weights without editing four blueprints per candidate value. The pool is
    -- meant to be fight-heavy so that Overworld's combat-share CAP is what decides the mix; when it is
    -- not, the cap stops binding and the guarantee pass's non-combat stops set the ratio by accident.
    if combatWeight then
        for _, e in ipairs(pool) do
            if e.kind == "combat" then e.weight = e.weight * combatWeight end
        end
    end

    if wantAll then
        local Biome = require("models.biome")
        local ids = {}
        for id in pairs(Biome.defs) do ids[#ids + 1] = id end
        table.sort(ids) -- `pairs` over the registry is unspecified; the table has to reproduce
        M.compare(ids, n, pool)
        return
    end

    local tot = {
        fights = 0, boons = 0, guarded = 0, rest = 0, stops = 0, caches = 0, services = 0,
        tierSum = 0, tierN = 0, walkTiles = 0, fightTiles = 0, sites = 0,
        seatSum = 0, seatN = 0, seatBelow = 0, seatMin = math.huge,
        openSum = 0, openBelow = 0, openMin = math.huge,
        endSeatSum = 0, endOpenSum = 0, endN = 0, endBelow = 0,
        depthTierSum = { 0, 0, 0, 0, 0 }, depthTierN = { 0, 0, 0, 0, 0 },
        byKind = {},
    }

    -- A DESCENT FLOOR, measured as the mode actually rolls one. Everything that makes a floor different
    -- from a ground comes off models/descent.lua rather than being restated here, so a retune there is
    -- measured here without an edit.
    local Descent = wantDescent and require("models.descent") or nil
    local drun = Descent and Descent.new(nil, 909) or nil
    if drun then drun.floor = descentFloor end
    local dq = Descent and Descent.floorQuest(drun) or nil
    if wantDescent then
        biome = dq.map.biome
        pool = Descent.floorPool({ biome = biome, day = DEFAULT_DAY, prestige = 10 })
    end

    for i = 1, n do
        local encN = DEFAULT_ENCOUNTERS
        local params = {
            biome = biome,
            encounterCount = encN,
            encounters = pool,
            houseMaterial = "material_salt_iron",
            braid = braid,
            -- Mirrors Overworld.generate's own derivation so a sweep can try a different divisor
            -- without editing the model. nil leaves the model's own rule in charge.
            cacheCount = cacheDiv and math.max(1, math.floor(((encN.min + encN.max) / 2) / cacheDiv)) or nil,
            patrols = true, -- the board as the campaign actually rolls it
            seed = SEED_BASE + i,
        }
        if wantDescent then
            local mp = dq.map
            encN = mp.encounters
            params.cols, params.rows = mp.cols, mp.rows
            params.layout, params.spacing = mp.carve, mp.spacing
            params.encounterCount = encN
            params.cacheCount = cacheDiv
                and math.max(1, math.floor(((encN.min + encN.max) / 2) / cacheDiv)) or mp.cacheCount
            params.combatShare = mp.combatShare
            params.guaranteeKinds = mp.guaranteeKinds
            params.guarantee = mp.guarantee
            params.ascent, params.keyCount = true, 0
            params.secrets, params.exitAtStart = mp.secrets, mp.exitAtStart
            params.guardBoons = mp.guardBoons
            params.objective = mp.objective
        end
        local grid = Overworld.generate(params)
        local r = measure(grid)
        for _, k in ipairs({ "fights", "boons", "guarded", "rest", "stops", "caches", "services",
                             "tierSum", "tierN", "deadEnds", "cacheOnDeadEnd", "boonsWithApproach",
                             "craftStock", "houseStock",
                             "walkTiles", "fightTiles", "sites", "seatSum", "seatN", "seatBelow",
                             "openSum", "openBelow",
                             "endSeatSum", "endOpenSum", "endN", "endBelow",
                             "patrols", "beatSum" }) do
            tot[k] = (tot[k] or 0) + r[k]
        end
        if r.seatN > 0 and r.seatMin < tot.seatMin then tot.seatMin = r.seatMin end
        if r.seatN > 0 and r.openMin < tot.openMin then tot.openMin = r.openMin end
        for b = 1, 5 do
            tot.depthTierSum[b] = tot.depthTierSum[b] + r.depthTierSum[b]
            tot.depthTierN[b] = tot.depthTierN[b] + r.depthTierN[b]
        end
        for k, v in pairs(r.byKind) do tot.byKind[k] = (tot.byKind[k] or 0) + v end
        perBoard[#perBoard + 1] = {
            guarded = r.guarded, caches = r.caches, fights = r.fights,
            relicCache = r.byKind.relic_cache or 0,
            treasure = r.byKind.treasure or 0,
            crossroads = r.byKind.crossroads or 0,
        }
    end

    local function per(v) return v / n end
    local function ratio(a, b) return b > 0 and (a / b) or 0 end

    local stopSpec = wantDescent and dq.map.encounters or DEFAULT_ENCOUNTERS
    print(string.format("BOARD REPORT -- %d rolled %s, %s, %d-%d stops, day %d",
        n, wantDescent and ("floor " .. descentFloor .. "s, " .. dq.map.cols .. "x" .. dq.map.rows)
            or "boards", biome,
        stopSpec.min, stopSpec.max, DEFAULT_DAY))
    print("")
    print(string.format("  %-22s %8s  %s", "", "per board", "note"))
    print(string.format("  %-22s %8.2f", "stops", per(tot.stops)))
    print(string.format("  %-22s %8.2f", "fights", per(tot.fights)))
    print(string.format("  %-22s %8.2f  %s", "boons", per(tot.boons),
        string.format("%.2f caches + %.2f finds", per(tot.caches), per(tot.boons - tot.caches))))
    print(string.format("  %-22s %8.2f", "services", per(tot.services)))
    print(string.format("  %-22s %8.2f  %s", "rest", per(tot.rest),
        string.format("one per %.1f fights", ratio(tot.fights, tot.rest))))
    print("")
    -- NOT a target. The ratio was the first suspect for the guarded-boon shortfall and it was the wrong
    -- one: forcing it to 1.0 by cutting caches lowered material income by a third AND lowered the
    -- absolute number of guarded boons, because it removed boons rather than adding pairings. Kept as
    -- context for the two rows under it, which are the ones that mean something.
    print(string.format("  %-22s %8.2f  %s", "boons per fight", ratio(tot.boons, tot.fights),
        "context only -- see `boons gateable` for the real ceiling"))
    print(string.format("  %-22s %8.1f%%  %s", "boons guarded", 100 * ratio(tot.guarded, tot.boons),
        string.format("%.2f of %.2f per board", per(tot.guarded), per(tot.boons))))
    print(string.format("  %-22s %8.1f%%  %s", "fights on guard", 100 * ratio(tot.guarded, tot.fights),
        "the rest stand in the open"))
    print("")
    print("  why a boon goes unguarded -- geometry or supply:")
    print(string.format("    %-20s %8.2f  %s", "dead ends", per(tot.deadEnds),
        string.format("%.2f of %.2f caches sit on one", per(tot.cacheOnDeadEnd), per(tot.caches))))
    print(string.format("    %-20s %8.1f%%  %s", "boons gateable", 100 * ratio(tot.boonsWithApproach, tot.boons),
        "have a neighbour that is a real cut vertex"))
    print(string.format("    %-20s %8.2f  %s", "loose fights", per(tot.fights - tot.guarded),
        "available to move onto an approach"))
    print("")
    -- CAN A BATTLE HAPPEN HERE. Printed above the economy rows because it now gates them: a board whose
    -- fights are seated on ground too thin to fight on pays nothing, whatever the cache maths says.
    print("")
    print(string.format("  can a fight happen here -- an %dx%d window of these tiles:",
        Overworld.BOX, Overworld.BOX))
    print(string.format("    %-20s %8.1f%%  %s", "fightable trail",
        100 * ratio(tot.fightTiles, tot.walkTiles),
        string.format("of %.0f walkable tiles a board", per(tot.walkTiles))))
    print(string.format("    %-20s %8.2f  %s", "arena sites", per(tot.sites),
        string.format("against %.2f fights to seat", per(tot.fights))))
    print(string.format("    %-20s %8.1f  %s", "mean seat score", ratio(tot.seatSum, tot.seatN),
        string.format("of %d; worst seen %d", Overworld.BOX * Overworld.BOX,
            tot.seatMin == math.huge and 0 or tot.seatMin)))
    print(string.format("    %-20s %8.1f  %s", "mean open ground", ratio(tot.openSum, tot.seatN),
        string.format("of %d; worst seen %d -- space is not shape",
            Overworld.BOX * Overworld.BOX, tot.openMin == math.huge and 0 or tot.openMin)))
    print(string.format("    %-20s %8.1f  %s", "the end's own seat", ratio(tot.endOpenSum, tot.endN),
        string.format("open ground at the %.2f objectives a board -- the fight nobody may skip",
            per(tot.endN))))
    print(string.format("    %-20s %8.2f  %s", "seated under floor", per(tot.seatBelow),
        string.format("fights a board below %d crossable -- must reach 0", Overworld.BOX_OK)))
    print(string.format("    %-20s %8.2f  %s", "seated under shape", per(tot.openBelow),
        string.format("...and below %d open -- must reach 0 (%.2f of them are ends)",
            Overworld.BOX_OPEN, per(tot.endBelow))))
    print(string.format("    %-20s %8.2f  %s", "patrols", per(tot.patrols),
        string.format("of %.2f fights, mean beat %.1f tiles", per(tot.fights),
            tot.patrols > 0 and (tot.beatSum / tot.patrols) or 0)))
    print("")
    print(string.format("  %-22s %8.2f  %s", "cache craft stock", per(tot.craftStock),
        "material income -- the thing a ratio change must not quietly gut"))
    print(string.format("  %-22s %8.2f", "cache house stock", per(tot.houseStock)))
    print("")
    print(string.format("  %-22s %8.2f", "mean fight tier", ratio(tot.tierSum, tot.tierN)))
    print("  tier by fifth of board (start -> far corner):")
    local bars = {}
    for b = 1, 5 do
        local m = ratio(tot.depthTierSum[b], tot.depthTierN[b])
        bars[#bars + 1] = string.format("%.2f", m)
    end
    print("    " .. table.concat(bars, "  -> "))

    -- CONTRACT SATISFIABILITY. A side contract is accepted BEFORE the board is rolled, so what matters
    -- is not the average board but the WORST one: a contract the player took and the board cannot
    -- possibly satisfy is a broken promise, and the mean says nothing about how often that happens.
    -- Each row is the share of boards carrying at least N of the thing a candidate condition counts.
    if wantContracts then
        print("")
        print("  contract satisfiability -- share of boards carrying at least N:")
        print(string.format("    %-16s %7s %7s %7s %7s", "", "N=1", "N=2", "N=3", "N=4"))
        local axes = {
            { "guarded fights", "guarded" },
            { "caches", "caches" },
            { "fights", "fights" },
            { "relic caches", "relicCache" },
            { "treasure", "treasure" },
            { "crossroads", "crossroads" },
        }
        for _, a in ipairs(axes) do
            local cells = {}
            for n = 1, 4 do
                local hit = 0
                for _, b in ipairs(perBoard) do if (b[a[2]] or 0) >= n then hit = hit + 1 end end
                cells[#cells + 1] = string.format("%6.1f%%", 100 * hit / #perBoard)
            end
            print(string.format("    %-16s %s", a[1], table.concat(cells, " ")))
        end
    end

    -- WHAT A DAY IS WORTH IN EXPERIENCE, measured by actually fighting the board rather than estimated
    -- from a guess about how often a body swings. It used to be what Experience.STEP was anchored on,
    -- back when the campaign kept a curve of its own; that curve is retired with the Quest Board and the
    -- one step left is anchored on the bottom of the descent (models/experience.lua). So this is a
    -- CROSS-CHECK now -- what a day of ordinary board fighting banks, read against the ladder the
    -- descent set -- and not the measurement the constant is derived from.
    --
    -- Resolves every combat/elite stop on a sample of boards through models/autobattle.lua -- the same
    -- loop the walk-off path uses, so the plan, the ordering and the free-action handling are the real
    -- ones -- and reads what combat actually banked (`combat.xpByChar`). A fresh company is minted per
    -- board so attrition does not compound across boards the player would have camped between.
    if wantXp then
        local Autobattle = require("models.autobattle")
        local Combat = require("models.combat")
        local EncounterBattle = require("models.encounter_battle")
        local Muster = require("models.muster")
        local Player = require("models.player")
        local Experience = require("models.experience")
        local Calendar = require("models.calendar")

        local Character = require("models.character")
        local Growth = require("models.growth")

        -- THE COMPANY HAS TO BE AT PARITY OR THE MEASUREMENT IS OF A MASSACRE. The opening roster is
        -- one body at level 1, and a lone level-1 Rowan against day-20 stock is dead in two turns --
        -- which reads as four experience a day and is a measurement of losing, not of playing.
        --
        -- There is a circularity here worth naming: to know what level a company reaches by day N you
        -- need the curve this measurement is meant to anchor. It is resolved by ASSUMING PARITY --
        -- level the company to what the calendar says the world is worth on that day, then ask what a
        -- day pays them. That is the fixed point the curve should hold: a company keeping pace earns
        -- enough to keep pacing.
        local FIELD = 4
        local function parityCompany(day)
            local player = Player.new()
            player.day = day
            for _, id in ipairs({ "character_knight", "character_mage", "character_hunter" }) do
                if #player.roster < FIELD and Character.defs[id] then
                    player.roster[#player.roster + 1] = Character.instantiate(id)
                end
            end
            local target = Calendar.dangerLevel(day)
            for _, char in ipairs(player.roster) do
                Experience.award(char, Experience.totalFor(target))
                Growth.resolve(char, target)
            end
            return player
        end

        local BOARDS = math.min(n, 12) -- fighting is dear; a dozen boards is plenty for a mean
        local totalXp, bodies, fought, refused = 0, 0, 0, 0
        for i = 1, BOARDS do
            local player = parityCompany(DEFAULT_DAY)
            local grid = Overworld.generate({
                biome = "forest", encounterCount = DEFAULT_ENCOUNTERS, encounters = pool,
                houseMaterial = "material_salt_iron", seed = SEED_BASE + i,
            })
            local boardXp = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local e = grid.cells[y][x].encounter
                    if e and FIGHT[e.kind] then
                        local ok, built = pcall(EncounterBattle.build, {
                            encounter = e, day = DEFAULT_DAY, party = player.roster, biome = "forest",
                        })
                        if ok and built and built.combat then
                            EncounterBattle.autoDeploy(built.combat, built.arena, Muster.fielded(player))
                            Combat.openBattle(built.combat)
                            Autobattle.run(built.combat, { maxTurns = 400 })
                            for _, got in pairs(built.combat.xpByChar or {}) do boardXp = boardXp + got end
                            fought = fought + 1
                        else
                            refused = refused + 1
                        end
                    end
                end
            end
            totalXp = totalXp + boardXp
            bodies = bodies + math.max(1, #player.roster)
        end

        -- Per BODY per BOARD. `bodies` accumulated the company size once per board, so dividing the
        -- whole haul by it gives what one member banked on one board -- which is one day.
        local perDay = totalXp / math.max(1, bodies)
        print("")
        print(string.format("  EXPERIENCE A DAY -- %d boards fought, %d fights resolved, %d refused",
            BOARDS, fought, refused))
        print(string.format("    %-24s %8.1f", "xp a body a day", perDay))
        print(string.format("    %-24s %8d", "over the campaign", math.floor(perDay * Calendar.DAYS)))
        print(string.format("    %-24s %8d  %s", "which reaches level",
            Experience.levelFor(perDay * Calendar.DAYS),
            "against a world ending at " .. Calendar.FINAL_DANGER))
        print(string.format("    %-24s %8d", "at Experience.STEP", Experience.STEP))
    end

    if wantTiers then
        print("")
        print("  stops by kind, per board:")
        local kinds = {}
        for k in pairs(tot.byKind) do kinds[#kinds + 1] = k end
        table.sort(kinds)
        for _, k in ipairs(kinds) do
            print(string.format("    %-16s %6.2f", k, per(tot.byKind[k])))
        end
    end
end

return M
