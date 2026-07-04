-- Battle state: reached when the player engages a combat encounter on the overworld
-- (states/game.lua -> game:openEncounter). It builds an 8x8 arena from the quest's
-- biome (models/arena.lua), placing the party on the near side and the encounter's
-- prestige-scaled enemy roster on the far side, and renders it with ui/battle_map.lua.
--
-- The turn-based system is a later task, so victory/defeat are DEBUG-triggered here:
--   k  -> win  (onWin: overworld resumes, tile cleared / quest completes)
--   l  -> lose (onLoss: party wiped, quest failed -> hub)
--   F5 -> save the current arena to data/arenas/ for hand-editing (dev only)
-- The onWin/onLoss callbacks are supplied by the overworld so the real objective
-- evaluation can replace the debug keys without touching the state transitions.

local Scale = require("scale")
local Arena = require("models.arena")
local BattleMap = require("ui.battle_map")
local Character = require("models.character")
local EncounterModel = require("models.encounter")

local battle = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)

-- Clickable "Forfeit" button so a mouse-only player can bail out (counts as a loss).
local forfeitButton = { x = 16, y = 16, w = 130, h = 36 }

local function forfeitContains(x, y)
    return x >= forfeitButton.x and x <= forfeitButton.x + forfeitButton.w
        and y >= forfeitButton.y and y <= forfeitButton.y + forfeitButton.h
end

-- Human-readable objective line for the HUD.
local function objectiveText(obj)
    if obj.type == "survive" then
        return "Objective: survive " .. (obj.turns or "?") .. " turns"
    elseif obj.type == "assassinate" then
        local target = obj.target and Character.defs[obj.target]
        return "Objective: defeat " .. ((target and target.name) or obj.target or "the target")
    end
    return "Objective: defeat all enemies"
end

-- Resolve the encounter's composition spec + objective. Placed encounters read their
-- blueprint; the objective tile reads the quest's `map.objective`.
local function specFor(opts, partyIds, seed)
    local spec = { biome = opts.biome, party = partyIds, seed = seed }
    local enc = opts.encounter or {}
    if enc.kind == "objective" then
        local obj = (opts.quest and opts.quest.map and opts.quest.map.objective) or {}
        spec.composition = obj.composition
        spec.objective = obj.win -- { type, target } win condition; nil -> killAll
    else
        local def = enc.id and EncounterModel.get(enc.id)
        spec.composition = def and def.composition
        spec.objective = def and def.objective
    end
    return spec
end

function battle.enter(self, opts)
    opts = opts or {}
    battle.onWin = opts.onWin
    battle.onLoss = opts.onLoss
    battle.encounter = opts.encounter or { kind = "combat", name = "Battle" }

    -- Active party instances (from the player), keyed by id for sprite/name lookup.
    local party = opts.party or {}
    local partyIds, partyById = {}, {}
    for i, char in ipairs(party) do
        partyIds[i] = char.id
        partyById[char.id] = char
    end

    local seed = os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000
    local ctx = { prestige = opts.prestige or 1, biome = opts.biome, quest = opts.quest }
    battle.arena = Arena.build(ctx, specFor(opts, partyIds, seed))

    -- Build render units (+ keep instances for the future turn system).
    local units = {}
    battle.partyUnits, battle.enemyUnits = {}, {}
    for _, u in ipairs(battle.arena.party) do
        local inst = partyById[u.id]
        units[#units + 1] = { x = u.x, y = u.y, side = "party",
            name = inst and inst.name, sprite = inst and inst.sprite }
        battle.partyUnits[#battle.partyUnits + 1] = { char = inst, x = u.x, y = u.y }
    end
    for _, u in ipairs(battle.arena.enemies) do
        local inst = Character.instantiate(u.id)
        units[#units + 1] = { x = u.x, y = u.y, side = "enemy",
            name = inst.name, sprite = inst.sprite }
        battle.enemyUnits[#battle.enemyUnits + 1] = { char = inst, x = u.x, y = u.y }
    end

    battle.map = BattleMap.new(battle.arena, { units = units })
end

local function win()
    if battle.onWin then battle.onWin() end
end

local function lose()
    if battle.onLoss then battle.onLoss() end
end

function battle.update(dt)
    battle.map:update(dt)
end

function battle.draw()
    love.graphics.setColor(0.04, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    battle.map:draw()
    battle.drawHud()
end

function battle.drawHud()
    -- Forfeit button.
    love.graphics.setColor(0.28, 0.18, 0.20)
    love.graphics.rectangle("fill", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.7, 0.4, 0.4)
    love.graphics.rectangle("line", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.9, 0.9)
    love.graphics.setFont(hudFont)
    love.graphics.printf("Forfeit", forfeitButton.x, forfeitButton.y + forfeitButton.h / 2 - 8,
        forfeitButton.w, "center")

    -- Encounter name.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(battle.encounter.name or "Battle", 0, 20, Scale.WIDTH, "center")

    -- Objective + party/enemy counts.
    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf(objectiveText(battle.arena.objective), 0, 52, Scale.WIDTH, "center")
    love.graphics.setColor(0.6, 0.75, 0.95)
    love.graphics.printf("Party: " .. #battle.partyUnits .. "    Enemies: " .. #battle.enemyUnits,
        0, 74, Scale.WIDTH, "center")

    -- Debug controls (stand-in until the turn system lands).
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf("DEBUG:  K = win    L = lose    F5 = save arena    Esc = forfeit",
        0, Scale.HEIGHT - 30, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)
end

function battle.keypressed(key)
    if key == "k" then
        win()
    elseif key == "l" or key == "escape" then
        lose()
    elseif key == "f5" then
        Arena.save(battle.arena, (battle.arena.biome or "arena") .. "_" .. os.time())
    else
        battle.map:keypressed(key)
    end
end

function battle.gamepadpressed(joystick, button)
    if button == "start" then
        win()
    elseif button == "back" then
        lose()
    else
        battle.map:gamepadpressed(joystick, button)
    end
end

function battle.mousemoved(x, y, dx, dy)
    battle.map:mousemoved(x, y)
end

function battle.mousepressed(x, y, button)
    if button == 1 and forfeitContains(x, y) then
        lose()
    else
        battle.map:mousepressed(x, y, button)
    end
end

return battle
