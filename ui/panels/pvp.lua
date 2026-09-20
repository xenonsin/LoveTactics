-- The Dueling Grounds pop-up: publish the team others will face, or go and face somebody else's.
--
-- Both halves lean on models/build.lua and models/builds.lua and hold no rules of their own. In
-- particular the panel does NOT decide what a fair fight is -- normalization does, on both sides at
-- once (Build.restore, run over the opponent's published build AND your own), so there is no place
-- here for a matchmaking rule to quietly disagree with the one the model states.
--
-- Modeled on ui/panels/encounter.lua: the hub owns it, forwards input while it is open, and it
-- closes via the X, Esc, or gamepad B. Mouse, keyboard and gamepad all drive it.
--
--   local panel = Pvp.new({ player = hub.player, onClose = function() ... end })

local CloseButton = require("ui.close_button")
local Keeper = require("ui.keeper") -- the city's keeper pane: face or mark, name, line
local Scale = require("scale")
local InputMode = require("input_mode")
local Player = require("models.player")
local Build = require("models.build")
local Builds = require("models.builds")
local Theme = require("ui.theme")

local Pvp = {}
Pvp.__index = Pvp

-- 560 x 320 until the sand grew a keeper. The Colosseum's door introduces somebody and this room is
-- behind it, so the pane is here like everywhere else in the city (ui/keeper.lua) -- and it is ADDED
-- rather than taken out of the middle: two buttons and three lines were never crowded, and squeezing
-- them into half a box to make room for a picture would be the picture winning an argument it should
-- not be in.
local BOX_W, BOX_H = 820, 400
local BTN_W, BTN_H = 220, 46
local PAD = 24

function Pvp.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Pvp)
    self.player = opts.player or Player.active
    self.onClose = opts.onClose
    -- The house behind this room (models/offer.lua hands it down); the Colosseum, unless something
    -- opens the sand from outside the city.
    self.vendorId = opts.vendor
    self.title = opts.title or "Dueling Grounds"
    self.titleFont = Theme.display(28)
    self.bodyFont = Theme.body(17)
    self.smallFont = Theme.body(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    self.keeperX = self.boxX + PAD
    self.keeperY = self.boxY + 64
    self.keeperH = BOX_H - 64 - PAD
    self.colX = self.keeperX + Keeper.W + PAD
    self.colW = self.boxX + BOX_W - PAD - self.colX

    local bx = self.colX + self.colW / 2 - BTN_W / 2
    self.buttons = {
        { key = "assemble", label = "Assemble Build", x = bx, y = self.boxY + 190, w = BTN_W, h = BTN_H },
        { key = "match",    label = "Find a Match",   x = bx, y = self.boxY + 248, w = BTN_W, h = BTN_H },
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

-- Pick the team that will stand in for you when you are not here (states/build_select.lua). A duel has
-- no deployment phase and no bench, so a build is exactly the Build.TEAM_SIZE who take the field --
-- which is why this is the one screen left that picks a subset of the roster at all.
function Pvp:assemble()
    local State = require("states")
    local player = self.player
    State.switch(require("states.build_select"), player, {
        onPublish = function(team)
            local build = Build.from(team, {
                author = { id = Player.authorId(player), name = player.name },
                prestige = player.prestige,
            })
            local _, why = Builds.publish(build)
            player.lastPublishError = why -- nil on success; the panel reads it when it reopens
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
    -- You duel with the build you published, not with "whoever is at the top of the roster". The
    -- roster is the campaign's whole company and has no team of four in it to read off; your build is
    -- the four you named, so it is both what others face and what you bring to the sand.
    local mine = Builds.backend.read(Builds.idFor(Player.authorId(player)))
    local myTeam = mine and Build.restore(mine) or nil
    if not myTeam then
        self.message = "Assemble a build first -- it is the team you fight with too."
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
        party = myTeam,
        enemyChars = foes,
        -- No deployment phase: both teams are normalized copies on a fixed board, and a build is the
        -- four who take the field (Build.TEAM_SIZE) with no bench behind them.
        deploy = false,
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

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    -- Centred on the COLUMN and not on the box: the keeper's pane holds the left of the panel, and a
    -- title centred on the whole thing lands over the gutter between the two.
    love.graphics.printf("Dueling Grounds", self.colX, self.boxY + 26, self.colW, "center")

    Keeper.draw(self.vendorId, self.keeperX, self.keeperY, Keeper.W, self.keeperH, {
        nameFont = self.bodyFont,
        lineFont = self.smallFont,
        title = self.title,
        line = false, -- the pane runs to the foot of the box; there is no room under it for a line
    })

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(
        self.published and "Your build is on the sand." or "You have left no build to be fought.",
        self.colX, self.boxY + 96, self.colW, "center")

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local pool = self.opponents == 1 and "1 build waiting" or (self.opponents .. " builds waiting")
    love.graphics.printf(pool .. "   -   everyone fights at level " .. Build.NORMAL_LEVEL,
        self.colX, self.boxY + 128, self.colW, "center")

    for i, b in ipairs(self.buttons) do
        local on = b.hovered or (not InputMode.isMouse() and self.cursor == i)
        local live = b.key ~= "match" or self.opponents > 0
        if not live then Theme.set(Theme.slot, 0.6)
        else Theme.set(on and Theme.panel or Theme.panel2) end
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(on and 1.5 or 1)
        if not live then Theme.set(Theme.frame, 0.5)
        elseif on then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame) end
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self.bodyFont)
        Theme.set(live and Theme.ink or Theme.muted)
        love.graphics.printf(b.label, b.x, b.y + b.h / 2 - 11, b.w, "center")
    end

    if self.message then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(self.message, self.colX, self.boxY + BOX_H - 42, self.colW, "center")
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
    elseif key == "up" or key == "left" or key == "w" or key == "a" then self:moveCursor(-1)
    elseif key == "down" or key == "right" or key == "s" or key == "d" then self:moveCursor(1)
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
