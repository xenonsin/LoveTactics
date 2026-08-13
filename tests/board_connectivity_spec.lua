-- ONE BOARD, NOT SEVERAL. Every walkable tile a generated map lays down must be reachable from the
-- start, on every ground and on any seed.
--
-- tests/overworld_spec.lua has asserted this since the generator existed, but only ever for the default
-- board -- the maze, with no biome named. That was the whole of the generator once. It is now one of
-- eight carves (models/layouts/), and a spec that walks the shape which was already right will stay
-- green through any number of grounds that are not: the desert came out in two or more pieces on 60% of
-- boards and every swamp board was in pieces, both while that test passed.
--
-- What a broken board looks like from inside the pipeline is the reason this needs its own guard rather
-- than a bug report. Nothing downstream complains: Overworld:computeStart takes the walkable tile
-- nearest the map centre without asking which piece it belongs to, and every pass after it -- the
-- objective, the gates, the caches, the fights -- works off a BFS from there. So a board cut in half
-- does not fail, it quietly becomes a board half the size, and the worst desert seed measured put the
-- party in a seven-tile pocket with 469 walkable tiles and every cache on the other side of the rock.
--
-- Rolled with the campaign's own default params (see tools/board_report), because a board is only ever
-- generated with content on it and the passes that place that content also carve.

local Overworld = require("models.overworld")
local Biome = require("models.biome")

local SEEDS = 12

local function roll(biome, seed)
    return Overworld.generate({
        biome = biome,
        seed = seed,
        encounterCount = { min = 8, max = 11 },
        keyCount = 1,
        objective = { name = "Boss" },
        houseMaterial = "material_salt_iron",
        encounters = { { kind = "combat", weight = 3 }, { kind = "elite", weight = 1 },
            { kind = "treasure", weight = 1 }, { kind = "rest", weight = 1 } },
    })
end

-- Walkable tiles the start cannot reach, and one of them for the failure message.
local function stranded(grid)
    local seen = grid:reachable(grid:startCell())
    local n, where = 0, nil
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            if grid:typeWalkable(c.tile) and not seen[grid:cellKey(x, y)] then
                n = n + 1
                where = where or (x .. "," .. y)
            end
        end
    end
    return n, where
end

return {
    {
        name = "every ground generates one connected board (all biomes, many seeds)",
        fn = function()
            local ids = {}
            for id in pairs(Biome.defs) do ids[#ids + 1] = id end
            table.sort(ids)
            assert(#ids > 0, "no biomes loaded")
            for _, id in ipairs(ids) do
                for seed = 1, SEEDS do
                    local grid = roll(id, seed)
                    local n, where = stranded(grid)
                    assert(n == 0, id .. " seed " .. seed .. ": " .. n
                        .. " walkable tiles unreachable from the start (e.g. " .. tostring(where) .. ")")
                end
            end
        end,
    },
    {
        -- The desert's compound is the one structure on the plain, and it is only a structure if you
        -- can get into it: a ridge laid across the approach used to seal all 64 of its tiles off.
        -- Asserted as "the interior is reachable", not "the door tile exists", because a door with rock
        -- outside it is exactly the bug and it looks like a door.
        name = "the desert ruin's interior is always reachable",
        fn = function()
            for seed = 1, 20 do
                local grid = roll("desert", seed)
                local seen = grid:reachable(grid:startCell())
                local reached = 0
                for _ in pairs(seen) do reached = reached + 1 end
                -- The compound is 9x7 of interior; a board that reaches fewer tiles than that has
                -- either sealed it or stranded the party somewhere smaller.
                assert(reached > 63, "desert seed " .. seed
                    .. ": start reaches only " .. reached .. " tiles")
            end
        end,
    },
}
