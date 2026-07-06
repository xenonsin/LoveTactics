-- Battle state: reached when the player engages a combat encounter on the overworld
-- (states/game.lua -> game:openEncounter). It builds an 8x8 arena from the quest's
-- biome (models/arena.lua), placing the party on the near side and the encounter's
-- prestige-scaled enemy roster on the far side, then drives a live models/combat.lua
-- timeline: units act in turn order (lowest `time` first), the player moves/acts the
-- current party unit, and enemies act via Combat.planEnemyAction. Victory/defeat come
-- from Combat.evaluate, firing the overworld-supplied onWin/onLoss.
--
-- Player interaction (mouse + keyboard + gamepad, per the project standard):
--   * A party unit's turn defaults to MOVE mode: blue reachable tiles are shown; picking
--     one moves the unit and ends its turn. Hovering a tile previews the turn order.
--   * Selecting an item (click a slot / number key / gamepad Y) ARMS it: its range is shown
--     in red. Confirming on a valid target resolves it; re-selecting the item cancels.
--   * Forfeit button / Esc / gamepad B (when not armed) = concede the battle (a loss).
--   * F5 saves the current arena to data/arenas/ for hand-editing (dev only).

local Scale = require("scale")
local Arena = require("models.arena")
local BattleMap = require("ui.battle_map")
local CombatPanel = require("ui.combat_panel")
local Character = require("models.character")
local Combat = require("models.combat")
local EncounterModel = require("models.encounter")

local battle = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)

local PANEL_W = CombatPanel.WIDTH
local AI_DELAY = 0.35 -- seconds between enemy actions, so each move is watchable

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

-- ---------------------------------------------------------------------------
-- Combat controller (all module-level locals so they close over `battle`; declared
-- before battle.enter so its panel callbacks can reference them as upvalues).
-- ---------------------------------------------------------------------------

local function win()
    battle.over = true
    if battle.onWin then battle.onWin() end
end

local function lose()
    battle.over = true
    if battle.onLoss then battle.onLoss() end
end

-- Reachable tiles for the current unit (blue move highlights + move validity).
local function computeReachable(unit)
    battle.reachable = Combat.reachable(battle.combat, unit)
    local cells = {}
    for _, node in pairs(battle.reachable) do
        cells[#cells + 1] = { x = node.x, y = node.y }
    end
    battle.moveCells = cells
end

-- The armed ability's range area (red highlights). Targeting validity is enforced by
-- Combat.useItem; this just shows the reach.
local function computeRange(unit, item)
    local range = (item.activeAbility and item.activeAbility.range) or 1
    local cells = {}
    for dx = -range, range do
        for dy = -range, range do
            if math.abs(dx) + math.abs(dy) <= range then
                local x, y = unit.x + dx, unit.y + dy
                if x >= 1 and x <= battle.arena.cols and y >= 1 and y <= battle.arena.rows then
                    cells[#cells + 1] = { x = x, y = y }
                end
            end
        end
    end
    battle.rangeCells = cells
end

-- Start the current unit's turn: MOVE mode + reachable set for a party unit, or an AI
-- delay for an enemy.
local function beginTurn()
    local current = Combat.currentUnit(battle.combat)
    battle.current = current
    battle.mode = "move"
    battle.armedItem = nil
    battle.hoverItem = nil
    battle.rangeCells = {}
    battle.moveCells = {}
    if not current then return end
    if current.side == "party" then
        computeReachable(current)
        battle.map.cursor.x, battle.map.cursor.y = current.x, current.y
    else
        battle.aiTimer = AI_DELAY
    end
end

-- Resolve the objective after an action; otherwise hand off to the next unit.
local function advanceTurn()
    local result = Combat.evaluate(battle.combat)
    if result == "win" then win() return
    elseif result == "loss" then lose() return end
    beginTurn()
end

local function cancelArm()
    battle.mode = "move"
    battle.armedItem = nil
end

-- Arm an ability item (or toggle it off if already armed).
local function armItem(item)
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    if not (item and item.activeAbility) then return end
    if battle.armedItem == item then cancelArm() return end
    battle.armedItem = item
    battle.mode = "armed"
    -- Support abilities (heal / buff, i.e. non-enemy targets) highlight green, not red.
    battle.armedSupport = item.activeAbility.target ~= "enemy"
    computeRange(current, item)
end

local function armSlot(n)
    local current = battle.current
    if not current or current.side ~= "party" then return end
    armItem(current.char.inventory[n])
end

-- Gamepad Y cycles through the current unit's ability items (past the end -> back to move).
local function cycleAbilityItem()
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    local items = Combat.abilityItems(current.char)
    if #items == 0 then return end
    local idx = 0
    for i, it in ipairs(items) do
        if it == battle.armedItem then idx = i break end
    end
    if idx + 1 > #items then cancelArm() else armItem(items[idx + 1]) end
end

-- Confirm on the cursor cell: move there, or use the armed item on it.
local function confirm()
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    if battle.mode == "move" then
        if battle.reachable[cx .. "," .. cy] then
            if Combat.moveUnit(battle.combat, current, cx, cy) then advanceTurn() end
        end
    elseif battle.mode == "armed" and battle.armedItem then
        if Combat.useItem(battle.combat, current, battle.armedItem, cx, cy) then advanceTurn() end
    end
end

-- A unit that can neither reach nor hit anyone still advances the timeline so combat
-- never stalls.
local function passTurn(unit)
    unit.time = unit.time + Combat.DEFAULT_SPEED
    battle.combat.turnCount = battle.combat.turnCount + 1
    battle.combat.clock = math.max(battle.combat.clock, unit.time)
end

local function executeEnemyAction()
    local current = battle.current
    if not current or current.side ~= "enemy" then return end
    local act = Combat.planEnemyAction(battle.combat, current)
    if act.kind == "move" then
        Combat.moveUnit(battle.combat, current, act.x, act.y)
    elseif act.kind == "item" then
        Combat.useItem(battle.combat, current, act.item, act.tx, act.ty)
    else
        passTurn(current)
    end
    advanceTurn()
end

-- Compute the turn-order preview + battlefield overlays and hand them to the widgets.
local function refreshView()
    local current = battle.current
    if not current then return end
    local isParty = current.side == "party" and not battle.over

    -- Preview how the pending action would reorder the timeline.
    local newTime
    if isParty then
        if battle.hoverItem and battle.hoverItem.activeAbility then
            newTime = current.time + (battle.hoverItem.activeAbility.speed or 0)
        elseif battle.mode == "armed" and battle.armedItem then
            newTime = current.time + (battle.armedItem.activeAbility.speed or 0)
        elseif battle.mode == "move" then
            local node = battle.reachable and battle.reachable[battle.map.cursor.x .. "," .. battle.map.cursor.y]
            if node then newTime = current.time + node.steps end
        end
    end
    -- Timeline entries for the panel: the live order, plus a ghost of the actor at its
    -- projected slot while a move/item is being previewed.
    local entries
    if newTime then
        entries = Combat.previewTimeline(battle.combat, current, newTime)
    else
        entries = {}
        for _, u in ipairs(Combat.turnOrder(battle.combat)) do
            entries[#entries + 1] = { unit = u, preview = false, time = u.time }
        end
    end

    battle.panel:setView({
        order = entries, current = current, isPartyTurn = isParty,
        items = (current.side == "party") and current.char.inventory or {},
        armedItem = battle.armedItem,
        showTime = battle.showInitiative,
    })

    -- Board highlights: the acting unit always, plus whichever unit the timeline is hovering.
    local overlays = { move = {}, range = {} }
    if isParty and battle.mode == "armed" then
        overlays.range = battle.rangeCells
        overlays.rangeSupport = battle.armedSupport
    elseif isParty then
        overlays.move = battle.moveCells
    end
    overlays.current = { x = current.x, y = current.y }
    local hover = battle.hoverUnit
    if hover and hover.alive then overlays.hover = { x = hover.x, y = hover.y } end
    battle.map:setOverlays(overlays)
end

-- ---------------------------------------------------------------------------
-- State callbacks
-- ---------------------------------------------------------------------------

function battle.enter(self, opts)
    opts = opts or {}
    battle.onWin = opts.onWin
    battle.onLoss = opts.onLoss
    battle.encounter = opts.encounter or { kind = "combat", name = "Battle" }
    battle.over = false
    battle.showInitiative = true -- initiative numbers on the turn order (F6 toggles)

    -- Active party instances (from the player), keyed by id for spawn lookup.
    local party = opts.party or {}
    local partyIds, partyById = {}, {}
    for i, char in ipairs(party) do
        partyIds[i] = char.id
        partyById[char.id] = char
    end

    local seed = os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000
    local ctx = { prestige = opts.prestige or 1, biome = opts.biome, quest = opts.quest }
    battle.arena = Arena.build(ctx, specFor(opts, partyIds, seed))

    -- Combat unit lists: { char = <instance>, x, y }.
    battle.partyUnits, battle.enemyUnits = {}, {}
    for _, u in ipairs(battle.arena.party) do
        battle.partyUnits[#battle.partyUnits + 1] = { char = partyById[u.id], x = u.x, y = u.y }
    end
    for _, u in ipairs(battle.arena.enemies) do
        battle.enemyUnits[#battle.enemyUnits + 1] =
            { char = Character.instantiate(u.id), x = u.x, y = u.y }
    end

    battle.combat = Combat.new(battle.arena, battle.partyUnits, battle.enemyUnits)
    battle.map = BattleMap.new(battle.arena, { combat = battle.combat, rightMargin = PANEL_W })
    battle.panel = CombatPanel.new(battle.combat, {
        onActivateItem = function(item) armItem(item) end,
        onHoverItem = function(item) battle.hoverItem = item end,
        onHoverUnit = function(unit) battle.hoverUnit = unit end,
    })

    beginTurn()
    refreshView()
end

function battle.update(dt)
    battle.map:update(dt)
    if not battle.over and battle.current and battle.current.side == "enemy" then
        battle.aiTimer = (battle.aiTimer or 0) - dt
        if battle.aiTimer <= 0 then executeEnemyAction() end
    end
    refreshView()
end

function battle.draw()
    love.graphics.setColor(0.04, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    battle.map:draw()
    battle.panel:draw()
    battle.drawHud()
end

function battle.drawHud()
    local leftW = Scale.WIDTH - PANEL_W -- centre HUD text over the battlefield, not the panel

    -- Forfeit button.
    love.graphics.setColor(0.28, 0.18, 0.20)
    love.graphics.rectangle("fill", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.7, 0.4, 0.4)
    love.graphics.rectangle("line", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.9, 0.9)
    love.graphics.setFont(hudFont)
    love.graphics.printf("Forfeit", forfeitButton.x, forfeitButton.y + forfeitButton.h / 2 - 8,
        forfeitButton.w, "center")

    -- Encounter name + objective, centred over the battlefield region.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(battle.encounter.name or "Battle", 0, 20, leftW, "center")

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf(objectiveText(battle.arena.objective), 0, 52, leftW, "center")

    -- Contextual control hint.
    local hint
    if battle.current and battle.current.side == "party" and not battle.over then
        if battle.mode == "armed" then
            local verb = battle.armedSupport and "Click an ally to support" or "Click a target to strike"
            hint = verb .. "  ·  click the item / Esc to cancel"
        else
            hint = "Click a blue tile to move  ·  click an item to attack"
        end
    else
        hint = "Enemy acting..."
    end
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, 0, Scale.HEIGHT - 28, leftW, "center")
    love.graphics.setColor(1, 1, 1)
end

function battle.keypressed(key)
    if key == "f5" then
        Arena.save(battle.arena, (battle.arena.biome or "arena") .. "_" .. os.time())
        return
    end
    if key == "f6" then -- debug: toggle initiative (timeline) numbers on the turn order
        battle.showInitiative = not battle.showInitiative
        return
    end
    if battle.over then return end
    if key == "return" or key == "kpenter" or key == "space" then
        confirm()
    elseif key == "escape" then
        if battle.mode == "armed" then cancelArm() else lose() end
    elseif key:match("^[1-9]$") then
        armSlot(tonumber(key))
    else
        battle.map:keypressed(key)
    end
end

function battle.gamepadpressed(joystick, button)
    if battle.over then return end
    if button == "a" or button == "start" then
        confirm()
    elseif button == "b" then
        if battle.mode == "armed" then cancelArm() else lose() end
    elseif button == "back" then
        lose()
    elseif button == "y" then
        cycleAbilityItem()
    else
        battle.map:gamepadpressed(joystick, button)
    end
end

function battle.mousemoved(x, y, dx, dy)
    if battle.panel:mousemoved(x, y) then return end
    battle.map:mousemoved(x, y)
end

function battle.mousepressed(x, y, button)
    if button == 1 and forfeitContains(x, y) then
        lose()
        return
    end
    if battle.panel:mousepressed(x, y, button) then return end
    if battle.map:mousepressed(x, y, button) then confirm() end
end

return battle
