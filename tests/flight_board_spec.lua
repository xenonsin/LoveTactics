-- Tests for the ground the prologue's flight leg is FOUGHT on (data/overworld/tutorial_flight.lua).
--
-- tests/flight_leg_spec.lua already pins the route: that the stops sit on one connected road and are
-- met in the authored order. This file pins the other half, the half the board-is-the-map rewrite added
-- (models/arena.lua's Arena.fromGrid): that a stop which OPENS A FIGHT stands somewhere a fight can
-- happen. The first version of the trail passed every route assertion there is and was still unplayable
-- -- one tile wide from S to X, so the defend stop stood the company, two survivors and the demons in a
-- single-file queue -- because nothing had ever asked it how much floor it held.
--
-- So the questions here are asked THROUGH the real seam, never off the ASCII: the window is cut by
-- Overworld:bestBox and the board is built by Arena.build off the same spec states/game.lua hands the
-- battle state, so a change to how a window is chosen fails here rather than in a screenshot.

local Arena = require("models.arena")
local Overworld = require("models.overworld")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")

-- The flight's grid, built the way states/game.lua builds it (resolving the quest's always-list first).
local function flightGrid()
    local map = require("states.prologue").FLIGHT_QUEST.map
    local always = {}
    for _, e in ipairs(map.encounters.always) do
        local id = type(e) == "table" and e.id or e
        local def = Encounter.get(id)
        always[#always + 1] = { id = id, kind = def.kind, name = def.name,
            loot = type(e) == "table" and e.loot or nil,
            conversation = type(e) == "table" and e.conversation or nil }
    end
    return Overworld.fromLayout({
        layout = map.layout, biome = map.biome,
        objective = map.objective, alwaysEncounters = always,
    }), map
end

-- Every cell carrying an encounter of the given id, plus the objective cell under the id "objective".
local function cellsByEncounter(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            local enc = c.encounter
            if enc then out[enc.kind == "objective" and "objective" or enc.id] = c end
        end
    end
    return out
end

-- The tile the company would have stepped off to reach `cell`: its neighbour one row north. Every
-- chamber on this map is entered from the north on purpose (see the layout's header), and the party's
-- edge -- and with it both objective regions -- is read off exactly this.
local function fromNorth(cell) return { x = cell.x, y = cell.y - 1 } end

-- How many tiles of a cut window are OPEN ground: a 3x3 with nothing solid in it. The measure a plain
-- walkable count cannot be -- a warren of 1-wide corridors can clear a walkable floor and still hold
-- nowhere anything can be flanked from (Overworld:isOpen makes the same argument about the map).
--
-- Arena.fromGrid hands back a layout, whose tiles are type STRINGS -- they are hydrated into tables one
-- layer up, in Arena.build -- so walkability is read through TILE_PROPS here.
local function openTiles(layout)
    local function walkable(x, y)
        local row = layout.tiles[y]
        local p = row and row[x] and Arena.TILE_PROPS[row[x]]
        return p and p.walkable
    end
    local n = 0
    for y = 1, layout.rows do
        for x = 1, layout.cols do
            local ok = true
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not walkable(x + dx, y + dy) then ok = false end
                end
            end
            if ok then n = n + 1 end
        end
    end
    return n
end

-- The three stops that open a board, and how much room each one's fight needs. The floor is
-- Overworld.BOX_OK, which is the generator's OWN refusal threshold: a rolled board will not seat a
-- fight below it, and an authored one has no business standing three there.
local FIGHTS = {
    { key = "encounter_survivors_defend", name = "the steading (defend)" },
    { key = "encounter_survivors_extract", name = "the ford (extract)" },
    { key = "objective", name = "the neck (the Champion)" },
}

return {
    {
        name = "every stop that opens a fight stands in a room, not a corridor",
        fn = function()
            local grid = flightGrid()
            local cells = cellsByEncounter(grid)
            for _, f in ipairs(FIGHTS) do
                local cell = cells[f.key]
                assert(cell, f.name .. " is on the map")
                local usable = Arena.boxUsable(grid, cell.x, cell.y)
                assert(usable >= Overworld.BOX_OK,
                    f.name .. " locks " .. usable .. " walkable of 64, under BOX_OK " .. Overworld.BOX_OK)
            end
        end,
    },
    {
        name = "...and the room has ground to manoeuvre on, not just floor to stand on",
        fn = function()
            local grid = flightGrid()
            local cells = cellsByEncounter(grid)
            for _, f in ipairs(FIGHTS) do
                local cell = cells[f.key]
                local arena = Arena.fromGrid(grid, { x = cell.x, y = cell.y, from = fromNorth(cell),
                    party = 4, enemies = 4, biome = "forest" })
                local open = openTiles(arena)
                -- Twelve is the same reading docs/overworld.md takes of an 8x8: enough of the window is
                -- room rather than passage that a body can be gone round instead of only queued behind.
                assert(open >= 12, f.name .. " holds only " .. open .. " open tiles of 64")
            end
        end,
    },
    {
        name = "a fight stop seats its whole authored cast -- the room never clips the composition",
        fn = function()
            -- Arena.enemyCap converts standing room into a ceiling (one body per 6 walkable tiles), so a
            -- thin board silently fields a smaller fight than the one that was written. The Champion's
            -- three-body cast is the one that must survive that intact: it is the leg's capstone, and
            -- `assassinate` makes the named body the win condition rather than a difficulty knob.
            local grid = flightGrid()
            local cells = cellsByEncounter(grid)
            local obj = require("states.prologue").FLIGHT_QUEST.map.objective
            local cell = cells.objective
            local built = EncounterBattle.build({
                encounter = { kind = "objective" }, objective = obj, biome = "forest", day = 1,
                grid = grid, at = { x = cell.x, y = cell.y }, from = fromNorth(cell),
                party = {}, seed = 4,
            })
            assert(#built.enemyUnits == 3,
                "the Champion fights with both its imps, got " .. #built.enemyUnits .. " bodies")

            local defend = cells.encounter_survivors_defend
            local built2 = EncounterBattle.build({
                encounter = { kind = "combat", id = "encounter_survivors_defend" },
                biome = "forest", day = 1,
                grid = grid, at = { x = defend.x, y = defend.y }, from = fromNorth(defend),
                party = {}, seed = 4,
            })
            assert(#built2.enemyUnits == 2, "the steading opens against both imps")
            local survivors = 0
            for _, u in ipairs(built2.partyUnits) do
                if u.char.id == "character_survivor" then survivors = survivors + 1 end
            end
            assert(survivors == 2, "and both survivors are on the board, got " .. survivors)
        end,
    },
    {
        name = "a fight stop offers a deploy zone worth choosing on",
        fn = function()
            -- The phase is only a placement if there are more tiles than bodies (docs/deployment.md).
            -- The old trail offered two, which is not a choice -- it is a queue with a prompt over it.
            local grid = flightGrid()
            local cells = cellsByEncounter(grid)
            for _, f in ipairs(FIGHTS) do
                local cell = cells[f.key]
                local arena = Arena.fromGrid(grid, { x = cell.x, y = cell.y, from = fromNorth(cell),
                    party = 4, enemies = 4, biome = "forest" })
                assert(#arena.deployZone > Arena.DEPLOY_MIN,
                    f.name .. " offers " .. #arena.deployZone .. " tiles to place four bodies on")
                assert(arena.box.entry == "top",
                    f.name .. " is entered from the north, so the objective regions point downfield")
            end
        end,
    },
    {
        name = "the Champion's chamber IS the authored arena, flipped to the edge the party walks in on",
        fn = function()
            -- Two files describe this board: the chamber in the map (what the flight actually fights on,
            -- since a windowed board wins over spec.layout) and data/arenas/demon_champion.lua (the
            -- fallback for a caller with no map, and what tests/demon_champion_spec.lua reads). They are
            -- pinned to each other here rather than trusted to have been copied carefully -- the whole
            -- point of the authored board is the levers, and a lever that drifted out of the live copy
            -- would take a stage of the boss fight with it.
            --
            -- The flip is the party's edge: the arena seats them on its bottom row, and descending into
            -- the chamber seats them on its top one. So chamber row j is arena row (rows + 1 - j).
            local grid = flightGrid()
            local cell = cellsByEncounter(grid).objective
            local chamber = Arena.fromGrid(grid, { x = cell.x, y = cell.y, from = fromNorth(cell),
                party = 4, enemies = 4, biome = "forest" })
            local authored = Arena.defs.demon_champion
            assert(authored, "the fallback arena is still there")
            assert(chamber.rows == #authored.tiles and chamber.cols == #authored.tiles[1],
                "the chamber is the arena's size")

            -- Two pairs of names are one fact each in models/terrain.lua, and the two files reach for
            -- opposite halves of both: `path`/`ground` are the identical walkable floor (the map calls a
            -- trail a trail), and `rock`/`obstacle` the identical solid (the map spells a wall with the
            -- one a forest ravine would have). Compared as classes, so this pins the SHAPE of the board
            -- and does not fail over a synonym.
            local CLASS = { path = "floor", ground = "floor", rock = "solid", obstacle = "solid" }
            local function class(t) return CLASS[t] or t end
            for j = 1, chamber.rows do
                for i = 1, chamber.cols do
                    local got = chamber.tiles[j][i]
                    local want = authored.tiles[chamber.rows + 1 - j][i]
                    assert(class(got) == class(want),
                        "chamber " .. i .. "," .. j .. " is " .. got .. ", the arena says " .. want)
                end
            end
        end,
    },
    {
        name = "the Champion's treeline is already burning when the lock closes",
        fn = function()
            -- The authored opening state, carried map -> cell -> window (Overworld.fromLayout's
            -- `hazards`, Arena.fromGrid). It is what data/arenas/demon_champion.lua's own `hazards` said
            -- and what the windowed board dropped on the floor until this seam existed.
            local grid = flightGrid()
            local cell = cellsByEncounter(grid).objective
            local chamber = Arena.fromGrid(grid, { x = cell.x, y = cell.y, from = fromNorth(cell),
                party = 4, enemies = 4, biome = "forest" })
            assert(#chamber.hazards == 2, "both hazards rode into the window, got " .. #chamber.hazards)
            for _, h in ipairs(chamber.hazards) do
                assert(h.id == "hazard_fire", "each is a fire")
                assert(h.x >= 1 and h.x <= chamber.cols and h.y >= 1 and h.y <= chamber.rows,
                    "and sits in BOARD coordinates, not map ones (" .. h.x .. "," .. h.y .. ")")
                assert(chamber.tiles[h.y][h.x] == "forest", "on the treeline it is said to be burning")
                -- The firebreak the arena's header argues for: the fire is on the Champion's side of the
                -- neck, so it can never walk up the treeline into the party's own line.
                assert(h.y > 5, "on the far side of the neck (row 5), not the party's")
            end

            -- A fight anywhere else on the leg opens on ground that is not on fire.
            local defend = cellsByEncounter(grid).encounter_survivors_defend
            local other = Arena.fromGrid(grid, { x = defend.x, y = defend.y, from = fromNorth(defend),
                party = 4, enemies = 4, biome = "forest" })
            assert(#other.hazards == 0, "the steading opens cold")
        end,
    },
    {
        name = "the corridor stops stay corridors -- room is what marks a fight out",
        fn = function()
            -- The inverse assertion, and it is the one that keeps the map from being answered by
            -- flooding it. A chest and a rest open no board, so widening them would say only that the
            -- three clearings are nothing special.
            local grid = flightGrid()
            local cells = cellsByEncounter(grid)
            for _, id in ipairs({ "encounter_treasure", "encounter_rest" }) do
                local cell = cells[id]
                assert(cell, id .. " is on the map")
                assert(not grid:isOpen(cell.x, cell.y), id .. " sits on trail, not in a clearing")
            end
        end,
    },
}
