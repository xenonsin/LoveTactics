-- Tests for the prologue flight leg's new engine + content (states/prologue.lua's FLIGHT_QUEST):
-- mid-map objective placement + the `defend` objective (models/arena.lua, models/combat.lua), the
-- ascent route carrying per-stop payloads (models/overworld.lua), the new encounters/characters, and
-- the leg's own wiring. Pure logic, headless; the coach bubbles + waves-in-battle are verified
-- in-window.

local Arena = require("models.arena")
local Combat = require("models.combat")
local Overworld = require("models.overworld")
local Encounter = require("models.encounter")
local Character = require("models.character")

-- A { char, x, y } spawn entry from a blueprint id.
local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- A flat, all-walkable arena of the given size, with an objective (mirrors tests/combat_spec.lua).
local function flatArena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", walkable = true, moveCost = 1 } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

return {
    -- ----- mid-map objective placement (models/arena.lua) -----
    {
        name = "a defend objective anchors its protected ally to the board's centre, off the party spawns",
        fn = function()
            local a = Arena.build({ prestige = 1 }, {
                biome = "__test_void", seed = 77,
                party = { "character_knight", "character_mage" },
                allies = { "character_survivor" },
                composition = function() return { "character_demon_imp", "character_demon_imp" } end,
                objective = { type = "defend", anchor = "center", turns = 5, protect = "character_survivor" },
            })
            local surv
            for _, u in ipairs(a.allies or {}) do if u.id == "character_survivor" then surv = u end end
            assert(surv, "the survivor ally was seated on the board")
            local cx, cy = math.floor(a.cols / 2), math.floor(a.rows / 2)
            assert(surv.x >= cx and surv.x <= cx + 1 and surv.y >= cy and surv.y <= cy + 1,
                "the survivor stands in the centre 2x2, not beside the party")
            for _, p in ipairs(a.party) do
                assert(not (p.x == surv.x and p.y == surv.y), "the survivor does not share a party spawn")
            end
        end,
    },
    {
        name = "the survivors_defend encounter is winnable: survivors seat within the party's reach, clear of the demons",
        fn = function()
            local defend = Encounter.get("encounter_survivors_defend")
            local a = Arena.build({ prestige = 1 }, {
                biome = "__test_void", seed = 123,
                party = { "character_avatar", "character_knight" }, -- the flight party (avatar + Rowan)
                allies = defend.allies,
                composition = defend.composition,
                objective = defend.objective,
            })
            local survs = {}
            for _, u in ipairs(a.allies or {}) do if u.id == "character_survivor" then survs[#survs + 1] = u end end
            assert(#survs == 2, "both survivors are seated, got " .. #survs)
            -- Measured along the board's depth (rows): a survivor the party can screen sits near the
            -- party and far from the demons -- the whole point of the `rally` anchor over `center`.
            for _, s in ipairs(survs) do
                local toParty, toEnemy = math.huge, math.huge
                for _, p in ipairs(a.party) do toParty = math.min(toParty, math.abs(s.y - p.y)) end
                for _, e in ipairs(a.enemies) do toEnemy = math.min(toEnemy, math.abs(s.y - e.y)) end
                assert(toParty <= 2, "a survivor sits within 2 rows of the party (screenable), got " .. toParty)
                assert(toEnemy >= 3, "a survivor sits at least 3 rows from the nearest demon, got " .. toEnemy)
                assert(toParty < toEnemy, "a survivor is closer to the party than to the demons")
            end
            -- Turn 1 opens with no melee grunt already in the survivors' faces (it arrives as a wave).
            for _, id in ipairs(defend.composition({ prestige = 1 })) do
                assert(id ~= "character_demon_grunt", "the grunt is held out of the opening composition")
            end
        end,
    },
    {
        name = "without an anchor, an escorted ally still seats on the party spawns (regression)",
        fn = function()
            local a = Arena.build({ prestige = 1 }, {
                biome = "__test_void", seed = 77,
                party = { "character_knight", "character_mage" },
                allies = { "character_caravan_driver" },
                composition = function() return { "character_demon_imp" } end,
                objective = { type = "reach", region = "far", protect = "character_caravan_driver" },
            })
            local driver
            for _, u in ipairs(a.allies or {}) do if u.id == "character_caravan_driver" then driver = u end end
            assert(driver, "the driver was seated")
            assert(driver.y >= a.rows - 1, "the driver seats on a near (party) row, not the middle")
        end,
    },

    -- ----- the `defend` objective (models/combat.lua) -----
    {
        name = "defend: outlast the tick duration with the protectee alive is a win; its death is a loss",
        fn = function()
            local obj = { type = "defend", duration = 15, protect = "character_survivor" }
            local c = Combat.new(flatArena(8, 8, obj),
                { unit("character_knight", 1, 1), unit("character_survivor", 2, 2) },
                { unit("character_bandit", 6, 6) })
            assert(Combat.evaluate(c) == nil, "ongoing before the clock passes the duration")
            c.clock = 15 -- ticks, the unit the clock counts
            assert(Combat.evaluate(c) == "win", "outlasting the duration with the survivor alive wins")

            local dead = Combat.new(flatArena(8, 8, obj),
                { unit("character_knight", 1, 1), unit("character_survivor", 2, 2) },
                { unit("character_bandit", 6, 6) })
            dead.units[2].alive = false -- the survivor falls
            assert(Combat.evaluate(dead) == "loss", "the protectee dying fails the defend, clock or no clock")
        end,
    },
    {
        name = "timed objectives and waves are authored in ticks, not turns",
        fn = function()
            local defend = Encounter.get("encounter_survivors_defend")
            assert(defend.objective.turns == nil, "no `turns` field survives on the objective")
            assert(type(defend.objective.duration) == "number", "the defend duration is a tick count")
            for _, wave in ipairs(defend.objective.waves) do
                assert(wave.turn == nil, "no `turn` field survives on a wave")
                assert(type(wave.at) == "number", "a wave arrives at a tick mark")
            end
        end,
    },

    -- ----- the ascent route carries per-stop payloads (models/overworld.lua) -----
    {
        name = "the flight route places its always-list in authored order by distance, with payloads intact",
        fn = function()
            local always = {
                { id = "encounter_treasure", loot = { "weapon_iron_bow" } },
                { id = "encounter_event", conversation = "flight_event_shrine" },
                "encounter_survivors_defend",
                "encounter_rest",
            }
            -- Resolve like states/game.lua does: bare ids and payload tables both allowed.
            local resolved = {}
            for _, e in ipairs(always) do
                local id = type(e) == "table" and e.id or e
                local def = Encounter.get(id)
                resolved[#resolved + 1] = { id = id, kind = def.kind, name = def.name,
                    loot = type(e) == "table" and e.loot or nil,
                    conversation = type(e) == "table" and e.conversation or nil }
            end

            local grid = Overworld.generate({
                cols = 31, rows = 21, seed = 20260720, biome = "forest",
                ascent = true, encounterCount = #resolved,
                alwaysEncounters = resolved, objective = { name = "Champion" },
            })

            local dist = grid:bfsDistances(grid:startCell())
            local function keyOf(c) return c.y * 100000 + c.x end
            local placed = {}
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    -- The objective tile carries an encounter of its own (kind "objective"); it is not
                    -- one of the route stops, so leave it out of the ordering check.
                    if c.encounter and c.encounter.kind ~= "objective" then placed[#placed + 1] = c end
                end
            end
            assert(#placed == #resolved, "every route stop was placed, got " .. #placed)
            table.sort(placed, function(a, b) return (dist[keyOf(a)] or 0) < (dist[keyOf(b)] or 0) end)

            local order = {}
            for i, c in ipairs(placed) do order[i] = c.encounter.id end
            assert(order[1] == "encounter_treasure", "the treasure is the nearest stop")
            assert(order[2] == "encounter_event", "the event follows it")
            assert(order[#order] == "encounter_rest", "the rest is the last stop before the objective")

            -- Payloads rode onto the cells.
            assert(placed[1].encounter.loot and placed[1].encounter.loot[1] == "weapon_iron_bow",
                "the treasure carries its authored loot")
            assert(placed[2].encounter.conversation == "flight_event_shrine",
                "the event carries its conversation")

            -- The objective sits beyond every stop.
            local objDist = dist[keyOf(grid:objectiveCell())] or 0
            for _, c in ipairs(placed) do
                assert(objDist > (dist[keyOf(c)] or 0), "the objective is farther than every route stop")
            end
        end,
    },

    -- ----- new content -----
    {
        name = "the new flight encounters are authored-only (weight 0) and never roll into an ordinary pool",
        fn = function()
            for _, id in ipairs({ "encounter_survivors_defend", "encounter_survivors_extract",
                                  "encounter_event", "encounter_rest" }) do
                local def = Encounter.get(id)
                assert(def, "encounter exists: " .. id)
                assert(def.weight == 0, id .. " is authored-only (weight 0)")
            end
            local pool = Encounter.pool({ prestige = 1, biome = "forest" })
            for _, e in ipairs(pool) do
                assert(e.id ~= "encounter_survivors_defend" and e.id ~= "encounter_rest",
                    "authored-only encounters stay out of the weighted pool")
            end
        end,
    },
    {
        name = "the defend encounter rallies survivors ahead of the party; the extract encounter escorts a driver out",
        fn = function()
            local defend = Encounter.get("encounter_survivors_defend")
            assert(defend.objective.type == "defend" and defend.objective.anchor == "rally",
                "defend anchors the survivors just ahead of the party, not mid-board")
            assert(defend.objective.protect == "character_survivor", "it protects the survivor")
            assert(#defend.objective.waves >= 1, "it fields reinforcement waves")

            local extract = Encounter.get("encounter_survivors_extract")
            assert(extract.objective.type == "reach", "extract is a reach objective")
            assert(extract.objective.who == "character_caravan_driver"
                and extract.objective.protect == "character_caravan_driver",
                "the driver must both cross and survive")
        end,
    },
    {
        name = "the survivor and the demon champion instantiate; the champion is a boss",
        fn = function()
            local surv = Character.instantiate("character_survivor")
            assert(surv and surv.archetype == "holdGround", "the survivor is rooted where it stands")
            local champ = Character.instantiate("character_demon_champion")
            assert(champ and champ.boss == true, "the champion is a boss (immune to instant execution)")
        end,
    },

    -- ----- the leg's wiring (states/prologue.lua) -----
    {
        name = "the flight leg is the overworld tutorial: a pinned trail ending on the champion",
        fn = function()
            local map = require("states.prologue").FLIGHT_QUEST.map
            assert(map.tutorial == "flight", "the flight leg drives the overworld coach flow")
            assert(map.layout == "tutorial_flight", "it walks a hand-authored trail, not a rolled maze")

            -- The authored route, in order: the ids the sequencer walks the player through.
            local ids = {}
            for _, e in ipairs(map.encounters.always) do ids[#ids + 1] = type(e) == "table" and e.id or e end
            assert(ids[1] == "encounter_treasure", "the route opens on the teaching chest")
            local sawDefend, sawExtract, sawEvent, sawRest = false, false, false, false
            for _, id in ipairs(ids) do
                sawDefend = sawDefend or id == "encounter_survivors_defend"
                sawExtract = sawExtract or id == "encounter_survivors_extract"
                sawEvent = sawEvent or id == "encounter_event"
                sawRest = sawRest or id == "encounter_rest"
                assert(Encounter.get(id), "route stop resolves: " .. id)
            end
            assert(sawDefend and sawExtract, "both combat-objective lessons are on the route")
            assert(sawEvent, "at least one narrative event is on the route")
            assert(ids[#ids] == "encounter_rest", "a rest is the last stop before the mini-boss")

            -- The first chest hands over the teaching kit; the mini-boss is the champion, won by assassinate.
            assert(map.encounters.always[1].loot[1] == "weapon_iron_bow", "the first chest gives the bow kit")
            assert(map.objective.win.type == "assassinate"
                and map.objective.win.target == "character_demon_champion",
                "the leg ends on the Demon Champion, felled by assassinate")
        end,
    },

    -- ----- the authored trail itself (models/overworld.lua's fromLayout + data/overworld/tutorial_flight) -----
    {
        name = "the authored flight trail is a single road: chest first, every stop in order, boss last",
        fn = function()
            local map = require("states.prologue").FLIGHT_QUEST.map

            -- Resolve the always-list the way states/game.lua does, then build the grid off the layout.
            local always = {}
            for _, e in ipairs(map.encounters.always) do
                local id = type(e) == "table" and e.id or e
                local def = Encounter.get(id)
                always[#always + 1] = { id = id, kind = def.kind, name = def.name,
                    loot = type(e) == "table" and e.loot or nil,
                    conversation = type(e) == "table" and e.conversation or nil }
            end
            local grid = Overworld.fromLayout({
                layout = map.layout, biome = map.biome,
                objective = map.objective, alwaysEncounters = always,
            })

            -- The start carries no encounter; the objective cell is the champion.
            assert(grid:startCell().encounter == nil, "the player does not spawn on an encounter tile")
            assert(grid:objectiveCell().encounter.kind == "objective", "X is the objective")

            -- Every route stop was placed, in the authored id order, keyed by distance from the start.
            local dist = grid:bfsDistances(grid:startCell())
            local function keyOf(c) return c.y * 100000 + c.x end
            local placed = {}
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.kind ~= "objective" then placed[#placed + 1] = c end
                end
            end
            assert(#placed == #always, "every route stop sits on the trail, got " .. #placed)
            table.sort(placed, function(a, b) return (dist[keyOf(a)] or 0) < (dist[keyOf(b)] or 0) end)
            for i, c in ipairs(placed) do
                assert(dist[keyOf(c)], "route stop " .. i .. " is reachable from the start")
                assert(c.encounter.id == always[i].id,
                    "stop " .. i .. " is " .. tostring(always[i].id) .. ", got " .. tostring(c.encounter.id))
            end
            assert(placed[1].encounter.id == "encounter_treasure", "the chest is the nearest stop")
            assert(placed[1].encounter.loot[1] == "weapon_iron_bow", "and it carries the bow kit")

            -- The boss sits beyond every stop, and the whole map is one reachable trail (no islands).
            local objDist = dist[keyOf(grid:objectiveCell())] or 0
            for _, c in ipairs(placed) do
                assert(objDist > (dist[keyOf(c)] or 0), "the champion is farther than every route stop")
            end
            local reachable = grid:reachable()
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if grid:typeWalkable(c.tile) then
                        assert(reachable[keyOf(c)], "trail tile " .. x .. "," .. y .. " is connected")
                    end
                end
            end
        end,
    },
}
