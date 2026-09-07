-- A row of PORTRAIT CARDS, picked between. Character creation's first step is the whole of it in
-- practice (states/character_creation.lua), where it asks which of the two avatar bodies the player
-- wears.
--
--   local choice = PortraitChoice.new({
--       { label = "...", portrait = "assets/portraits/avatar_1.png", action = function() ... end },
--       { label = "...", portrait = "assets/portraits/avatar_2.png", action = function() ... end },
--   })
--   choice:update(dt); choice:draw()
--   choice:mousemoved(x, y); choice:mousepressed(x, y, button)
--   choice:keypressed(key); choice:gamepadpressed(joystick, button)
--
-- WHY IT IS NOT ui/menu.lua WITH A PICTURE ON IT. The body step used to be that menu, two rows deep,
-- reading "Body 1" and "Body 2" under the heading "Who will you be?" -- a question about identity
-- answered by an index. The choice IS the picture; a label naming a sprite set is the one thing it
-- cannot be made of. So the card is a portrait first and carries its label underneath, and the
-- selection reads as a frame around a face rather than a highlighted button.
--
-- THE PORTRAIT IS THE PORTRAIT, and never the board token standing in for it. `assets/chars/avatar_1`
-- exists and `assets/portraits/avatar_1` does not, and substituting the one for the other would put a
-- 256px silhouette on a plate -- the composed board piece, tinted by kind, framed at draw time by
-- battlefield side (tools/char_compose.lua) -- into a slot the player is being asked to read a face
-- in. It would answer the question with the wrong picture rather than with no picture. So a card
-- whose art has not landed draws the empty frame below, which is honest and is what makes the art
-- debt visible on the screen that most needs it (`. art-report`, docs/commission-portraits.md).
--
-- Lazy fonts (newed in :new, never at require-time) keep it load-safe under tests/ui_load_spec.

local Scale = require("scale")
local Theme = require("ui.theme")
local Sound = require("models.sound")
local Sprite = require("models.sprite")

local PortraitChoice = {}
PortraitChoice.__index = PortraitChoice

-- A card is a portrait well with a label strip under it. 3:4 is the crop a commissioned portrait is
-- delivered at (docs/commission-portraits.md), so the well is authored at that ratio and the image is
-- fitted inside it rather than the well being fitted to whatever arrived.
--
-- SIZED TO THE BAND LEFT OVER, not to what a portrait would like. The host draws a heading and a
-- prompt above this row and they are fixed where they are, so the row gets the remainder: a card is
-- 396 tall all in, which centres in the ~460px under a prompt sitting at 230 without touching either
-- end. A taller card was tried first and put the top of the frame straight through the title.
local CARD_W, CARD_H = 264, 352
local LABEL_H = 44
local GAP = 48

function PortraitChoice.new(items, opts)
    opts = opts or {}
    local self = setmetatable({}, PortraitChoice)
    self.items = items
    self.selected = 1
    self.centerY = opts.centerY or (Scale.HEIGHT / 2)
    self.labelFont = Theme.display(20)
    self.emptyFont = Theme.display(15)
    self:layout()
    return self
end

-- Lay the row out centred on `centerY`, each card holding its own rect so hit-testing and drawing
-- read the same numbers.
function PortraitChoice:layout()
    local n = #self.items
    local total = n * CARD_W + (n - 1) * GAP
    local x = (Scale.WIDTH - total) / 2
    local y = self.centerY - (CARD_H + LABEL_H) / 2
    for _, item in ipairs(self.items) do
        item.x, item.y, item.w, item.h = x, y, CARD_W, CARD_H + LABEL_H
        -- Resolved once, here rather than every frame: Sprite.load is memoized, but a card that has
        -- no art must also not re-ask the filesystem sixty times a second.
        item.image = Sprite.load(item.portrait)
        x = x + CARD_W + GAP
    end
end

local function isInside(item, x, y)
    return x >= item.x and x <= item.x + item.w and y >= item.y and y <= item.y + item.h
end

function PortraitChoice:moveSelection(delta)
    local before = self.selected
    self.selected = ((self.selected - 1 + delta) % #self.items) + 1
    if self.selected ~= before then Sound.play("ui.move") end
end

function PortraitChoice:activate()
    local item = self.items[self.selected]
    if not item then return end
    Sound.play("ui.confirm")
    if item.action then item.action() end
end

function PortraitChoice:update() end

-- One card. `active` draws the face in full colour inside the selection ring; the others sit back a
-- tier, so the row reads as one picked and the rest available rather than as two lit buttons.
function PortraitChoice:drawCard(item, active)
    local wellH = CARD_H
    Theme.plate(item.x, item.y, item.w, item.h, 4, active and Theme.panel or Theme.panel2)

    -- The portrait well: the deepest inset, so an empty one reads as a hole waiting for a picture
    -- rather than as a blank panel that might be the design.
    local pad = 10
    local wx, wy = item.x + pad, item.y + pad
    local ww, wh = item.w - pad * 2, wellH - pad * 2
    Theme.fill(Theme.slot, wx, wy, ww, wh, 3)

    if type(item.image) == "userdata" then
        local sw, sh = item.image:getDimensions()
        -- Fit inside the well, never crop and never upscale past the well, so a portrait delivered
        -- at any size lands whole.
        local scale = math.min(ww / sw, wh / sh)
        local dw, dh = sw * scale, sh * scale
        Theme.set({ 1, 1, 1 }, active and 1 or 0.45)
        love.graphics.draw(item.image, wx + (ww - dw) / 2, wy + (wh - dh) / 2, 0, scale, scale)
    else
        -- No art yet. Say so in the well rather than drawing a stand-in: an initial in a box reads as
        -- a design decision, and this is a commission that has not landed.
        love.graphics.setFont(self.emptyFont)
        Theme.set(Theme.muted, active and 0.75 or 0.4)
        love.graphics.printf("portrait pending", wx, wy + wh / 2 - 10, ww, "center")
        Theme.set(Theme.hairline, active and 1 or 0.5)
        local lw = love.graphics.getLineWidth()
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", wx + 6, wy + 6, ww - 12, wh - 12, 3, 3)
        love.graphics.setLineWidth(lw)
    end

    love.graphics.setFont(self.labelFont)
    Theme.set(active and Theme.accentAmber or Theme.muted)
    love.graphics.printf(item.label or "", item.x, item.y + wellH + (LABEL_H - self.labelFont:getHeight()) / 2,
                         item.w, "center")

    -- The moving selection wears the steel ring, never the gold: gold is what is FOCUSED and live,
    -- steel is where the cursor happens to be standing (see ui/theme.lua's three edge tiers).
    if active then
        Theme.set(Theme.cursor)
        local lw = love.graphics.getLineWidth()
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", item.x - 3, item.y - 3, item.w + 6, item.h + 6, 5, 5)
        love.graphics.setLineWidth(lw)
    end
end

function PortraitChoice:draw()
    for i, item in ipairs(self.items) do
        self:drawCard(item, i == self.selected)
    end
    love.graphics.setColor(1, 1, 1)
end

function PortraitChoice:mousemoved(x, y)
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            if self.selected ~= i then
                self.selected = i
                Sound.play("ui.move")
            end
            return
        end
    end
end

function PortraitChoice:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            self.selected = i
            self:activate()
            return
        end
    end
end

-- True when the point is over a card, so the state can show the hand cursor there (ui/cursor.lua).
function PortraitChoice:mouseOverItem(x, y)
    for _, item in ipairs(self.items) do
        if isInside(item, x, y) then return true end
    end
    return false
end

-- The cards sit side by side, so the row is worked HORIZONTALLY -- left/right and the d-pad's
-- horizontal axis. Up/down are accepted too rather than left dead: a vertical menu is what stood here
-- before, and the hands that learned it are the ones arriving at this screen.
function PortraitChoice:keypressed(key)
    if key == "left" or key == "a" or key == "up" or key == "w" then
        self:moveSelection(-1)
    elseif key == "right" or key == "d" or key == "down" or key == "s" then
        self:moveSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate()
    end
end

function PortraitChoice:gamepadpressed(joystick, button)
    if button == "dpleft" or button == "dpup" then
        self:moveSelection(-1)
    elseif button == "dpright" or button == "dpdown" then
        self:moveSelection(1)
    elseif button == "a" or button == "start" then
        self:activate()
    end
end

return PortraitChoice
