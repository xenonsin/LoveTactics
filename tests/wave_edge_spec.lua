-- Where a reinforcement wave walks on from (models/combat.lua's edge resolution, driven by
-- states/battle.lua's spawnWaves). A wave's `from` descriptor picks a board side; the dynamic forms
-- (`flank`, `open`, `surround`, `random`) read the live board so the same encounter throws its
-- reserves at whichever flank the fight has actually opened up. Pure logic, headless.

local Combat = require("models.combat")
local Character = require("models.character")

-- A hydrated arena: 1..cols by 1..rows of walkable ground, minus any obstacles, plus the authored
-- enemy spawns that Combat.enemyHomeEdge reads. Mirrors the { type, walkable } cells hydrateTiles
-- produces, which is all the edge code touches.
local function arena(cols, rows, opts)
    opts = opts or {}
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", walkable = true } end
    end
    for _, o in ipairs(opts.obstacles or {}) do
        tiles[o.y][o.x] = { type = "obstacle", walkable = false }
    end
    return { cols = cols, rows = rows, tiles = tiles, enemies = opts.enemies or {},
             party = opts.party }
end

local function combatWith(a, units)
    return { arena = a, units = units or {} }
end

local function unit(side, x, y)
    return { side = side, x = x, y = y, alive = true }
end

local function has(list, x, y)
    for _, t in ipairs(list) do if t.x == x and t.y == y then return true end end
    return false
end

return {
    {
        name = "edgeTiles reads the outermost line of each side, walkable only",
        fn = function()
            local c = combatWith(arena(8, 8))
            local top = Combat.edgeTiles(c, "top", 1)
            assert(#top == 8, "a clear top row is 8 tiles, got " .. #top)
            for _, t in ipairs(top) do assert(t.y == 1, "top depth-1 is row 1") end

            local left = Combat.edgeTiles(c, "left", 1)
            assert(#left == 8, "a clear left column is 8 tiles, got " .. #left)
            for _, t in ipairs(left) do assert(t.x == 1, "left depth-1 is column 1") end

            local right = Combat.edgeTiles(c, "right", 1)
            for _, t in ipairs(right) do assert(t.x == 8, "right depth-1 is the last column") end
            local bottom = Combat.edgeTiles(c, "bottom", 1)
            for _, t in ipairs(bottom) do assert(t.y == 8, "bottom depth-1 is the last row") end
        end,
    },
    {
        name = "edgeTiles skips obstacles and spills inward with depth",
        fn = function()
            local c = combatWith(arena(8, 8, { obstacles = { { x = 3, y = 1 } } }))
            assert(not has(Combat.edgeTiles(c, "top", 1), 3, 1), "an obstacle on the edge is not a landing tile")
            local two = Combat.edgeTiles(c, "top", 2)
            assert(has(two, 3, 2), "depth 2 reaches the second row behind the blocked cell")
        end,
    },
    {
        name = "freeEdgeTile spills to the next line when the front is packed",
        fn = function()
            local units = {}
            for x = 1, 8 do units[#units + 1] = unit("enemy", x, 1) end -- top row full
            local c = combatWith(arena(8, 8), units)
            local x, y = Combat.freeEdgeTile(c, "top")
            assert(x and y == 2, "a packed top row pushes the arrival to row 2, got y=" .. tostring(y))
        end,
    },
    {
        name = "enemyHomeEdge follows the authored spawn side, not live units",
        fn = function()
            local topSpawn = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }))
            assert(Combat.enemyHomeEdge(topSpawn) == "top", "enemies seated at row 1 come from the top")
            local botSpawn = combatWith(arena(8, 8, { enemies = { { x = 4, y = 8 } } }))
            assert(Combat.enemyHomeEdge(botSpawn) == "bottom", "enemies seated at row 8 come from the bottom")
        end,
    },
    {
        name = "the home edge is the side away from the company, however the enemy is scattered",
        fn = function()
            -- The enemy no longer musters in two ranks on one wall: models/arena.lua scatters knots
            -- across the board, so their own average row can sit anywhere -- including past the halfway
            -- line, which used to hand a default wave the edge the COMPANY is standing on. The party's
            -- seating is what the far side is measured from.
            local scattered = combatWith(arena(8, 8, {
                party = { { x = 3, y = 8 }, { x = 4, y = 8 }, { x = 4, y = 7 } },
                enemies = { { x = 2, y = 5 }, { x = 3, y = 5 }, { x = 7, y = 4 } },
            }))
            assert(Combat.enemyHomeEdge(scattered) == "top",
                "a wave walked on from behind the company that is standing at the bottom")
            local entered = combatWith(arena(8, 8, {
                party = { { x = 3, y = 1 }, { x = 4, y = 1 } }, -- came in by the north door
                enemies = { { x = 2, y = 4 }, { x = 6, y = 5 } },
            }))
            assert(Combat.enemyHomeEdge(entered) == "bottom",
                "a company entering from the north is reinforced against from the south")
        end,
    },
    {
        name = "resolveWaveEdge: nil/back is the enemy home edge, explicit sides pass through",
        fn = function()
            local c = combatWith(arena(8, 8, { enemies = { { x = 4, y = 8 } } }))
            assert(Combat.resolveWaveEdge(c, nil) == "bottom", "a default wave arrives from behind the enemy line")
            assert(Combat.resolveWaveEdge(c, "back") == "bottom", "'back' is the same as the default")
            assert(Combat.resolveWaveEdge(c, "left") == "left", "an explicit side is honoured verbatim")
            assert(Combat.resolveWaveEdge(c, "nonsense") == "bottom", "an unknown name degrades to the home edge")
        end,
    },
    {
        name = "resolveWaveEdge flank aims at the living party's nearest edge",
        fn = function()
            -- Party pinned to the left column; the wave should come in on their flank, not the far line.
            local c = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }),
                { unit("party", 1, 4), unit("party", 1, 5) })
            assert(Combat.resolveWaveEdge(c, "flank") == "left", "a left-hugging party is flanked from the left")
            -- With no party left standing it falls back to the enemy home edge rather than erroring.
            assert(Combat.resolveWaveEdge(combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } })), "flank") == "top",
                "flank falls back to the home edge when no party stands")
        end,
    },
    {
        name = "resolveWaveEdge open picks the emptiest side",
        fn = function()
            -- Jam the top two rows solid; the bottom edge is wide open, so that is where a big wave lands.
            local units = {}
            for y = 1, 2 do for x = 1, 8 do units[#units + 1] = unit("enemy", x, y) end end
            local c = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }), units)
            assert(Combat.resolveWaveEdge(c, "open") == "bottom", "the clear bottom edge is the open one")
        end,
    },
    {
        name = "resolveWaveEdge random is reproducible from the battle seed",
        fn = function()
            local a = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }))
            a.rng = Combat.newRandom(1234)
            local b = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }))
            b.rng = Combat.newRandom(1234)
            assert(Combat.resolveWaveEdge(a, "random") == Combat.resolveWaveEdge(b, "random"),
                "the same seed picks the same edge")
        end,
    },
    {
        name = "waveEdges keeps one side per unit, but surround fans out",
        fn = function()
            local c = combatWith(arena(8, 8, { enemies = { { x = 4, y = 1 } } }))
            local same = Combat.waveEdges(c, "left", 3)
            assert(same[1] == "left" and same[2] == "left" and same[3] == "left",
                "an ordinary wave lands every unit on the one named side")

            local ring = Combat.waveEdges(c, "surround", 4)
            local seen = {}
            for _, e in ipairs(ring) do seen[e] = true end
            local n = 0
            for _ in pairs(seen) do n = n + 1 end
            assert(n == 4, "a 4-unit surround wave touches all four edges, got " .. n)
        end,
    },

    -- ---------------------------------------------------------------------------
    -- previewWaveArrival: the committed plan states/battle.lua both draws and spawns from, so the
    -- reinforcement telegraph and the bodies that land are one and the same.
    -- ---------------------------------------------------------------------------
    {
        name = "previewWaveArrival lands each unit on the named edge, on its own free tile",
        fn = function()
            local plan = Combat.previewWaveArrival(combatWith(arena(8, 8)),
                { composition = { "character_bandit", "character_bandit" }, from = "top" })
            assert(plan, "a two-unit wave with a clear top edge resolves a plan")
            assert(#plan.tiles == 2, "both units find a tile, got " .. #plan.tiles)
            for _, t in ipairs(plan.tiles) do assert(t.y == 1, "a top wave lands on row 1") end
            assert(not (plan.tiles[1].x == plan.tiles[2].x and plan.tiles[1].y == plan.tiles[2].y),
                "two units in one wave never claim the same tile")
            assert(plan.edge == "top" and #plan.chars == 2 and #plan.ids == 2, "the plan carries its roster")
        end,
    },
    {
        name = "previewWaveArrival is deterministic for a fixed edge",
        fn = function()
            local w = { composition = { "character_bandit", "character_bandit", "character_bandit" }, from = "left" }
            local a = Combat.previewWaveArrival(combatWith(arena(8, 8)), w)
            local b = Combat.previewWaveArrival(combatWith(arena(8, 8)), w)
            assert(#a.tiles == #b.tiles, "the same board resolves the same count")
            for i = 1, #a.tiles do
                assert(a.tiles[i].x == b.tiles[i].x and a.tiles[i].y == b.tiles[i].y,
                    "the same board resolves the same tiles -- what is drawn is what will spawn")
            end
        end,
    },
    {
        name = "previewWaveArrival never commits a tile a unit already stands on",
        fn = function()
            -- A body on the outer corner of the top edge: the arrival skips it (the block, at commit time).
            local c = combatWith(arena(8, 8), { unit("party", 1, 1) })
            local plan = Combat.previewWaveArrival(c, { composition = { "character_bandit" }, from = "top" })
            assert(plan and #plan.tiles == 1, "the wave still finds a tile past the held one")
            assert(not (plan.tiles[1].x == 1 and plan.tiles[1].y == 1), "it does not commit the held tile")
        end,
    },
    {
        name = "previewWaveArrival evaluates a composition function exactly once",
        fn = function()
            local calls = 0
            local plan = Combat.previewWaveArrival(combatWith(arena(8, 8)),
                { from = "top", composition = function() calls = calls + 1; return { "character_bandit" } end })
            assert(plan, "the wave resolves")
            assert(calls == 1, "a composition function is fixed once at commit, not rolled per unit, got " .. calls)
        end,
    },
    {
        name = "previewWaveArrival's default 'back' fills the holes the opening formation left",
        fn = function()
            local c = combatWith(arena(8, 8, { enemies = { { x = 4, y = 8 } } }))
            local plan = Combat.previewWaveArrival(c, { composition = { "character_bandit" } }) -- from nil = back
            assert(plan.tiles[1].x == 4 and plan.tiles[1].y == 8,
                "a back wave reuses an unoccupied original enemy spawn before spilling to the edge")
        end,
    },
    {
        name = "previewWaveArrival returns nil when there is nowhere to stand",
        fn = function()
            local units = {}
            for y = 1, 8 do for x = 1, 8 do units[#units + 1] = unit("enemy", x, y) end end
            local plan = Combat.previewWaveArrival(combatWith(arena(8, 8), units),
                { composition = { "character_bandit" }, from = "top" })
            assert(plan == nil, "a full board commits no arrival")
        end,
    },
}
