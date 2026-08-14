-- Quest.board: what the board offers today, grouped by the ground you would have to travel to.
--
-- The distinction this file guards is that Quest.available and Quest.board answer DIFFERENT questions
-- and neither may quietly start answering the other's. `available` is progress; `board` is progress
-- plus the season table. A quest a shut window filtered out is not locked, and the moment those two
-- blur, either forty specs start failing or the windows stop existing.

local Quest = require("models.quest")
local Player = require("models.player")
local Calendar = require("models.calendar")
local BiomeWindow = require("models.biome_window")

local function playerOn(day, completed)
    local p = Player.new()
    p.completedQuests = completed or {}
    p.day = day
    return p
end

-- Standing is a count of finished quests, so a walkable mid-campaign player is built by filling in
-- synthetic ids -- ones not in Quest.defs move the count and drag no sponsor in behind them.
local function standing(n)
    local done = {}
    for i = 1, math.max(0, n - 1) do done["_filler_" .. i] = true end
    return done
end

local function ids(board)
    local out = {}
    for _, g in ipairs(board.grounds) do out[#out + 1] = g.id end
    return out
end

local function groundNamed(board, id)
    for _, g in ipairs(board.grounds) do
        if g.id == id then return g end
    end
    return nil
end

return {
    {
        name = "the board's grounds are the day's open ones",
        fn = function()
            for _, day in ipairs({ 1, 8, 15, 22, 30, 40 }) do
                local board = Quest.board(playerOn(day, standing(12)))
                for _, id in ipairs(BiomeWindow.openOn(day)) do
                    assert(groundNamed(board, id), "day " .. day .. ": open ground " .. id ..
                        " is missing from the board")
                end
            end
        end,
    },
    {
        name = "every quest offered on a ground can actually be run there",
        fn = function()
            for day = 1, Calendar.DAYS do
                local board = Quest.board(playerOn(day, standing(20)))
                for _, g in ipairs(board.grounds) do
                    for _, q in ipairs(g.quests) do
                        local def = Quest.defs[q.id]
                        local named = BiomeWindow.biomesOf(def)
                        local ok = #named == 0 or def.finale
                        for _, biomeId in ipairs(named) do
                            if biomeId == g.id then ok = true end
                        end
                        assert(ok, string.format("day %d: %s was offered in %s, which it does not name",
                            day, q.id, g.id))
                    end
                end
            end
        end,
    },
    {
        name = "the board never offers a quest Quest.available withheld",
        fn = function()
            for _, day in ipairs({ 1, 10, 25, 40 }) do
                local p = playerOn(day, standing(9))
                local allowed = {}
                for _, q in ipairs(Quest.available(p)) do allowed[q.id] = true end
                for _, g in ipairs(Quest.board(p).grounds) do
                    for _, q in ipairs(g.quests) do
                        assert(allowed[q.id], "day " .. day .. ": board offered ungated quest " .. q.id)
                    end
                end
            end
        end,
    },
    {
        name = "a shut window withholds work without locking it",
        fn = function()
            -- The whole premise: the same player, two days apart, offered different work -- and the
            -- quest that vanished is not marked locked, it is simply somewhere else.
            local seen = {}
            for day = 1, Calendar.DAYS do
                local board = Quest.board(playerOn(day, standing(20)))
                for _, g in ipairs(board.grounds) do
                    for _, q in ipairs(g.quests) do seen[q.id] = (seen[q.id] or 0) + 1 end
                end
            end
            local sometimes = 0
            for _, days in pairs(seen) do
                if days < Calendar.DAYS then sometimes = sometimes + 1 end
            end
            assert(sometimes > 0, "no quest was ever withheld by a window -- the schedule does nothing")
        end,
    },
    {
        name = "the debut is reachable on the first morning",
        fn = function()
            -- Measured the hard way once: the debut stands on the sand and the first draft of the
            -- season table opened the desert on day 10, which made days 1-9 unplayable.
            local board = Quest.board(playerOn(1, {}))
            local offered = 0
            for _, g in ipairs(board.grounds) do offered = offered + #g.quests end
            assert(offered > 0, "day 1 offers no quest at all -- the campaign cannot start")
        end,
    },
    {
        name = "every day of the campaign offers at least one quest to a mid-campaign company",
        fn = function()
            for day = 1, Calendar.DAYS do
                local board = Quest.board(playerOn(day, standing(20)))
                local offered = 0
                for _, g in ipairs(board.grounds) do offered = offered + #g.quests end
                assert(offered > 0, "day " .. day .. " offers a mid-campaign company nothing at all")
            end
        end,
    },
    {
        name = "the finale always gets a ground, even one the schedule has shut",
        fn = function()
            local p = playerOn(Calendar.DAYS, standing(20))
            local board = Quest.board(p)
            local found
            for _, g in ipairs(board.grounds) do
                for _, q in ipairs(g.quests) do
                    if Quest.defs[q.id] and Quest.defs[q.id].finale then found = g.id end
                end
            end
            assert(found, "the last day does not offer the finale")
        end,
    },
    {
        name = "the last morning offers the Gate and nothing else, on one ground",
        fn = function()
            -- THE DAY BELONGS TO HIM. Every other ground is still open and still listed -- the schedule
            -- says so and the panel's tab row is laid out over what it is given -- but nothing is filed
            -- under them, which is what collapses the travel row to a single plate (the panel drops a
            -- ground holding nothing). A board still offering the Bastion's next errand on day forty
            -- would be the game hiding its own ending behind a tab.
            local board = Quest.board(playerOn(Calendar.DAYS, standing(20)))
            local offered, ground = 0, nil
            for _, g in ipairs(board.grounds) do
                offered = offered + #g.quests
                if #g.quests > 0 then ground = g end
            end
            assert(offered == 1, "the last day offered " .. offered .. " expeditions, not just the Gate")
            assert(Quest.defs[ground.quests[1].id].finale, "and the one on offer is not the finale")

            -- The day before, the board is an ordinary board.
            local before = Quest.board(playerOn(Calendar.DAYS - 1, standing(20)))
            local ordinary = 0
            for _, g in ipairs(before.grounds) do ordinary = ordinary + #g.quests end
            assert(ordinary > 1, "day " .. (Calendar.DAYS - 1) .. " must still be a day of choices")
        end,
    },
    {
        -- What Quest.start used to guard, asked of the thing that replaced it. Its job was to collapse
        -- a quest's SET of grounds down to the one travelled to, without writing through to the shared
        -- blueprint -- a save-corrupting bug no single-run spec would ever have seen. The trip names
        -- the ground once, at the top, for everything standing on it; the blueprint must still come
        -- out of it untouched.
        name = "a trip names one ground and leaves the blueprints alone",
        fn = function()
            local blueprint = { biomes = { "swamp", "castle" }, keyCount = 1,
                objective = { name = "boss" } }
            local entry = { id = "_synthetic", name = "Synthetic", map = blueprint }

            local castle = Quest.trip("castle", { entry })
            assert(castle.map.biome == "castle", "the chosen ground was not stamped")
            assert(castle.map.biomes == nil, "the set survived into the run")
            assert(castle.map.keyCount == 1, "the rest of the map spec was dropped")

            assert(blueprint.biomes and #blueprint.biomes == 2, "the trip wrote through to the blueprint")
            assert(blueprint.biome == nil, "the trip stamped the blueprint's own map")
            assert(blueprint.objective.questId == nil,
                "the trip stamped its quest id onto the blueprint's objective")

            -- A second trip may pick the other ground; nothing was pinned by the first.
            assert(Quest.trip("swamp", { entry }).map.biome == "swamp",
                "the ground was pinned by the first trip")
        end,
    },
}
