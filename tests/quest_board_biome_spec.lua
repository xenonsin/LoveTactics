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
        name = "Quest.start resolves the set to one ground without touching the blueprint",
        fn = function()
            local entry = { id = "_synthetic", map = { biomes = { "swamp", "castle" }, keyCount = 1 } }
            local run = Quest.start(entry, "castle")
            assert(run.map.biome == "castle", "the chosen ground was not stamped")
            assert(run.map.biomes == nil, "the set survived into the run")
            assert(run.map.keyCount == 1, "the rest of the map spec was dropped")
            -- The blueprint's map is shared by every future run of the quest.
            assert(entry.map.biomes and #entry.map.biomes == 2, "Quest.start wrote through to the blueprint")
            assert(entry.map.biome == nil, "Quest.start stamped the blueprint's own map")
            -- A second run may pick the other ground.
            assert(Quest.start(entry, "swamp").map.biome == "swamp", "the set was pinned by the first run")
        end,
    },
    {
        name = "Quest.start falls back to the quest's own ground when none is named",
        fn = function()
            local legacy = { id = "_legacy", map = { biome = "forest" } }
            assert(Quest.start(legacy, nil).map.biome == "forest", "the old single field was lost")
            local set = { id = "_set", map = { biomes = { "tundra" } } }
            assert(Quest.start(set, nil).map.biome == "tundra", "no ground resolved from the set")
        end,
    },
}
