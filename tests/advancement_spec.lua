-- The post-quest overlay (ui/panels/advancement.lua), and the reward table it is built from.
--
-- IT USED TO BE ABOUT A BAR, AND TWO OF THEM HAVE NOW BEEN DELETED OUT FROM UNDER THIS FILE. The panel
-- was built around prestige: the whole roster levelled at the payout, and the bar underneath showed the
-- climb toward the next level so that a quest which levelled nobody still read as progress. Both halves
-- went at once -- a body earns its own level in the fighting now, and prestige does not exist -- so the
-- fields the bar filled from were not set by anything and the panel was drawing a bar off nil. The DAY
-- took the slot, on the argument that an expedition always spends one; then the deadline went too
-- (models/calendar.lua) and a bar filling toward nothing was a promise the campaign no longer keeps.
--
-- WHAT IS LEFT TO PIN IS THE COUPLING, which is the half that was always the real risk: the panel reads
-- fields by name off a table built somewhere else, so a rename on either side is invisible until
-- somebody finishes a quest. Nothing else builds this panel.
--
-- Fonts are stubbed the way tests/shop_buy_spec.lua does it -- the panel bakes them in `new` and
-- love.graphics.newFont throws with no window. Nothing here draws.

local Advancement = require("ui.panels.advancement")

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

return {
    {
        name = "a reward table carrying a stale calendar reading builds the panel anyway",
        fn = function()
            stubFonts(function()
                -- A save written while the deadline still existed carries `day` and `days` in its
                -- pendingSummary, and the hub will hand that table straight to this panel on the next
                -- load. The fields are simply not read any more; what must not happen is a panel that
                -- refuses to open because of them.
                local p = panelFor({ gold = 100, day = 11, days = 40, advancement = {} })
                assert(p, "an old summary still opens")
                assert(p.boxH and p.boxH > 0, "and is sized")
                if p.update then p:update(1 / 60) end
            end)
        end,
    },
    {
        name = "a reward table with nothing but gold on it draws a panel rather than an error",
        fn = function()
            stubFonts(function()
                local p = panelFor({ gold = 10, advancement = {} })
                assert(p.boxH and p.boxH > 0)
                if p.update then p:update(1 / 60) end
            end)
        end,
    },
    {
        name = "the panel reads the reward table Quest.complete actually returns",
        fn = function()
            -- The coupling this file exists to protect. Built through the real function rather than by
            -- hand, so a rename on either side comes out here rather than at a payout.
            local Player = require("models.player")
            local Quest = require("models.quest")
            local p = Player.new()
            p.completedQuests = {}
            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "the debut should be available on a fresh save")

            local r = Quest.complete(p, quest)
            assert(type(r.gold) == "number", "a payout is gold, at minimum")
            assert(type(r.standing) == "number",
                "standing is a count of finished quests, not a table of circles")

            stubFonts(function()
                local panel = panelFor(r)

                -- THE HEADER IS BUILT, not just the box. This is the half the coupling case missed:
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
