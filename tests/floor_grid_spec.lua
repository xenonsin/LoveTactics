-- The three standing guards over a floor's shape (models/overworld.lua).
--
-- This replaces tests/board_connectivity_spec.lua, whose subject was the eight layout carves and which
-- went with them. The rule it existed for did not go: the pass that shapes a floor OWNS connectivity and
-- nothing downstream repairs it -- Overworld:computeStart takes a place without asking which piece it is
-- in, and every pass after it works off a BFS from there, so a floor in two pieces is silently a floor
-- half the size and reads as a small floor rather than as a bug ([[carve-owns-connectivity]]).
--
-- What is new is the second guard. On a tile board a gate was a cut vertex the generator HOPED a maze
-- would hand it, and where it did not -- a floor of chambers has no articulation point anywhere -- the
-- chain was skipped and the key hunt bought nothing. The choke pass builds one on purpose, so the
-- promise is now something a spec can hold it to: the deepest end has exactly one approach, that
-- approach is the gate, and blocking it really does cut the end off.

local Overworld = require("models.overworld")

local function floor(overrides)
    local params = {
        cols = 7, rows = 7, seed = 1, biome = "underworld",
        encounterCount = { min = 8, max = 10 },
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
        objective = { name = "Boss" },
    }
    for k, v in pairs(overrides or {}) do params[k] = v end
    return Overworld.generate(params)
end

local function places(grid)
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid:typeWalkable(grid.cells[y][x].tile) then n = n + 1 end
        end
    end
    return n
end

return {
    {
        name = "a floor is one connected region, on every seed and every size",
        fn = function()
            for span = 5, 10 do
                for seed = 1, 20 do
                    local grid = floor({ cols = span, rows = span, seed = seed })
                    local reach = 0
                    for _ in pairs(grid:reachable()) do reach = reach + 1 end
                    local n = places(grid)
                    assert(reach == n, string.format(
                        "%dx%d seed %d: %d of %d places stranded", span, span, seed, n - reach, n))
                    -- ...and the floor is not mostly missing. The hollow pass refuses a block that would
                    -- strand a place, so a share pitched too high stops early rather than eating the
                    -- floor -- but a bug that made every candidate legal would hollow it out in silence.
                    assert(n >= span * span * 0.6, string.format(
                        "%dx%d seed %d: only %d places left", span, span, seed, n))
                end
            end
        end,
    },
    {
        name = "the deepest end has exactly one approach, and that approach is the gate",
        fn = function()
            -- Not "a gate exists" -- that would pass on a lock anybody can walk around, which is what
            -- the old board shipped whenever its maze had no cut vertex to offer. The claim is the one
            -- the key is sold on: take the gate away and the end is unreachable.
            local built = 0
            for seed = 1, 30 do
                local grid = floor({ seed = seed, keyCount = 1 })
                local end_ = grid:objectiveCell()
                local nbs = grid:pathNeighbors(end_.x, end_.y)
                if #grid.keyIds > 0 then
                    built = built + 1
                    assert(#nbs == 1, "seed " .. seed .. ": the gated end has " .. #nbs .. " approaches")
                    local gate = nbs[1]
                    assert(gate.gate, "seed " .. seed .. ": the end's one approach carries no gate")
                    assert(grid:cuts(gate, end_),
                        "seed " .. seed .. ": the gate can be walked around")

                    -- ...and the key for it is on the near side, so the floor is solvable in order.
                    local dist = grid:bfsDistances(grid:startCell())
                    local gateD = dist[gate.y * 100000 + gate.x]
                    local found = false
                    for y = 1, grid.rows do
                        for x = 1, grid.cols do
                            local c = grid.cells[y][x]
                            if c.key and c.key.keyId == gate.gate.keyId then
                                found = true
                                assert((dist[y * 100000 + x] or math.huge) < gateD,
                                    "seed " .. seed .. ": the key is behind its own gate")
                            end
                        end
                    end
                    assert(found, "seed " .. seed .. ": a gate stands with no key on the floor")
                end
                assert((grid:solve()), "seed " .. seed .. ": the floor is unsolvable")
            end
            -- The choke is built rather than found, so it should land on nearly every floor. A run of
            -- thirty that produced two or three would mean the pass is bailing out somewhere.
            assert(built >= 25, "only " .. built .. " of 30 floors got a real gate")
        end,
    },
    {
        name = "the door and the guardian are the two ends of the longest walk",
        fn = function()
            -- THE CROSSING IS THE FLOOR'S OWN DEPTH, not the depth an arbitrary door happened to open
            -- onto. The way in was a RANDOM rim place once and the guardian was the farthest place from
            -- that, so the crossing measured the eccentricity of a coin flip: 17.85 steps against a
            -- diameter of 20.10, about a ninth of every floor thrown away and more on a bad roll.
            for seed = 1, 15 do
                local grid = floor({ seed = seed })
                local start = grid:startCell()
                local dist = grid:bfsDistances(start)
                local crossing = dist[grid.objective.y * 100000 + grid.objective.x] or 0

                -- The best any rim place could have done. The guardian must reach it, or a door was
                -- chosen that the floor had a deeper alternative to.
                local best = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid.cells[y][x]
                        if grid:typeWalkable(c.tile)
                            and (x == 1 or y == 1 or x == grid.cols or y == grid.rows) then
                            for _, d in pairs(grid:bfsDistances(c)) do
                                if d > best then best = d end
                            end
                        end
                    end
                end
                assert(crossing == best, string.format(
                    "seed %d: the guardian stands %d steps in, and the floor could have put it %d",
                    seed, crossing, best))
            end
        end,
    },
    {
        name = "which edge you walk in from varies -- the tie is broken by the seed, not the scan",
        fn = function()
            -- Several rim places usually tie for the deepest floor behind them, so HOW the tie is broken
            -- decides the shape of every floor in the game. Taking the first one scanned resolved every
            -- tie the same way and the scan runs outward from y = 1: measured, four starts in five
            -- landed on the top row and every floor was a walk downward. A positional tie-break is not
            -- neutral, it is a bias with no author.
            local onTop, total = 0, 0
            for seed = 1, 30 do
                local grid = floor({ seed = seed })
                total = total + 1
                if grid.start.y == 1 then onTop = onTop + 1 end
            end
            -- A quarter would be even across four edges; the bar is loose enough not to fail on a run
            -- of luck and tight enough to catch the tie-break collapsing back to the scan order.
            assert(onTop / total <= 0.55, string.format(
                "%d of %d floors are entered from the top row -- the tie-break has a bias",
                onTop, total))
        end,
    },
    {
        name = "the whole floor fits one screen, at every depth",
        fn = function()
            -- The cell size is derived from Overworld.BOARD_EXTENT so a 6x6 and an 8x8 fill the same
            -- frame; a floor that outgrew it would need a camera back, which is the thing the shape was
            -- changed to be rid of.
            local Descent = require("models.descent")
            for f = 1, Descent.FLOORS do
                local cols, rows = Descent.floorDims(f)
                local grid = floor({ cols = cols, rows = rows, seed = 100 + f })
                assert(grid.size * math.max(cols, rows) <= Overworld.BOARD_EXTENT,
                    "floor " .. f .. " draws wider than the frame it is given")
                -- FORTY-FOUR, which is the floor rather than a target. The extent is fixed and the
                -- floor grows inside it, so cell size falls as the descent deepens (61 at the top,
                -- 50 at the bottom) -- and the thing that breaks first is a marker plate with its
                -- tier pips under it. The old tile board drew its markers at 32, so there is real
                -- headroom here; what this guards is a floor grown so far that the frame stops being
                -- able to show what is standing in it.
                assert(grid.size >= 44,
                    "floor " .. f .. " draws its places at " .. grid.size .. " pixels -- too small "
                    .. "for a marker and its pips")
            end
        end,
    },
}
