-- The one terrain table (models/terrain.lua). The map and the board are the same ground, so these pin
-- the thing that made merging them possible: both layers read one table, and the two words that meant
-- two different things each became two tiles.
--
-- And the rise-and-rock cases at the bottom, which are a THIRD word that was wrong. `mountain` was
-- the walkable vantage and `obstacle` the anonymous solid beside it; they are now `hill` and
-- `mountain`. Renaming costs nothing here on its own -- the fingerprint case below pins walkability
-- rather than names for exactly that reason -- but one of the three claims the new names make is
-- true only by way of ANOTHER FILE, and that one needed a test.

local Terrain = require("models.terrain")
local Tileset = require("models.tileset")
local Arena = require("models.arena")
local Overworld = require("models.overworld")
local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Wall = require("models.wall")

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

-- A flat BATTLE board with the named cells replaced by one terrain type (mirrors
-- tests/knockback_spec.lua's). Nothing to do with bareBoard above, which rolls an overworld.
local function board(cols, rows, kind, cells)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    local def = Terrain.get(kind)
    for _, c in ipairs(cells or {}) do
        tiles[c.y][c.x] = { type = kind, moveCost = def.moveCost, walkable = def.walkable,
                            sightCost = def.sightCost, bonus = def.bonus }
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A body with a generous move budget, so nothing below fails merely for running out of steps.
local function walker(itemIds)
    local char = Character.instantiate("character_rowan")
    if itemIds then
        char.inventory = {}
        for _, id in ipairs(itemIds) do Character.addItem(char, Item.instantiate(id)) end
    end
    char.stats.movement = 8
    return { char = char, x = 3, y = 5 }
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
        name = "terrain: the floor's silhouette is fixed, and a refactor may not move it",
        fn = function()
            -- THE FINGERPRINT. It pins WALKABILITY rather than tile names, so a rename is free and a
            -- hole in a wall is not.
            --
            -- This number was read off the boards, not derived. If it moves, the question is not "what
            -- should it be" -- it is "which pass started laying different ground, and was that meant".
            -- Content is switched off (no encounters, caches or keys) so nothing here depends on the
            -- encounter pool's unspecified order.
            --
            -- IT USED TO BE FOUR NUMBERS, one per ground, because a biome named a carve and each carve
            -- laid its own geometry. There is one shape now (models/overworld.lua's Overworld:hollow),
            -- so every ground on a given seed prints the same fingerprint -- and asserting that they
            -- MATCH is the stronger version of the old case, since a biome that started laying its own
            -- ground again would fail here rather than quietly passing.
            local EXPECTED = { 258528, 535 }
            local bad = {}
            for _, biome in ipairs({ "forest", "castle", "tundra", "desert" }) do
                local sum, n = walkPrint(bareBoard(biome, 20260812))
                if n ~= EXPECTED[2] or sum ~= EXPECTED[1] then
                    bad[#bad + 1] = string.format("%s = { %d, %d }", biome, sum, n)
                end
            end
            -- Report EVERY ground that moved, not just the first.
            assert(#bad == 0, "the silhouette moved -- actual: " .. table.concat(bad, ", "))
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
    {
        name = "the hill is the rise you take and the mountain is the rock you go around",
        fn = function()
            local hill, mountain = Terrain.TYPES.hill, Terrain.TYPES.mountain

            assert(hill.walkable, "a hill is high ground you can actually stand on")
            assert(hill.moveCost == 3, "and it charges for the climb")
            assert(hill.bonus and hill.bonus.range == 1, "which is what the reach pays for")
            assert(hill.sightCost >= Combat.SIGHT_BLOCK, "a hill screens the lane behind it on its own")

            assert(not mountain.walkable, "a mountain bars the tile")
            assert(mountain.sightCost >= Combat.SIGHT_BLOCK, "and the sight through it")
            assert(mountain.bonus == nil, "nothing stands on it, so it pays nobody anything")

            -- The old names are GONE rather than aliased, and that is deliberate. `mountain` is now
            -- Terrain.get's fallback for an unknown type, so a leftover "obstacle" left standing as a
            -- second door would keep an old arena loading while quietly meaning something new. Better
            -- it be a name nobody uses, and the parse pass names the file that still types it.
            assert(Terrain.TYPES.obstacle == nil, "`obstacle` was renamed, not kept as a second door")
            assert(Terrain.get("no_such_tile") == Terrain.TYPES.mountain, "unknown reads as solid")
            assert(Terrain.get(nil) == Terrain.TYPES.mountain, "and so does nil")
        end,
    },
    {
        -- THE CLAIM NOTHING IN THIS FILE COULD SEE. models/terrain.lua says nothing about flight; a
        -- mountain is crossed because Combat.isFlying overrides `walkable` in the move graph, which is
        -- a fact about models/combat.lua. So the tooltip's "only a flier crosses it" and the Zephyr
        -- Striders' "mountains included" could both have gone false the day that graph tightened, and
        -- every guard reading the terrain table would have stayed green.
        name = "a flier crosses a mountain and a walker does not",
        fn = function()
            local ridge = {} -- a wall of mountain across y3 with no gap: over it or nowhere
            for x = 1, 6 do ridge[#ridge + 1] = { x = x, y = 3 } end

            local cWalk = Combat.new(board(6, 6, "mountain", ridge), { walker() }, {})
            local onFoot = Combat.reachable(cWalk, cWalk.units[1])
            assert(onFoot["3,4"], "the walker moves freely on its own side")
            assert(not onFoot["3,3"], "but it cannot enter the mountain")
            assert(not onFoot["3,1"], "and nothing beyond the ridge is reachable either")

            local cFly = Combat.new(board(6, 6, "mountain", ridge),
                { walker({ "utility_zephyr_striders" }) }, {})
            local u = cFly.units[1]
            assert(Combat.isFlying(u), "the Striders are what lift it")
            local aloft = Combat.reachable(cFly, u)
            assert(aloft["3,3"], "a flier may stand on the mountain itself")
            assert(aloft["3,1"], "and crosses to the far side of the ridge")
        end,
    },
    {
        -- The other half of the same line, and the reason the mountain opening is not a hole: terrain
        -- bars the way by being poor footing, an object bars it by being IN the way. The Striders buy
        -- "the ground stops mattering", never "nothing stops you".
        name = "a wall still stops the flier the mountain did not",
        fn = function()
            local c = Combat.new(board(6, 6, "ground", {}),
                { walker({ "utility_zephyr_striders" }) }, {})
            for x = 1, 6 do Wall.place(c, x, 3, "illusory_wall") end

            local aloft = Combat.reachable(c, c.units[1])
            assert(aloft["3,4"], "the near side is still open")
            assert(not aloft["3,3"], "a flier cannot end its turn inside a wall")
            assert(not aloft["3,1"], "nor pass through one to the far side")
        end,
    },

    -- -----------------------------------------------------------------------
    -- THE CEILING ON TERRAIN ARMOUR
    -- -----------------------------------------------------------------------
    {
        -- Fire Emblem's fort gives +2 against a Defence that runs 0-20. Ours runs 3-6 across the whole
        -- roster, so the same +2 is a third to two thirds of a body's entire mitigation -- heavier by
        -- far than the forest's +20 avoid, which comes off a hit chance already sitting at 61-91%.
        -- A model game sets the magnitude only while the stat it was set against is the same width.
        --
        -- ONE TILE, which is the other half of the rule and the half a spec is actually needed for: a
        -- ceiling on the value is easy to keep by eye, and the number of tiles carrying it is exactly
        -- the thing that creeps. Armour on a second floor is a re-tier, and a re-tier obliges a
        -- rebalance rather than a line in a table.
        name = "terrain armour is capped, and exactly one tile carries any",
        fn = function()
            local armoured = {}
            for name, def in pairs(Terrain.TYPES) do
                for _, key in ipairs({ "defense", "magicDefense" }) do
                    local v = def.bonus and def.bonus[key]
                    if v and v ~= 0 then
                        armoured[#armoured + 1] = name .. "." .. key .. "=" .. v
                        assert(v <= Terrain.DEFENSE_CEILING,
                            name .. " grants " .. key .. " " .. v .. ", over the ceiling of "
                            .. Terrain.DEFENSE_CEILING)
                    end
                end
            end
            table.sort(armoured)
            assert(#armoured == 1, "exactly one tile may armour the body standing on it, saw: "
                .. table.concat(armoured, ", "))
        end,
    },
    {
        -- The tile the whole positional package is built around, pinned as a SHAPE rather than as four
        -- numbers: it has to be cheaper to reach than the hill, worth less to a shooter, and the only
        -- ground that thickens armour. Any one of those drifting turns it back into a second forest.
        name = "the redoubt is the hill's opposite, not its cheaper copy",
        fn = function()
            local fort, hill = Terrain.get("redoubt"), Terrain.get("hill")
            assert(fort.walkable, "a fort you cannot stand in is a wall")
            assert(fort.moveCost < hill.moveCost, "the redoubt has to be the cheaper ground to take")
            assert((fort.bonus.range or 0) == 0, "it is the wall's tile, not the archer's")
            assert(fort.sightCost == 0, "you can see out of a thing you stand behind")
            assert(fort.bonus.avoid < hill.bonus.avoid,
                "the hill is still the better place to not be hit at all")
            assert((fort.bonus.defense or 0) > 0, "...and the redoubt is the only place that armours you")
        end,
    },
    {
        -- Ground that renews and ground that bogs are both HAZARDS here, which is what keeps the
        -- terrain table a table of footing, sight and a bonus bag. The risk in that decision is the
        -- wiring: a tile whose whole second half lives in another model is a tile that can ship with
        -- the half missing and look completely fine on the board.
        name = "a board's redoubts and mires stand their own zones, on both build paths",
        fn = function()
            local function zonesOn(tiles)
                local rows, cols = #tiles, #tiles[1]
                local out = {}
                for _, h in ipairs(Arena.terrainZones(tiles, rows, cols)) do
                    out[h.x .. "," .. h.y] = h.id
                end
                return out
            end

            local z = zonesOn({
                { "ground", "redoubt", "ground" },
                { "mire", "ground", "hill" },
            })
            assert(z["2,1"] == "hazard_renewal", "a redoubt mends whoever holds it")
            assert(z["1,2"] == "hazard_quicksand", "and the bog finally bites")
            assert(z["3,2"] == nil, "a hill stands nothing: it pays in reach, as it always did")
            assert(z["1,1"] == nil, "open ground stands nothing")

            -- The rolled path, end to end: a castle board fills with redoubts, so its arena must come
            -- out of Arena.build with a zone on each of them. This is the case that would have caught
            -- the feature shipping wired to nothing.
            -- Every curated castle arena is `fixed` (the two galleries and the tutorial village), so
            -- a castle fight always rolls procedural and this reaches the palette rather than a
            -- hand-authored board. Asserted below rather than assumed: `forts > 0` is what would fail
            -- if that ever stopped being true.
            local a = Arena.build({ prestige = 1 }, {
                biome = "castle", seed = 7,
                party = { "character_rowan" },
                composition = function() return { "character_bandit" } end,
            })
            local forts = 0
            for y = 1, a.rows do
                for x = 1, a.cols do
                    if a.tiles[y][x].type == "redoubt" then forts = forts + 1 end
                end
            end
            assert(forts > 0, "a castle board is supposed to scatter redoubts")
            local renewals = 0
            for _, h in ipairs(a.hazards or {}) do
                if h.id == "hazard_renewal" then
                    renewals = renewals + 1
                    assert(a.tiles[h.y][h.x].type == "redoubt",
                        "a renewal zone landed on ground that is not a fort")
                    assert(h.side == nil, "the fort belongs to whoever gets there first, not to a side")
                end
            end
            assert(renewals == forts,
                "every fort on the board should renew (" .. forts .. " forts, " .. renewals .. " zones)")
        end,
    },
}
