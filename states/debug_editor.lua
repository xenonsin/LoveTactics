-- Debug character editor: the Loadout panel, opened over the WHOLE GAME instead of over your party.
--
-- The rail lists every character blueprint in data/characters/; the stash holds every item in
-- data/items/, restocked as you spend it. So the three tabs the panel already provides become an
-- authoring tool without a new screen being written:
--
--   Loadout   arrange any character's 3x3 grid from the full item catalog
--   Tactics   write its AI rule list (ui/tactics_editor.lua)
--   Stats     edit its blueprint numbers and identity (ui/stat_editor.lua)
--
-- N mints a new character, S writes the focused one back to data/characters/<id>.lua
-- (tools/write_character.lua) -- which is what makes this an editor rather than a viewer.
--
-- The player it drives is SYNTHETIC and is never saved: `persist = false` on the panel, and
-- Player.active is not touched. Editing here can't cost anybody a real save.

local State = require("states")
local Party = require("ui.panels.party")
local NameEntry = require("ui.name_entry")
local Character = require("models.character")
local Item = require("models.item")
local Writer = require("tools.write_character")
local Scale = require("scale")

local editor = {}

local statusFont = love.graphics.newFont(16)

-- The synthetic player. Same shape Player.new builds (models/player.lua), because the panel and the
-- transfer helpers it calls read these fields directly -- but assembled from the registries rather
-- than from data/player.lua's starting roster.
local player

-- `panel` unless the name entry has taken over; see the widget-swap pattern in
-- states/character_creation.lua.
local panel, nameEntry
local pendingRename -- the character a rename will land on, nil when naming a NEW character

-- The stash filters the panel draws. `selected` is the panel's to toggle; the option lists are ours.
local filters

-- An empty selection is "no restriction", so an untouched strip shows the whole catalog.
local function accepts(i, value)
    local selected = filters[i].selected
    return next(selected) == nil or (value ~= nil and selected[value]) or false
end

-- Rebuild the catalog in place -- SAME table identity, because PoolGrid holds a reference to it
-- (Party.new feeds it player.stash directly) and swapping the table would leave the pool drawing a
-- list nobody updates any more.
--
-- Every matching item is restocked to a full stack every time, which is what makes the catalog feel
-- infinite: give a sword away and it is back before you look for it again. Sorted by id so the grid
-- does not reshuffle under the cursor between restocks.
local function restock()
    local ids = {}
    for id, def in pairs(Item.defs) do
        if accepts(1, def.type) and accepts(2, Item.classOf(def)) then ids[#ids + 1] = id end
    end
    table.sort(ids)

    local stash = player.stash
    for i = #stash, 1, -1 do stash[i] = nil end
    for i, id in ipairs(ids) do
        local def = Item.defs[id]
        stash[i] = Item.instantiate(id, Item.isStackable(def) and Item.maxStack(def) or 1)
    end
end

-- Restocking while an item is in hand would renumber the stash under a live pickup -- the drag would
-- land on whatever slid into that index. So the catalog only tops up between actions, which is
-- invisible in practice because there is no moment you are both holding something and looking for
-- more of it.
local function idle()
    return panel and panel.drag == nil and not panel.pool.picked
        and not panel.grid.picked and not panel.quantityPopup
end

local function setStatus(text, ok)
    editor.status, editor.statusOk, editor.statusTimer = text, ok, 6
end

-- Write the focused character out as a blueprint. This is the one action here that touches the
-- project source tree.
local function saveFocused()
    local char = panel:currentChar()
    if not char then return end
    local ok, info = Writer.write(char)
    setStatus(ok and ("Wrote " .. info) or ("Save failed: " .. tostring(info)), ok)
end

-- A blueprint id from a typed name: "Sand Wyrm" -> character_sand_wyrm. Anything that isn't a letter
-- or digit becomes an underscore, so the id is always a legal filename and a legal registry key.
local function idFor(name)
    return "character_" .. name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

-- The starting point for a new character: middling numbers, an empty grid, and the default fists.
-- Deliberately unremarkable -- it is a blank to edit, not a template to inherit from.
local function blankDef(name)
    return {
        name = name,
        sprite = "assets/chars/knight.png",
        stats = {
            health = 50, mana = 20, stamina = 50, staminaRegen = 2,
            damage = 10, magicDamage = 10, defense = 5, magicDefense = 5,
            movement = 4, speed = 5,
        },
        startingItems = {},
    }
end

local function closeNameEntry()
    nameEntry, pendingRename = nil, nil
end

-- Rename an EXISTING character (the Stats tab's Name field) -- id and file stay put, only the display
-- name moves.
local function askRename(char)
    pendingRename = char
    nameEntry = NameEntry.new({
        prompt = "Rename " .. (char.name or "character"),
        onSubmit = function(name)
            char.name = name
            closeNameEntry()
            setStatus("Renamed to " .. name .. ".", true)
        end,
    })
end

-- Mint a new character: register a blank blueprint under the typed id, then instantiate it through
-- the ordinary registry path. Going through Character.defs rather than hand-building a runtime table
-- is what keeps creation and tools/write_character.lua agreeing about the schema.
local function askNewCharacter()
    pendingRename = nil
    nameEntry = NameEntry.new({
        prompt = "Name the new character",
        onSubmit = function(name)
            local id = idFor(name)
            closeNameEntry()
            if id == "character_" then
                setStatus("That name has no letters or digits in it.", false)
                return
            end
            if Character.defs[id] then
                setStatus(id .. " already exists.", false)
                return
            end
            Character.defs[id] = blankDef(name)
            player.roster[#player.roster + 1] = Character.instantiate(id)
            panel:focusChar(#player.roster)
            setStatus("Created " .. id .. ". Press S to write it to data/characters/.", true)
        end,
    })
end

function editor.enter()
    player = { roster = {}, party = {}, stash = {}, gold = 0, prestige = 1, materials = {}, recipes = {} }

    -- Every character in the game, sorted by id. Not levelled (no Player.syncLevels): a level-1
    -- character carries no accumulated growth, so what the Stats tab shows is the blueprint's own
    -- numbers rather than the blueprint plus progression.
    local ids = {}
    for id in pairs(Character.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        player.roster[#player.roster + 1] = Character.instantiate(id)
    end

    local types = { "weapon", "armor", "consumable", "ability", "utility" }
    local classes = {}
    for c in pairs(Item.CLASSES) do classes[#classes + 1] = c end
    table.sort(classes)
    filters = {
        { label = "Type", options = types, selected = {} },
        { label = "Class", options = classes, selected = {} },
    }

    editor.status, editor.statusTimer = nil, 0

    panel = Party.new({
        player = player,
        title = "Character Editor",
        stats = true,
        persist = false, -- a synthetic player must never reach the save file
        filters = filters,
        onFilterChanged = restock,
        onEditName = askRename,
        onClose = function() State.switch(require("states.menu")) end,
    })

    restock()
    panel:refreshStash()
end

function editor.update(dt)
    if editor.statusTimer and editor.statusTimer > 0 then
        editor.statusTimer = editor.statusTimer - dt
    end
    if nameEntry then nameEntry:update(dt) return end
    panel:update(dt)
    if idle() then
        restock()
        panel:refreshStash()
    end
end

function editor.draw()
    -- The name entry paints the whole screen itself (field + on-screen keyboard), so it replaces the
    -- view rather than sitting over it -- same call as states/character_creation.lua.
    if nameEntry then nameEntry:draw() return end

    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    panel:draw()

    love.graphics.setFont(statusFont)
    if editor.status and editor.statusTimer > 0 then
        love.graphics.setColor(editor.statusOk and 0.55 or 0.95, editor.statusOk and 0.8 or 0.55,
            editor.statusOk and 0.6 or 0.5)
        love.graphics.printf(editor.status, 0, 12, Scale.WIDTH, "center")
    else
        love.graphics.setColor(0.45, 0.48, 0.58)
        love.graphics.printf("N: new character    S: write blueprint to data/characters/",
            0, 12, Scale.WIDTH, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function editor.keypressed(key)
    if nameEntry then
        if key == "escape" then closeNameEntry() return end
        nameEntry:keypressed(key)
        return
    end
    -- The editor's own two verbs, claimed before the panel sees the key. Neither is bound in the
    -- panel, and both are meaningless outside this state.
    if key == "n" then askNewCharacter() return end
    if key == "s" and panel.mode ~= "loadout" then
        -- On the Loadout tab "s" is grid navigation (see Party:keypressed); everywhere else it is
        -- free, and the Stats tab is where you would reach for it anyway.
        saveFocused()
        return
    end
    if key == "f5" then saveFocused() return end -- always available, whatever the tab
    panel:keypressed(key)
end

function editor.textinput(t)
    if nameEntry then nameEntry:textinput(t) end
end

function editor.mousemoved(x, y)
    if nameEntry then nameEntry:mousemoved(x, y) return end
    panel:mousemoved(x, y)
end

function editor.mousepressed(x, y, button)
    if nameEntry then nameEntry:mousepressed(x, y, button) return end
    panel:mousepressed(x, y, button)
end

function editor.mousereleased(x, y, button)
    if nameEntry then return end
    panel:mousereleased(x, y, button)
end

function editor.wheelmoved(dx, dy)
    if nameEntry then return end
    panel:wheelmoved(dx, dy)
end

function editor.gamepadpressed(joystick, button)
    if nameEntry then nameEntry:gamepadpressed(joystick, button) return end
    -- No pad glyph is free for "new character" without stealing one the panel already uses, so the
    -- pad gets the destructive-free half: X on the Stats tab writes the blueprint.
    if button == "start" then saveFocused() return end
    panel:gamepadpressed(joystick, button)
end

function editor:cursorKind(x, y)
    if nameEntry then return nameEntry:cursorKind(x, y) end
    return panel:cursorKind(x, y)
end

return editor
