-- A HOLE IN THE FLOOR (Overworld:placeDrops, Descent.fall).
--
-- Step onto it and you are a floor deeper, having beaten nothing. The trade is depth for everything
-- else: the stair up there stays shut, its guard stays standing, and the rest of that floor's finds and
-- fights stay on it.
--
-- Two things can rot here and both are the kind that only show up in a save file:
--
--   * a hole on a general's floor, which would let a company walk past one of the seven
--   * a fall that credits the floor as CLEARED, which would report a floor beaten by a party that fell
--     through it -- and, on a general's floor, seal a circle nobody fought for

local Overworld = require("models.overworld")
local Descent = require("models.descent")
local Player = require("models.player")

local function floorWith(seed, drops)
    return Overworld.generate({
        biome = "forest", cols = 13, rows = 13, seed = seed,
        encounterCount = 10, cacheCount = 2, keyCount = 0, ascent = true,
        dropCount = drops,
        trapCount = { min = 0, max = 0 },
        encounters = { { kind = "combat", weight = 1 } },
    })
end

local function dropsOf(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and e.kind == "drop" then out[#out + 1] = grid.cells[y][x] end
        end
    end
    return out
end

return {
    { name = "a floor lays the holes it was asked for, and none when nobody asked", fn = function()
        assert(#dropsOf(floorWith(909, nil)) == 0,
            "a board that never mentioned drops grew one -- every authored quest would sprout holes")
        assert(#dropsOf(floorWith(909, { min = 0, max = 0 })) == 0,
            "a floor asked for no drops laid one")
        assert(#dropsOf(floorWith(909, { min = 1, max = 1 })) == 1, "asked for one hole and got another number")
    end },

    { name = "a hole is never beside the door, and never the only way through", fn = function()
        for seed = 1, 40 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            for _, c in ipairs(dropsOf(grid)) do
                assert(not (grid.start.x == c.x and grid.start.y == c.y),
                    "seed " .. seed .. ": a hole sits on the tile the company walks in on")
                -- Past the halfway mark of the crossing: the offer should arrive once the company has
                -- some idea what they would be leaving behind.
                local dist = grid:bfsDistances(grid:startCell())
                local far = 0
                for _, d in pairs(dist) do if d > far then far = d end end
                local d = dist[c.y * 100000 + c.x]
                assert(d and d >= math.floor(far * 0.5),
                    "seed " .. seed .. ": a hole sits in the near half of the floor, so the company can "
                    .. "skip the level before seeing any of it")
                -- Never a cut: a hole on the one route through is a toll, and this one bills a floor.
                assert(#grid:pathNeighbors(c.x, c.y) > 1,
                    "seed " .. seed .. ": a hole sits on the only way through")
            end
        end
    end },

    { name = "NO FLOOR A GENERAL STANDS ON HAS A HOLE IN IT, and neither does the bottom", fn = function()
        -- The promise that keeps the seven generals gates rather than scenery. Asked of the real
        -- descriptor rather than of the constant, so a change to how floorQuest decides fails here.
        local player = Player.new()
        local run = Descent.new(player, 31337)
        local generals, bottoms, ordinary = 0, 0, 0
        for floor = 1, Descent.FLOORS do
            run.floor = floor
            local mp = Descent.floorQuest(run, player).map
            if Descent.isBottom(floor) then
                bottoms = bottoms + 1
                assert(mp.dropCount == nil, "the bottom floor offers a hole with nothing under it")
            elseif Descent.isGeneralFloor(floor) then
                generals = generals + 1
                assert(mp.dropCount == nil,
                    "floor " .. floor .. " is held by a sin and has a hole in it -- a company could "
                    .. "drop past one of the seven")
            else
                ordinary = ordinary + 1
                assert(mp.dropCount ~= nil, "floor " .. floor .. " is ordinary ground and offers no hole")
            end
        end
        assert(generals == #Descent.SINS, "expected one general floor per sin, saw " .. generals)
        assert(bottoms == 1 and ordinary > 0, "the stack's shape is not what this case assumes")
    end },

    { name = "falling goes down WITHOUT crediting the floor as cleared", fn = function()
        local player = Player.new()
        local run = Descent.new(player, 77)
        run.floor, run.cleared = 4, 3

        Descent.fall(run, player)
        assert(Descent.depth(run) == 5, "falling did not move the company down a floor")
        assert(run.cleared == 3,
            "falling credited floor 4 as cleared (" .. run.cleared .. ") -- a floor the company fell "
            .. "through is not a floor they beat, and on a general's floor that would seal a circle "
            .. "nobody fought for")

        -- ...where taking the stair DOES credit it, which is the whole difference between the two.
        local run2 = Descent.new(player, 77)
        run2.floor, run2.cleared = 4, 3
        Descent.advance(run2, player)
        assert(run2.cleared == 4, "the stair stopped crediting the floor it left")
    end },

    { name = "the hole rate leaves most floors without one", fn = function()
        assert(Descent.FLOOR_DROPS.min == 0,
            "every floor having a hole makes the stack a chute and the stair decorative")
        assert(Descent.FLOOR_DROPS.max <= 2,
            "at " .. Descent.FLOOR_DROPS.max .. " holes a floor, skipping the level is the default play")
    end },
}
