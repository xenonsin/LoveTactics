-- "Company Advancement" overlay: the post-quest summary, opened by the hub on entry whenever a quest
-- was just completed (states/hub.lua consumes player.pendingSummary). It surfaces the reward table
-- that Quest.complete already builds -- gold / prestige / reputation -- and, front and centre, the
-- per-character LEVEL-UPS that riding prestige triggered: every roster member advanced to
-- level == prestige, gaining the stats of its most-used class (models/growth.lua, Player.syncLevels).
--
-- Modal, owned by the hub (mirrors ui/panels/encounter.lua): the state forwards input while it is
-- open, and it closes via the X button, Enter, Esc, or gamepad B/A. Three-input + mouse-only. A long
-- roster scrolls (wheel / up-down / D-pad).
--
--   local panel = Advancement.new({ reward = questRewardTable, onClose = fn })

local CloseButton = require("ui.close_button")
local Scale = require("scale")

local Advancement = {}
Advancement.__index = Advancement

local BOX_W, BOX_H = 560, 520
local ROW_H = 46

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

    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)
    self.smallFont = love.graphics.newFont(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    -- List viewport: below the reward header, above the footer prompt.
    self.listX = self.boxX + 24
    self.listY = self.boxY + 150
    self.listW = BOX_W - 48
    self.listH = self.boxY + BOX_H - 56 - self.listY
    self.visible = math.max(1, math.floor(self.listH / ROW_H))

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
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

function Advancement:update(dt) end

-- The one-line reward header: gold / prestige / reputation, plus a rank-up shout when one landed.
function Advancement:rewardLine()
    local r = self.reward
    local parts = {}
    if (r.gold or 0) > 0 then parts[#parts + 1] = r.gold .. " gold" end
    if (r.prestige or 0) > 0 then parts[#parts + 1] = "+" .. r.prestige .. " prestige" end
    if (r.rep or 0) > 0 then parts[#parts + 1] = "+" .. r.rep .. " reputation" end
    return table.concat(parts, "    ")
end

function Advancement:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Quest Complete", self.boxX, self.boxY + 22, BOX_W, "center")

    -- Reward header.
    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.85, 0.88, 0.94)
    love.graphics.printf(self:rewardLine(), self.boxX + 24, self.boxY + 66, BOX_W - 48, "center")

    if self.reward.rankedUp then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.printf("New standing: " .. tostring(self.reward.rankName),
            self.boxX + 24, self.boxY + 92, BOX_W - 48, "center")
    end

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.7, 0.74, 0.82)
    love.graphics.print("The company grows", self.listX, self.boxY + 122)

    self:drawList()
    self:drawFooter()

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function Advancement:drawList()
    if #self.entries == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.62, 0.7)
        love.graphics.printf("No advancement this time.", self.listX, self.listY + 8, self.listW, "left")
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
    love.graphics.setColor(0.15, 0.16, 0.21)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

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
    love.graphics.printf("Enter / Click X to continue", self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")
end

function Advancement:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

function Advancement:wheelmoved(_, dy)
    if dy ~= 0 then self:scrollBy(-dy) end
end

function Advancement:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    -- A click anywhere outside the box dismisses it too (it is a summary, nothing to lose).
    if x < self.boxX or x > self.boxX + BOX_W or y < self.boxY or y > self.boxY + BOX_H then
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
