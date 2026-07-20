-- The Dueling Grounds pop-up: publish the team others will face, or go and face somebody else's.
--
-- Both halves lean on models/build.lua and models/builds.lua and hold no rules of their own. In
-- particular the panel does NOT decide what a fair fight is -- normalization does, on both sides at
-- once (Build.restore for the opponent, Build.normalizeParty for you), so there is no place here for
-- a matchmaking rule to quietly disagree with the one the model states.
--
-- Modeled on ui/panels/encounter.lua: the hub owns it, forwards input while it is open, and it
-- closes via the X, Esc, or gamepad B. Mouse, keyboard and gamepad all drive it.
--
--   local panel = Pvp.new({ player = hub.player, onClose = function() ... end })

local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Player = require("models.player")
local Build = require("models.build")
local Builds = require("models.builds")

local Pvp = {}
Pvp.__index = Pvp

local BOX_W, BOX_H = 560, 320
local BTN_W, BTN_H = 220, 46

function Pvp.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Pvp)
    self.player = opts.player or Player.active
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(28)
    self.bodyFont = love.graphics.newFont(17)
    self.smallFont = love.graphics.newFont(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    local bx = self.boxX + BOX_W / 2 - BTN_W / 2
    self.buttons = {
        { key = "assemble", label = "Assemble Build", x = bx, y = self.boxY + 150, w = BTN_W, h = BTN_H },
        { key = "match",    label = "Find a Match",   x = bx, y = self.boxY + 208, w = BTN_W, h = BTN_H },
    }
    self.cursor = 1 -- keyboard / gamepad selection

    self:refresh()
    return self
end

-- Re-read what the world looks like from here: have I published, and is there anyone to fight?
-- Called on open and after publishing, so the panel never states something it stopped knowing.
function Pvp:refresh()
    local authorId = Player.authorId(self.player)
    self.published = Builds.backend.read(Builds.idFor(authorId)) ~= nil
    self.opponents = #Builds.eligible({ excludeAuthor = authorId })
    -- Surfaced rather than swallowed: a publish that failed leaves no build, and "you have not
    -- published" without a reason is the kind of silence that reads as a bug.
    self.message = self.player.lastPublishError
end

function Pvp:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- Pick the team that will stand in for you when you are not here. Reuses the embark screen, which
-- already knows how to choose four from a roster with all three input devices (states/party_select).
function Pvp:assemble()
    local State = require("states")
    local player = self.player
    State.switch(require("states.party_select"), nil, player.prestige, player, {
        title = "Assemble Your Build",
        subtitle = "The team others face when you are not here -- and the tactics you gave it",
        embarkLabel = "Publish",
        onEmbark = function(p)
            local build = Build.from(p.party, {
                author = { id = Player.authorId(p), name = p.name },
                prestige = p.prestige,
            })
            local _, why = Builds.publish(build)
            p.lastPublishError = why -- nil on success; the panel reads it when it reopens
            -- authorId may have been minted just now, and it has to outlive the session or the
            -- next one would be a stranger to its own build.
            Player.save()
            State.switch(require("states.hub"))
        end,
        onBack = function() State.switch(require("states.hub")) end,
    })
end

-- Go and fight one. Both teams are normalized, so this is the same board for whoever is on it.
function Pvp:findMatch()
    local State = require("states")
    local player = self.player
    if #(player.party or {}) == 0 then
        self.message = "Take someone with you first."
        return
    end

    local picked = Builds.pick({ excludeAuthor = Player.authorId(player) })
    if not picked then
        self.message = "No one has left a build to face yet."
        return
    end

    local foes, why = Build.restore(picked.build)
    if not foes then
        -- eligible() already restored this build once, so reaching here means it changed underneath
        -- us. Say so rather than dropping the player into a broken fight.
        self.message = "That build could not be read: " .. tostring(why)
        return
    end

    local author = picked.build.author or {}
    State.switch(require("states.battle"), {
        encounter = { kind = "objective" },
        biome = "castle",
        -- The duelling level, not this player's: the arena's own scaling should not read one
        -- duellist's climb as the difficulty of the fight.
        prestige = Build.NORMAL_LEVEL,
        -- Normalized COPIES, never the live roster. Fresh instances mean a duel cannot spend the
        -- player's real health or lose them an item, so nothing about the campaign rides on it.
        party = Build.normalizeParty(player.party),
        enemyChars = foes,
        quest = { map = { biome = "castle", objective = {
            name = (author.name and (author.name .. "'s build")) or "A rival build",
            win = { type = "killAll" },
        } } },
        onWin = function() State.switch(require("states.hub")) end,
        onLoss = function() State.switch(require("states.hub")) end,
    })
end

function Pvp:activate(key)
    if key == "assemble" then self:assemble()
    elseif key == "match" then self:findMatch() end
end

function Pvp:update(dt) end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function Pvp:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Dueling Grounds", self.boxX, self.boxY + 26, BOX_W, "center")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.78, 0.8, 0.88)
    love.graphics.printf(
        self.published and "Your build is on the sand." or "You have left no build to be fought.",
        self.boxX + 30, self.boxY + 76, BOX_W - 60, "center")

    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    local pool = self.opponents == 1 and "1 build waiting" or (self.opponents .. " builds waiting")
    love.graphics.printf(pool .. "   -   everyone fights at level " .. Build.NORMAL_LEVEL,
        self.boxX + 30, self.boxY + 104, BOX_W - 60, "center")

    for i, b in ipairs(self.buttons) do
        local on = b.hovered or (not InputMode.isMouse() and self.cursor == i)
        local live = b.key ~= "match" or self.opponents > 0
        if not live then
            love.graphics.setColor(0.16, 0.16, 0.19)
        else
            love.graphics.setColor(on and 0.35 or 0.22, on and 0.45 or 0.28, on and 0.35 or 0.24)
        end
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
        love.graphics.setColor(live and 0.6 or 0.32, live and 0.7 or 0.34, live and 0.55 or 0.38)
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(live and 0.95 or 0.45, live and 0.95 or 0.45, live and 0.95 or 0.5)
        love.graphics.printf(b.label, b.x, b.y + b.h / 2 - 11, b.w, "center")
    end

    if self.message then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(self.message, self.boxX + 24, self.boxY + BOX_H - 42, BOX_W - 48, "center")
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function inButton(b, x, y)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function Pvp:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    for _, b in ipairs(self.buttons) do b.hovered = inButton(b, x, y) end
end

function Pvp:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, b in ipairs(self.buttons) do
        if inButton(b, x, y) then return "hand" end
    end
    return "arrow"
end

function Pvp:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, b in ipairs(self.buttons) do
        if inButton(b, x, y) then self:activate(b.key) return end
    end
end

function Pvp:moveCursor(delta)
    self.cursor = ((self.cursor - 1 + delta) % #self.buttons) + 1
end

function Pvp:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "left" then self:moveCursor(-1)
    elseif key == "down" or key == "right" then self:moveCursor(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate(self.buttons[self.cursor].key)
    end
end

function Pvp:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" or button == "dpleft" then self:moveCursor(-1)
    elseif button == "dpdown" or button == "dpright" then self:moveCursor(1)
    elseif button == "a" or button == "start" then
        self:activate(self.buttons[self.cursor].key)
    end
end

return Pvp
