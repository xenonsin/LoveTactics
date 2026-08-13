-- What the QUEST BOARD offers, which is not the same question as what Quest.available returns: the
-- panel adds rows of its own (the houses' foraging offers, models/request.lua), and those are not
-- quests and are gated on their own terms.
--
-- THIS FILE EXISTS BECAUSE THAT DISTINCTION SHIPPED A REGRESSION. Foraging rows were added
-- unconditionally, so a brand-new save opened the board on the debut plus seven "Forage for..." offers
-- -- and the debut on the sand is the tutorial, which teaches by being the only thing there. Nothing
-- caught it: Quest.available still returned exactly one quest, which is what every existing spec asks.
--
-- Fonts are stubbed the way tests/shop_buy_spec.lua does it, since the panel bakes them in `new`.
-- Nothing here draws.

local QuestBoard = require("ui.panels.quest_board")
local Player = require("models.player")
local Quest = require("models.quest")
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

local function countForage(board)
    local n = 0
    for _, label in ipairs(labels(board)) do
        if tostring(label):match("^Forage for ") then n = n + 1 end
    end
    return n
end

return {
    {
        name = "a brand-new save is offered the debut and nothing else",
        fn = function()
            stubFonts(function()
                local p = Player.new()
                p.completedQuests = {}
                local board = boardFor(p)
                local rows = labels(board)

                assert(#rows == 1, "the tutorial teaches by being the only thing on the board, got "
                    .. #rows .. ": " .. table.concat(rows, ", "))
                local debut = Quest.defs.quest_colosseum_slot_01
                assert(rows[1] == debut.name,
                    "and the one thing is the debut on the sand, got " .. tostring(rows[1]))
            end)
        end,
    },
    {
        name = "foraging opens once the company has worked at all",
        fn = function()
            stubFonts(function()
                local p = Player.new()
                p.completedQuests = { quest_colosseum_slot_01 = true }
                local board = boardFor(p)
                assert(countForage(board) > 0,
                    "the houses post errands to somebody who has worked for them")
                -- Under the quests, never above: this is the fallback a player reaches for, not the
                -- campaign, and the first row a cursor lands on should be somebody's actual work.
                local rows = labels(board)
                assert(not tostring(rows[1]):match("^Forage for "),
                    "the campaign leads the board; foraging sits under it")
            end)
        end,
    },
    {
        name = "the last day offers the Gate and no foraging at all",
        fn = function()
            stubFonts(function()
                local p = Player.new()
                p.completedQuests = { quest_colosseum_slot_01 = true }
                p.day = Calendar.DAYS
                local board = boardFor(p)
                assert(countForage(board) == 0,
                    "a row that let the player spend the last day on ore would be the game hiding "
                    .. "its own ending")
                local found
                for _, label in ipairs(labels(board)) do
                    if tostring(label):match("Gate Below") then found = true end
                end
                assert(found, "and the Gate is what the last day is for")
            end)
        end,
    },
}
