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

-- Debug: the pool the mock battle rolls loadouts from -- every shoppable item, i.e. everything a
-- player could actually end up holding. Excluded: natural weapons (a beast's fangs are its body, not
-- gear) and bound signature relics (they belong to one bearer and Character.reconcileBound would put
-- them back anyway). Built once, sorted by id so a given roll is reproducible from a seed.
local function randomizablePool()
    local Item = require("models.item")
    local pool = {}
    for id, def in pairs(Item.defs) do
        if not Item.isBound(def) and Item.archetype(def) ~= "natural" then
            pool[#pool + 1] = id
        end
    end
    table.sort(pool)
    return pool
end

-- Debug: replace `char`'s authored loadout with random gear, leaving bound cells (a signature relic)
-- as the blueprint placed them. Every free cell gets an item -- a full grid is the point, since it is
-- adjacency that makes items interesting -- and the first free cell is forced to a weapon so the unit
-- always has a real strike to open with. `taken` is shared across the party and each id is drawn at
-- most once into it, so no item repeats within a grid or between units. Consumables roll a random
-- stack depth. A repair pass then makes every `requiresAdjacent` ability in the grid actually
-- castable (see below) -- a roll of dead abilities exercises nothing.
local function randomizeLoadout(char, pool, taken)
    local Character = require("models.character")
    local Item = require("models.item")
    local Combat = require("models.combat")

    local weapons = {}
    for _, id in ipairs(pool) do
        if Item.defs[id].type == "weapon" then weapons[#weapons + 1] = id end
    end

    for cell = 1, Character.MAX_INVENTORY do
        local held = char.inventory[cell]
        if held then taken[held.id] = true end
    end

    -- Draw without replacement: `ids` is a candidate list, already-taken entries are skipped.
    local function draw(ids)
        local available = {}
        for _, id in ipairs(ids) do
            if not taken[id] then available[#available + 1] = id end
        end
        if #available == 0 then return nil end
        local id = available[love.math.random(#available)]
        taken[id] = true
        local def = Item.defs[id]
        local qty = Item.isStackable(def) and love.math.random(1, Item.maxStack(def)) or 1
        return Item.instantiate(id, qty)
    end

    char.defaultActionSlot = nil
    for cell = 1, Character.MAX_INVENTORY do
        if not Item.isBound(char.inventory[cell]) then
            local weaponCell = char.defaultActionSlot == nil
            char.inventory[cell] = draw(weaponCell and weapons or pool)
            if weaponCell and char.inventory[cell] then char.defaultActionSlot = cell end
        end
    end

    -- An ability that names a neighbor (Power Shot's "adjacent ranged") is blocked outright where the
    -- fill happened not to drop one beside it, so the roll would keep handing units abilities they
    -- can't cast. Each offender is repaired in place: first by SWAPPING a matching item already in
    -- the grid next to it -- which keeps the roll's spread and the ability itself -- and only if no
    -- swap helps, by redrawing that cell as something satisfied where it sits. Bound cells never move.
    local function unmetCount()
        local n = 0
        for cell = 1, Character.MAX_INVENTORY do
            local it = char.inventory[cell]
            if it and not Combat.adjacencyMetAt(char, it, cell) then n = n + 1 end
        end
        return n
    end

    local function movable(cell)
        return char.inventory[cell] ~= nil and not Item.isBound(char.inventory[cell])
    end

    -- Swap a `req`-matching item into one of `cell`'s neighbors. Accepted only when the grid ends with
    -- fewer unmet requirements than it started with, so a swap that merely moves the block onto the
    -- donor's own ability is reverted rather than traded for.
    local function swapNeighborIn(cell, req)
        local before = unmetCount()
        for _, nb in ipairs(Character.adjacentIndices(cell)) do
            for donor = 1, Character.MAX_INVENTORY do
                if donor ~= cell and donor ~= nb and movable(nb) and movable(donor)
                    and Combat.matchesAdjacency(char.inventory[donor], req) then
                    char.inventory[nb], char.inventory[donor] = char.inventory[donor], char.inventory[nb]
                    if unmetCount() < before then return true end
                    char.inventory[nb], char.inventory[donor] = char.inventory[donor], char.inventory[nb]
                end
            end
        end
        return false
    end

    -- Candidates for `cell` that need nothing this grid can't already give them. A weapon cell stays
    -- a weapon, so repairing one can't leave the unit without a strike to open with.
    local function satisfiedHere(cell, weaponsOnly)
        local ids = {}
        for _, id in ipairs(weaponsOnly and weapons or pool) do
            local def = Item.defs[id]
            if Combat.adjacencyMetAt(char, def, cell) then ids[#ids + 1] = id end
        end
        return ids
    end

    local pinned = char.defaultActionSlot and char.inventory[char.defaultActionSlot]
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory[cell]
        local ab = item and item.activeAbility
        local req = ab and ab.requiresAdjacent
        if req and movable(cell) and not Combat.adjacencyMetAt(char, item, cell) then
            if not swapNeighborIn(cell, req) then
                taken[item.id] = nil -- back into the pool: this grid has no room for it
                char.inventory[cell] = draw(satisfiedHere(cell, item.type == "weapon"))
            end
        end
    end

    -- The pin follows the item the fill chose, wherever a swap moved it. If the repair drew it away
    -- entirely, drop the pin: Combat.defaultAction falls back to the first grid weapon on its own.
    char.defaultActionSlot = pinned and Character.slotIndex(char, pinned) or nil
end

-- Debug: drop straight into a battle with a stock party and a small enemy roster (mirrors the
-- objective-battle opts states/game.lua builds), so combat can be exercised without a full run.
-- Loadouts are rolled fresh each time (see randomizeLoadout) so repeated runs exercise a spread of
-- items rather than the same four authored grids. One `taken` set spans the party, so the four grids
-- between them show 36 distinct items.
local function startMockBattle()
    local Character = require("models.character")
    local pool = randomizablePool()
    local taken = {}
    local party = {}
    for _, id in ipairs({ "character_knight", "character_mage", "character_archer", "character_priest" }) do
        local char = Character.instantiate(id)
        randomizeLoadout(char, pool, taken)
        party[#party + 1] = char
    end
    State.switch(require("states.battle"), {
        encounter = { kind = "objective" },
        biome = "castle",
        prestige = 3,
        party = party,
        quest = { map = { biome = "castle", objective = {
            name = "Mock Battle",
            composition = function() return { "character_bandit", "character_bandit", "character_champion" } end,
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
            -- Character creation (pick the avatar's body, then name it) opens a New Game; it hands off to the
            -- prologue -- for now, straight to the hub. See states/character_creation.lua.
            State.switch(require("states.character_creation"))
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
