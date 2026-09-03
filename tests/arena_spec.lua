-- Tests for the battle arena model (models/arena.lua): seeded determinism, grid
-- shape + spawn walkability, prestige-driven composition scaling, and the debug
-- serialize round-trip. Pure logic only (no rendering), so it runs headless.

local Arena = require("models.arena")

-- A spec that always generates procedurally (unknown biome -> no curated match),
-- so structural checks aren't captured by data/arenas/forest_01.lua.
local function proceduralSpec(overrides)
    local spec = {
        biome = "__test_void", -- no curated arena tagged for this biome
        party = { "character_rowan", "character_mage", "character_archer" },
        composition = function(ctx)
            local list = {}
            for i = 1, 2 + (ctx.prestige or 1) do list[i] = "character_bandit" end
            return list
        end,
        seed = 4242,
    }
    if overrides then
        for k, v in pairs(overrides) do spec[k] = v end
    end
    return spec
end

-- A comparable signature of an arena's tiles + spawn positions.
local function signature(arena)
    local parts = {}
    for y = 1, arena.rows do
        for x = 1, arena.cols do
            parts[#parts + 1] = arena.tiles[y][x].type
        end
    end
    for _, u in ipairs(arena.party) do parts[#parts + 1] = "P" .. u.x .. "," .. u.y end
    for _, u in ipairs(arena.enemies) do parts[#parts + 1] = "E" .. u.x .. "," .. u.y end
    return table.concat(parts, "|")
end

-- The same, for a raw LAYOUT (Arena.generateLayout) rather than a built arena: its tiles are plain type
-- strings and its spawns are partySpawns/enemySpawns, with no units bound yet. Props ride along, since a
-- board that laid its barrels somewhere else is a different board.
local function layoutSignature(layout)
    local parts = {}
    for y = 1, layout.rows do
        for x = 1, layout.cols do
            parts[#parts + 1] = layout.tiles[y][x]
        end
    end
    for _, s in ipairs(layout.partySpawns or {}) do parts[#parts + 1] = "P" .. s.x .. "," .. s.y end
    for _, s in ipairs(layout.enemySpawns or {}) do parts[#parts + 1] = "E" .. s.x .. "," .. s.y end
    for _, p in ipairs(layout.props or {}) do parts[#parts + 1] = "O" .. p.id .. "@" .. p.x .. "," .. p.y end
    return table.concat(parts, "|")
end

return {
    {
        name = "same seed produces an identical arena (determinism)",
        fn = function()
            local a = Arena.build({ prestige = 2 }, proceduralSpec())
            local b = Arena.build({ prestige = 2 }, proceduralSpec())
            assert(signature(a) == signature(b), "same seed should yield identical arenas")
        end,
    },
    {
        name = "arena is 8x8 and every spawn tile is walkable",
        fn = function()
            local a = Arena.build({ prestige = 3 }, proceduralSpec())
            assert(a.cols == 8 and a.rows == 8, "arena should be 8x8")
            for _, u in ipairs(a.party) do
                assert(a.tiles[u.y][u.x].walkable, "party spawn must be walkable")
            end
            for _, u in ipairs(a.enemies) do
                assert(a.tiles[u.y][u.x].walkable, "enemy spawn must be walkable")
            end
        end,
    },
    {
        name = "party spawns near, the enemy stands clear of them",
        fn = function()
            -- This case used to read `u.y <= 2` -- the enemy mustered on the two rows farthest from the
            -- party, and nowhere else. It scatters over the board now (see the two cases at the end of
            -- this file); what survives of the old claim is the half of it that was ever a rule: the
            -- party lands on its own edge, and nothing opens the fight on its doorstep.
            local a = Arena.build({ prestige = 1 }, proceduralSpec())
            for _, u in ipairs(a.party) do
                assert(u.y >= a.rows - 1, "party should spawn on the near rows")
            end
            for _, u in ipairs(a.enemies) do
                assert(a.rows - u.y >= Arena.ENEMY_MIN_DEPTH,
                    "an enemy opened the fight inside the company's own ground")
            end
        end,
    },
    {
        -- A spawn list hands out one point per body, which describes the board only while every body
        -- is 1x1. The Ogre encounter is the counter-example that shipped broken: its 2x2 brute covered
        -- the points beside its anchor, and the escort seated on them opened the fight standing inside
        -- it. Walked over many seeds and days, on the real blueprint, counting whole FOOTPRINTS.
        name = "no body opens the fight standing inside another (the Ogre and its escort)",
        fn = function()
            local Character = require("models.character")
            local ogre = require("data.encounters.encounter_ogre")

            local function census(a, where)
                local held = {}
                local function claim(u)
                    local fp = Character.normalizeFootprint(
                        (Character.defs[u.id] or {}).footprint)
                    for j = 0, fp.h - 1 do
                        for i = 0, fp.w - 1 do
                            local x, y = u.x + i, u.y + j
                            local k = x .. "," .. y
                            assert(not held[k], string.format(
                                "%s: %s stands on %d,%d, already held by %s", where, u.id, x, y, held[k] or "?"))
                            assert(x >= 1 and y >= 1 and x <= a.cols and y <= a.rows,
                                string.format("%s: %s hangs off the board at %d,%d", where, u.id, x, y))
                            assert(a.tiles[y][x].walkable, string.format(
                                "%s: %s stands on unwalkable ground at %d,%d", where, u.id, x, y))
                            held[k] = u.id
                        end
                    end
                end
                for _, u in ipairs(a.party) do claim(u) end
                for _, u in ipairs(a.allies or {}) do claim(u) end
                for _, u in ipairs(a.enemies) do claim(u) end
            end

            for _, biome in ipairs({ "__test_void", "forest" }) do
                for day = 2, 12, 2 do
                    for seed = 1, 12 do
                        local a = Arena.build({ prestige = 3, day = day }, proceduralSpec({
                            biome = biome, seed = seed, composition = ogre.composition,
                        }))
                        census(a, string.format("%s day %d seed %d", biome, day, seed))
                    end
                end
            end
        end,
    },
    {
        name = "composition scales the enemy count with prestige",
        fn = function()
            local low = Arena.build({ prestige = 1 }, proceduralSpec())
            local high = Arena.build({ prestige = 5 }, proceduralSpec())
            assert(#high.enemies > #low.enemies,
                "higher prestige should field more enemies (" .. #high.enemies
                    .. " vs " .. #low.enemies .. ")")
        end,
    },
    {
        name = "objective defaults to killAll, or honours an explicit win condition",
        fn = function()
            local dflt = Arena.build({ prestige = 1 }, proceduralSpec())
            assert(dflt.objective.type == "killAll", "missing objective should default to killAll")
            local surv = Arena.build({ prestige = 1 },
                proceduralSpec({ objective = { type = "survive", duration = 25 } }))
            assert(surv.objective.type == "survive" and surv.objective.duration == 25,
                "explicit objective (tick duration) should pass through")
        end,
    },
    {
        name = "curated arenas join the random pool (not always picked, not never)",
        fn = function()
            -- forest_01.lua (data/arenas) is tagged biome = "forest" with a 2x2 obstacle
            -- block at rows 4-5, cols 4-5 -- a signature the procedural generator will
            -- not reproduce. Over many seeds we should see BOTH the curated layout and
            -- fresh procedural ones, confirming a mixed pool rather than "always curated".
            local function isCurated(a)
                return a.tiles[4][4].type == "obstacle" and a.tiles[4][5].type == "obstacle"
                    and a.tiles[5][4].type == "obstacle" and a.tiles[5][5].type == "obstacle"
            end
            local curatedHits, proceduralHits = 0, 0
            for seed = 1, 60 do
                local a = Arena.build({ prestige = 1 }, proceduralSpec({ biome = "forest", seed = seed }))
                if isCurated(a) then curatedHits = curatedHits + 1 else proceduralHits = proceduralHits + 1 end
            end
            assert(curatedHits > 0, "the curated forest arena should be picked sometimes")
            assert(proceduralHits > 0, "procedural generation should still happen sometimes")
        end,
    },
    {
        name = "serialize round-trips tiles and spawn positions",
        fn = function()
            local a = Arena.build({ prestige = 2 }, proceduralSpec())
            local src = Arena.serialize(a)
            local layout = assert(loadstring(src), "serialized arena should be valid Lua")()
            assert(layout.biome == a.biome, "biome should round-trip")
            for y = 1, a.rows do
                for x = 1, a.cols do
                    assert(layout.tiles[y][x] == a.tiles[y][x].type,
                        "tile type should round-trip at " .. x .. "," .. y)
                end
            end
            assert(#layout.partySpawns == #a.party, "party spawn count should round-trip")
            assert(#layout.enemySpawns == #a.enemies, "enemy spawn count should round-trip")
            assert(layout.enemySpawns[1].x == a.enemies[1].x
                and layout.enemySpawns[1].y == a.enemies[1].y, "spawn positions should round-trip")
        end,
    },
    {
        -- A board built off the clock cannot be produced again, so the bug it contains cannot be
        -- shown to anyone -- and two machines building the same fight would quietly disagree about
        -- the ground. Generating without a seed is a programming error and has to say so.
        name = "generating a board without a seed is an error, not a silent roll of the clock",
        fn = function()
            local ok, err = pcall(Arena.generateLayout, { biome = "__test_void", party = 2, enemies = 2 })
            assert(not ok, "an unseeded generateLayout should raise")
            assert(tostring(err):find("seed"), "the error should name the seed: " .. tostring(err))

            local pickOk, pickErr = pcall(Arena.pickLayout, { biome = "__test_void" }, 2, 2)
            assert(not pickOk, "an unseeded pickLayout should raise")
            assert(tostring(pickErr):find("seed"), "the error should name the seed: " .. tostring(pickErr))
        end,
    },
    {
        name = "Arena.randomSeed is the one deliberate way to ask for a board nobody has seen",
        fn = function()
            local seed = Arena.randomSeed()
            assert(type(seed) == "number", "randomSeed should produce a number")
            -- It has to satisfy the gate it exists to satisfy.
            local layout = Arena.generateLayout({ biome = "__test_void", seed = seed,
                party = 2, enemies = 2 })
            assert(layout and layout.tiles, "a randomSeed board should build")
        end,
    },
    {
        -- A forced layout is authored ground, so it needs no seed to reproduce -- the escape the
        -- tutorial's scripted board takes.
        name = "a forced layout needs no seed",
        fn = function()
            local ok = pcall(Arena.pickLayout, { biome = "forest", layout = "tutorial_village" }, 2, 3)
            assert(ok, "naming a layout outright should not require a seed")
        end,
    },

    -- ----------------------------------------------------------------- the enemy ceiling
    {
        name = "the clamp keeps the named cast and cuts only the filler",
        fn = function()
            local ids = { "character_bandit_chief" }
            for _ = 1, 40 do ids[#ids + 1] = "character_bandit" end
            local cut = Arena.clampComposition(ids, 6)
            assert(#cut == 6, "cut to the cap, got " .. #cut)
            assert(cut[1] == "character_bandit_chief", "the named unit survives")

            -- ...and it survives from ANY position, not just the head. Every composition in the game
            -- lists its named unit first today, so a tail-truncation would pass by luck; this is the
            -- case that proves the rule is structural. Dropping an assassinate target is a softlock.
            local buried = {}
            for _ = 1, 40 do buried[#buried + 1] = "character_bandit" end
            buried[#buried + 1] = "character_bandit_chief"
            local cutB = Arena.clampComposition(buried, 6)
            assert(#cutB == 6, "still cut to the cap")
            local found = false
            for _, id in ipairs(cutB) do if id == "character_bandit_chief" then found = true end end
            assert(found, "a named unit at the TAIL survives the cut too")

            -- A short list is returned untouched, and a hand-authored cast of distinct names outranks
            -- the cap rather than being silently decimated.
            local short = { "a", "b" }
            assert(Arena.clampComposition(short, 6) == short, "under the cap, nothing is copied")
            local allNamed = { "a", "b", "c", "d", "e", "f", "g", "h" }
            assert(#Arena.clampComposition(allNamed, 3) == 8, "distinct names outrank the ceiling")
        end,
    },
    {
        -- THE REGRESSION THIS EXISTS FOR: every objective sizes its enemies off prestige, prestige is a
        -- lifetime total that New Game+ carries forward, and nothing used to bound the result -- the
        -- `/2` quests reached 71 bodies by the campaign's ~138 prestige and 140 in a second run. The
        -- ceiling has to hold at every prestige the game can actually reach, not just at the ones a
        -- fixture happens to pick.
        name = "no quest's objective can field more than its difficulty allows, at any prestige",
        fn = function()
            local Quest = require("models.quest")
            local checked = 0
            for id, def in pairs(Quest.defs) do
                local objective = def.map and def.map.objective
                if objective and objective.composition then
                    local ctx = { quest = def, biome = def.map.biome }
                    local cap = Arena.enemyCap(ctx)
                    -- 1 (a fresh company) through 276 (a full New Game+ carry), stepped to keep the
                    -- sweep cheap while still crossing every threshold a floor division can trip.
                    for prestige = 1, 276, 5 do
                        ctx.prestige = prestige
                        local raw = Arena.resolveComposition(objective.composition, ctx)
                        local cut = Arena.clampComposition(raw, cap)
                        -- Distinct ids outrank the cap by design, so the bound is whichever is larger.
                        local distinct, seen = 0, {}
                        for _, cid in ipairs(raw) do
                            if not seen[cid] then seen[cid] = true; distinct = distinct + 1 end
                        end
                        assert(#cut <= math.max(cap, distinct), string.format(
                            "%s fields %d at prestige %d (cap %d)", id, #cut, prestige, cap))

                        -- An assassinate target must still be standing on the board to be killed.
                        local win = objective.win
                        if win and win.type == "assassinate" and win.target then
                            local present = false
                            for _, cid in ipairs(cut) do
                                if cid == win.target then present = true end
                            end
                            local authored = false
                            for _, cid in ipairs(raw) do
                                if cid == win.target then authored = true end
                            end
                            assert(present or not authored, string.format(
                                "%s clamped away its assassinate target at prestige %d", id, prestige))
                        end
                    end
                    checked = checked + 1
                end
            end
            -- SEVEN postings, five prestige bands. It read `> 30` against the 42-quest ladder, and
            -- `> 50` against the 92-quest board before that; the ladder went with the houses
            -- (models/errand.lua) and what is left is one posting per class, so the floor moves
            -- with the campaign rather than the sweep silently passing on a fraction of it.
            assert(checked >= 7, "the sweep should cover every posting, saw " .. checked)
        end,
    },

    -- ---------------------------------------------------------------------------
    -- Ground: the overworld tile a fight was taken on shapes the board
    -- ---------------------------------------------------------------------------

    {
        name = "a rolled board ignores anything it was told about ground",
        fn = function()
            -- The ground profiles are gone: a fight is taken on the map's own tiles now, so nothing needs
            -- to guess what the ground was (see the note above Arena.BIOME_TERRAIN). What this pins is
            -- that the boardless callers -- draft matches, duels, build previews, the debug harness, every
            -- stored seed -- kept the board they always had, which is the one the old `path` profile drew.
            for seed = 1, 40 do
                local base = Arena.generateLayout({ biome = "forest", seed = seed * 13, party = 4, enemies = 3 })
                local junk = Arena.generateLayout({ biome = "forest", seed = seed * 13, party = 4, enemies = 3,
                    ground = "__no_such_ground" })
                assert(layoutSignature(base) == layoutSignature(junk),
                    "a leftover `ground` argument should change nothing")
            end
        end,
    },
    {
        name = "a rolled board reproduces from its seed",
        fn = function()
            do
                for _, biome in ipairs({ "forest", "swamp", "volcanic", "tundra" }) do
                    local a = Arena.generateLayout({ biome = biome, seed = 90210, party = 4, enemies = 3,
                        })
                    local b = Arena.generateLayout({ biome = biome, seed = 90210, party = 4, enemies = 3,
                        })
                    assert(layoutSignature(a) == layoutSignature(b),
                        biome .. " is not reproducible from its seed")
                end
            end
        end,
    },
    {
        name = "a rolled board never strands a spawn from the fight",
        fn = function()
            -- A4. The channel cannot cut a board -- water is walkable -- but the `block` scatter lays
            -- genuinely impassable tiles (obstacle, and lava on a volcanic floor), and the rock profile
            -- raises that count. So the connectivity this asserts is real and it is the block scatter's
            -- to break: every party spawn must be able to reach every enemy spawn.
            local function walkable(t)
                local p = Arena.TILE_PROPS[t]
                return p ~= nil and p.walkable == true
            end
            do
                for _, biome in ipairs({ "forest", "desert", "tundra", "volcanic", "swamp", "castle" }) do
                    for seed = 1, 25 do
                        local L = Arena.generateLayout({ biome = biome, seed = seed * 137, party = 4, enemies = 3,
                            })
                        local from = L.partySpawns[1]
                        assert(from, "a generated board seated no party spawn")
                        -- Flood from the first party spawn over walkable tiles.
                        local seen = { [from.y * 100 + from.x] = true }
                        local q, qi = { from }, 1
                        while qi <= #q do
                            local c = q[qi]; qi = qi + 1
                            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                                local nx, ny = c.x + d[1], c.y + d[2]
                                local k = ny * 100 + nx
                                if nx >= 1 and ny >= 1 and nx <= L.cols and ny <= L.rows
                                    and not seen[k] and walkable(L.tiles[ny][nx]) then
                                    seen[k] = true
                                    q[#q + 1] = { x = nx, y = ny }
                                end
                            end
                        end
                        for _, e in ipairs(L.enemySpawns) do
                            assert(seen[e.y * 100 + e.x], string.format(
                                "%s seed %d: enemy spawn %d,%d is walled off from the party",
                                biome, seed * 137, e.x, e.y))
                        end
                    end
                end
            end
        end,
    },
    {
        name = "...and neither does a hand-drawn one",
        fn = function()
            -- A hand-authored board runs NONE of the guards a rolled one does -- the block scatter's
            -- ceiling does not apply to it. Its floor has to be one piece because somebody drew it that
            -- way, and the only thing that will ever say otherwise is this.
            local function walkable(t)
                local p = Arena.TILE_PROPS[t]
                return p ~= nil and p.walkable == true
            end
            local checked = 0
            for id, def in pairs(Arena.defs) do
                local L = def
                local rows = L.rows or (L.tiles and #L.tiles) or 0
                local cols = L.cols or (L.tiles and L.tiles[1] and #L.tiles[1]) or 0
                assert(rows > 0 and cols > 0, id .. " has no tiles")
                local start
                for y = 1, rows do
                    for x = 1, cols do
                        if not start and walkable(L.tiles[y][x]) then start = { x = x, y = y } end
                    end
                end
                assert(start, id .. " has no floor at all")
                local seen = { [start.y * 100 + start.x] = true }
                local q, qi, n = { start }, 1, 0
                while qi <= #q do
                    local c = q[qi]; qi = qi + 1
                    n = n + 1
                    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local nx, ny = c.x + d[1], c.y + d[2]
                        local k = ny * 100 + nx
                        if nx >= 1 and ny >= 1 and nx <= cols and ny <= rows
                            and not seen[k] and walkable(L.tiles[ny][nx]) then
                            seen[k] = true
                            q[#q + 1] = { x = nx, y = ny }
                        end
                    end
                end
                local floor = 0
                for y = 1, rows do
                    for x = 1, cols do
                        if walkable(L.tiles[y][x]) then floor = floor + 1 end
                    end
                end
                assert(n == floor, string.format(
                    "%s: %d tiles of floor in one piece and %d walled off from it", id, n, floor - n))
                -- ...and every body the map itself seats stands in that piece.
                for _, list in ipairs({ L.partySpawns or {}, L.enemySpawns or {}, L.deployZone or {} }) do
                    for _, s in ipairs(list) do
                        assert(seen[s.y * 100 + s.x], string.format(
                            "%s: a body is seated at (%d,%d), off the board's own floor", id, s.x, s.y))
                    end
                end
                checked = checked + 1
            end
            assert(checked >= 4, "expected the curated pool to have been walked, saw " .. checked)
        end,
    },
    {
        name = "a rolled board never buries a spawn under terrain",
        fn = function()
            do
                for _, biome in ipairs({ "forest", "volcanic", "swamp" }) do
                    for seed = 1, 25 do
                        local L = Arena.generateLayout({ biome = biome, seed = seed * 211, party = 4, enemies = 3,
                            })
                        for _, list in ipairs({ L.partySpawns, L.enemySpawns }) do
                            for _, s in ipairs(list) do
                                local t = L.tiles[s.y][s.x]
                                assert(t == "ground", string.format(
                                    "%s/%s: a spawn opened the fight standing on %s", biome, ground, t))
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        name = "a rolled board never musters the enemy on the party's doorstep",
        fn = function()
            -- The board is entered by a door (models/arena.lua's `entry`) and the party's own two lines
            -- stand at depth 0..1 off that edge whichever wall it turns out to be. Nothing may seat
            -- inside ENEMY_MIN_DEPTH of it: the deployment zone is DEPLOY_DEPTH deep, so a body any
            -- closer opens the fight already in contact with a company that has not moved yet.
            local function depth(entry, cols, rows, s)
                if entry == "north" then return s.y - 1 end
                if entry == "west" then return s.x - 1 end
                if entry == "east" then return cols - s.x end
                return rows - s.y
            end
            for _, entry in ipairs({ "south", "north", "east", "west" }) do
                for seed = 1, 30 do
                    local L = Arena.generateLayout({ biome = "forest", seed = seed * 71, party = 4,
                        enemies = 5, entry = entry })
                    assert(#L.enemySpawns == 5, string.format(
                        "entry %s seed %d: seated %d of 5 enemies", entry, seed * 71, #L.enemySpawns))
                    for _, s in ipairs(L.enemySpawns) do
                        assert(depth(entry, L.cols, L.rows, s) >= Arena.ENEMY_MIN_DEPTH, string.format(
                            "entry %s seed %d: an enemy stands %d tiles off the company's edge",
                            entry, seed * 71, depth(entry, L.cols, L.rows, s)))
                    end
                end
            end
        end,
    },
    {
        name = "a rolled board scatters the enemy over the map rather than along the far wall",
        fn = function()
            -- WHAT THIS IS FOR: the enemy used to be seated by the same even line-fill the party gets, on
            -- the two rows farthest from it -- so every rolled fight opened identically, two ranks
            -- staring across six empty rows, and none of the ground between them mattered because both
            -- sides crossed all of it together. What replaced it is knots at varying depth, and this says
            -- so in the three ways that shape is visible from outside: the far wall is no longer where
            -- the fight is, the board is used across both axes, and bodies stand together.
            local depths, cols, wallOnly, withNeighbour, boards = {}, {}, 0, 0, 0
            for seed = 1, 40 do
                local L = Arena.generateLayout({ biome = "forest", seed = seed * 97, party = 4,
                    enemies = 5 })
                boards = boards + 1
                local deep, seen = true, {}
                for _, s in ipairs(L.enemySpawns) do
                    depths[L.rows - s.y] = true
                    cols[s.x] = true
                    if s.y > 2 then deep = false end
                    seen[s.x .. "," .. s.y] = true
                end
                if deep then wallOnly = wallOnly + 1 end
                for _, s in ipairs(L.enemySpawns) do
                    if seen[(s.x + 1) .. "," .. s.y] or seen[(s.x - 1) .. "," .. s.y]
                        or seen[s.x .. "," .. (s.y + 1)] or seen[s.x .. "," .. (s.y - 1)] then
                        withNeighbour = withNeighbour + 1
                        break
                    end
                end
            end
            local function count(t)
                local n = 0
                for _ in pairs(t) do n = n + 1 end
                return n
            end
            assert(count(depths) >= 4, "the enemy only ever appears at " .. count(depths) .. " depths")
            assert(count(cols) >= 6, "the enemy only ever appears in " .. count(cols) .. " columns")
            assert(wallOnly <= boards / 10, string.format(
                "%d of %d boards put the whole line on the far two rows", wallOnly, boards))
            -- Knots, not loners: a board of single enemies spread evenly is four separate 4-on-1s.
            assert(withNeighbour >= boards * 2 / 3, string.format(
                "only %d of %d boards stood any two enemies together", withNeighbour, boards))
        end,
    },
    {
        name = "the scatter leaves an escorted body room to be screened",
        fn = function()
            -- The one fight the scatter can decide before it starts: a `protect` objective anchors the
            -- body being escorted AHEAD of the party (`rally`), one row short of the ground the scatter
            -- is otherwise free to use -- so without ENEMY_PROTECT_CLEARANCE an escort fight opens with
            -- a body already touching the survivor. Walked over seeds, on the same shape
            -- encounter_survivors_defend brings.
            for seed = 1, 40 do
                local a = Arena.build({ prestige = 1 }, {
                    biome = "__test_void", seed = seed * 29,
                    party = { "character_avatar", "character_rowan" },
                    allies = { "character_survivor" },
                    composition = function() return { "character_demon_imp", "character_demon_imp",
                        "character_demon_imp" } end,
                    objective = { type = "defend", anchor = "rally", turns = 5,
                        protect = "character_survivor" },
                })
                for _, u in ipairs(a.allies or {}) do
                    for _, e in ipairs(a.enemies) do
                        local d = math.max(math.abs(u.x - e.x), math.abs(u.y - e.y))
                        assert(d > Arena.ENEMY_PROTECT_CLEARANCE, string.format(
                            "seed %d: an enemy opened the fight %d tiles from the escorted body",
                            seed * 29, d))
                    end
                end
            end
        end,
    },
}
