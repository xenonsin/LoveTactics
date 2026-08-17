-- Board renderer: run with
--
--     & "E:\LOVE\lovec.exe" . board-render [biome] [seed]
--     & "E:\LOVE\lovec.exe" . board-render layout=tutorial_flight
--
-- Dumps ONE board to the console, twice: as ground, and as fightability. The second form takes a
-- HAND-AUTHORED map (data/overworld/*.lua) through Overworld.fromLayout instead of rolling one. That
-- form was missing for as long as authored maps have existed, which meant the only way to look at the
-- prologue's trail was to read its ASCII -- and the ASCII is the one view that cannot show you what the
-- game does to it: the fill is weathered on load (Overworld:decorate), so what the author typed and what
-- the player walks through are no longer the same board.
--
-- It exists because
-- `. board-report` answers "what do two hundred boards average" and cannot answer "what is wrong with
-- THIS one" -- and the layout work ahead is six new carve algorithms, each of which will be wrong in a
-- shape rather than in a number. A mean cannot show you a shape.
--
-- The second panel is the one to read. Every walkable tile carries a digit: how much of the best 8x8
-- window containing it the tile can actually CROSS TO (Overworld:bestBox, which counts what a fight
-- standing here could reach without leaving the box), divided by eight -- so `4` means 32 of 64 and is
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

-- The SOLID half is spelled out rather than flattened to one `#`, because the fill's variants are laid
-- by noise (Overworld:decorate) and a panel that prints them all the same cannot show you the one thing
-- that pass is for: whether the wood either side of a trail reads as country or as a flat plane.
local function groundChar(grid, cell)
    if cell.tile == "river" then return "~" end
    if cell.tile == "bridge" then return "=" end
    if cell.tile == "rock" then return "^" end
    if cell.tile == "grass" then return "," end
    if not grid:typeWalkable(cell.tile) then return "#" end
    if cell.tile == "forest" then return "f" end
    if cell.tile == "mountain" then return "m" end
    if cell.tile == "water" then return "w" end
    return "."
end

-- An authored map, plus its raw ASCII so the panel can print the glyphs the author typed (S, X, 1..9).
-- Those are consumed by fromLayout into encounters that only exist once a quest hands it an always-list,
-- and this tool has no quest -- so the marks come off the source rather than off the cells.
local function layoutBoard(id)
    local ok, def = pcall(require, "data.overworld." .. id)
    if not ok then return nil end
    return Overworld.fromLayout({ layout = id, objective = { name = "Objective" } }), def
end

function M.run(args)
    args = args or {}
    local layoutId = tostring(args[1] or ""):match("^layout=(.+)$")
    if layoutId then return M.runLayout(layoutId) end
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
        patrols = true,
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

-- The authored form. Same two panels, and a third reading nothing else prints: the window every
-- authored stop would be FOUGHT in (Overworld:bestBox), which is the number an authored map has no
-- generator to enforce for it -- a hand-typed chamber runs none of the seating passes and nothing on the
-- way in says so (see tests/flight_board_spec.lua).
function M.runLayout(id)
    local grid, def = layoutBoard(id)
    if not grid then
        print("unknown layout '" .. tostring(id) .. "'; known maps live in data/overworld/")
        return
    end

    print(string.format("BOARD RENDER -- authored layout '%s', biome %s, %dx%d",
        id, tostring(grid.biome), grid.cols, grid.rows))
    print("")

    for y = 1, grid.rows do
        local row, src = {}, def.map[y]
        for x = 1, grid.cols do
            local authored = src:sub(x, x)
            row[#row + 1] = authored:match("[SX%d]") and authored
                or groundChar(grid, grid.cells[y][x])
        end
        print("  " .. table.concat(row))
    end
    print("")
    print("  S start  X objective  1..9 route stop   . trail  f scrub  m high ground  w ford")
    print("  # thicket  ^ rock  , scrub-fill  ~ river  = bridge   (the fill is weathered on load)")
    print("")

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
    print("")

    -- Every authored mark, in the order the ASCII names them, against the floor a rolled board keeps.
    for y = 1, grid.rows do
        local src = def.map[y]
        for x = 1, grid.cols do
            local ch = src:sub(x, x)
            if ch:match("[X%d]") then
                local ox, oy, score = grid:bestBox(x, y, sums)
                print(string.format("  %s at (%2d,%2d)  window (%2d,%2d)  %2d of %d  %s",
                    ch, x, y, ox, oy, score, Overworld.BOX * Overworld.BOX,
                    score >= Overworld.BOX_OK and "seats a fight" or "corridor"))
            end
        end
    end
end

return M
