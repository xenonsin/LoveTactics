-- THE TRIP: a day buys a GROUND, and everything the houses have posted there is standing on the board
-- when the company arrives.
--
-- The unit of an expedition used to be a quest -- one objective, one payout, one trip home -- and this
-- file pins what changed when it became a place. The rules worth guarding are all of the shape "the
-- panel, the board and the payout must agree about what is out there":
--
--   * every piece of work on the ground gets an end, and every end names its own quest
--   * the ends are distinct tiles and the board grows to hold them
--   * a resumed trip comes back with the same work and the same boxes ticked
--   * clearing one piece of work pays exactly that one, once
--
-- Pure model throughout (no state module, nothing drawn), so it loads under the headless runner.

local Quest = require("models.quest")
local Player = require("models.player")
local Overworld = require("models.overworld")
local Save = require("models.save")
local Calendar = require("models.calendar")

-- A board entry of the shape Quest.available hands out, without needing a real blueprint: the trip
-- builder reads id / name / map / sponsor / floorLevel and nothing else.
local function entry(id, opts)
    opts = opts or {}
    return {
        id = id,
        name = opts.name or id,
        sponsor = opts.sponsor,
        floorLevel = opts.floorLevel,
        rewardItems = opts.rewardItems,
        map = {
            biome = opts.biome or "forest",
            encounters = opts.encounters or { min = 3, max = 4 },
            keyCount = opts.keyCount,
            objective = opts.objective or { name = id .. " boss" },
        },
    }
end

local function generate(trip, seed)
    return Overworld.generate({
        biome = trip.map.biome,
        seed = seed or 20260813,
        encounterCount = trip.map.encounters,
        keyCount = trip.map.keyCount,
        objectives = trip.map.objectives,
        encounters = { { kind = "combat", weight = 1 } },
    })
end

return {
    {
        name = "a ground's trip carries every piece of work posted on it",
        fn = function()
            local trip = Quest.trip("forest", {
                entry("_a", { sponsor = "colosseum" }),
                entry("_b", { sponsor = "bastion" }),
                entry("_c"),
            })
            assert(trip, "three pieces of work is a day worth travelling for")
            assert(#trip.quests == 3, "all three ride the trip, got " .. #trip.quests)
            assert(#trip.map.objectives == 3, "and each gets an end, got " .. #trip.map.objectives)
            assert(trip.map.biome == "forest", "the ground is stamped as the run's one biome")
            -- The id must not collide with a quest blueprint: a resumed run tells the two apart by it.
            assert(Quest.isTripId(trip.id), "a trip's id says what it is: " .. tostring(trip.id))
            assert(Quest.defs[trip.id] == nil, "and it is not a quest anything could look up")
        end,
    },
    {
        name = "every end names the quest it belongs to",
        fn = function()
            -- The tile carries an ID rather than the spec itself, because a spec can hold a composition
            -- FUNCTION (the finale sizes itself by how many generals are still standing) and the whole
            -- board is serialized into the save, which has to stay plain data.
            local trip = Quest.trip("forest", { entry("_a"), entry("_b") })
            for _, spec in ipairs(trip.map.objectives) do
                assert(spec.questId, "an end with no quest on it pays nobody")
            end
            assert(trip.map.objectives[1].questId ~= trip.map.objectives[2].questId,
                "two ends, two quests")
        end,
    },
    {
        name = "a locked warning gets no end -- it is not a destination",
        fn = function()
            -- The Gate's countdown rides along with every ground (Quest.board) as a warning. Giving it
            -- an objective tile would put the demon lord on the tundra.
            local warning = entry("_locked")
            warning.locked = true
            local trip = Quest.trip("forest", { entry("_a"), warning })
            assert(#trip.quests == 1, "only the startable work rides")
            assert(#trip.map.objectives == 1, "and only it gets an end")
        end,
    },
    {
        name = "a ground with nothing startable on it is not a trip at all",
        fn = function()
            local warning = entry("_locked")
            warning.locked = true
            assert(Quest.trip("forest", { warning }) == nil,
                "a ground holding only a warning cannot be travelled to")
            assert(Quest.trip("forest", {}) == nil, "nor can an empty one")
        end,
    },
    {
        name = "the day's fights are summed but capped",
        fn = function()
            local heavy = {}
            for i = 1, 6 do
                heavy[i] = entry("_h" .. i, { encounters = { min = 8, max = 12 } })
            end
            local trip = Quest.trip("forest", heavy)
            local enc = trip.map.encounters
            assert(enc.max <= Quest.TRIP_ENCOUNTER_CAP, string.format(
                "six heavy quests asked for %d stops; the cap is %d", enc.max, Quest.TRIP_ENCOUNTER_CAP))
            assert(enc.min <= enc.max, "the floor was capped too, or the range is inverted")
            -- Two light quests are genuinely a longer day than one, which is the point of summing.
            local light = Quest.trip("forest", { entry("_a"), entry("_b") })
            assert(light.map.encounters.max > entry("_a").map.encounters.max,
                "two pieces of work make a longer road than one")
        end,
    },
    {
        name = "only the deepest approach keeps its lock",
        fn = function()
            -- Key counts are authored per quest. Summing them would have a player hunting six keys to
            -- spend one day, and a door that cannot be opened is the one failure a trip must not
            -- produce (models/overworld.lua gates the deepest end only).
            local trip = Quest.trip("forest", {
                entry("_a", { keyCount = 2 }),
                entry("_b", { keyCount = 1 }),
                entry("_c", { keyCount = 3 }),
            })
            assert(trip.map.keyCount == 3,
                "the deepest lock stands, got " .. tostring(trip.map.keyCount))
        end,
    },
    {
        name = "the board puts every end on its own tile",
        fn = function()
            local trip = Quest.trip("forest", { entry("_a"), entry("_b"), entry("_c") })
            local grid = generate(trip)
            assert(#grid.objectives == 3, "three ends were asked for, got " .. #grid.objectives)

            local seen = {}
            for _, obj in ipairs(grid.objectives) do
                local key = obj.x .. "," .. obj.y
                assert(not seen[key], "two ends landed on the same tile at " .. key)
                seen[key] = true
                local cell = grid:get(obj.x, obj.y)
                assert(cell and cell.encounter and cell.encounter.kind == "objective",
                    "an end with no objective encounter on it is unreachable work")
                assert(cell.encounter.questId == obj.questId,
                    "the tile and the index disagree about whose end this is")
            end
            -- The deepest end keeps the old name, so everything that wants "the far end of the board"
            -- as a single tile still has one.
            assert(grid.objective and grid.objective.x == grid.objectives[1].x,
                "grid.objective must still point at the deepest end")
        end,
    },
    {
        name = "every end is reachable from the start",
        fn = function()
            -- The one failure this whole system must not be able to produce: a piece of work the player
            -- travelled for, standing on ground they cannot walk to. Several seeds, because the ends
            -- are placed against whatever dead ends a given carve happened to leave.
            local trip = Quest.trip("forest", { entry("_a"), entry("_b"), entry("_c") })
            for seed = 1, 25 do
                local grid = generate(trip, seed * 7919)
                local dist = grid:bfsDistances(grid:get(grid.start.x, grid.start.y))
                for i, obj in ipairs(grid.objectives) do
                    local key = obj.y * 100000 + obj.x
                    assert(dist[key], string.format(
                        "seed %d: end %d at %d,%d cannot be walked to", seed, i, obj.x, obj.y))
                end
            end
        end,
    },
    {
        name = "the board grows to hold the ends it was given",
        fn = function()
            local one = generate(Quest.trip("forest", { entry("_a") }))
            local many = generate(Quest.trip("forest",
                { entry("_a"), entry("_b"), entry("_c"), entry("_d") }))
            assert(many.cols * many.rows >= one.cols * one.rows, string.format(
                "four ends got a %dx%d board against one end's %dx%d",
                many.cols, many.rows, one.cols, one.rows))
        end,
    },
    {
        name = "a single-quest leg still generates exactly as it always did",
        fn = function()
            -- Every authored leg and every descent floor passes `objective`, not `objectives`. They
            -- must come through the generator as a list of one, with the same tile chosen by the same
            -- rule -- this is what makes the change invisible to the prologue.
            local params = {
                biome = "forest", seed = 4242, encounterCount = { min = 4, max = 4 },
                objective = { name = "The Old Way" },
                encounters = { { kind = "combat", weight = 1 } },
            }
            local grid = Overworld.generate(params)
            assert(grid.objectives and #grid.objectives == 1,
                "one objective reports as a list of one")
            assert(grid.objective.x == grid.objectives[1].x and grid.objective.y == grid.objectives[1].y,
                "and the two names point at the same tile")
            local cell = grid:get(grid.objective.x, grid.objective.y)
            assert(cell.encounter.name == "The Old Way", "the authored name still lands on the tile")
        end,
    },
    {
        name = "a trip survives a save and comes back with the same work",
        fn = function()
            local trip = Quest.trip("forest", { entry("_a"), entry("_b") })
            local grid = generate(trip)
            local run = {
                questId = trip.id,
                day = 5,
                trip = { groundId = "forest", questIds = { "_a", "_b" } },
                tripDone = { _a = true },
                grid = grid,
                map = { px = grid.start.x, py = grid.start.y, keysHeld = {}, cacheHaul = {} },
            }
            local snap = Save.snapshotRun(run, Player.new())
            assert(snap, "a trip in progress snapshots")
            assert(snap.trip and snap.trip.groundId == "forest", "the ground travels with the run")
            assert(#snap.trip.questIds == 2, "and so does what was posted on it")
            assert(snap.tripDone._a == true and snap.tripDone._b == nil,
                "and exactly which boxes were ticked")
            -- The board itself carries the ends, so a resumed run knows where the work is standing.
            assert(snap.grid.objectives and #snap.grid.objectives == 2,
                "the stored board keeps both ends")
            local back = Overworld.fromSnapshot(snap.grid)
            assert(#back.objectives == 2, "and gets them back")
            assert(back.objectives[1].questId, "with the quest each belongs to")
        end,
    },
    {
        name = "a board saved before trips existed restores with the one end it had",
        fn = function()
            -- An expedition in flight when the game is upgraded must finish, not resume onto a board
            -- with no work on it.
            local grid = Overworld.generate({
                biome = "forest", seed = 99, encounterCount = { min = 3, max = 3 },
                objective = { name = "Legacy" },
                encounters = { { kind = "combat", weight = 1 } },
            })
            local snap = grid:snapshot()
            snap.objectives = nil -- as an older save would have been written
            local back = Overworld.fromSnapshot(snap)
            assert(#back.objectives == 1, "the single end it had is still an end")
            assert(back.objectives[1].x == back.objective.x, "and it is the one it always was")
        end,
    },
    {
        name = "rebuilding a trip from its ids does not ask the board again",
        fn = function()
            -- Half the point of a trip is that clearing work takes it OFF the board, so a resume that
            -- re-derived the list would lose the very rows it had just ticked. The ids travel with the
            -- run; this turns them back into work, whatever the player has since completed.
            local ids = { "quest_colosseum_slot_01" }
            local rebuilt = Quest.tripFromIds("colosseum_sand", ids)
            assert(rebuilt, "the debut's ground rebuilds from its id alone")
            assert(#rebuilt.quests == 1 and rebuilt.quests[1].id == ids[1],
                "with exactly the work the run was carrying")
            -- An id that has left the data is skipped rather than fatal: its end simply pays nothing.
            local partial = Quest.tripFromIds("colosseum_sand", { ids[1], "_removed_since" })
            assert(partial and #partial.quests == 1,
                "a renamed quest costs its own end, not the whole expedition")
        end,
    },
    {
        name = "clearing one piece of work pays that one, and only once",
        fn = function()
            local p = Player.new()
            p.completedQuests = {}
            p.day = 3
            local gold = p.gold or 0

            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "the debut is a real quest to finish")
            local reward = Quest.complete(p, quest, nil, { keepMeal = true })
            assert(reward, "the first clear pays")
            assert((p.gold or 0) > gold, "in gold")
            assert(p.completedQuests[quest.id], "and the ledger says so")
            assert(Quest.complete(p, quest, nil, { keepMeal = true }) == nil,
                "a second clear of the same end pays nothing")
        end,
    },
    {
        name = "the supper survives a piece of work and is spent by the day",
        fn = function()
            -- The Cafe's platter is bought for the DAY now. Without keepMeal the first objective of
            -- three ate it and the other two fights went hungry.
            local Meal = require("models.meal")
            local p = Player.new()
            p.completedQuests = {}
            p.meal = "meal_morning_oats"

            local quest = Quest.get("quest_colosseum_slot_01")
            local reward = Quest.complete(p, quest, nil, { keepMeal = true })
            assert(p.meal == "meal_morning_oats", "the company is still fed after one fight")
            assert(reward.mealSpent == nil, "and nothing claims the supper ran out")

            Meal.clear(p)
            assert(p.meal == nil, "the exit is what spends it")
        end,
    },
    {
        name = "the last day's trip is the Gate alone",
        fn = function()
            local p = Player.new()
            p.completedQuests = { quest_colosseum_slot_01 = true }
            p.day = Calendar.DAYS

            local board = Quest.board(p)
            local trips = 0
            for _, ground in ipairs(board.grounds) do
                local trip = Quest.trip(ground.id, ground.quests)
                if trip then
                    trips = trips + 1
                    assert(#trip.quests == 1 and trip.quests[1].id == "quest_the_gate_below",
                        "the only work on the last day is the Gate")
                end
            end
            assert(trips == 1, "and there is exactly one ground to take it on, got " .. trips)
        end,
    },
}
