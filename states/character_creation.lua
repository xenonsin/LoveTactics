-- Character creation: the first screen of a New Game, before the prologue. The player picks the
-- avatar's gender here; the NAME is not asked until the Colosseum announcer demands it on the sand
-- (see docs/story.md, "The three acts" -- the arena gives the nameless survivor a name). So this
-- screen is deliberately small: one choice, then the story begins.
--
-- Reached from states/menu.lua's New Game after Player.start(true) has built the fresh player, so
-- the choice writes straight onto Player.active. Advances to the prologue once that exists; until
-- then it hands off to the hub so the New Game flow stays playable.
--
-- Reuses ui/menu.lua, which carries mouse + keyboard + gamepad for free (the project's three-input
-- standard). See states/menu.lua for the same widget driving the title screen.

local State = require("states")
local Menu = require("ui.menu")
local Player = require("models.player")
local Scale = require("scale")

local creation = {}

local titleFont = love.graphics.newFont(40)
local promptFont = love.graphics.newFont(20)

local widget

-- Record the chosen gender on the live player, then begin the prologue (states/prologue.lua builds
-- the avatar from this gender and runs Act 0).
local function choose(gender)
    if Player.active then Player.active.gender = gender end
    State.switch(require("states.prologue"))
end

function creation.enter()
    widget = Menu.new({
        { label = "Woman", action = function() choose("F") end },
        { label = "Man",   action = function() choose("M") end },
    }, { startY = 320 })
end

function creation.update(dt)
    widget:update(dt)
end

function creation.draw()
    -- Fill the logical area explicitly (letterbox bars are cleared to black), matching states/menu.lua.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("A New Journey", 0, 150, Scale.WIDTH, "center")

    love.graphics.setFont(promptFont)
    love.graphics.setColor(0.6, 0.65, 0.78)
    love.graphics.printf("Who will you be?", 0, 230, Scale.WIDTH, "center")

    widget:draw()

    love.graphics.setColor(1, 1, 1)
end

function creation.mousemoved(x, y)
    widget:mousemoved(x, y)
end

-- Hand over a choice button, arrow elsewhere (see ui/cursor.lua), like the title menu.
function creation:cursorKind(x, y)
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function creation.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

function creation.keypressed(key)
    widget:keypressed(key)
end

function creation.gamepadpressed(joystick, button)
    widget:gamepadpressed(joystick, button)
end

return creation
