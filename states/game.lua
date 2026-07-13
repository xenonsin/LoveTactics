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
local Player = require("models.player")
local Quest = require("models.quest")
local EncounterPanel = require("ui.panels.encounter")
local EncounterModel = require("models.encounter")
local Party = require("ui.panels.party")

local game = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)

-- Clickable "Back" button so a mouse-only player can leave to the hub.
local backButton = { x = 16, y = 16, w = 110, h = 36 }
-- Clickable "Items" button: opens the Party screen (stash mode) to arrange party items on the overworld.
local itemsButton = { x = 138, y = 16, w = 110, h = 36 }

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function backContains(x, y)
    return rectContains(backButton, x, y)
end

-- Open the Party screen over the overworld (same modal slot as the encounter panel).
local function openLoadout()
    game.activePanel = Party.new({
        player = game.player,
        onClose = function() game.activePanel = nil end,
    })
end

-- prestige defaults to 1 when a quest is launched without it (e.g. dev/test).
function game.enter(self, quest, prestige, player)
    game.quest = quest
    game.prestige = prestige or 1
    game.player = player -- kept so combat encounters can deploy the active party
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
        -- Fog-of-war radius from the active party (a torch-carrier widens it).
        visionRadius = Player.visionRadius(player),
    })
end

-- Engaging an encounter. Combat kinds (combat / elite / objective) drop into the
-- battle arena; the non-combat kinds (town / treasure) keep the simple modal.
function game:openEncounter(cell)
    local kind = cell.encounter.kind
    if kind == "combat" or kind == "elite" or kind == "objective" then
        local mp = game.quest and game.quest.map or {}
        State.switch(require("states.battle"), {
            encounter = cell.encounter,
            biome = mp.biome,
            quest = game.quest,
            prestige = game.prestige,
            party = game.player and game.player.party or {},
            -- The player's stash, by reference: an item stolen mid-battle by a thief with a full
            -- grid is appended straight to it, so a theft survives whatever the battle does next.
            stash = game.player and game.player.stash,
            -- Victory resumes THIS overworld (no regenerate); the objective completes
            -- the quest instead. See the file header on why enter is skipped here.
            onWin = function()
                cell.cleared = true
                game.activePanel = nil
                if kind == "objective" then
                    game.complete = true
                    -- The single payout seam: gold, prestige, and sponsor reputation are
                    -- granted here, once, and the game saves. Losing the quest (onLoss)
                    -- pays nothing, so a wipe costs the run.
                    game.reward = Quest.complete(game.player, game.quest)
                    -- Hand the reward (gold/prestige/rep + the roster's level-ups) to the hub, which
                    -- opens the Company Advancement overlay on entry and clears this once shown.
                    if game.player and game.reward then game.player.pendingSummary = game.reward end
                    State.switch(require("states.hub"))
                else
                    State.current = game
                end
            end,
            -- A total party wipe (or forfeit) fails the quest: back to the hub.
            onLoss = function() State.switch(require("states.hub")) end,
        })
        return
    end

    game.activePanel = EncounterPanel.new({
        encounter = cell.encounter,
        onResolve = function()
            cell.cleared = true
            game.activePanel = nil
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

    -- Items button.
    love.graphics.setColor(0.20, 0.23, 0.32)
    love.graphics.rectangle("fill", itemsButton.x, itemsButton.y, itemsButton.w, itemsButton.h, 6, 6)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", itemsButton.x, itemsButton.y, itemsButton.w, itemsButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(hudFont)
    love.graphics.printf("Items", itemsButton.x, itemsButton.y + itemsButton.h / 2 - 8,
        itemsButton.w, "center")

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
    love.graphics.printf("Move: WASD / Arrows / D-pad / click adjacent tile      I: items      Esc: hub",
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
    elseif button == 1 and rectContains(itemsButton, x, y) then
        openLoadout()
    else
        game.map:mousepressed(x, y, button)
    end
end

-- Only panels that scroll or drag define these; the overworld map handles neither.
function game.mousereleased(x, y, button)
    local panel = game.activePanel
    if panel and panel.mousereleased then panel:mousereleased(x, y, button) end
end

function game.wheelmoved(dx, dy)
    local panel = game.activePanel
    if panel and panel.wheelmoved then panel:wheelmoved(dx, dy) end
end

function game.keypressed(key)
    if game.activePanel then
        game.activePanel:keypressed(key)
    elseif key == "escape" then
        toHub()
    elseif key == "i" then
        openLoadout()
    else
        game.map:keypressed(key)
    end
end

function game.gamepadpressed(joystick, button)
    if game.activePanel then
        game.activePanel:gamepadpressed(joystick, button)
    elseif button == "back" then
        toHub()
    elseif button == "y" then
        openLoadout()
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
