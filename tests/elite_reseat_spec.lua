-- Tests for Descent.reseatElites / Overworld:reseatElites: an elite is met once a trip, and a new trip
-- walking back onto a kept floor finds its elites dealt again -- a possibly different set, on new places.
--
-- Built on a bare board through Overworld.fromSnapshot rather than the generator, for gate_spec's reason:
-- what is under test is where an elite lands, and a rolled board would put its own stops in the answer.

local Descent = require("models.descent")
local Overworld = require("models.overworld")

-- A 7x7 floor of open places, the door in the corner, two elites laid deep (one already beaten), a
-- sprung mimic and a spent cache.
local function kept()
    local cells = {}
    for y = 1, 7 do
        cells[y] = {}
        for x = 1, 7 do cells[y][x] = { tile = "path" } end
    end
    cells[7][7].encounter = { kind = "elite", id = "encounter_a", tier = 3 }
    cells[7][7].cleared = true
    cells[5][7].encounter = { kind = "elite", id = "encounter_b", tier = 3 }
    cells[7][4].encounter = { kind = "elite", id = "encounter_mimic", mimic = true }
    cells[7][4].cleared = true
    cells[4][6].encounter = { kind = "treasure", id = "chest" }
    cells[4][6].cleared = true
    return Overworld.fromSnapshot({
        cols = 7, rows = 7, tilesetId = "forest", start = { x = 1, y = 1 }, cells = cells,
    })
end

local POOL = {
    { kind = "elite", id = "encounter_a", name = "A", weight = 1 },
    { kind = "elite", id = "encounter_b", name = "B", weight = 1 },
    { kind = "elite", id = "encounter_c", name = "C", weight = 1 },
    { kind = "elite", id = "encounter_d", name = "D", weight = 1 },
    { kind = "rest", id = "encounter_rest", weight = 1 },
}

-- The elites standing on a board, as "id@x,y" sorted, plus the cells they stand on.
local function standing(grid)
    local out, cells = {}, {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            if e and e.kind == "elite" and not e.mimic then
                out[#out + 1] = e.id .. "@" .. x .. "," .. y
                cells[#cells + 1] = c
            end
        end
    end
    table.sort(out)
    return table.concat(out, " "), cells
end

local function trip(n, floor)
    return { seed = 4242, floor = floor or 3 }, { runsStarted = n }
end

return {
    { name = "a new trip stands the same number of elites, all on their feet, all deep", fn = function()
        local grid = kept()
        local run, player = trip(2)
        local n = Descent.reseatElites(grid, POOL, run, player)
        assert(n == 2, "the board was laid with two elites and reseated " .. n)

        local _, cells = standing(grid)
        assert(#cells == 2, "two elites stand on the board, got " .. #cells)
        local dist = grid:bfsDistances(grid:startCell())
        local far = 0
        for _, d in pairs(dist) do if d > far then far = d end end
        local seen = {}
        for _, c in ipairs(cells) do
            assert(not c.cleared, "an elite came back already beaten -- it is met once a trip, not never")
            local d = dist[grid:cellKey(c.x, c.y)]
            assert(d / far >= 0.5, "an elite was reseated on the near half, at depth " .. d .. "/" .. far)
            assert(c.encounter.tier, "a reseated elite carries no pip")
            assert(not seen[c.encounter.id], "the same elite stands twice while the pool had spares")
            seen[c.encounter.id] = true
        end
    end },

    { name = "a sprung mimic and a spent place are left exactly as they were", fn = function()
        local grid = kept()
        Descent.reseatElites(grid, POOL, trip(2))
        local mimic = grid.cells[7][4]
        assert(mimic.encounter and mimic.encounter.mimic and mimic.cleared,
            "a sprung mimic is a spent chest, and reseating it would be a printing press")
        local chest = grid.cells[4][6]
        assert(chest.encounter and chest.encounter.kind == "treasure" and chest.cleared,
            "a place moved or woke up -- the maze is permanent")
    end },

    { name = "one trip reproduces as itself, and the next trip is a different floor", fn = function()
        local a1 = kept()
        Descent.reseatElites(a1, POOL, trip(5))
        local a2 = kept()
        Descent.reseatElites(a2, POOL, trip(5))
        assert(standing(a1) == standing(a2), "one seed dealt two different floors: "
            .. standing(a1) .. " vs " .. standing(a2))

        -- Across a handful of trips, both halves of the claim have to show: somewhere new, and
        -- potentially somebody new.
        local layouts, sets = {}, {}
        local nLayouts, nSets = 0, 0
        for t = 1, 8 do
            local g = kept()
            Descent.reseatElites(g, POOL, trip(t))
            local s, cells = standing(g)
            if not layouts[s] then layouts[s] = true; nLayouts = nLayouts + 1 end
            local ids = {}
            for _, c in ipairs(cells) do ids[#ids + 1] = c.encounter.id end
            table.sort(ids)
            local k = table.concat(ids, ",")
            if not sets[k] then sets[k] = true; nSets = nSets + 1 end
        end
        assert(nLayouts > 1, "eight trips stood the elites in the same places every time")
        assert(nSets > 1, "eight trips drew the same elites every time from a pool of four")
    end },

    { name = "on all fifteen real floors the reseat keeps the count, the pool and the depth",
      fn = function()
        local Player = require("models.player")
        local Seed = require("models.seed")
        local reseated = 0
        for floor = 1, Descent.FLOORS do
            local run = Descent.new(Player.new(), 909)
            run.floor = floor
            local mp = Descent.floorQuest(run, Player.new()).map
            -- THE FLOOR'S OWN POOL, named with its ground (a sweep without the biome rates a subset).
            local pool = Descent.floorPool({ depth = floor, biome = mp.biome })
            local grid = Overworld.generate({
                biome = mp.biome, cols = mp.cols, rows = mp.rows,
                seed = Seed.mix(909, floor), ascent = true, keyCount = 0,
                encounterCount = mp.encounters, cacheCount = mp.cacheCount,
                encounters = pool, wanderingCombat = true, combatShare = mp.combatShare,
                secrets = mp.secrets, exitAtStart = mp.exitAtStart,
                guaranteeKinds = mp.guaranteeKinds, guarantee = mp.guarantee,
            })
            local back = Overworld.fromSnapshot(grid:snapshot())
            local before = select(2, standing(back))
            local n = Descent.reseatElites(back, pool, run, { runsStarted = 3 })
            local _, after = standing(back)
            reseated = reseated + n
            assert(#after == #before or #before == 0,
                "floor " .. floor .. " stood " .. #before .. " elites and reseated " .. #after)

            local legal = {}
            for _, e in ipairs(pool) do if e.kind == "elite" then legal[e.id] = true end end
            local dist = back:bfsDistances(back:startCell())
            local far = 0
            for _, d in pairs(dist) do if d > far then far = d end end
            for _, c in ipairs(after) do
                assert(#before == 0 or legal[c.encounter.id],
                    "floor " .. floor .. " stood " .. c.encounter.id .. ", which its pool cannot deal")
                assert(not (c.cache or c.vault or c.trap or c.secret or c.gate or c.key),
                    "floor " .. floor .. " seated an elite on top of something already there")
                assert((dist[back:cellKey(c.x, c.y)] or 0) / far >= 0.5,
                    "floor " .. floor .. " seated an elite on the near half")
            end
        end
        assert(reseated > 0, "fifteen floors reseated nothing -- the sweep measured no elites at all")
    end },

    { name = "an empty elite pool leaves the woken board alone rather than emptying it", fn = function()
        local grid = kept()
        local before = standing(grid)
        local n = Descent.reseatElites(grid, { { kind = "rest", id = "encounter_rest", weight = 1 } },
            trip(2))
        assert(n == 0 and standing(grid) == before,
            "a floor whose pool has no elites lost the ones it stood")
    end },
}
