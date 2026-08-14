-- What the QUEST BOARD offers, which is not the same question as what Quest.available returns: the
-- panel lists PLACES, and a place is drawn only when there is something on it worth the day.
--
-- THIS FILE EXISTS BECAUSE THAT DISTINCTION SHIPPED A REGRESSION. Rows were once added to the board
-- unconditionally -- seven "Forage for..." offers beside the debut on a brand-new save -- and the debut
-- on the sand is the tutorial, which teaches by being the only thing there. Nothing caught it:
-- Quest.available still returned exactly one quest, which is what every existing spec asks. The rows
-- are grounds now rather than errands, and the same rule has to hold: one row, one piece of work.
--
-- Fonts are stubbed the way tests/shop_buy_spec.lua does it, since the panel bakes them in `new`.
-- Nothing here draws.

local QuestBoard = require("ui.panels.quest_board")
local Player = require("models.player")
local Quest = require("models.quest")
local Biome = require("models.biome")
local Calendar = require("models.calendar")

local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, s) return #tostring(s or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function boardFor(player)
    return QuestBoard.new({ player = player, onClose = function() end })
end

local function labels(board)
    local out = {}
    for _, item in ipairs(board.menu.items or {}) do out[#out + 1] = item.label end
    return out
end

-- The names of the work waiting on the row the cursor is standing on.
local function workNames(board)
    local _, work = board:here()
    local out = {}
    for _, quest in ipairs(work) do out[#out + 1] = quest.name end
    return out
end

return {
    {
        name = "a brand-new save is offered one ground with the debut on it",
        fn = function()
            stubFonts(function()
                local p = Player.new()
                p.completedQuests = {}
                local board = boardFor(p)
                local rows = labels(board)

                assert(#rows == 1, "the tutorial teaches by being the only thing on the board, got "
                    .. #rows .. ": " .. table.concat(rows, ", "))
                -- The row is a PLACE now. Four grounds are open on the first morning and three of them
                -- have nothing posted on them, so three of them draw nothing: you cannot spend a day
                -- travelling somewhere purely to dig.
                local sand = Biome.get(Quest.defs.quest_colosseum_slot_01.map.biome)
                assert(rows[1] == (sand and sand.name), "and the one row is the ground the debut " ..
                    "stands on, got " .. tostring(rows[1]))

                local work = workNames(board)
                assert(#work == 1 and work[1] == Quest.defs.quest_colosseum_slot_01.name,
                    "with exactly the debut waiting on it, got " .. table.concat(work, ", "))
            end)
        end,
    },
    {
        name = "a ground carries every piece of work that can be run there",
        fn = function()
            stubFonts(function()
                -- A mid-campaign company with several houses' lines open. Whichever ground the cursor
                -- lands on, the dossier and the trip must agree about what is standing on it -- a
                -- player arriving to find work the panel never mentioned is the failure this guards.
                local p = Player.new()
                p.completedQuests = {}
                for i = 1, 12 do p.completedQuests["_filler_" .. i] = true end
                local board = boardFor(p)

                local ground, work = board:here()
                assert(ground, "a mid-campaign company has somewhere to go")
                local trip = Quest.trip(ground.id, ground.quests)
                assert(trip, "and the ground it is looking at can be travelled to")
                assert(#trip.quests == #work, string.format(
                    "the dossier lists %d pieces of work and the trip carries %d", #work, #trip.quests))
                assert(#trip.map.objectives == #work,
                    "and every one of them gets an end on the board")
            end)
        end,
    },
    {
        name = "every piece of work on the board says what it is",
        fn = function()
            -- The dossier prints a title with the quest's own sentence under it, and a title alone
            -- names a thing without describing it -- three of those on one ground is a choice the
            -- player cannot make. The pane reads whatever the day's grounds happen to hold, so the
            -- only place this can be checked is the whole set at once.
            local missing = {}
            for id, def in pairs(Quest.defs) do
                if type(def.description) ~= "string" or def.description == "" then
                    missing[#missing + 1] = id
                end
            end
            table.sort(missing)
            assert(#missing == 0,
                "quests with nothing said about them: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "the last day offers the Gate's ground and nothing else",
        fn = function()
            stubFonts(function()
                local p = Player.new()
                p.completedQuests = { quest_colosseum_slot_01 = true }
                p.day = Calendar.DAYS
                local board = boardFor(p)

                local rows = labels(board)
                assert(#rows == 1, "the last day is the Gate's alone, got " .. #rows ..
                    " grounds: " .. table.concat(rows, ", "))
                local work = workNames(board)
                assert(#work == 1 and work[1] == Quest.defs.quest_the_gate_below.name,
                    "and the one thing on it is the Gate, got " .. table.concat(work, ", "))
            end)
        end,
    },
}
