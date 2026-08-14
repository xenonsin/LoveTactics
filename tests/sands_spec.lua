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
        name = "no fight on the sand is cut from an empty room",
        fn = function()
            -- THE UNIT IS THE FIGHT, not the board. A bout is taken on an 8x8 window of these tiles
            -- (Arena.fromGrid), so what the furnishing rate has to be judged on is what stands in one of
            -- those sixty-four -- and the first two attempts at it, both tuned on whole-board numbers,
            -- put about two tiles of stone in a window and left a quarter of the bowl bare. A floor with
            -- nothing on it is a floor with no decisions on it.
            --
            -- So: every window a fight could be seated in has SOMETHING in it, and a typical one has
            -- enough to hold a lane behind. The lattice in Sands.carve is what makes the first of those
            -- true by construction rather than by luck.
            local BOX = 8
            for seed = 1, 8 do
                local grid = bowl(seed)
                local m = grid.margin
                local windows, blockedSum, barest = 0, 0, math.huge
                for y = 1 + m, grid.rows - m - BOX + 1 do
                    for x = 1 + m, grid.cols - m - BOX + 1 do
                        local walk, blocked = 0, 0
                        for j = y, y + BOX - 1 do
                            for i = x, x + BOX - 1 do
                                if typeWalkable(grid.cells[j][i].tile) then walk = walk + 1
                                else blocked = blocked + 1 end
                            end
                        end
                        -- Only windows a fight could actually be seated in (Overworld.BOX_OK = 32).
                        if walk >= 32 then
                            windows = windows + 1
                            blockedSum = blockedSum + blocked
                            if blocked < barest then barest = blocked end
                        end
                    end
                end
                assert(windows > 0, "seed " .. seed .. " has nowhere a fight could be seated")
                assert(barest >= 1, "seed " .. seed .. " can cut a fight from 64 tiles of bare sand")
                assert(blockedSum / windows >= 6, string.format(
                    "seed %d: a fight averages %.1f tiles of stone in it, which is an empty room",
                    seed, blockedSum / windows))
            end
        end,
    },
    {
        name = "the floor is still one room, and still mostly standing space",
        fn = function()
            -- The other side of the case above, and the reason the furnishing rate has a ceiling as well
            -- as a floor: a bowl you cannot cross is a warren wearing sand. Two guards, one for each
            -- failure -- the sand stays one room whatever is set down on it (Sands.place takes a piece
            -- straight back up if it ever splits the floor), and enough of it stays OPEN ground, a tile
            -- with a full 3x3 of floor around it, that a company can form up somewhere.
            --
            -- The bar is deliberately low and it used to be high. It read "most of the floor is open" --
            -- half of it, per board -- which was a whole-board claim tuned before anyone looked at what
            -- a FIGHT cut out of this ground contained, and it was the thing keeping the arena empty.
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
                -- A sixth, measured: the tightest of the eight boards reads 18%, because a small bowl is
                -- proportionally more rim and the rim is never open ground.
                assert(open / walk > 0.15, string.format(
                    "seed %d: only %.0f%% of the sand is open ground -- this is a warren, not a bowl",
                    seed, 100 * open / walk))
                local seen = grid:reachable(grid:startCell())
                local reached = 0
                for _ in pairs(seen) do reached = reached + 1 end
                assert(reached == walk, string.format(
                    "seed %d: the furniture cut the floor in two (%d of %d reachable)", seed, reached, walk))
            end
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
