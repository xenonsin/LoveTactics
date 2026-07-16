local State = require("states")
local Menu = require("ui.menu")
local Player = require("models.player")
local Scale = require("scale")

local menu = {}

local titleFont = love.graphics.newFont(48)
local hintFont = love.graphics.newFont(16)

local widget

-- Debug menu entries (jump into a battle, run string extraction) for development. Flip this off for
-- a release build and the extra buttons disappear.
local DEBUG = true

-- Debug: drop straight into a battle with a stock party and a small enemy roster (mirrors the
-- objective-battle opts states/game.lua builds), so combat can be exercised without a full run.
local function startMockBattle()
    local Character = require("models.character")
    local party = {}
    for _, id in ipairs({ "knight", "mage", "archer", "priest" }) do
        party[#party + 1] = Character.instantiate(id)
    end
    State.switch(require("states.battle"), {
        encounter = { kind = "objective" },
        biome = "castle",
        prestige = 3,
        party = party,
        quest = { map = { biome = "castle", objective = {
            name = "Mock Battle",
            composition = function() return { "bandit", "bandit", "champion" } end,
            win = { type = "killAll" },
        } } },
        -- No hub/quest to return to: send both outcomes back to the menu.
        onWin = function() State.switch(require("states.menu")) end,
        onLoss = function() State.switch(require("states.menu")) end,
    })
end

-- Debug: run the localization string extractor (stamps ids + syncs data/lang/strings.lua). Same as
-- `lovec . extract-strings`; surfaced here so it can be run from a normal windowed session. Reports
-- the outcome in a short status line (there is no console under love.exe).
local function runExtractStrings()
    local ok, err = pcall(function() require("tools.extract_strings").run() end)
    menu.status = ok and "Extracted strings -> data/lang/strings.lua" or ("Extract failed: " .. tostring(err))
    menu.statusTimer = 5
end

-- Built on entry, not at require time: whether "Continue" belongs on the menu depends on
-- whether a save exists, and that can change while the game is running (starting a new
-- game writes one; there is no save until the first quest is completed or purchase made).
local function buildMenu()
    local items = {}

    if Player.hasSave() then
        items[#items + 1] = {
            label = "Continue",
            action = function()
                Player.start()
                State.switch(require("states.hub"))
            end,
        }
    end

    items[#items + 1] = {
        label = "New Game",
        action = function()
            Player.start(true) -- discards any save
            State.switch(require("states.hub"))
        end,
    }

    if DEBUG then
        items[#items + 1] = { label = "Mock Battle (debug)", action = startMockBattle }
        items[#items + 1] = { label = "Extract Strings (debug)", action = runExtractStrings }
    end

    items[#items + 1] = {
        label = "Exit To Desktop",
        action = function() love.event.quit() end,
    }

    return Menu.new(items, { startY = 280 })
end

function menu.enter()
    widget = buildMenu()
end

function menu.update(dt)
    widget:update(dt)
    if menu.statusTimer and menu.statusTimer > 0 then
        menu.statusTimer = menu.statusTimer - dt
    end
end

function menu.draw()
    local screenW = Scale.WIDTH

    -- Fill the logical area explicitly: letterbox bars are cleared to black, so
    -- setBackgroundColor (which paints the whole real window) can't be used here.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("LoveTactics", 0, 120, screenW, "center")

    widget:draw()

    if Player.hasSave() then
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.printf("New Game erases your save.", 0, Scale.HEIGHT - 48, screenW, "center")
    end

    -- Transient debug status (e.g. the result of Extract Strings).
    if menu.status and menu.statusTimer and menu.statusTimer > 0 then
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.55, 0.8, 0.6)
        love.graphics.printf(menu.status, 0, Scale.HEIGHT - 24, screenW, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function menu.mousemoved(x, y)
    widget:mousemoved(x, y)
end

-- Hand over a menu button, arrow elsewhere (see ui/cursor.lua).
function menu:cursorKind(x, y)
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function menu.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

function menu.keypressed(key)
    widget:keypressed(key)
end

function menu.gamepadpressed(joystick, button)
    widget:gamepadpressed(joystick, button)
end

return menu
