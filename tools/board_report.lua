-- Floor ledger: run with
--
--     & "E:\LOVE\lovec.exe" . board-report [n] [descent [floor=N]] [all | biome=ID] [tiers]
--
-- Rolls `n` floors with the mode's own map params and reports WHAT THE GENERATOR ACTUALLY LAID DOWN. It
-- exists because every knob that shapes a run's offer -- `cacheTarget`, `combatBudget`, `BLOCKING_SHARE`,
-- `GUARANTEE.rest` -- is a fraction of a fraction, and the composition they produce together is not
-- readable from any one of them.
--
-- That is not a hypothetical failure, and this tool has now caught the same class of error twice in
-- opposite directions:
--
--   * The guarded-boon knob was carried for a whole pass as "roughly two and a half boons per fight", a
--     figure derived by multiplying the constants. The boards said otherwise, because a boon is only
--     guardable when a fight can actually be seated on a cut beside it, and no constant knows how many
--     of those a floor has.
--   * The reverse, later: a floor of optional stops read as a shopping list, and the obvious diagnosis
--     was "not enough fights". The boards said the opposite -- fourteen places on a floor are the only
--     way to something and fights stood on 6% of them. It was never a supply problem, and a count would
--     have been the wrong fix.
--
-- Both were found by reporting the SUPPLY and the TAKE as separate columns. A share that will not move
-- is either a geometry problem or a seating problem, the two want opposite fixes, and one number cannot
-- tell them apart. THE RULE IS docs/roadmap.md's: do not hand-derive a count, roll the floors and read
-- what they say.
--
-- WHAT IS COUNTED, and why these:
--
--     fights      combat + elite. The cost side of every offer on the floor. Reported beside `ends`,
--                 because a floor's ends are fights the pool never dealt and a budget that cannot see
--                 them is a budget that is wrong by several.
--     boons       cache places + treasure/relic_cache stops. The payout side. A shrine is NOT a boon
--                 (it sells, it does not give) and neither is a rest or a merchant: those are services,
--                 and nothing ever stands a fight in front of one.
--     places      walkable cells, against the cells the grid holds. `full` is what share of them hold
--                 something -- the number the whole shape is pitched at.
--     cuts        places that are the ONLY way to something, and how many of them a fight is standing
--                 on. The supply and the take, kept apart for the reason above.
--     rest        the run's one refund. Reported per floor AND per fight, because what matters is how
--                 much attrition a camp is being asked to hand back, not how many camps there are.
--     tier arc    mean encounter tier by fifth of the floor, walked by BFS distance from the way in. A
--                 generator that means to escalate should show a rising column here; a flat column means
--                 the ramp is being swamped by its own noise term.
--
-- Read-only, and it drives Overworld directly rather than a game state, so no save is touched. Seeds are
-- sequential from a fixed base, so two runs of this tool agree exactly.

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


-- One floor's worth of counts. Walks every cell once; the tier arc needs a BFS, which Overworld already
-- exposes for its own placement passes.
--
-- WHAT MOVED WHEN THE BOARD BECAME A GRID. Most of this file's old columns measured the carve: the
-- share of trail that was open rather than corridor, how many dead ends a braid left, whether a boon
-- had a neighbour that was a real cut vertex, how many fights had lifted onto a beat. None of those
-- questions exist on a grid of places -- there is no corridor, no braid, no patrol -- and a column no
-- pass reads is silently false, so they are gone rather than kept reading zero.
--
-- What replaces them is the one question this shape asks: HOW FULL IS THE FLOOR, and how far across it
-- is the thing at the end. Occupancy is the number the whole design is pitched at (about half the places
-- holding something, the rest what you route through) and `steps to the stair` is what replaced forty
-- tiles of corridor.
local function measure(grid)
    local r = {
        fights = 0, boons = 0, rest = 0, stops = 0,
        caches = 0, services = 0, tierSum = 0, tierN = 0,
        craftStock = 0, houseStock = 0,
        byKind = {},
        depthTierSum = { 0, 0, 0, 0, 0 },
        depthTierN = { 0, 0, 0, 0, 0 },
    }

    local dist = grid:bfsDistances(grid:startCell())
    local maxD = 1
    for _, d in pairs(dist) do if d > maxD then maxD = d end end
    r.deepest = maxD

    -- THE LONGEST WALK THE FLOOR ACTUALLY OFFERS -- its diameter, over every pair of places.
    -- Reported beside `steps to the end` so the gap between what the floor could have asked for
    -- and what it did ask for is a number rather than an impression.
    r.diameter = 0
    for yy = 1, grid.rows do
        for xx = 1, grid.cols do
            if grid:typeWalkable(grid.cells[yy][xx].tile) then
                local d2 = grid:bfsDistances(grid.cells[yy][xx])
                for _, d in pairs(d2) do if d > r.diameter then r.diameter = d end end
            end
        end
    end

    -- ENDS THE FLOOR COULD NOT SEAT. Every piece of work posted here wants its own place, held apart
    -- from the others; when the floor runs out the extra end is counted rather than left silent,
    -- because a floor that keeps doing it is a floor whose sizing has stopped keeping up.
    r.crowdedEnds = grid.crowdedEnds or 0
    r.ends = grid.objectives and #grid.objectives or (grid.objective and 1 or 0)

    -- HOW FAR IN THE STAIR IS, in steps, which is the figure the whole shape was changed for: a 40x40
    -- lattice floor put it forty steps from the door with about thirty-eight of them empty corridor.
    r.toEnd = 0
    if grid.objective then
        r.toEnd = dist[grid.objective.y * 100000 + grid.objective.x] or 0
    end

    r.places, r.blocked, r.deadEnds, r.marks, r.endN = 0, 0, 0, 0, 0
    r.gates, r.keys, r.secrets = 0, 0, 0

    -- HOW MUCH OF THIS FLOOR IS BEHIND SOMETHING, which is the question a floor of optional stops has to
    -- be able to answer about itself. A CUT is a place whose removal puts some of the floor out of
    -- reach; a fight standing on one is a fight you cannot walk around to get at what is past it.
    --
    -- `cuts` is the supply -- how many such places the silhouette happens to offer -- and `blocking` is
    -- how many of them a fight is actually standing on. The gap between them is what a seating pass has
    -- left to work with, and reading them apart is the whole lesson of the guarded-boon misdiagnosis:
    -- a share that will not rise is either a geometry problem or a supply problem and the two want
    -- opposite fixes.
    r.cuts, r.blocking, r.behind = 0, 0, 0
    -- HOW MUCH OF THE FLOOR THE COMPANY CAN REACH WITHOUT FIGHTING, from the place it walks in on.
    -- A floor whose entrance opens onto nothing but fights is a floor that takes the first
    -- decision away: the only move is a battle nobody chose and may not be ready for.
    r.freeFromDoor, r.pennedIn, r.deadEndsFull = 0, 0, 0
    do
        local s = grid:startCell()
        local function fight(c)
            local e = c and c.encounter
            return e and not c.cleared and (e.kind == "combat" or e.kind == "elite"
                or e.kind == "objective") or false
        end
        local seen, q, qi = { [s.y * 100000 + s.x] = true }, { s }, 1
        local n = 1
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, nb in ipairs(grid:pathNeighbors(c.x, c.y)) do
                local k = nb.y * 100000 + nb.x
                if not seen[k] and not fight(nb) then
                    seen[k] = true; n = n + 1; q[#q + 1] = nb
                end
            end
        end
        r.freeFromDoor = n
        r.pennedIn = (n <= 3) and 1 or 0
    end
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if grid:typeWalkable(c.tile) and not (grid.start.x == x and grid.start.y == y) then
                local was = c.tile
                c.tile = "thicket"
                local start = grid:startCell()
                local reach = (start and grid:typeWalkable(start.tile)) and grid:reachable(start) or {}
                c.tile = was
                local n = 0
                for _ in pairs(reach) do n = n + 1 end
                -- Everything walkable except this cell should still be reachable; short of that, this
                -- place is the only way to whatever is missing.
                local walkable = 0
                for yy = 1, grid.rows do
                    for xx = 1, grid.cols do
                        if grid:typeWalkable(grid.cells[yy][xx].tile) then walkable = walkable + 1 end
                    end
                end
                local stranded = walkable - 1 - n
                if stranded > 0 then
                    r.cuts = r.cuts + 1
                    r.behind = r.behind + stranded
                    if c.encounter and FIGHT[c.encounter.kind] then r.blocking = r.blocking + 1 end
                end
            end
        end
    end

    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if not grid:typeWalkable(c.tile) then
                r.blocked = r.blocked + 1
                if c.secret then r.secrets = r.secrets + 1 end
            else
                r.places = r.places + 1
                if #grid:pathNeighbors(x, y) == 1 then r.deadEnds = r.deadEnds + 1 end
                -- ...AND WHETHER IT ENDS IN ANYTHING. A spur that ends in nothing is a walk the
                -- floor charged for and did not pay: the old board had a whole pass (pruneDeadStubs)
                -- to cut them, and a grid has none -- so this is the column that says whether it
                -- needs one.
                if #grid:pathNeighbors(x, y) == 1 and (c.encounter or c.cache) then
                    r.deadEndsFull = (r.deadEndsFull or 0) + 1
                end
                if c.gate then r.gates = r.gates + 1 end
                if c.key then r.keys = r.keys + 1 end
                if c.encounter or c.cache or c.gate or c.key then r.marks = r.marks + 1 end
            end

            if c.cache then
                r.caches = r.caches + 1; r.boons = r.boons + 1
                -- What the floor actually pays in forging stock. Counted by walking the placed caches
                -- rather than derived from cacheTarget, because the payload is scaled per place by the
                -- detour it cost -- so the constant that looks responsible for material income is never
                -- the one that sets it.
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
                        -- Fifth of the floor by distance from the way in.
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
                elseif e.kind == "objective" then
                    r.endN = r.endN + 1
                else
                    r.services = r.services + 1
                end
            end
        end
    end

    -- ONE CONNECTED REGION, asked of the floor the player is actually handed. The hollow pass
    -- guarantees it by construction and the choke pass runs after it, so this is the standing check
    -- that the second did not undo the first.
    local reach = grid:reachable(grid:startCell())
    local n = 0
    for _ in pairs(reach) do n = n + 1 end
    r.stranded = r.places - n

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
-- id fixes it here.
--
-- THE DECISION THIS NOTE ASKED FOR HAS SINCE BEEN TAKEN: Encounter.pool sorts by id itself now, because
-- a save carries a seed (models/seed.lua) and a seed that deals a different floor on another machine is
-- not a seed. It did change which boards players get, once. So this function is no longer what makes
-- the report reproducible -- the game is -- and it is kept rather than deleted because the guarantee it
-- states is the tool's own: an instrument should not be able to lose it if the model ever does.
--
-- What none of that changes is why a board is SERIALIZED whole rather than re-rolled on load
-- (Overworld:snapshot): a floor holds run state -- fog lifted, stops cleared, doors found -- and no seed
-- can say what a player did.
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
    print(string.format("BOARD REPORT -- %d floors per ground, %d-%d stops, day %d",
        n, DEFAULT_ENCOUNTERS.min, DEFAULT_ENCOUNTERS.max, DEFAULT_DAY))
    print("")
    print(string.format("  %-11s %7s %7s %8s %8s", "ground", "places", "full", "steps", "ends"))
    print("  " .. string.rep("-", 48))
    -- A DAY'S WORK, AS THE CAMPAIGN ACTUALLY ROLLS IT. Three pieces of work is the middle of the range a
    -- ground carries (models/quest.lua's Quest.trip), and it is what this has to measure -- with one end
    -- the floor is smaller and every stop has more room than it will really get. The specs are bare:
    -- nothing here fights them, they exist so three ends are asked for.
    local trip = { { name = "end 1" }, { name = "end 2" }, { name = "end 3" } }
    local crowded = 0
    for _, biome in ipairs(biomes) do
        local t = { places = 0, marks = 0, cells = 0, steps = 0, ends = 0, n = 0 }
        for i = 1, n do
            local grid = Overworld.generate({
                biome = biome,
                encounterCount = DEFAULT_ENCOUNTERS,
                encounters = pool,
                objectives = trip,
                houseMaterial = "material_salt_iron",
                seed = SEED_BASE + i,
            })
            crowded = crowded + (grid.crowdedEnds or 0)
            local r = measure(grid)
            t.places = t.places + r.places
            t.marks = t.marks + r.marks
            t.cells = t.cells + grid.cols * grid.rows
            t.steps = t.steps + r.toEnd
            t.ends = t.ends + r.endN
            t.n = t.n + 1
        end
        local function ratio(a, b) return b > 0 and (a / b) or 0 end
        print(string.format("  %-11s %7.1f %6.1f%% %8.1f %8.2f",
            biome,
            ratio(t.places, t.n),
            100 * ratio(t.marks, t.places),
            ratio(t.steps, t.n),
            ratio(t.ends, t.n)))
    end
    print("")
    -- SAID OUT LOUD RATHER THAN LEFT IN THE ARITHMETIC. Every floor above was asked for three ends; this
    -- is how often one of them could not be given a place of its own at all.
    if crowded > 0 then
        print(string.format("  NOTE  %d of %d ends had no place left to take (%.1f%%)",
            crowded, #biomes * n * #trip, 100 * crowded / (#biomes * n * #trip)))
        print("")
    end
    print("  places     walkable cells a floor holds -- the rest of the grid is not there")
    print("  full       share of those places holding SOMETHING: a stop, a find, a gate, a key.")
    print("             The number the whole shape is pitched at -- about half, so the rest is")
    print("             what you route through.")
    print("  steps      how far the deepest end is from the way in, in steps")
    print("  ends       pieces of work seated, of the three asked for")
end

function M.run(args)
    args = args or {}
    local n = tonumber(args[1]) or 200
    local wantTiers, braid, cacheDiv, combatWeight = false, nil, nil, nil
    local stopsOverride, fightsOverride, endsOverride = nil, nil, nil
    local wantContracts, wantXp, wantDescent = false, false, false
    local descentFloor = 1
    local carveOverride, sizeOverride = nil, nil
    local wantCost, partySize = false, 4
    -- Which ground(s). `all` walks every blueprint in data/biomes; `biome=x` reports one; the bare
    -- default stays forest, so every figure recorded in docs/overworld.md still reproduces exactly.
    local biome, wantAll = "forest", false
    local perBoard = {} -- one row per board, for the distribution questions a mean cannot answer
    for _, a in ipairs(args) do
        if a == "tiers" then wantTiers = true end
        if a == "contracts" then wantContracts = true end
        if a == "xp" then wantXp = true end
        -- DOES A FIGHT COST HEALTH. The descent's whole economy is a life budget -- nothing refills
        -- between fights on a floor -- and a budget only binds if spending it is compulsory. This
        -- resolves every fight on a sample of floors and reads what came off the company, which is the
        -- question asked directly rather than through Muster's rating of it:
        --
        --     . board-report 12 descent floor=1 cost party=4
        --
        -- `party` is the lever the measurement exists to pull. models/descent.lua's OPENING_CAP is sized
        -- for the TWO bodies the campaign hands over on floor one, and Descent.PARTY_MAX is four -- so a
        -- returning company walks that floor against fights cut to fit a pair, and 2 against 4 is the
        -- comparison that says whether that gap is real.
        if a == "cost" then wantCost = true end
        local pc = tostring(a):match("^party=(%d+)$"); if pc then partySize = tonumber(pc) end
        if a == "all" then wantAll = true end
        local bi = tostring(a):match("^biome=(%w+)$"); if bi then biome = bi end
        -- Override knobs for a tuning sweep, so a candidate value is measured before it is committed to
        -- the model: `. board-report 200 braid=0.25 cachediv=3`.
        local b = tostring(a):match("^braid=([%d%.]+)$"); if b then braid = tonumber(b) end
        local d = tostring(a):match("^cachediv=([%d%.]+)$"); if d then cacheDiv = tonumber(d) end
        local w = tostring(a):match("^cw=([%d%.]+)$"); if w then combatWeight = tonumber(w) end
        -- THE KNOBS THAT DECIDE HOW MANY FIGHTS A FLOOR HOLDS, swept here for exactly the reason the
        -- three above are. The retired Descent.FLOOR_STOPS carried a hand-derived fight count in its own
        -- header -- "sixteen leaves eleven to roll, which lands six or seven fights" -- and the boards
        -- said eleven. A stop count and a combat share multiply into a fight count through the guarantee
        -- pass, and that product is not readable from either constant.
        --
        -- `ends=N` is the one that was missing and is the reason the old figure was wrong twice over. A
        -- floor's board is built here from a NIL PLAYER, and Descent.floorObjectives answers a nil player
        -- with the stair and nothing else -- so the instrument had never once seen an errand or a
        -- door-opener, which are three or four more fights on a real floor one. This seats N ends instead
        -- of the one, so an errand-heavy floor can be measured rather than imagined.
        --
        --     . board-report 60 descent stops=12 fights=4 ends=4
        local st = tostring(a):match("^stops=([%d%.]+)$"); if st then stopsOverride = tonumber(st) end
        local fg = tostring(a):match("^fights=([%d%.]+)$"); if fg then fightsOverride = tonumber(fg) end
        local en = tostring(a):match("^ends=([%d%.]+)$"); if en then endsOverride = tonumber(en) end
        -- `descent` measures a FLOOR rather than a campaign ground: the dungeon carve at its own
        -- spacing, the floor's stop count and cache pins, its reweighted pool and its guarantees.
        -- Without this the instrument could only ever report on the half of the game that is parked.
        if a == "descent" then wantDescent = true end
        -- WHICH floor, because a floor's board is no longer one size: it widens a tile a floor
        -- (Descent.floorDims), so "a descent floor" is a question that needs a depth to answer. Defaults
        -- to the first, so every figure recorded against the bare `descent` still reproduces.
        local f = tostring(a):match("^floor=(%d+)$"); if f then descentFloor = tonumber(f) end
        local cv = tostring(a):match("^carve=(%w+)$"); if cv then carveOverride = cv end
        local sz = tostring(a):match("^size=(%d+)$"); if sz then sizeOverride = tonumber(sz) end
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
        fights = 0, boons = 0, rest = 0, stops = 0, caches = 0, services = 0,
        tierSum = 0, tierN = 0, endN = 0,
        places = 0, blocked = 0, marks = 0, toEnd = 0, deepest = 0, deadEnds = 0,
        cuts = 0, blocking = 0, behind = 0,
        freeFromDoor = 0, pennedIn = 0,
        deadEndsFull = 0,
        diameter = 0,
        gates = 0, keys = 0, secrets = 0, stranded = 0, crowdedEnds = 0,
        craftStock = 0, houseStock = 0,
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
            seed = SEED_BASE + i,
        }
        if wantDescent then
            local mp = dq.map
            encN = stopsOverride and { min = stopsOverride, max = stopsOverride } or mp.encounters
            params.cols, params.rows = mp.cols, mp.rows
            -- A SIZE OVERRIDE, so a candidate grid is measured before it is committed to
            -- models/descent.lua rather than after:
            --
            --     . board-report 30 descent floor=1 size=7
            --
            -- Nothing else about the floor moves -- the stop budget, the pins, the reweighted pool and
            -- the guarantees are all still the model's, which is what makes the two rows comparable.
            -- (`carve=` went with the layouts: a floor has one shape now, and how much of it is not
            -- there is Overworld.BLOCK_SHARE.)
            if sizeOverride then params.cols, params.rows = sizeOverride, sizeOverride end
            params.encounterCount = encN
            params.cacheCount = cacheDiv
                and math.max(1, math.floor(((encN.min + encN.max) / 2) / cacheDiv)) or mp.cacheCount
            params.combatShare = mp.combatShare
            params.combatBudget = fightsOverride or mp.combatBudget
            params.guaranteeKinds = mp.guaranteeKinds
            params.guarantee = mp.guarantee
            params.ascent, params.keyCount = true, 0
            params.secrets, params.exitAtStart = mp.secrets, mp.exitAtStart
            params.objective = mp.objective
            -- EVERY END THE FLOOR CARRIES, which is the half of the board this tool used to leave on the
            -- floor. `mp.objectives` was never passed at all, so the generator laid one end where a real
            -- floor lays four, and the fight ledger under it was measuring a board nobody plays.
            params.objectives = mp.objectives
            -- ...and `ends=N` stands in for the errands a nil player cannot have asked for. The stair is
            -- copied, because what is being measured is how many ENDS the board can seat and what the
            -- budget does when they take it -- not which fight is on each one.
            if endsOverride and endsOverride > 1 then
                local ends = { mp.objective }
                for _ = 2, endsOverride do ends[#ends + 1] = mp.objective end
                params.objectives = ends
                local stops, rolled = Descent.floorBudget(endsOverride, descentFloor)
                params.combatBudget = fightsOverride or rolled
                -- The stop count moves with the budget for the same reason it does in the model: fewer
                -- rolled fights on the same number of stops is not a sparser floor, it is a floor of
                -- merchants. An explicit `stops=` still wins.
                if not stopsOverride then encN, params.encounterCount = stops, stops end
            end
        end
        local grid = Overworld.generate(params)
        local r = measure(grid)
        for _, k in ipairs({ "fights", "boons", "rest", "stops", "caches", "services",
                             "tierSum", "tierN", "deadEnds", "craftStock", "houseStock",
                             "places", "blocked", "marks", "endN", "toEnd", "deepest",
                             "cuts", "blocking", "behind",
                             "freeFromDoor", "pennedIn",
                             "deadEndsFull",
                             "diameter",
                             "gates", "keys", "secrets", "stranded", "crowdedEnds" }) do
            tot[k] = (tot[k] or 0) + (r[k] or 0)
        end
        for b = 1, 5 do
            tot.depthTierSum[b] = tot.depthTierSum[b] + r.depthTierSum[b]
            tot.depthTierN[b] = tot.depthTierN[b] + r.depthTierN[b]
        end
        for k, v in pairs(r.byKind) do tot.byKind[k] = (tot.byKind[k] or 0) + v end
        perBoard[#perBoard + 1] = {
            caches = r.caches, fights = r.fights,
            relicCache = r.byKind.relic_cache or 0,
            treasure = r.byKind.treasure or 0,
            crossroads = r.byKind.crossroads or 0,
        }
    end

    local function per(v) return v / n end
    local function ratio(a, b) return b > 0 and (a / b) or 0 end

    local stopSpec = wantDescent
        and (stopsOverride and { min = stopsOverride, max = stopsOverride } or dq.map.encounters)
        or DEFAULT_ENCOUNTERS
    print(string.format("BOARD REPORT -- %d rolled %s, %s, %d-%d stops, day %d",
        n, wantDescent and ("floor " .. descentFloor .. "s, " .. dq.map.cols .. "x" .. dq.map.rows)
            or "boards", biome,
        stopSpec.min, stopSpec.max, DEFAULT_DAY))
    print("")
    print(string.format("  %-22s %8s  %s", "", "per board", "note"))
    print(string.format("  %-22s %8.2f", "stops", per(tot.stops)))
    print(string.format("  %-22s %8.2f", "fights", per(tot.fights)))
    -- THE ENDS ARE FIGHTS TOO, and leaving them off this ledger is how a floor came to be shipped at
    -- fifteen while the report read eleven. An objective is not a stop the pool DEALT -- which is why it
    -- is outside `fights` above and outside `services` in measure() -- but it is unambiguously a fight
    -- the player takes, and on a descent floor there are several: the stair, one per errand a house has
    -- asked for down here, and one per door still shut on the first circle (Descent.floorObjectives).
    -- Reported as its own row plus a total, so both questions stay answerable from one run.
    print(string.format("  %-22s %8.2f  %s", "ends", per(tot.endN),
        "the stair, the errands, the openers -- fights the pool never dealt"))
    print(string.format("  %-22s %8.2f  %s", "FIGHTS IN ALL", per(tot.fights + tot.endN),
        "what a sitting on this floor actually costs"))
    print(string.format("  %-22s %8.2f  %s", "boons", per(tot.boons),
        string.format("%.2f caches + %.2f finds", per(tot.caches), per(tot.boons - tot.caches))))
    print(string.format("  %-22s %8.2f", "services", per(tot.services)))
    print(string.format("  %-22s %8.2f  %s", "rest", per(tot.rest),
        string.format("one per %.1f fights", ratio(tot.fights, tot.rest))))
    print("")
    print("")
    -- WHAT THE FLOOR IS SHAPED LIKE, which on a grid is three numbers and not a page of them.
    print("  what this floor is shaped like:")
    print(string.format("    %-20s %8.2f  %s", "places", per(tot.places),
        string.format("of %.0f cells -- %.0f are not there", per(tot.places + tot.blocked),
            per(tot.blocked))))
    print(string.format("    %-20s %8.1f%%  %s", "full", 100 * ratio(tot.marks, tot.places),
        string.format("%.2f of them hold something", per(tot.marks))))
    print(string.format("    %-20s %8.2f  %s", "steps to the end", per(tot.toEnd),
        string.format("deepest place is %.1f", per(tot.deepest))))
    print(string.format("    %-20s %8.2f  %s", "longest the floor has", per(tot.diameter),
        string.format("the crossing takes %.0f%% of it",
            100 * ratio(tot.toEnd, tot.diameter))))
    print(string.format("    %-20s %8.2f  %s", "dead ends", per(tot.deadEnds),
        "places with one way in"))
    print(string.format("    %-20s %8.2f  %s", "...ending in nothing",
        per(tot.deadEnds - tot.deadEndsFull),
        string.format("%.0f%% of them pay for the walk",
            100 * ratio(tot.deadEndsFull, tot.deadEnds))))
    print(string.format("    %-20s %8.2f  %s", "cuts", per(tot.cuts),
        string.format("places that are the ONLY way to something -- %.1f places behind them",
            per(tot.behind))))
    print(string.format("    %-20s %8.2f  %s", "blocked by a fight", per(tot.blocking),
        string.format("%.0f%% of the cuts; the rest can be walked past",
            100 * ratio(tot.blocking, tot.cuts))))
    print(string.format("    %-20s %8.2f  %s", "free from the door", per(tot.freeFromDoor),
        string.format("places reachable without a fight; %.0f%% of floors pen you in",
            100 * per(tot.pennedIn))))
    if tot.gates > 0 or tot.secrets > 0 then
        print(string.format("    %-20s %8.2f  %s", "gates", per(tot.gates),
            string.format("%.2f keys before them", per(tot.keys))))
        print(string.format("    %-20s %8.2f  %s", "secrets", per(tot.secrets),
            "places that read as absent until somebody looks"))
    end
    -- MUST READ 0. The hollow pass owns connectivity and the choke pass runs after it; this is the
    -- standing check that the second never undid the first. A floor in two pieces is silently a floor
    -- half the size ([[carve-owns-connectivity]]).
    print(string.format("    %-20s %8.2f  %s", "stranded", per(tot.stranded),
        "places unreachable from the way in -- must be 0"))
    if tot.crowdedEnds > 0 then
        print(string.format("    %-20s %8.2f  %s", "ends with no place", per(tot.crowdedEnds),
            "work the floor could not seat -- a sizing failure"))
    end
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
    if wantXp or wantCost then
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

        -- WHAT A FIGHT TAKES OFF THE COMPANY, resolved fight by fight from FULL.
        --
        -- Deliberately reset between fights rather than compounded, and the distinction is the whole
        -- measurement: the question is not "how worn is a company by the stair" (which confounds a floor
        -- that is too hard with one that is too long) but "is this fight, on its own, something the
        -- player pays for". A fight that costs nothing from full costs nothing at any health.
        --
        -- Read off the roster rather than off the combat, because the combat's units are views onto
        -- these instances and Player.restore is the same call the hub makes -- so what is measured is
        -- exactly what the player would see on the party panel afterwards.
        if wantCost then
            local mp = dq and dq.map
            local pool = M.stablePool(DEFAULT_DAY)
            local spent, zero, cheap, fights = 0, 0, 0, 0
            local poolMax = 0
            for i = 1, BOARDS do
                local player = parityCompany(DEFAULT_DAY)
                while #player.roster > partySize do table.remove(player.roster) end
                local params = {
                    biome = (mp and mp.biome) or "forest",
                    encounterCount = (mp and mp.encounters) or DEFAULT_ENCOUNTERS,
                    encounters = pool, houseMaterial = "material_salt_iron",
                    seed = SEED_BASE + i,
                }
                if mp then
                    params.cols, params.rows = sizeOverride or mp.cols, sizeOverride or mp.rows
                    params.spacing = mp.spacing
                    params.combatBudget = mp.combatBudget
                    params.combatShare, params.guarantee = mp.combatShare, mp.guarantee
                    params.objective, params.objectives = mp.objective, mp.objectives
                    params.ascent, params.keyCount = true, 0
                end
                local grid = Overworld.generate(params)
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local e = grid.cells[y][x].encounter
                        if e and FIGHT[e.kind] then
                            Player.restore(player)
                            local before = 0
                            for _, c in ipairs(player.roster) do
                                local h = c.stats and c.stats.health
                                if type(h) == "table" then before = before + (h.current or 0) end
                            end
                            local ok, built = pcall(EncounterBattle.build, {
                                encounter = e, day = DEFAULT_DAY, party = player.roster,
                                biome = params.biome, quest = dq,
                            })
                            if ok and built and built.combat then
                                EncounterBattle.autoDeploy(built.combat, built.arena, Muster.fielded(player))
                                Combat.openBattle(built.combat)
                                Autobattle.run(built.combat, { maxTurns = 400 })
                                local after = 0
                                for _, c in ipairs(player.roster) do
                                    local h = c.stats and c.stats.health
                                    if type(h) == "table" then after = after + (h.current or 0) end
                                end
                                local lost = math.max(0, before - after)
                                fights = fights + 1
                                spent = spent + lost
                                poolMax = poolMax + before
                                if lost <= 0 then zero = zero + 1 end
                                if before > 0 and (lost / before) < 0.05 then cheap = cheap + 1 end
                            end
                        end
                    end
                end
            end
            local n1 = math.max(1, fights)
            print("")
            print(string.format("  WHAT A FIGHT COSTS -- %d boards, %d fights, a company of %d",
                BOARDS, fights, partySize))
            print(string.format("    %-26s %7.1f%%  %s", "health spent a fight",
                100 * spent / math.max(1, poolMax), "of the company's pool, from full"))
            print(string.format("    %-26s %7.1f%%  %s", "fights that cost NOTHING",
                100 * zero / n1, "the number the life budget lives or dies on"))
            print(string.format("    %-26s %7.1f%%  %s", "fights under 5%",
                100 * cheap / n1, "near enough to free"))
        end

        local totalXp, bodies, fought, refused = 0, 0, 0, 0
        for i = 1, (wantXp and BOARDS or 0) do
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
        if wantXp then
        print("")
        print(string.format("  EXPERIENCE A DAY -- %d boards fought, %d fights resolved, %d refused",
            BOARDS, fought, refused))
        print(string.format("    %-24s %8.1f", "xp a body a day", perDay))
        print(string.format("    %-24s %8d", "over the campaign", math.floor(perDay * Calendar.SPAN)))
        print(string.format("    %-24s %8d  %s", "which reaches level",
            Experience.levelFor(perDay * Calendar.SPAN),
            "against a world ending at " .. Calendar.FINAL_DANGER))
        print(string.format("    %-24s %8d", "at Experience.STEP", Experience.STEP))
        end
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
