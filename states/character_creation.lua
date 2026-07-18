-- Character creation: the first screen of a New Game, before the prologue. Two steps, in order:
-- the avatar's BODY (`body` 1 or 2 -- which sprite set you wear, deliberately not a gender label),
-- then the NAME. The name is asked here rather than on the Colosseum's sand because Rowan is sworn
-- to you from the first scene and has to be able to address you (see docs/story.md).
--
-- Reached from states/menu.lua's New Game after Player.start(true) has built the fresh player, so
-- both choices write straight onto Player.active; states/prologue.lua reads them in `begin`.
--
-- Reuses ui/menu.lua and ui/name_entry.lua, which each carry mouse + keyboard + gamepad (the
-- project's three-input standard). See states/menu.lua for the same menu widget on the title screen.

local State = require("states")
local Menu = require("ui.menu")
local NameEntry = require("ui.name_entry")
local Player = require("models.player")
local Scale = require("scale")

local creation = {}

local titleFont = love.graphics.newFont(40)
local promptFont = love.graphics.newFont(20)

-- `mode` is "body" (the menu) or "name" (the entry widget); `widget` is whichever owns input now.
local widget

-- Step 2: ask the name, then begin the prologue with both choices banked on the player.
local function askName()
    creation.mode = "name"
    widget = NameEntry.new({
        prompt = "And what do they call you?",
        onSubmit = function(name)
            if Player.active then Player.active.name = name end
            State.switch(require("states.prologue"))
        end,
    })
end

-- Step 1: record the chosen body on the live player, then move to the name.
local function chooseBody(body)
    if Player.active then Player.active.body = body end
    askName()
end

function creation.enter()
    creation.mode = "body"
    widget = Menu.new({
        { label = "Body 1", action = function() chooseBody(1) end },
        { label = "Body 2", action = function() chooseBody(2) end },
    }, { startY = 320 })
end

function creation.update(dt)
    widget:update(dt)
end

function creation.draw()
    -- The name step draws its own full screen (field + on-screen keyboard); the body step is this
    -- state's own backdrop plus the menu.
    if creation.mode == "name" then
        widget:draw()
        return
    end

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

-- Hand over anything clickable (a choice button, a key), arrow elsewhere -- see ui/cursor.lua. The
-- name widget answers this itself; the menu is asked whether the point is over an item.
function creation:cursorKind(x, y)
    if creation.mode == "name" then return widget:cursorKind(x, y) end
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function creation.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

function creation.keypressed(key)
    widget:keypressed(key)
end

-- Typed letters arrive here, not through keypressed; only the name step wants them.
function creation.textinput(t)
    if creation.mode == "name" then widget:textinput(t) end
end

function creation.gamepadpressed(joystick, button)
    widget:gamepadpressed(joystick, button)
end

return creation
