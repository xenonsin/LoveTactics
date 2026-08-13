-- The one terrain table (models/terrain.lua). The map and the board are the same ground, so these pin
-- the thing that made merging them possible: both layers read one table, and the two words that meant
-- two different things each became two tiles.

local Terrain = require("models.terrain")
local Tileset = require("models.tileset")
local Arena = require("models.arena")
local Overworld = require("models.overworld")

-- A board with NO content on it: every placement pass that reads the encounter pool is skipped, so what
-- is left is pure carved geometry. That matters because the pool is built with `pairs` over a registry
-- and its order is unspecified, which makes anything downstream of it unreproducible between runs.
local function bareBoard(biome, seed)
    return Overworld.generate({
        biome = biome, seed = seed,
        cols = 31, rows = 23,
        encounterCount = 0, cacheCount = 0, keyCount = 0,
        objective = { name = "Boss" },
    })
end

-- Order-independent checksum of WHICH TILES ARE WALKABLE. Deliberately not a hash of the tile names:
-- the names changed when the tables merged (`forest` became `thicket`, `water` became `river`) while
-- the shape of the maze did not, and it is the shape this is here to protect.
local function walkPrint(grid)
    local sum, n = 0, 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid:typeWalkable(grid.cells[y][x].tile) then
                sum = (sum + y * 31 + x * 7) % 1000003
                n = n + 1
            end
        end
    end
    return sum, n
end

return {
    {
        name = "terrain: every type answers every question, in one table",
        fn = function()
            for name, def in pairs(Terrain.TYPES) do
                assert(type(def.walkable) == "boolean", name .. " has no walkable")
                assert(type(def.moveCost) == "number", name .. " has no moveCost")
                assert(type(def.sightCost) == "number", name .. " has no sightCost")
                assert(type(def.index) == "number", name .. " has no art index")
                assert(type(def.color) == "table" and #def.color == 3, name .. " has no fallback colour")
                -- An unwalkable tile must cost the earth to enter, or a reach search would happily
                -- route a body through a wall it can never stand on.
                if not def.walkable then
                    assert(def.moveCost == math.huge, name .. " is solid but cheap to enter")
                end
            end
        end,
    },
    {
        name = "terrain: the map and the board cannot disagree about ground",
        fn = function()
            -- Both layers are views onto the one table. This is the assertion that stops the two
            -- opinions growing back: it fails the moment anyone re-declares a type in either place.
            for name, def in pairs(Terrain.TYPES) do
                assert(Arena.TILE_PROPS[name], "arena lost terrain type " .. name)
                assert(Arena.TILE_PROPS[name].walkable == def.walkable,
                    name .. ": the board disagrees with the map about walkability")
                assert(Tileset.TYPES[name], "the tileset lost terrain type " .. name)
                assert(Tileset.TYPES[name].walkable == def.walkable,
                    name .. ": the tileset disagrees with the terrain table")
            end
            -- ...and a biome may restyle a tile but never re-rule it.
            for _, id in ipairs({ "forest", "castle", "tundra", "swamp", "desert", "volcanic", "underworld", "colosseum" }) do
                local def = Tileset.get(id)
                for name, base in pairs(Terrain.TYPES) do
                    assert(def.tiles[name], id .. " tileset is missing " .. name)
                    assert(def.tiles[name].walkable == base.walkable,
                        id .. " tileset re-rules " .. name .. "'s walkability")
                end
            end
        end,
    },
    {
        name = "terrain: the two collided words are two tiles now",
        fn = function()
            -- forest: the map's fill was solid, the board's was soft cover. Both are wanted, and a
            -- clearing wants both at once -- thicket for the wall, forest for the cover inside it.
            assert(Terrain.TYPES.thicket.walkable == false, "thicket is the wall a trail is cut through")
            assert(Terrain.TYPES.forest.walkable == true, "forest is cover you walk through")
            assert(Terrain.TYPES.forest.sightCost > 0, "forest is soft cover or it is nothing")

            -- water: the map's was a barrier crossed at a bridge, the board's a wadeable ford.
            assert(Terrain.TYPES.river.walkable == false, "a river is crossed at a bridge")
            assert(Terrain.TYPES.water.walkable == true, "a ford is wadeable")
            assert(Terrain.TYPES.river.sightCost == 0, "you can see across a river, you just cannot cross")

            -- Both halves of the water split conduct: a lightning line does not care which one it is.
            local function hasTag(t, want)
                for _, tag in ipairs(Terrain.TYPES[t].tags or {}) do if tag == want then return true end end
                return false
            end
            assert(hasTag("water", "conductable"), "a ford conducts")
            assert(hasTag("river", "conductable"), "a river conducts")
        end,
    },
    {
        name = "terrain: the overworld only ever lays tiles the terrain table knows",
        fn = function()
            -- A tile the table has never heard of reads as solid (Terrain.get's fallback), which on a
            -- generated map would silently wall off a trail. Catch it here instead.
            for _, biome in ipairs({ "forest", "castle", "tundra", "swamp", "desert", "volcanic", "underworld", "colosseum" }) do
                local grid = bareBoard(biome, 555)
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local t = grid.cells[y][x].tile
                        assert(Terrain.TYPES[t],
                            biome .. " laid an unknown tile: " .. tostring(t))
                    end
                end
            end
        end,
    },
    {
        name = "terrain: the carved geometry is fixed, and a refactor may not move it",
        fn = function()
            -- THE FINGERPRINT. Six new carve algorithms are coming and each will be extracted from this
            -- one; this is what says an extraction changed nothing. It pins WALKABILITY rather than tile
            -- names, so a rename is free and a hole in a wall is not.
            --
            -- These numbers were read off the boards, not derived. If one moves, the question is not
            -- "what should it be" -- it is "which pass started laying different ground, and was that
            -- meant". Content is switched off (no encounters, caches or keys) so nothing here depends on
            -- the encounter pool's unspecified order.
            --
            -- MOVED ONCE, DELIBERATELY: Overworld:weatherEdges now eats a wandering coastline out of the
            -- rectangle each carve stops against, and generate() hands the carve a rectangle two tiles
            -- larger on every side to pay for it -- so these boards are both bigger and more chewed than
            -- they were, by different amounts on each ground. The castle is untouched to the digit
            -- (Rooms.ownsEdge), which is the check that the pass really is scoped to the edge.
            local EXPECTED = {
                forest = { 249403, 389 }, -- glades: the maze, opened (models/layouts/glades.lua)
                castle = { 212536, 401 }, -- rooms: chambers and halls (models/layouts/rooms.lua)
                tundra = { 349875, 568 }, -- floes: open flats quartered by meltwater, every lobe forded
                desert = { 413779, 624 }, -- open: a plain with ridges and one ruin
            }
            local bad = {}
            for biome, want in pairs(EXPECTED) do
                local sum, n = walkPrint(bareBoard(biome, 20260812))
                if n ~= want[2] or sum ~= want[1] then
                    bad[#bad + 1] = string.format("%s = { %d, %d }", biome, sum, n)
                end
            end
            -- Report EVERY ground that moved, not just the first: a carve change usually touches
            -- several, and one-at-a-time is four runs to learn what one run could have said.
            assert(#bad == 0, "carved geometry moved -- actual: " .. table.concat(bad, ", "))
        end,
    },
    {
        name = "a crossing is crossable: every meltwater lead keeps a ford",
        fn = function()
            -- REHOMED, not lost. Arena.GROUND_PROFILES' `band = "cross"` used to promise a rolled board
            -- exactly one free ford across its channel, tuned so the water could never cut the board in
            -- half. The profiles are gone with U6 -- a fight is taken on the map's own tiles, so nothing
            -- guesses at the ground any more -- and the promise moved to whichever layout lays the water.
            --
            -- The tundra is where it bites: floes cuts the flats into lobes with channels, and a lead
            -- with no crossing would strand the objective behind impassable water. Asserted the way the
            -- old spec was, on the TILE TYPE rather than on reachability, because water elsewhere is
            -- wadeable and a board can pass a connectivity check while its designed crossing is a wall.
            for seed = 1, 20 do
                local grid = Overworld.generate({
                    biome = "tundra", seed = seed * 91, cols = 37, rows = 25,
                    encounterCount = 6, keyCount = 1, objective = { name = "Boss" },
                    houseMaterial = "material_iron",
                })
                local rivers, bridges = 0, 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local t = grid.cells[y][x].tile
                        if t == "river" then rivers = rivers + 1 end
                        if t == "bridge" then bridges = bridges + 1 end
                    end
                end
                if rivers > 0 then
                    assert(bridges > 0, string.format(
                        "seed %d: %d tiles of meltwater and not one ford", seed * 91, rivers))
                end
                -- ...and the board is still one piece: every walkable tile reachable from the start.
                local reached, walkable = grid:reachable(), 0
                local seen = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if grid:typeWalkable(grid.cells[y][x].tile) then walkable = walkable + 1 end
                    end
                end
                for _ in pairs(reached) do seen = seen + 1 end
                assert(seen == walkable, string.format(
                    "seed %d: %d of %d walkable tiles are cut off", seed * 91, walkable - seen, walkable))
            end
        end,
    },
}
