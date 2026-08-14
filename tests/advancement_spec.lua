-- The post-quest overlay's CALENDAR BAR (ui/panels/advancement.lua).
--
-- The panel was built around prestige: the whole roster levelled at the payout, and the bar underneath
-- showed the climb toward the next level so that a quest which levelled nobody still read as progress.
-- Both halves went at once -- a body earns its own level in the fighting now, and prestige does not
-- exist -- so the fields the bar filled from (`prestigeBefore` / `prestigeAfter`) are not set by
-- anything and the panel was drawing a bar off nil.
--
-- Nothing caught that, and nothing could have: no spec builds this panel, and a stale field in Lua is
-- not an error until it is arithmetic. So the arithmetic is pinned here.
--
-- Fonts are stubbed the way tests/shop_buy_spec.lua does it -- the panel bakes them in `new` and
-- love.graphics.newFont throws with no window. Nothing here draws.

local Advancement = require("ui.panels.advancement")
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

local function panelFor(reward)
    return Advancement.new({ reward = reward, onClose = function() end })
end

-- The shape Quest.complete actually returns, trimmed to what this panel reads.
local function reward(day, extra)
    local r = { gold = 100, day = day, days = Calendar.DAYS,
                standingBefore = day - 1, standing = day, advancement = {} }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

return {
    {
        name = "the bar fills from the morning the expedition set out to the evening it returned",
        fn = function()
            stubFonts(function()
                local p = panelFor(reward(11))
                assert(p.hasBar, "a reward carrying a day draws a bar")
                assert(p.dayFrom == 10 and p.dayTo == 11,
                    "the bar spans the one day this expedition spent")
                assert(p.shownDay == 10, "and opens on the morning, so the spend is visible as movement")

                -- Driven past the hold and the fill, it lands exactly on the day just spent.
                for _ = 1, 300 do p:update(1 / 60) end
                assert(math.abs(p.shownDay - 11) < 0.001,
                    "the bar settles on the day, got " .. tostring(p.shownDay))
            end)
        end,
    },
    {
        name = "the first expedition of the campaign still has a bar to fill",
        fn = function()
            stubFonts(function()
                local p = panelFor(reward(1))
                assert(p.hasBar, "day one is still a day spent")
                assert(p.dayFrom == 0, "it fills from an empty calendar rather than from day zero-minus-one")
                for _ = 1, 300 do p:update(1 / 60) end
                assert(math.abs(p.shownDay - 1) < 0.001)
            end)
        end,
    },
    {
        name = "the last day does not overrun the calendar",
        fn = function()
            stubFonts(function()
                local p = panelFor(reward(Calendar.DAYS))
                for _ = 1, 300 do p:update(1 / 60) end
                assert(p.shownDay <= Calendar.DAYS,
                    "the bar cannot fill past the end of the calendar, got " .. tostring(p.shownDay))
            end)
        end,
    },
    {
        name = "a reward table with no calendar on it draws no bar rather than one off nil",
        fn = function()
            stubFonts(function()
                -- A test, a debug grant, or any caller that predates the calendar. This is the exact
                -- shape that was silently drawing a bar off `prestigeBefore` after that field stopped
                -- being set, so the guard is asserted rather than assumed.
                local p = panelFor({ gold = 10, advancement = {} })
                assert(not p.hasBar, "no day, no bar")
                p:update(1 / 60) -- must not reach the easing arithmetic
            end)
        end,
    },
    {
        name = "the panel reads the reward table Quest.complete actually returns",
        fn = function()
            -- The coupling this file exists to protect. The panel reads fields by name off a table
            -- built somewhere else, so a rename on either side is invisible until someone finishes a
            -- quest. Built here through the real function rather than by hand.
            local Player = require("models.player")
            local Quest = require("models.quest")
            local p = Player.new()
            p.completedQuests = {}
            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_colosseum_slot_01" then quest = q end
            end
            assert(quest, "the debut should be available on a fresh save")

            local r = Quest.complete(p, quest)
            assert(type(r.day) == "number" and type(r.days) == "number",
                "Quest.complete must carry the calendar, or the panel has no bar to draw")

            stubFonts(function()
                local panel = panelFor(r)
                assert(panel.hasBar, "and the panel must recognise it")

                -- THE HEADER IS BUILT, not just the bar. This is the half the coupling case missed:
                -- the reward line read `standing` as a table of vendor -> circles, a descent's shape,
                -- while Quest.complete returns it as a number -- so `pairs` over an integer took the
                -- panel down the moment a quest paid out. Draw-free, so it runs headless.
                local line = panel:rewardLine()
                assert(type(line) == "string" and line:find("gold"),
                    "the header names the gold a quest paid, got " .. tostring(line))
            end)
        end,
    },
}
