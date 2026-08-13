-- Board renderer: run with
--
--     & "E:\LOVE\lovec.exe" . board-render [biome] [seed]
--
-- Dumps ONE rolled board to the console, twice: as ground, and as fightability. It exists because
-- `. board-report` answers "what do two hundred boards average" and cannot answer "what is wrong with
-- THIS one" -- and the layout work ahead is six new carve algorithms, each of which will be wrong in a
-- shape rather than in a number. A mean cannot show you a shape.
--
-- The second panel is the one to read. Every walkable tile carries a digit: the walkable count of the
-- best 8x8 window containing it (Overworld:bestBox), divided by eight, so `4` means 32 of 64 and is
-- exactly the floor an encounter may be seated on. An `O` means the tile is OPEN -- a full 3x3 of trail
-- around it -- which is the difference between a chamber and a warren, and which no board in the game
-- currently produces at all.
--
-- Read-only and seeded, so two runs with the same arguments print the same board.

local Overworld = require("models.overworld")
local Encounter = require("models.encounter")
local Biome = require("models.biome")

local M = {}

local DEFAULT_ENCOUNTERS = { min = 8, max = 11 }
local DEFAULT_DAY = 20

-- What a stop draws. Deliberately one character each and deliberately mnemonic rather than pretty: this
-- is read beside the fightability panel, so the eye needs to match positions between two grids.
local MARK = {
    combat = "c", elite = "E", objective = "X", treasure = "t", relic_cache = "R",
    rest = "r", merchant = "m", crossroads = "+", shrine = "s", town = "T",
}

local function groundChar(grid, cell)
    if cell.tile == "river" then return "~" end
    if cell.tile == "bridge" then return "=" end
    if not grid:typeWalkable(cell.tile) then return "#" end
    return "."
end

function M.run(args)
    args = args or {}
    local biome = args[1] or "forest"
    local seed = tonumber(args[2]) or 20260812

    if not Biome.defs[biome] then
        print("unknown biome '" .. tostring(biome) .. "'; known grounds:")
        local ids = {}
        for id in pairs(Biome.defs) do ids[#ids + 1] = id end
        table.sort(ids)
        print("  " .. table.concat(ids, "  "))
        return
    end

    local grid = Overworld.generate({
        biome = biome,
        encounterCount = DEFAULT_ENCOUNTERS,
        -- Sorted, or two runs of the same seed disagree about which stop landed where. See
        -- tools/board_report's stablePool for why the pool alone is not reproducible.
        encounters = require("tools.board_report").stablePool(DEFAULT_DAY),
        houseMaterial = "material_salt_iron",
        keyCount = 1,
        objective = { name = "Boss" },
        seed = seed,
    })

    print(string.format("BOARD RENDER -- %s, seed %d, %dx%d, spacing %d",
        biome, seed, grid.cols, grid.rows, grid.spacing or 0))
    print("")

    -- ---- panel one: the ground ------------------------------------------------
    for y = 1, grid.rows do
        local row = {}
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local ch = groundChar(grid, c)
            if grid.start and grid.start.x == x and grid.start.y == y then ch = "S"
            elseif c.encounter and MARK[c.encounter.kind] then ch = MARK[c.encounter.kind]
            elseif c.gate then ch = "G"
            elseif c.key then ch = "K"
            elseif c.cache then ch = "$" end
            row[#row + 1] = ch
        end
        print("  " .. table.concat(row))
    end
    print("")
    print("  S start  X objective  c fight  E elite  $ cache  K key  G gate")
    print("  r rest  t treasure  R reliquary  m merchant  + crossroads  s shrine")
    print("  . trail  # fill  ~ water  = bridge")
    print("")

    -- ---- panel two: is there a battle here ------------------------------------
    local sums = grid:walkableSums()
    for y = 1, grid.rows do
        local row = {}
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if not grid:typeWalkable(c.tile) then
                row[#row + 1] = " "
            elseif grid:isOpen(x, y) then
                row[#row + 1] = "O"
            else
                local _, _, score = grid:bestBox(x, y, sums)
                row[#row + 1] = tostring(math.min(9, math.floor(score / 8)))
            end
        end
        print("  " .. table.concat(row))
    end
    print("")
    print(string.format("  digit = best window containing this tile, /8. `%d` is the seating floor of %d.",
        math.floor(Overworld.BOX_OK / 8), Overworld.BOX_OK))
    print("  O = open ground: a full 3x3 of trail around it. A corridor never scores one.")
    print("")

    -- ---- what the fights actually got -----------------------------------------
    local worst, worstAt, seats = math.huge, nil, 0
    local openTiles = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if grid:typeWalkable(c.tile) and grid:isOpen(x, y) then openTiles = openTiles + 1 end
            if c.encounter and (c.encounter.kind == "combat" or c.encounter.kind == "elite") then
                local _, _, score = grid:bestBox(x, y, sums)
                seats = seats + 1
                if score < worst then worst, worstAt = score, { x, y } end
            end
        end
    end
    if worst == math.huge then worst = 0 end
    print(string.format("  %d fights seated; worst board %d of %d%s", seats, worst, Overworld.BOX * Overworld.BOX,
        worstAt and string.format(" at (%d,%d)", worstAt[1], worstAt[2]) or ""))
    print(string.format("  %d open tiles on the whole board", openTiles))
end

return M
