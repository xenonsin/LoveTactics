-- Character creation: the first screen of a New Game, before the prologue. Two steps, in order:
-- the avatar's BODY (`body` 1 or 2 -- which sprite set you wear, deliberately not a gender label),
-- then the NAME. The name is asked here rather than on the Colosseum's sand because Rowan has known
-- you since before the first scene -- same company, and she taught you the sword -- so she has to be
-- able to address you by it (see docs/story.md).
--
-- THE BODY STEP SHOWS THE BODIES. It used to be ui/menu.lua carrying two rows that read "Body 1" and
-- "Body 2", under the heading "Who will you be?" -- a question about a face, answered by an index,
-- with the faces themselves nowhere on the screen. It is now a pair of portrait cards
-- (ui/portrait_choice.lua) and the pictures are the choice.
--
-- IT IS ALSO THE ONLY PLACE THE CHOICE IS EVER PAID OFF. The unchosen body used to go on Bryn, a
-- sibling standing in the house the prologue burned, so the menu meant something one scene later and
-- off screen; that scene is cut (data/conversations/prologue/conversation_prologue_village.lua). So
-- the picture is not decoration on the step, it is the whole of what makes the step a decision.
--
-- Reached from states/menu.lua's New Game after Player.start(true) has built the fresh player, so
-- both choices write straight onto Player.active; states/prologue.lua reads them in `begin`.
--
-- Reuses ui/portrait_choice.lua and ui/name_entry.lua, which each carry mouse + keyboard + gamepad
-- (the project's three-input standard). Both draw on Theme.drawMount, so the two steps of one flow
-- stand on the same ground.

local State = require("states")
local PortraitChoice = require("ui.portrait_choice")
local NameEntry = require("ui.name_entry")
local Player = require("models.player")
local Scale = require("scale")

local creation = {}

local Theme = require("ui.theme")
local titleFont = Theme.display(40)
local promptFont = Theme.display(20)

-- `mode` is "body" (the menu) or "name" (the entry widget); `widget` is whichever owns input now.
local widget

-- Step 2: ask the name, then begin the prologue with both choices banked on the player.
local function askName()
    creation.mode = "name"
    widget = NameEntry.new({
        -- "And what do they call you?" stood here, and the "And" was continuing a conversation the
        -- step before it never started: the body step asks a question with a picture, not a sentence.
        prompt = "What do they call you?",
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
    -- The portrait paths the avatar blueprint and models/conversation.lua's `speaker` already resolve
    -- to off `player.body`, so the card shows the face the game will actually draw for this save
    -- rather than a picture chosen for the menu. Both are uncommissioned today and the card says so;
    -- see the header of ui/portrait_choice.lua on why the composed board token is not borrowed here.
    widget = PortraitChoice.new({
        { label = "Body 1", portrait = "assets/portraits/avatar_1.png", action = function() chooseBody(1) end },
        { label = "Body 2", portrait = "assets/portraits/avatar_2.png", action = function() chooseBody(2) end },
    }, { centerY = 486 }) -- centred in the band under the prompt at 230; see ui/portrait_choice.lua
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
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("A New Journey", 0, 150, Scale.WIDTH, "center")

    love.graphics.setFont(promptFont)
    Theme.set(Theme.muted)
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
