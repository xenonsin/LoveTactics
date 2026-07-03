-- Overworld state: reached by starting a quest from the Quest Board. It generates
-- a procedural overworld map (models/overworld.lua) from the quest's `map` params,
-- renders it with a scrolling camera (ui/overworld_map.lua), and lets the player
-- traverse it. Stepping onto an encounter tile opens a modal encounter panel;
-- clearing the objective completes the quest and returns to the hub.
--
-- All per-run state (grid, map widget, open panel) is (re)built in `enter`, so
-- re-entering a quest always starts a fresh map.

local State = require("states")
local Scale = require("scale")
local Overworld = require("models.overworld")
local OverworldMap = require("ui.overworld_map")
local EncounterPanel = require("ui.panels.encounter")
local EncounterModel = require("models.encounter")

local game = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)

-- Clickable "Back" button so a mouse-only player can leave to the hub.
local backButton = { x = 16, y = 16, w = 110, h = 36 }

local function backContains(x, y)
    return x >= backButton.x and x <= backButton.x + backButton.w
        and y >= backButton.y and y <= backButton.y + backButton.h
end

-- prestige defaults to 1 when a quest is launched without it (e.g. dev/test).
function game.enter(self, quest, prestige)
    game.quest = quest
    game.prestige = prestige or 1
    local mp = quest and quest.map or {}

    -- Dynamic encounter selection: build the eligible weighted pool for this
    -- player's prestige + the quest's biome, plus any guaranteed "always" picks.
    local ctx = { prestige = game.prestige, biome = mp.biome, quest = quest }
    local encSpec = mp.encounters or {}
    local always = {}
    for _, id in ipairs(encSpec.always or {}) do
        local def = EncounterModel.get(id)
        if def then always[#always + 1] = { id = id, kind = def.kind, name = def.name } end
    end

    local params = {
        biome = mp.biome,
        cols = mp.cols,
        rows = mp.rows,
        keyCount = mp.keyCount,
        objective = mp.objective,
        encounterCount = { min = encSpec.min or 6, max = encSpec.max or encSpec.min or 6 },
        encounters = EncounterModel.pool(ctx),
        alwaysEncounters = always,
        seed = os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000,
    }

    game.grid = Overworld.generate(params)
    game.activePanel = nil
    game.complete = false
    game.map = OverworldMap.new(game.grid, {
        onEncounter = function(cell) game:openEncounter(cell) end,
    })
end

function game:openEncounter(cell)
    game.activePanel = EncounterPanel.new({
        encounter = cell.encounter,
        onResolve = function()
            cell.cleared = true
            game.activePanel = nil
            if cell.encounter.kind == "objective" then
                game.complete = true
                State.switch(require("states.hub"))
            end
        end,
        onClose = function() game.activePanel = nil end,
    })
end

local function toHub()
    State.switch(require("states.hub"))
end

function game.update(dt)
    if game.activePanel then
        game.activePanel:update(dt)
    else
        game.map:update(dt)
    end
end

function game.draw()
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    game.map:draw()

    game.drawHud()

    if game.activePanel then
        game.activePanel:draw()
    end
end

function game.drawHud()
    -- Back button.
    love.graphics.setColor(0.20, 0.23, 0.32)
    love.graphics.rectangle("fill", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(hudFont)
    love.graphics.printf("Back", backButton.x, backButton.y + backButton.h / 2 - 8,
        backButton.w, "center")

    -- Quest name + objective hint.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(game.quest and game.quest.name or "Quest", 0, 20, Scale.WIDTH, "center")

    -- Keys held (only shown when the map has locks).
    local total = #game.grid.keyIds
    if total > 0 then
        local held = 0
        for _ in pairs(game.map.keysHeld) do held = held + 1 end
        love.graphics.setFont(hudFont)
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.printf("Keys: " .. held .. " / " .. total, 0, 52, Scale.WIDTH, "center")
    end

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf("Move: WASD / Arrows / D-pad / click adjacent tile      Esc: hub",
        0, Scale.HEIGHT - 30, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)
end

function game.mousemoved(x, y, dx, dy)
    if game.activePanel then
        game.activePanel:mousemoved(x, y)
    else
        game.map:mousemoved(x, y)
    end
end

function game.mousepressed(x, y, button)
    if game.activePanel then
        game.activePanel:mousepressed(x, y, button)
    elseif button == 1 and backContains(x, y) then
        toHub()
    else
        game.map:mousepressed(x, y, button)
    end
end

function game.keypressed(key)
    if game.activePanel then
        game.activePanel:keypressed(key)
    elseif key == "escape" then
        toHub()
    else
        game.map:keypressed(key)
    end
end

function game.gamepadpressed(joystick, button)
    if game.activePanel then
        game.activePanel:gamepadpressed(joystick, button)
    elseif button == "back" then
        toHub()
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
