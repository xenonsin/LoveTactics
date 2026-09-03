-- Tests for the procedural overworld generator (models/overworld.lua): seeded
-- determinism, trail connectivity, and the objective/lock-key solvability
-- guarantee, plus the quest -> map param plumbing.

local Overworld = require("models.overworld")
local Quest = require("models.quest")
local Player = require("models.player")
local Tileset = require("models.tileset")

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

-- Deterministic small map for structural checks.
local function gen(overrides)
    local params = {
        cols = 31, rows = 21, seed = 1234, riverCount = 2,
        encounterCount = 5, keyCount = 1, objective = { name = "Boss" },
        encounters = { { kind = "combat", weight = 3 }, { kind = "elite", weight = 1 } },
    }
    if overrides then
        for k, v in pairs(overrides) do params[k] = v end
    end
    return Overworld.generate(params)
end

-- Flatten a grid to a comparable string signature.
local function signature(grid)
    local parts = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            parts[#parts + 1] = table.concat({
                c.tile,
                c.gate and c.gate.keyId or "-",
                c.key and c.key.keyId or "-",
                c.encounter and c.encounter.kind or "-",
            }, ":")
        end
    end
    return table.concat(parts, "|")
end

local function countWalkable(grid)
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if typeWalkable(grid:get(x, y).tile) then n = n + 1 end
        end
    end
    return n
end

return {
    {
        name = "density & mix: a rolled board guarantees texture and caps the combat share",
        fn = function()
            -- A fight-heavy pool (as the real registry is) plus the texture kinds. Without the guarantee
            -- pass + combat-share cap, weighted-random would leave a run nearly all fights.
            local pool = {
                { kind = "combat", weight = 6 }, { kind = "elite", weight = 2 },
                { kind = "relic_cache", weight = 1 }, { kind = "rest", weight = 1 },
                { kind = "treasure", weight = 1 },
            }
            local function kindCounts(grid)
                local counts, total = {}, 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local e = grid:get(x, y).encounter
                        if e and e.kind ~= "objective" then
                            counts[e.kind] = (counts[e.kind] or 0) + 1
                            total = total + 1
                        end
                    end
                end
                return counts, total
            end
            -- A few seeds, since placement is seeded: the guarantees must hold on every roll.
            for _, seed in ipairs({ 11, 42, 99, 2024 }) do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, keyCount = 0,
                    encounterCount = 10, encounters = pool, objective = { name = "Boss" },
                })
                local counts, total = kindCounts(grid)
                assert((counts.relic_cache or 0) >= 1, "seed " .. seed .. ": at least one Reliquary is guaranteed")
                assert((counts.rest or 0) >= 1, "seed " .. seed .. ": at least one Rest is guaranteed")
                local fights = (counts.combat or 0) + (counts.elite or 0)
                assert(fights <= math.ceil(total * 0.6) + 1,
                    "seed " .. seed .. ": combat share capped (~60%), got " .. fights .. "/" .. total)
            end
        end,
    },
    {
        name = "each biome resolves its own tileset (art differs, walkability shared)",
        fn = function()
            local forest = Overworld.generate({ cols = 41, rows = 29, seed = 7, biome = "forest" })
            local castle = Overworld.generate({ cols = 41, rows = 29, seed = 7, biome = "castle" })
            assert(forest.tilesetId == "forest", "forest should use the forest tileset")
            assert(castle.tilesetId == "castle", "castle should use the castle tileset")

            local ft, ct = Tileset.get(forest.tilesetId), Tileset.get(castle.tilesetId)
            assert(ft.image ~= ct.image, "biomes should point at different tileset images")
            -- Distinct art: at least the path colour should differ between biomes.
            assert(ft.tiles.path.color[1] ~= ct.tiles.path.color[1]
                or ft.tiles.path.color[3] ~= ct.tiles.path.color[3],
                "forest and castle path colours should differ")
            -- Walkability is universal, not per-biome.
            for tile in pairs(Tileset.TYPES) do
                assert(ft.tiles[tile].walkable == ct.tiles[tile].walkable,
                    "walkability of '" .. tile .. "' must match across biomes")
            end
            -- `river`, not `water`: the two meanings of water were split when the map's tiles and the
            -- board's became one table (models/terrain.lua). A river is the barrier you cross at a
            -- bridge; `water` is now the wadeable ford, and asserting THAT is blocked would pin the
            -- wrong half of the split.
            assert(ft.tiles.path.walkable and not ft.tiles.river.walkable,
                "path walkable, river blocked, in every tileset")
            assert(ft.tiles.water.walkable, "a ford is wadeable -- see models/terrain.lua")
        end,
    },
    {
        name = "unknown/missing biome falls back without error, and is still solvable",
        fn = function()
            local grid = Overworld.generate({ cols = 9, rows = 9, seed = 9, keyCount = 1 })
            assert(grid.tilesetDef, "an unnamed biome still resolves a tileset to draw with")
            assert((grid:solve()), "default-biome floor unsolvable")
        end,
    },
    {
        name = "castle (tight) maps stay solvable with keys across many seeds",
        fn = function()
            for seed = 1, 30 do
                local grid = Overworld.generate({
                    cols = 51, rows = 35, seed = seed, biome = "castle",
                    encounterCount = 12, keyCount = 2,
                    objective = { name = "Warlord" },
                })
                assert((grid:solve()), "castle seed " .. seed .. " unsolvable")
            end
        end,
    },
    {
        name = "encounter count honours the { min, max } range",
        fn = function()
            for seed = 1, 20 do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, biome = "forest",
                    encounterCount = { min = 6, max = 9 },
                    encounters = { { kind = "combat", weight = 1 } },
                })
                local n = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.encounter and c.encounter.kind ~= "objective" then n = n + 1 end
                    end
                end
                assert(n >= 6 and n <= 9, "seed " .. seed .. " placed " .. n .. " (want 6..9)")
            end
        end,
    },
    {
        name = "map size scales with encounter count when cols/rows are unset",
        fn = function()
            -- No explicit cols/rows: the play area should grow with the resolved
            -- encounter count so light quests get compact maps and heavy ones sprawl.
            local small = Overworld.generate({
                seed = 11, biome = "forest", encounterCount = 3,
                encounters = { { kind = "combat", weight = 1 } },
            })
            local big = Overworld.generate({
                seed = 11, biome = "forest", encounterCount = 14,
                encounters = { { kind = "combat", weight = 1 } },
            })
            assert(small.cols < big.cols and small.rows < big.rows,
                "a 3-encounter map (" .. small.cols .. "x" .. small.rows
                .. ") should be smaller than a 14-encounter map ("
                .. big.cols .. "x" .. big.rows .. ")")
        end,
    },
    {
        name = "an auto-sized floor is capped, so no roll produces a floor you get lost in",
        fn = function()
            -- Growth is sub-linear and hard-capped. The ceiling was 37x25 of TILES with a margin ring
            -- and a coastline surplus padded around it; a grid has neither -- every cell is play area --
            -- and the cap is TWELVE a side, which is the deepest floor the descent itself asks for
            -- (Descent.floorDims) -- so a caller that does not pin can never be handed a grid the mode
            -- would not draw. See deriveDims.
            for seed = 1, 15 do
                local grid = Overworld.generate({
                    seed = seed, biome = "forest", encounterCount = 40, keyCount = 4,
                    encounters = { { kind = "combat", weight = 1 } },
                    objective = { name = "Boss" },
                })
                assert(grid.cols <= 12, "cols exceeded the cap: " .. grid.cols)
                assert(grid.rows <= 12, "rows exceeded the cap: " .. grid.rows)
                assert(grid.margin == 0, "a grid of places has no frame to pad")
            end
        end,
    },
    {
        name = "small auto-sized maps with keys stay solvable",
        fn = function()
            -- The auto-size path shrinks the play area for light quests; the
            -- objective/lock/key solvability guarantee must still hold there.
            for seed = 1, 25 do
                local grid = Overworld.generate({
                    seed = seed, biome = "forest", encounterCount = 3, keyCount = 2,
                    encounters = { { kind = "combat", weight = 1 } },
                    objective = { name = "Boss" },
                })
                assert((grid:solve()), "auto-sized keyed seed " .. seed .. " unsolvable")
            end
        end,
    },
    {
        name = "explicit cols/rows override the encounter-count sizing",
        fn = function()
            local grid = Overworld.generate({
                cols = 8, rows = 7, seed = 7, biome = "forest", encounterCount = 3,
                encounters = { { kind = "combat", weight = 1 } },
            })
            -- EXACTLY, with nothing added. The old grid inflated a requested play area by a margin ring
            -- and a coastline surplus, so a caller asking for 41x29 got 49x37 of cells with the extra
            -- eaten back by the weathering. A floor is what it says it is.
            assert(grid.cols == 8, "explicit cols should win over auto-size")
            assert(grid.rows == 7, "explicit rows should win over auto-size")
        end,
    },
    {
        name = "always-encounters are force-placed",
        fn = function()
            local grid = Overworld.generate({
                cols = 41, rows = 29, seed = 4, biome = "forest",
                encounterCount = { min = 6, max = 9 },
                encounters = { { kind = "combat", weight = 1 } },
                alwaysEncounters = { { id = "encounter_elite", kind = "elite", name = "Phoenix" } },
            })
            local found = false
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.id == "encounter_elite" then found = true end
                end
            end
            assert(found, "guaranteed elite was not placed")
        end,
    },
    {
        -- An ascent is a route, not a region: the authored order of `alwaysEncounters` has to survive
        -- placement, or "pickets, then the line, then the breach camp" is just three encounters in a
        -- bag. Distance from the start is what "further up the mountain" means on a generated map.
        name = "an ascent lays its guaranteed encounters out in authored order, climbing",
        fn = function()
            local ids = { "encounter_siege_pickets", "encounter_siege_line", "encounter_siege_breach" }
            for _, seed in ipairs({ 3, 17, 91, 404 }) do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, biome = "castle", ascent = true,
                    encounterCount = { min = 3, max = 3 }, keyCount = 0,
                    objective = { name = "The Gate" },
                    encounters = { { kind = "combat", weight = 1 } },
                    alwaysEncounters = {
                        { id = ids[1], kind = "combat", name = "Pickets" },
                        { id = ids[2], kind = "combat", name = "Line" },
                        { id = ids[3], kind = "elite", name = "Breach" },
                    },
                })

                -- Same key the generator uses internally (models/overworld.lua's cellKey).
                local function key(x, y) return y * 100000 + x end
                local dist = grid:bfsDistances(grid.start)
                local at, onSpine = {}, {}
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.encounter and c.encounter.id then
                            at[c.encounter.id] = dist[key(x, y)]
                            onSpine[c.encounter.id] = grid.spineKeys[key(x, y)] or false
                        end
                    end
                end

                for i = 1, #ids do
                    assert(at[ids[i]], "seed " .. seed .. ": " .. ids[i] .. " was not placed")
                end
                assert(at[ids[1]] <= at[ids[2]] and at[ids[2]] <= at[ids[3]],
                    "seed " .. seed .. ": the climb must run outward from the start, got "
                    .. at[ids[1]] .. " / " .. at[ids[2]] .. " / " .. at[ids[3]])

                -- ...and the peak is beyond all of it.
                local objd = dist[key(grid.objective.x, grid.objective.y)]
                assert(objd and objd > at[ids[3]],
                    "seed " .. seed .. ": the objective must sit past the last encounter on the road")

                -- ORDER IS NOT SPACING. The three assertions above all held while every marker sat
                -- within six steps of the start and forty tiles of road ran empty behind them -- an
                -- ordered pile on the doorstep is still a pile. A climb has to be spread over the
                -- climb, so check the fractions: marker k of n belongs near k/(n+1) of the way up.
                for i, id in ipairs(ids) do
                    local want = i / (#ids + 1)
                    local got = at[id] / objd
                    assert(math.abs(got - want) <= 0.15, "seed " .. seed .. ": " .. id
                        .. " should sit near " .. want .. " of the way up the road, sits at " .. got)
                end

                -- And on the road, not down a side spur the climb never passes: on an ascent the
                -- fight IS the route, which only means anything if the route is where it stands.
                for _, id in ipairs(ids) do
                    assert(onSpine[id], "seed " .. seed .. ": " .. id .. " sits off the spine")
                end
            end
        end,
    },
    {
        name = "same seed reproduces an identical map",
        fn = function()
            local a = gen({ seed = 777 })
            local b = gen({ seed = 777 })
            assert(signature(a) == signature(b), "identical seeds diverged")
        end,
    },
    {
        name = "different seeds produce different maps",
        fn = function()
            local a = gen({ seed = 1 })
            local b = gen({ seed = 2 })
            assert(signature(a) ~= signature(b), "different seeds gave same map")
        end,
    },
    {
        name = "every trail tile is reachable from the start",
        fn = function()
            local grid = gen()
            local seen = grid:reachable(grid:startCell())
            local reached = 0
            for _ in pairs(seen) do reached = reached + 1 end
            assert(reached == countWalkable(grid),
                "trail not fully connected: reached " .. reached .. " of " .. countWalkable(grid))
        end,
    },
    {
        name = "objective + lock/key maps are always solvable (many seeds)",
        fn = function()
            for seed = 1, 40 do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, riverCount = 3,
                    encounterCount = 8, keyCount = 2, objective = { name = "Boss" },
                })
                local solved, info = grid:solve()
                assert(solved, "seed " .. seed .. " unsolvable: objectiveReached="
                    .. tostring(info.objectiveReached))
            end
        end,
    },
    {
        name = "keyless maps are solvable and gate-free",
        fn = function()
            local grid = gen({ keyCount = 0 })
            assert(#grid.keyIds == 0, "keyless map still has keyIds")
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    assert(grid:get(x, y).gate == nil, "keyless map has a gate")
                end
            end
            assert((grid:solve()), "keyless map unsolvable")
        end,
    },
    {
        name = "exactly one objective encounter, never on the start tile",
        fn = function()
            local grid = gen()
            local count = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.kind == "objective" then count = count + 1 end
                end
            end
            assert(count == 1, "expected 1 objective, found " .. count)
            assert(not (grid.objective.x == grid.start.x and grid.objective.y == grid.start.y),
                "objective placed on start tile")
        end,
    },
    {
        name = "encounter count respects the cap and skips the start tile",
        fn = function()
            local grid = gen({ encounterCount = 5 })
            local nonObjective = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.kind ~= "objective" then
                        nonObjective = nonObjective + 1
                    end
                end
            end
            -- objective is placed separately, then up to `encounterCount` more.
            assert(nonObjective <= 5, "too many encounters: " .. nonObjective)
            assert(grid:startCell().encounter == nil, "encounter placed on start tile")
        end,
    },
    {
        name = "the spur ends in the reward and the fight is in the way of it",
        fn = function()
            -- THIS CASE ASSERTED A WEAKER CLAIM, and the rewrite is the composition getting sharper
            -- rather than the test being bent to pass.
            --
            -- It read "encounters keep a partial dead-end bias": encounters of ANY kind had to be
            -- over-represented on degree-1 tiles, because on the old board a spur ending in nothing was
            -- a walk you were charged for and not paid, and scattering some stops down them was the
            -- answer. Two passes have since taken that job over and split it in half:
            --
            --   placeCaches   takes the dead ends FIRST -- the find is at the end of the spur;
            --   blockRoutes   moves most fights onto CUTS -- and a leaf is never a cut, since removing
            --                 it strands nothing.
            --
            -- So fights leave the dead ends by construction and boons arrive there by construction,
            -- which is the pairing the old guarded-boon pass was reaching for and could not reliably
            -- get. Asserting the undifferentiated version now would be asserting the weaker shape back:
            -- it passes just as well when a fight sits on a leaf gating nothing.
            local boonOnDead, boonTotal = 0, 0
            local fightOnCut, fightTotal = 0, 0
            local deadCands, allCands = 0, 0
            for seed = 1, 25 do
                local grid = Overworld.generate({
                    cols = 10, rows = 10, seed = seed, biome = "forest",
                    encounterCount = { min = 6, max = 9 }, keyCount = 0,
                    encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                    ascent = true, -- a descent floor: combat is the route, so every cut is fair
                })
                local total = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if grid:typeWalkable(grid.cells[y][x].tile) then total = total + 1 end
                    end
                end
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if typeWalkable(c.tile)
                            and (c.encounter == nil or c.encounter.kind ~= "objective") then
                            local isDead = #grid:pathNeighbors(x, y) == 1
                            allCands = allCands + 1
                            if isDead then deadCands = deadCands + 1 end

                            local e = c.encounter
                            if c.cache or (e and (e.kind == "treasure" or e.kind == "relic_cache")) then
                                boonTotal = boonTotal + 1
                                if isDead then boonOnDead = boonOnDead + 1 end
                            end
                            if e and (e.kind == "combat" or e.kind == "elite") then
                                fightTotal = fightTotal + 1
                                -- Is this place the only way to something?
                                local was = c.tile
                                c.tile = "thicket"
                                local reach = grid:reachable(grid:startCell())
                                c.tile = was
                                local n = 0
                                for _ in pairs(reach) do n = n + 1 end
                                if total - 1 - n > 0 then fightOnCut = fightOnCut + 1 end
                            end
                        end
                    end
                end
            end
            assert(boonTotal > 0 and fightTotal > 0, "the fixture floors hold neither boons nor fights")

            -- THE FIND IS AT THE END OF THE SPUR: boons over-represented on dead ends against a uniform
            -- sprinkle, which is what placeCaches taking them first is for.
            local baseline = deadCands / allCands
            local boonRate = boonOnDead / boonTotal
            assert(boonRate > baseline, string.format(
                "boons should still favour the spur ends: %.3f against a uniform %.3f",
                boonRate, baseline))

            -- ...AND THE FIGHT IS IN THE WAY. Measured at 60%, which is Overworld.BLOCKING_SHARE; the
            -- floor is well under it so a retune of the share does not have to come and edit this.
            local cutRate = fightOnCut / fightTotal
            assert(cutRate >= 0.4, string.format(
                "only %.0f%% of fights are the only way to something -- the floor is a shopping list",
                cutRate * 100))
        end,
    },
    {
        name = "no two stops share a side",
        fn = function()
            -- THE SPACING RULE, AND WHAT IT USED TO HAVE TO BE. On a tile board this case measured a
            -- Poisson disc: mean nearest-neighbour distance, the share of stops within two tiles of
            -- another, and the worst pile one lit disc could show. It had to, because a floor's stops
            -- were darts thrown at nine hundred tiles and darts clump -- five fights inside one lit disc
            -- with an empty map behind them was the complaint that produced the rule.
            --
            -- A place is a stop's own unit now, so the whole question collapses to one: do two stops
            -- share a side. Nothing can stack (a place holds one thing by construction) and nothing can
            -- be "nearly" adjacent. Asserted as a SHARE rather than never, because the gap relaxes on a
            -- floor too crowded to meet it -- which is the graceful partial every pass in the generator
            -- takes, and is honest about a floor asked to hold more than it has room for.
            local pairsAdjacent, stopsTotal = 0, 0
            for seed = 1, 30 do
                local grid = Overworld.generate({
                    cols = 9, rows = 9, seed = seed, biome = "forest",
                    encounterCount = { min = 10, max = 12 }, keyCount = 0,
                    encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                })
                local stops = {}
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.encounter and c.encounter.kind ~= "objective" then stops[#stops + 1] = c end
                    end
                end
                assert(#stops >= 8, "expected a dense floor to hold its stops, got " .. #stops)
                for _, a in ipairs(stops) do
                    stopsTotal = stopsTotal + 1
                    for _, b in ipairs(stops) do
                        if a ~= b and math.abs(a.x - b.x) + math.abs(a.y - b.y) == 1 then
                            pairsAdjacent = pairsAdjacent + 1
                            break
                        end
                    end
                end
            end
            local share = pairsAdjacent / stopsTotal
            assert(share <= 0.45, string.format(
                "%.0f%% of stops sit next to another -- the gap is not being walked widest-first",
                share * 100))
        end,
    },
    {
        -- Skippable combats: the objective must be reachable without clearing a fight, so no
        -- combat/elite may sit on the start->objective spine (a wounded party routes around).
        -- The generator persists that spine as grid.spineKeys.
        name = "no combat/elite encounter sits on the objective spine (non-ascent)",
        fn = function()
            local function key(x, y) return y * 100000 + x end
            for seed = 1, 30 do
                local grid = Overworld.generate({
                    seed = seed, biome = "forest", encounterCount = { min = 6, max = 10 },
                    keyCount = 1, objective = { name = "Boss" },
                    encounters = { { kind = "combat", weight = 3 }, { kind = "elite", weight = 1 },
                                   { kind = "treasure", weight = 1 } },
                })
                assert(grid.spineKeys, "generate should persist a spine")
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        local e = c.encounter
                        if e and (e.kind == "combat" or e.kind == "elite") then
                            assert(not grid.spineKeys[key(x, y)],
                                "seed " .. seed .. ": a " .. e.kind .. " sits on the spine at "
                                .. x .. "," .. y)
                        end
                    end
                end
            end
        end,
    },
    {
        -- ONE STEP, on a rolled floor and an authored one alike. It was three on a rolled board and two
        -- on an authored leg, because a tile board's radius was a NEIGHBOURHOOD -- three tiles of trail
        -- you could read ahead and route around. A cell is a place now: one step is four places, and a
        -- radius of two would hand over most of a small floor at a stroke. What the fog hides is not
        -- where the places are (the silhouette is drawn from arrival) but what is standing in them.
        name = "the fog lifts one step, on a rolled floor and an authored one alike",
        fn = function()
            local rolled = Overworld.generate({ seed = 5, biome = "forest", encounterCount = 4,
                encounters = { { kind = "combat", weight = 1 } } })
            assert(rolled.visionRadius == 1, "a rolled floor reads the places beside it, and no further")
            local authored = Overworld.fromLayout({
                biome = "forest", objective = { name = "X" },
                layoutDef = { biome = "forest", map = { "S.X" } },
            })
            assert(authored.visionRadius == 1, "an authored floor reads exactly as far")
        end,
    },
    {
        name = "reveal lights a circular disc of cells (fog of war)",
        fn = function()
            local grid = gen()
            local cx, cy = 15, 11 -- an interior cell so the radius stays in bounds
            assert(grid:get(cx, cy).seen == nil, "cell starts undiscovered")
            grid:reveal(cx, cy, 2)
            -- Centre and the cardinal edges of the disc are discovered.
            assert(grid:get(cx, cy).seen == true, "centre should be seen")
            assert(grid:get(cx + 2, cy).seen == true, "east edge should be seen")
            assert(grid:get(cx - 2, cy).seen == true, "west edge should be seen")
            assert(grid:get(cx, cy + 2).seen == true, "south edge should be seen")
            assert(grid:get(cx, cy - 2).seen == true, "north edge should be seen")
            -- The far corners of the bounding square fall outside the disc (circular,
            -- not square), and anything past the radius stays hidden.
            assert(grid:get(cx + 2, cy + 2).seen == nil, "diagonal corner is outside the disc")
            assert(grid:get(cx + 3, cy).seen == nil, "cell past the radius stays hidden")
            assert(grid:get(cx, cy + 3).seen == nil, "cell past the radius stays hidden")
        end,
    },
    {
        name = "reveal counts only cells discovered for the first time",
        fn = function()
            -- What the Poacher's Map gates on: a step into fog returns a positive count, and re-lighting
            -- the same disc returns 0, so re-treading known ground can never read as exploration.
            local grid = gen()
            local cx, cy = 15, 11
            local first = grid:reveal(cx, cy, 2)
            assert(first > 0, "the first look at a patch of fog discovers cells")
            assert(grid:reveal(cx, cy, 2) == 0, "lighting the same disc again discovers nothing")
            local shifted = grid:reveal(cx + 1, cy, 2)
            assert(shifted > 0 and shifted < first, "a step sideways discovers only the new sliver")
        end,
    },
    {
        name = "pixel <-> cell round-trips",
        fn = function()
            local grid = gen()
            for _, p in ipairs({ { 1, 1 }, { 10, 7 }, { grid.cols, grid.rows } }) do
                local px, py = grid:cellToPixel(p[1], p[2])
                local cx, cy = grid:pixelToCell(px, py)
                assert(cx == p[1] and cy == p[2], "top-left round-trip failed at " .. p[1] .. "," .. p[2])
                -- a point in the middle of the cell maps to the same cell
                local mx, my = grid:pixelToCell(px + grid.size / 2, py + grid.size / 2)
                assert(mx == p[1] and my == p[2], "mid-cell round-trip failed")
            end
        end,
    },
    {
        name = "quest map params flow through Quest.available without mutating blueprints",
        fn = function()
            local player = Player.new()
            player.prestige = 3
            player.completedQuests.quest_colosseum_slot_01 = true

            local found = Quest.get("quest_colosseum_slot_01")
            assert(found, "the Colosseum's posting resolves")
            assert(found.map, "map params not carried")
            -- blueprint still intact
            assert(Quest.defs.quest_colosseum_slot_01.id == nil, "quest blueprint mutated")
            assert(Quest.defs.quest_colosseum_slot_01.map.objective, "quest map blueprint mutated")
        end,
    },
    {
        name = "caches land on spare dead ends, never on top of other content",
        fn = function()
            local Material = require("models.material")
            local house = Material.houseFor("knight")
            local anyDeadEnd, anyHouse = false, false
            for seed = 1, 20 do
                local grid = Overworld.generate({
                    seed = seed, biome = "forest", encounterCount = { min = 5, max = 8 },
                    keyCount = 1, objective = { name = "Boss" }, houseMaterial = house,
                    encounters = { { kind = "combat", weight = 1 } },
                })
                local caches = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.cache then
                            caches = caches + 1
                            assert(not c.encounter and not c.gate and not c.key,
                                "seed " .. seed .. ": a cache doubled up on other content at " .. x .. "," .. y)
                            assert(typeWalkable(c.tile), "seed " .. seed .. ": a cache landed off the trail")
                            assert(not (grid.start.x == x and grid.start.y == y), "a cache sat on the start tile")
                            assert(next(c.cache.materials), "seed " .. seed .. ": an empty cache")
                            if #grid:pathNeighbors(x, y) == 1 then anyDeadEnd = true end
                            if c.cache.materials[house] then anyHouse = true end
                        end
                    end
                end
                assert(caches > 0, "seed " .. seed .. ": a rolled board paid out nothing")
                assert(caches <= grid.cacheTarget, "seed " .. seed .. ": more caches than the target")
                assert((grid:solve()), "seed " .. seed .. ": caches broke solvability")
            end
            assert(anyDeadEnd, "caches should prefer dead ends -- none landed on one across 20 seeds")
            assert(anyHouse, "the sponsoring house's stock should ride in the payload")
        end,
    },
    {
        name = "a cache's payload grows with the detour it cost, and is seed-stable",
        fn = function()
            local Material = require("models.material")
            local params = {
                seed = 77, biome = "forest", encounterCount = 8, keyCount = 1,
                objective = { name = "Boss" }, houseMaterial = Material.houseFor("mage"),
                encounters = { { kind = "combat", weight = 1 } },
            }
            local a = Overworld.generate(params)
            local b = Overworld.generate(params)

            local function haul(grid)
                local out, byDetour = {}, {}
                local dist = grid:spineDistances()
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.cache then
                            local total = 0
                            for _, n in pairs(c.cache.materials) do total = total + n end
                            out[#out + 1] = x .. "," .. y .. "=" .. total
                            byDetour[#byDetour + 1] = { d = dist[c.y * 100000 + c.x] or 0, total = total }
                        end
                    end
                end
                table.sort(out)
                return table.concat(out, "|"), byDetour
            end

            local sigA, detours = haul(a)
            local sigB = haul(b)
            assert(sigA == sigB, "the same seed must lay the same caches")
            -- A tile ON the route pays the floor; nothing further out ever pays less than it.
            local floor
            for _, e in ipairs(detours) do
                if e.d == 0 then floor = math.min(floor or e.total, e.total) end
            end
            for _, e in ipairs(detours) do
                if floor and e.d > 0 then
                    assert(e.total >= floor, "a detour paid less than a tile on the road")
                end
            end
        end,
    },

    -- THE REST GUARANTEE. Both halves ratchet, because this is the failure that hid in the gap between
    -- two files that each read correctly on their own: models/overworld.lua named "rest" in its
    -- guaranteeKinds, data/encounters/encounter_rest.lua set weight 0 to stay out of the random draw, and
    -- the guarantee read the WEIGHT-FILTERED pool -- so it silently found nothing and every rolled board
    -- shipped with no refund at all. A test on either file alone would have passed.
    {
        name = "overworld: every rolled board carries a rest",
        fn = function()
            local Encounter = require("models.encounter")
            -- The real, weight-filtered pool -- the exact table states/game.lua passes, and the one that
            -- does NOT contain a rest. If this guarantee ever starts depending on the pool again, it fails.
            local pool = Encounter.pool({ prestige = 3, biome = "forest" })
            for _, e in ipairs(pool) do
                assert(e.kind ~= "rest", "encounter_rest should stay out of the weighted pool (weight 0)")
            end

            for seed = 1, 40 do
                local grid = Overworld.generate({
                    biome = "forest", seed = seed * 977, encounters = pool,
                    encounterCount = { min = 8, max = 11 },
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                })
                local rests = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local enc = grid:get(x, y).encounter
                        if enc and enc.kind == "rest" then rests = rests + 1 end
                    end
                end
                assert(rests >= 1, "seed " .. seed .. " rolled a board with no rest on it")
            end
        end,
    },
    {
        name = "overworld: a rest is seated on or beside the critical path",
        fn = function()
            local Encounter = require("models.encounter")
            local pool = Encounter.pool({ prestige = 3, biome = "forest" })
            -- One tile: the radius GUARANTEE.rest declares. A refund the party has to leave the road to
            -- reach is another boon to earn, not the pressure valve the attrition model needs.
            local RADIUS = 1

            for seed = 1, 40 do
                local grid = Overworld.generate({
                    biome = "forest", seed = seed * 977, encounters = pool,
                    encounterCount = { min = 8, max = 11 },
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                })
                local dist = grid:spineDistances()
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.encounter and c.encounter.kind == "rest" then
                            local d = dist[c.y * 100000 + c.x]
                            assert(d and d <= RADIUS,
                                "seed " .. seed .. ": rest at " .. x .. "," .. y
                                .. " sits " .. tostring(d) .. " tiles off the road")
                        end
                    end
                end
            end
        end,
    },
    {
        name = "overworld: a longer quest gets more rests",
        fn = function()
            local Encounter = require("models.encounter")
            local pool = Encounter.pool({ prestige = 3, biome = "forest" })
            local function restsOn(count, seed)
                local grid = Overworld.generate({
                    biome = "forest", seed = seed, encounters = pool, encounterCount = count,
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                })
                local n = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local enc = grid:get(x, y).encounter
                        if enc and enc.kind == "rest" then n = n + 1 end
                    end
                end
                return n
            end
            -- One per 6 stops (GUARANTEE.rest.per): a short errand gets one refund, a 16-stop march
            -- gets three. The run's only recovery has to scale with how long the run is.
            for seed = 1, 12 do
                assert(restsOn(6, seed * 31) >= 1, "a 6-stop board should carry one rest")
                assert(restsOn(16, seed * 31) >= 3, "a 16-stop board should carry three rests")
            end
        end,
    },

}
