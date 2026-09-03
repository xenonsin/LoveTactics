-- Floor renderer: run with
--
--     & "E:\LOVE\lovec.exe" . board-render [biome] [seed] [size=N]
--     & "E:\LOVE\lovec.exe" . board-render layout=tutorial_flight
--
-- Dumps ONE floor to the console, twice: as ground, and as depth. The second form takes a HAND-AUTHORED
-- floor (data/overworld/*.lua) through Overworld.fromLayout instead of rolling one.
--
-- It exists because `. board-report` answers "what do two hundred floors average" and cannot answer
-- "what is wrong with THIS one". A mean cannot show you a shape -- and a grid still has one: which cells
-- the hollow pass took out, whether the gate really has one approach, and how far in the end sits.
--
-- Read-only and seeded, so two runs with the same arguments print the same floor.

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

    -- CARVE / SIZE OVERRIDES, because one carve in the game is not reachable through any biome.
    -- `dungeon` (models/layouts/dungeon.lua) is named by models/descent.lua and by nothing in
    -- data/biomes, so a descent floor -- the floor fifteen sittings of a run are walked on -- was the
    -- one ground this tool could not draw. Overworld.generate honours an explicit size ahead of
    -- its own derivation, so:
    --
    --     . board-render underworld 7 size=6      -- a descent floor 1
    --     . board-render castle 7 size=8          -- the same seed, a deeper one
    --
    -- The biome still supplies the TILESET and therefore the fill glyphs, which is the same split
    -- the descent itself makes: the circle owns the look, the descent owns the shape underneath it.
    -- (`carve=` and `spacing=` went with the layouts.)
    local size
    for _, a in ipairs(args) do
        local z = tostring(a):match("^size=(%d+)$"); if z then size = tonumber(z) end
    end

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
        cols = size,
        rows = size,
        encounterCount = DEFAULT_ENCOUNTERS,
        -- Sorted, or two runs of the same seed disagree about which stop landed where. See
        -- tools/board_report's stablePool for why the pool alone is not reproducible.
        encounters = require("tools.board_report").stablePool(DEFAULT_DAY),
        houseMaterial = "material_salt_iron",
        keyCount = 1,
        objective = { name = "Boss" },
        seed = seed,
    })

    print(string.format("BOARD RENDER -- %s, seed %d, %dx%d",
        biome, seed, grid.cols, grid.rows))
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

    -- ---- panel two: how far in ------------------------------------------------
    --
    -- This panel used to read the board for open ground against corridor, because a carve's failure was
    -- a SHAPE -- a warren that looked like a country until you counted -- and a mean could not show it.
    -- A grid has one shape. What it can still be wrong about is DEPTH: a floor whose blocked cells
    -- happened to fall in a line is a floor with a two-step crossing, and that is exactly as invisible
    -- in a mean as the old failure was. So the second panel prints the step distance from the way in,
    -- one digit a place, and the number at the end of it is the crossing.
    print("  " .. string.rep("-", grid.cols))
    local dist = grid:bfsDistances(grid:startCell())
    local deepest, places = 0, 0
    for y = 1, grid.rows do
        local row = {}
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if not grid:typeWalkable(c.tile) then
                row[#row + 1] = " "
            else
                local d = dist[y * 100000 + x]
                places = places + 1
                if d and d > deepest then deepest = d end
                row[#row + 1] = d and string.sub("0123456789abcdefghijklmnopqrstuvwxyz", (d % 36) + 1, (d % 36) + 1) or "?"
            end
        end
        print("  " .. table.concat(row))
    end
    print("")
    print("  steps from the way in, one digit a place. A blank is a cell that is not there.")
    print(string.format("  %d places, deepest is %d steps in", places, deepest))
end

-- The authored form. Same two panels, over a hand-typed map -- which runs none of the generator's
-- passes, so anything the roll would have guaranteed has to be read off the page here instead.
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
    print("  S start  X objective  1..9 route stop   . a place   # a cell that is not there")
    print("")

    local dist = grid:bfsDistances(grid:startCell())
    local places, deepest = 0, 0
    for y = 1, grid.rows do
        local row = {}
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if not grid:typeWalkable(c.tile) then
                row[#row + 1] = " "
            else
                local d = dist[y * 100000 + x]
                places = places + 1
                if d and d > deepest then deepest = d end
                row[#row + 1] = d and string.sub("0123456789abcdefghijklmnopqrstuvwxyz", (d % 36) + 1, (d % 36) + 1) or "?"
            end
        end
        print("  " .. table.concat(row))
    end
    print("")
    print(string.format("  steps from the way in. %d places, deepest is %d steps.", places, deepest))
    print("")

    -- Every authored mark, in the order the ASCII names them -- and how far in it stands, which is the
    -- one thing an author cannot read off their own page.
    for y = 1, grid.rows do
        local src = def.map[y]
        for x = 1, grid.cols do
            local ch = src:sub(x, x)
            if ch:match("[X%d]") then
                print(string.format("  %s at (%2d,%2d)  %s steps in", ch, x, y,
                    tostring(dist[y * 100000 + x] or "-")))
            end
        end
    end
end

return M
