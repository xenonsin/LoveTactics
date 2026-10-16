-- Character creation: who the avatar is, asked at the front of a New Game. Two steps, in order:
--
--   name    what the avatar is called (ui/name_entry.lua)
--   people  the avatar's race, one of the eight playable peoples (models/adventurers.lua's RACES)
--
-- IT IS BACK AT THE FRONT (2026-10-16). For a stretch it was the Charter's roll, filled in after the first
-- fight; the author moved it back to where it used to be, after the opening narration and before the first
-- fight on floor one (states/prologue.lua's beat list), so the name exists before anybody says it. It
-- returns to the prologue through prologue.resume either way.
--
-- IT ASKS NO CLASS AND NO LOOK, and both were asked here once. The avatar starts as a Novice and earns
-- every class afterwards, one at a time, as an achievement (a deed + a Charter Seal) -- so a trade picked
-- on the first page would hand over what the rest of the game is built to make you earn. The look went
-- with it: the default body is worn (Player.applyAvatarBody still runs).
--
-- A people is the first choice in the game with consequences. It is put on the body that already exists
-- (Character.setRace): its stat line, its resist and anything it puts in the grid -- and it is the one
-- equip gate in the game, so it decides which race pieces the avatar can ever carry (Character.canCarry).
-- Saved per body (models/save.lua).
--
-- The people step can step back to the name: Esc, the pad's B, or the Back button in the corner for a
-- mouse. The name step cannot: behind it is only the opening narration.
--
-- Widgets: ui/name_entry.lua and ui/menu.lua (card rows with a `sub` line), each carrying mouse +
-- keyboard + gamepad (the project's three-input standard), all on Theme.drawMount.

local State = require("states")
local NameEntry = require("ui.name_entry")
local Menu = require("ui.menu")
local Player = require("models.player")
local Character = require("models.character")
local Race = require("models.race")
local Scale = require("scale")
local Theme = require("ui.theme")

local creation = {}

local titleFont = Theme.display(40)
local promptFont = Theme.display(20)
local subFont = Theme.body(15)
local backFont = Theme.body(18)

local widget
local choice = {}

local BACK = { x = 40, y = 40, w = 120, h = 40 }
local backHot = false

local function avatarOf(player)
    for _, char in ipairs((player and player.roster) or {}) do
        if char.id == "character_avatar" then return char end
    end
    return nil
end

local askName, askPeople

-- The roll is written: everything lands on the live avatar, and the prologue picks up where it left off.
local function finish()
    local p = Player.active
    local avatar = avatarOf(p)
    if p then
        p.name = choice.name or p.name
    end
    if avatar then
        if choice.name then avatar.name = choice.name end
        if choice.race then Character.setRace(avatar, choice.race) end
    end
    Player.applyAvatarBody(p)
    require("states.prologue").resume()
end

function askName()
    creation.mode = "name"
    widget = NameEntry.new({
        prompt = "What's your name?",
        text = choice.name,
        onSubmit = function(name)
            choice.name = name
            askPeople()
        end,
    })
end

local function cardMenu(items)
    return Menu.new(items, {
        buttonWidth = 640, buttonHeight = 64, spacing = 8, startY = 280,
        subFont = subFont, maxVisible = 5,
    })
end

function askPeople()
    creation.mode = "people"
    creation.prompt = "Your people"
    local items = {}
    for _, id in ipairs(require("models.adventurers").RACES) do
        local def = Race.get(id)
        if def then
            items[#items + 1] = {
                label = def.name or id,
                sub = def.description,
                action = function() choice.race = id; finish() end,
            }
        end
    end
    widget = cardMenu(items)
end

local function canGoBack() return creation.mode ~= "name" end

local function goBack()
    if creation.mode == "people" then askName() end
end

local function overBack(x, y)
    return canGoBack() and x >= BACK.x and x <= BACK.x + BACK.w and y >= BACK.y and y <= BACK.y + BACK.h
end

function creation.enter()
    choice = { name = Player.active and Player.active.name or nil }
    askName()
end

function creation.update(dt)
    widget:update(dt)
end

function creation.draw()
    -- The name step draws its own full screen (field + on-screen keyboard).
    if creation.mode == "name" then
        widget:draw()
        return
    end

    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Charter's Roll", 0, 150, Scale.WIDTH, "center")

    love.graphics.setFont(promptFont)
    Theme.set(Theme.muted)
    love.graphics.printf(creation.prompt or "", 0, 210, Scale.WIDTH, "center")

    widget:draw()

    -- The mouse's way back a step; Esc and B are the other two.
    love.graphics.setFont(backFont)
    Theme.set(backHot and Theme.accentAmber or Theme.muted)
    love.graphics.rectangle("line", BACK.x, BACK.y, BACK.w, BACK.h, 4, 4)
    love.graphics.printf("Back", BACK.x, BACK.y + (BACK.h - backFont:getHeight()) / 2, BACK.w, "center")

    love.graphics.setColor(1, 1, 1)
end

function creation.mousemoved(x, y)
    backHot = overBack(x, y)
    widget:mousemoved(x, y)
end

function creation:cursorKind(x, y)
    if creation.mode == "name" then return widget:cursorKind(x, y) end
    if overBack(x, y) then return "hand" end
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function creation.mousepressed(x, y, button)
    if button == 1 and overBack(x, y) then goBack(); return end
    widget:mousepressed(x, y, button)
end

function creation.wheelmoved(dx, dy)
    if widget.wheelmoved then widget:wheelmoved(dx, dy) end
end

function creation.keypressed(key)
    if key == "escape" and canGoBack() then goBack(); return end
    widget:keypressed(key)
end

-- Typed letters arrive here, not through keypressed; only the name step wants them.
function creation.textinput(t)
    if creation.mode == "name" then widget:textinput(t) end
end

function creation.gamepadpressed(joystick, button)
    if button == "b" and canGoBack() then goBack(); return end
    widget:gamepadpressed(joystick, button)
end

return creation
