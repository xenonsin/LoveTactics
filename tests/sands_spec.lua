-- THE BOWL (models/layouts/sands.lua): the Colosseum's own ground, and the only board in the game that
-- is a building. What is pinned here is the three claims the carve makes, because every one of them is
-- load-bearing somewhere else:
--
--   it is a ROOM         -- one oval of floor, no route, and the wall the same distance away whichever
--                           way you run. If it stops being that it is just an expensive plain.
--   it has DEAD ENDS     -- the pens under the stands. placeObjectiveAndGates insists on a strict dead
--                           end to hang the objective and its gate chain on, and an oval has no cut
--                           vertex anywhere, so without them this layout cannot carry a quest at all.
--   the STANDS HOLD      -- no walkable tile in the margin ring, the same rule every ground obeys, and
--                           the one that stops a bowl having a hole kicked in the side of it.
--
-- Connectivity is asserted for every ground at once in tests/board_connectivity_spec.lua; this file
-- takes the properties only this carve has.

local Overworld = require("models.overworld")
local Tileset = require("models.tileset")
local Biome = require("models.biome")

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

local function bowl(seed)
    return Overworld.generate({
        biome = "colosseum", seed = seed,
        encounterCount = { min = 6, max = 8 }, keyCount = 1, cacheCount = 2,
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
        objective = { name = "The Card" },
    })
end

-- Walkable tiles with exactly one walkable neighbour: the strict dead ends the placement passes want.
local function deadEnds(grid)
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if typeWalkable(grid.cells[y][x].tile) and #grid:pathNeighbors(x, y) == 1 then
                n = n + 1
            end
        end
    end
    return n
end

return {
    {
        name = "the colosseum is a ground, an oval and a card: blueprint, tileset, layout",
        fn = function()
            local def = Biome.defs.colosseum
            assert(def, "no data/biomes/colosseum.lua")
            assert(def.layout == "sands", "the bowl is carved by models/layouts/sands.lua")
            assert(def.rivers == 0, "nothing runs through a floor the crowd paid to see")
            assert(Tileset.defs[def.tileset], "the colosseum names a missing tileset")
            -- The curated debut board is the same place and must say so, or the prologue's climax --
            -- every line of which is about the sand -- is fought on flagstone.
            local Arena = require("models.arena")
            assert(Arena.defs.colosseum_sand.biome == "colosseum",
                "the debut's own board still names another ground")
        end,
    },
    {
        name = "the floor is one room, and most of it is standing space",
        fn = function()
            -- OPEN ground -- a tile with a full 3x3 of floor around it -- is what a bowl is for. Every
            -- other ground in the game is mostly edge; this one has to be mostly middle, or the carve
            -- has quietly become a plain with walls in it.
            --
            -- Half the floor is the bar, taken across the eight boards rather than on each: an oval's
            -- rim is never open ground and a small board is nearly all rim, so a single tight seed
            -- reading 50% is the shape working, not failing. The per-board floor below is the guard
            -- against the shape actually going -- a bowl that fell to a third would be a board of
            -- corridors wearing sand.
            local walkAll, openAll = 0, 0
            for seed = 1, 8 do
                local grid = bowl(seed)
                local walk, open = 0, 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if typeWalkable(grid.cells[y][x].tile) then
                            walk = walk + 1
                            if grid:isOpen(x, y) then open = open + 1 end
                        end
                    end
                end
                assert(walk > 0, "seed " .. seed .. " carved no floor at all")
                assert(open / walk > 0.45, string.format(
                    "seed %d: only %.0f%% of the sand is open ground -- this is a plain, not a bowl",
                    seed, 100 * open / walk))
                walkAll, openAll = walkAll + walk, openAll + open
            end
            assert(openAll / walkAll > 0.5, string.format(
                "the bowl averages %.0f%% open ground across eight boards", 100 * openAll / walkAll))
        end,
    },
    {
        name = "the pens give the oval the dead ends it cannot grow itself",
        fn = function()
            -- An oval has no cut vertex anywhere, so every one of these is a pen or its mouth. Two is
            -- the floor rather than the target: the objective takes one and the gate chain wants
            -- another, and a board that offers exactly that has nothing left over for a boon.
            for seed = 1, 8 do
                local grid = bowl(seed)
                assert(deadEnds(grid) >= 2, "seed " .. seed .. " cut no pens: nowhere to seat a gate")
                assert(grid.objective, "seed " .. seed .. " seated no objective")
                assert((grid:solve()), "seed " .. seed .. " is unsolvable with its own keys")
            end
        end,
    },
    {
        name = "the card is fought in the middle and the company walks in from the bottom",
        fn = function()
            -- Sands.anchors, and the reason it exists: the shared rules put the START in the middle of
            -- the map and the OBJECTIVE on a far dead end, which on this ground means beginning in the
            -- centre of the sand and holding the bout in a cage under the stands -- the arena exactly
            -- inside out. Two tiles of slack on the middle, because furniture standing on the centre
            -- moves the anchor rather than dropping it.
            for seed = 1, 8 do
                local grid = bowl(seed)
                local m = grid.margin
                local x0, x1 = 1 + m, grid.cols - m
                local y0, y1 = 1 + m, grid.rows - m
                local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

                assert(math.abs(grid.objective.x - cx) <= 2 and math.abs(grid.objective.y - cy) <= 2,
                    string.format("seed %d fought the card at %d,%d, not in the middle (%d,%d)",
                        seed, grid.objective.x, grid.objective.y, cx, cy))
                assert(grid.start.y >= y1 - (y1 - y0) * 0.15,
                    string.format("seed %d let the company in at row %d, not at the bottom (%d)",
                        seed, grid.start.y, y1))
                assert(math.abs(grid.start.x - cx) <= 3,
                    string.format("seed %d put the gate at column %d rather than under the middle",
                        seed, grid.start.x))
            end
        end,
    },
    {
        name = "there are no locked doors on the sand",
        fn = function()
            -- `bowl` asks for a key. A gate belongs on the tile before a dead end, where it genuinely
            -- locks something; the objective is in the open middle here, so a gate on the road to it is
            -- walked around and the chain is skipped instead (Overworld:placeObjectiveAndGates).
            for seed = 1, 8 do
                local grid = bowl(seed)
                assert(#grid.keyIds == 0, "seed " .. seed .. " hung a key hunt on an open floor")
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        assert(not grid.cells[y][x].gate,
                            "a locked gate at " .. x .. "," .. y .. " on seed " .. seed)
                    end
                end
            end
        end,
    },
    {
        name = "the stands hold all the way round",
        fn = function()
            for seed = 1, 8 do
                local grid = bowl(seed)
                local m = grid.margin
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if x <= m or x > grid.cols - m or y <= m or y > grid.rows - m then
                            assert(not typeWalkable(grid.cells[y][x].tile),
                                "a hole in the stands at " .. x .. "," .. y .. " (seed " .. seed .. ")")
                        end
                    end
                end
            end
        end,
    },
    {
        name = "the bowl is not weathered: a wall someone built keeps its shape",
        fn = function()
            -- Sands.ownsEdge. The coastline pass (Overworld:weatherEdges) would chew the stands into a
            -- ragged cave mouth, and it would also pad the rectangle to pay for the chewing -- so the
            -- sizing is the check that reads cleanest.
            local grid = bowl(3)
            assert(grid.coast == 0, "the bowl was padded for a coastline it must never be given")
        end,
    },
}
