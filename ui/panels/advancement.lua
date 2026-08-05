-- "Company Advancement" overlay: the post-quest summary, opened by the hub on entry whenever a quest
-- was just completed (states/hub.lua consumes player.pendingSummary). It surfaces the reward table
-- that Quest.complete already builds -- gold / prestige / the run's forging haul -- and, front and
-- centre, the per-character LEVEL-UPS that riding prestige triggered: every roster member advanced to
-- level == prestige, gaining the stats of its most-used class (models/growth.lua, Player.syncLevels).
--
-- Modal, owned by the hub (mirrors ui/panels/encounter.lua): the state forwards input while it is
-- open, and it closes via the X button, Enter, Esc, or gamepad B/A. Three-input + mouse-only. A long
-- roster scrolls (wheel / up-down / D-pad).
--
--   local panel = Advancement.new({ reward = questRewardTable, onClose = fn })

local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local ProgressBar = require("ui.progress_bar")
local Growth = require("models.growth")
local Material = require("models.material")

local Advancement = {}
Advancement.__index = Advancement

local BOX_W = 560
local ROW_H = 46

-- Everything above the level-up list (title, rewards, the prestige bar, the section heading) and
-- everything below it (the footer prompt). The box is sized to its CONTENT between them: a quest that
-- levelled nobody is a short panel rather than a tall one with a hole in it, which matters now that
-- most quests are exactly that.
local HEAD_H, FOOT_H = 205, 56
local MAX_ROWS = 6

-- The prestige bar's fill: a beat to read the starting state, then the climb. Slow enough that a
-- single prestige is a visible movement rather than a jump -- the whole point of the bar is that a
-- quest which levels nobody still shows the company advancing.
local BAR_HOLD, BAR_FILL = 0.35, 0.9

-- Stat display names + a stable order, matching the Loadout panel's sheet (ui/panels/party.lua).
local STAT_LABEL = {
    health = "HP", mana = "MP", stamina = "SP",
    damage = "Attack", magicDamage = "Magic",
    defense = "Defense", magicDefense = "M.Def",
    movement = "Move", speed = "Speed",
}
local STAT_ORDER = { "health", "mana", "stamina", "damage", "magicDamage", "defense", "magicDefense", "movement", "speed" }

local function classLabel(class)
    if not class then return "" end
    return (class:gsub("^%l", string.upper))
end

-- "+3 Magic, +5 MP" from a { stat = amount } gains table, in the sheet's stat order.
local function gainsText(gains)
    local parts = {}
    for _, stat in ipairs(STAT_ORDER) do
        local amount = gains and gains[stat]
        if amount and amount ~= 0 then
            parts[#parts + 1] = "+" .. amount .. " " .. (STAT_LABEL[stat] or stat)
        end
    end
    return table.concat(parts, ", ")
end

function Advancement.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Advancement)
    self.reward = opts.reward or {}
    self.onClose = opts.onClose
    self.entries = self.reward.advancement or {}
    self.scroll = 0 -- first visible entry index - 1

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(18)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)

    -- One row minimum, so the "no one levelled" line has somewhere to sit.
    self.visible = math.max(1, math.min(#self.entries, MAX_ROWS))
    self.boxH = HEAD_H + self.visible * ROW_H + FOOT_H

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    -- The prestige step this quest moved the company along. Both ends come from Quest.complete; a
    -- reward table built by anything else (a test, a debug grant) simply has no bar and the panel
    -- falls back to reporting level-ups alone.
    self.prestigeFrom = self.reward.prestigeBefore
    self.prestigeTo = self.reward.prestigeAfter
    self.hasBar = type(self.prestigeFrom) == "number" and type(self.prestigeTo) == "number"
    self.shownPrestige = self.prestigeFrom or 0
    self.barT = 0

    -- List viewport: below the reward header and the bar, above the footer prompt. Sized from
    -- `visible` above rather than the other way round, so the box wraps the rows instead of the rows
    -- being fitted into a fixed box.
    self.listX = self.boxX + 24
    self.listY = self.boxY + HEAD_H
    self.listW = BOX_W - 48
    self.listH = self.visible * ROW_H

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- The company grew: ring the level-up cue as the overlay opens, but only when there is actually an
    -- advancement to celebrate (a quest with no level-ups shows "No advancement this time" in silence).
    if #self.entries > 0 then require("models.sound").play("quest.levelup") end
    return self
end

function Advancement:close()
    if self.onClose then self.onClose() end
end

function Advancement:maxScroll()
    return math.max(0, #self.entries - self.visible)
end

function Advancement:scrollBy(delta)
    self.scroll = math.max(0, math.min(self:maxScroll(), self.scroll + delta))
end

-- Ease the DISPLAYED prestige from where the company stood to where it now stands. The bar's level and
-- its fill are both derived from that one running number, so crossing a threshold rolls the bar over on
-- its own -- there is no separate "did we level" branch to keep in step with the arithmetic.
function Advancement:update(dt)
    if not self.hasBar then return end
    self.barT = self.barT + (dt or 0)
    local t = math.max(0, math.min(1, (self.barT - BAR_HOLD) / BAR_FILL))
    local eased = 1 - (1 - t) ^ 3
    self.shownPrestige = self.prestigeFrom + (self.prestigeTo - self.prestigeFrom) * eased
end

-- The one-line reward header: gold, prestige, and the forging stock the run banked -- the caches the
-- party walked to, plus the salvage the objective itself left behind (models/spoils.lua). The
-- materials used to be granted in silence here, which made the whole detour economy a number that
-- changed somewhere off screen; naming them is the only place a finished run says what it mined.
-- Sorted by name so the same haul always reads the same way (`pairs` would reshuffle it every quest).
function Advancement:rewardLine()
    local r = self.reward
    local parts = {}
    if (r.gold or 0) > 0 then parts[#parts + 1] = r.gold .. " gold" end
    if (r.prestige or 0) > 0 then parts[#parts + 1] = "+" .. r.prestige .. " prestige" end

    local mats = {}
    for id, count in pairs(r.materials or {}) do
        if (count or 0) > 0 then
            local def = Material.get(id)
            mats[#mats + 1] = ((def and def.name) or id) .. " x" .. count
        end
    end
    table.sort(mats)
    if #mats > 0 then parts[#parts + 1] = table.concat(mats, ", ") end
    return table.concat(parts, "    ")
end

function Advancement:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Quest Complete", self.boxX, self.boxY + 22, BOX_W, "center")

    -- Reward header. Fitted rather than drawn at a fixed size: a run that emptied four caches names
    -- four materials on this line, and the fix for that is a smaller native face, never a scaled one.
    local line = self:rewardLine()
    local font = Theme.fitText(Theme.display, line, BOX_W - 48, 18, 12)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.printf(line, self.boxX + 24, self.boxY + 66, BOX_W - 48, "center")

    -- A companion who just joined outranks every other line on this panel: gold and new stock change
    -- what you can buy, a recruit changes who you field. Drawn above the stock-unlocked line and in the
    -- brightest colour the box uses, and the two never collide -- a quest that earns a companion is
    -- the head of its vendor's line, so it is not also the one that opens a fresh wave of its shelf.
    local joined = self.reward.recruited
    if joined then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.95, 0.7)
        love.graphics.printf(tostring(joined.name or "A companion") .. " joins the company",
            self.boxX + 24, self.boxY + 92, BOX_W - 48, "center")
    elseif self.reward.unlockedStock then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.printf("New stock unlocked at the sponsor's shop",
            self.boxX + 24, self.boxY + 92, BOX_W - 48, "center")
    end

    self:drawPrestigeBar()

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.muted)
    love.graphics.print("The company grows", self.listX, self.boxY + 177)

    self:drawList()
    self:drawFooter()

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- The company's climb toward its next level, filling live. This exists because a level costs several
-- prestige while a quest pays one or two, so MOST quests advance the company without levelling anyone
-- -- and before the bar, those quests said "No advancement this time" and read as wasted.
function Advancement:drawPrestigeBar()
    if not self.hasBar then return end

    local x, w = self.listX, self.listW
    local y = self.boxY + 122
    local level = Growth.levelForPrestige(self.shownPrestige)
    local into, span = Growth.prestigeIntoLevel(self.shownPrestige)
    local capped = into == nil

    -- Endpoints: what the company is now, and what it is climbing toward.
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.ink)
    love.graphics.print("Level " .. level, x, y)
    Theme.set(Theme.muted)
    local right = capped and "Max" or ("Level " .. (level + 1))
    love.graphics.printf(right, x, y, w, "right")

    -- The slice that arrived just now is lit, so the eye lands on the change rather than the total.
    local gained = self.shownPrestige - self.prestigeFrom
    ProgressBar.draw(x, y + 20, w, 14, into or 1, span or 1, {
        gain = capped and 0 or math.min(gained, into or 0),
        full = capped,
    })

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local caption = capped and "The company can grow no further"
        or string.format("%d / %d prestige to the next level", math.floor(into), span)
    love.graphics.print(caption, x, y + 40)

    local earned = (self.prestigeTo or 0) - (self.prestigeFrom or 0)
    if earned > 0 then
        Theme.set(Theme.accentAmber)
        love.graphics.printf("+" .. earned .. " this quest", x, y + 40, w, "right")
    end
end

function Advancement:drawList()
    if #self.entries == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.62, 0.7)
        -- With the bar above, a quest that levelled nobody has still visibly moved the company, so say
        -- what is actually true rather than "no advancement". The flat denial is kept only for a reward
        -- table that carries no prestige step at all and therefore draws no bar.
        local line = self.hasBar and "No one crossed a level this time -- the company still gains."
            or "No advancement this time."
        love.graphics.printf(line, self.listX, self.listY + 8, self.listW, "left")
        return
    end

    local last = math.min(#self.entries, self.scroll + self.visible)
    for i = self.scroll + 1, last do
        local entry = self.entries[i]
        local y = self.listY + (i - self.scroll - 1) * ROW_H
        self:drawEntry(entry, self.listX, y, self.listW, ROW_H - 6)
    end

    -- Overflow chevrons when the roster is taller than the viewport.
    if #self.entries > self.visible then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.64, 0.75, self.scroll > 0 and 0.9 or 0.2)
        love.graphics.printf("^", self.listX, self.listY - 14, self.listW, "center")
        love.graphics.setColor(0.6, 0.64, 0.75, self.scroll < self:maxScroll() and 0.9 or 0.2)
        love.graphics.printf("v", self.listX, self.listY + self.listH + 2, self.listW, "center")
    end
end

function Advancement:drawEntry(entry, x, y, w, h)
    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)

    local char = entry.char or {}
    local ps = h - 8
    local px, py = x + 4, y + 4

    -- Portrait (sprite, or the name's initial as a fallback -- same convention as party.lua).
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 9, ps, "center")
    end

    local tx = px + ps + 12

    -- Name + "Lv X -> Y" + the class it grew as, on the top line.
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.print(char.name or "?", tx, y + 5)

    local levelText = "Lv " .. tostring(entry.fromLevel) .. " -> " .. tostring(entry.toLevel)
    love.graphics.setColor(0.6, 0.85, 0.6)
    love.graphics.printf(levelText, x, y + 5, w - 10, "right")

    -- Growth class + stat gains on the second line.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.75, 0.7, 0.5)
    local classText = "as " .. classLabel(entry.class)
    love.graphics.print(classText, tx, y + 24)

    local gt = gainsText(entry.gains)
    love.graphics.setColor(0.72, 0.78, 0.86)
    local classW = self.smallFont:getWidth(classText)
    love.graphics.print(gt, tx + classW + 10, y + 24)
end

function Advancement:drawFooter()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.6, 0.63, 0.7)
    -- Show the glyph for the device last used: pad button only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad() and "A to continue" or "Enter / Click X to continue"
    love.graphics.printf(hint, self.boxX, self.boxY + self.boxH - 30, BOX_W, "center")
end

function Advancement:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

-- Hand over the close X (the only button; the rest is a summary). See ui/cursor.lua.
function Advancement:cursorKind(x, y)
    return self.closeButton:contains(x, y) and "hand" or "arrow"
end

function Advancement:wheelmoved(_, dy)
    if dy ~= 0 then self:scrollBy(-dy) end
end

function Advancement:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    -- A click anywhere outside the box dismisses it too (it is a summary, nothing to lose).
    if x < self.boxX or x > self.boxX + BOX_W or y < self.boxY or y > self.boxY + self.boxH then
        self:close()
    end
end

function Advancement:keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" or key == "space" then
        self:close()
    elseif key == "up" or key == "w" then self:scrollBy(-1)
    elseif key == "down" or key == "s" then self:scrollBy(1)
    end
end

function Advancement:gamepadpressed(_, button)
    if button == "b" or button == "a" or button == "start" then
        self:close()
    elseif button == "dpup" then self:scrollBy(-1)
    elseif button == "dpdown" then self:scrollBy(1)
    end
end

return Advancement
