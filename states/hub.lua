-- Hub city state: the town screen reached from the main menu. Buildings are
-- clickable hotspots over a background image; clicking one opens a modal pop-up
-- panel (Quest Board, or a placeholder for buildings not yet designed). The
-- city grows as the player's prestige unlocks more buildings (see
-- models/building.lua and data/buildings/).

local State = require("states")
local Player = require("models.player")
local Building = require("models.building")
local Sprite = require("models.sprite")
local BuildingMap = require("ui.building_map")
local BurgerButton = require("ui.burger_button")
local CoachBubble = require("ui.coach_bubble")
local Conversation = require("models.conversation")
local Discipline = require("models.discipline")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Locale = require("models.locale")
local Scale = require("scale")
local ScreenFx = require("ui.screen_fx")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local hub = {}

local titleFont = Theme.display(28)

local map           -- BuildingMap widget
local background    -- love Image, or a path string if the asset is missing
local activePanel   -- the open pop-up panel, or nil
local burger        -- BurgerButton widget: the mouse's way into the system menu

-- Close the open modal, ringing the "cancel" cue -- the shared way out of a building panel or the
-- system menu, so backing out sounds the same on mouse, keyboard and pad. Silent until the file
-- exists (models/sound.lua). The post-quest Advancement overlay does NOT use this: its dismissal is a
-- "continue" past a reward, not a cancel, and it rings its own cue as it opens.
local function dismissPanel()
    Sound.play("ui.cancel")
    activePanel = nil
end

-- Where the burger sits. Top-LEFT: the title is centered and the right-hand side of the city is where
-- the eye goes for buildings, so the left corner is the one piece of chrome nothing else wants.
local BURGER_X, BURGER_Y = 18, 18

-- The building the first-visit tutorial points the newcomer at: the Adventurers' Guild board, where
-- the guard's advice (data/conversations/prologue_arrival.lua) sends them for work.
local INTRO_BUILDING = "quest_board"

-- The hotspot rect of the building the intro coaches, read off the live map, or nil. The coach bubble
-- anchors to this (ui/coach_bubble.lua).
local function introBuildingRect()
    for _, b in ipairs(map and map.buildings or {}) do
        if b.id == INTRO_BUILDING then
            return { x = b.x, y = b.y, w = b.w, h = b.h }
        end
    end
    return nil
end

local function titleCase(s) return (s:gsub("^%l", string.upper)) end

-- The stash filters the Armory (Loadout) panel offers: one chip per item type, weapon type and
-- discipline PRESENT in the stash, so the strip only ever offers a cut that returns something rather
-- than a wall of the whole taxonomy (5 types, 13 weapon families, 37 disciplines) most of which the
-- player owns nothing of. `valueOf` tells the panel how to read an item's value for the group;
-- `format` prettifies the chip label without changing the stored value the filter matches on. Options
-- are read at open, so they reflect the stash the player is standing in front of.
local function armoryFilters(player)
    local stash = (player and player.stash) or {}
    local typeSet, archSet, discSet = {}, {}, {}
    for _, item in ipairs(stash) do
        if item.type then typeSet[item.type] = true end
        local a = Item.archetype(item)
        if a then archSet[a] = true end
        if item.discipline and Discipline.defs[item.discipline] then discSet[item.discipline] = true end
    end

    local types, archs, discs = {}, {}, {}
    for t in pairs(typeSet) do types[#types + 1] = t end
    for a in pairs(archSet) do archs[#archs + 1] = a end
    for d in pairs(discSet) do discs[#discs + 1] = d end
    table.sort(types)
    table.sort(archs)
    table.sort(discs, function(a, b)
        return (Discipline.displayName(a) or a) < (Discipline.displayName(b) or b)
    end)

    local groups = {}
    if #types > 0 then
        groups[#groups + 1] = {
            label = "Type", options = types, selected = {},
            valueOf = function(item) return item.type end,
            format = titleCase,
        }
    end
    if #archs > 0 then
        groups[#groups + 1] = {
            label = "Weapon", options = archs, selected = {},
            valueOf = function(item) return Item.archetype(item) end,
            format = titleCase,
        }
    end
    if #discs > 0 then
        groups[#groups + 1] = {
            label = "Discipline", options = discs, selected = {},
            valueOf = function(item) return item.discipline end,
            format = function(id) return Discipline.displayName(id) or id end,
        }
    end
    return (#groups > 0) and groups or nil
end

-- Open the pop-up panel for a building. Buildings name a module under
-- ui/panels/; anything without one falls back to the generic placeholder.
local function launchPanel(building)
    local moduleName = building.panel or "placeholder"
    local ok, PanelModule = pcall(require, "ui.panels." .. moduleName)
    if not ok then
        PanelModule = require("ui.panels.placeholder")
    end
    activePanel = PanelModule.new({
        title = building.name,
        prestige = hub.player and hub.player.prestige or 1,
        player = hub.player, -- forwarded so a launched quest knows the active party
        vendor = building.vendor, -- vendor id, for buildings that are shops
        -- The Armory (Loadout) shelf gets a weapon-type / discipline filter over the stash; other
        -- buildings' panels ignore the field.
        filters = (moduleName == "party") and armoryFilters(hub.player) or nil,
        onClose = dismissPanel,
    })
end

-- The scenes a shop plays BEFORE its shelf, in order: its one-time first-visit greeting, then one
-- "the shelf just grew" announcement for each newly unlocked discipline whose stock lands here. Each
-- is authored inline; each records its flag and saves so it never repeats. Returns a flat list of
-- { conversationId, before } steps, where `before` runs just ahead of the scene (used to set the
-- discipline name the {discipline} token reads). An empty list means open straight to the shelf.
local function vendorScenes(building)
    local steps = {}
    local vendorId = building.vendor
    if not vendorId then return steps end

    -- 1. First-visit greeting (data/conversations/vendor_<id>_intro.lua).
    local introId = "vendor_" .. vendorId .. "_intro"
    if not Player.hasVisitedVendor(hub.player, vendorId) and Conversation.defs[introId] then
        steps[#steps + 1] = { id = introId, before = function()
            Player.markVendorVisited(hub.player, vendorId)
        end }
    end

    -- 2. One announcement per newly unlocked discipline that stocks this shelf. The shop speaks; the
    -- {discipline} token names each one (set on the player for the scene's duration -- Locale.substitute).
    local vdef = Vendor.get(vendorId)
    local class = vdef and vdef.class
    local announceId = "discipline_unlocked_" .. vendorId
    if class and Conversation.defs[announceId] then
        for _, disciplineId in ipairs(Discipline.pendingAnnouncements(hub.player, class)) do
            local name = Discipline.defs[disciplineId] and Discipline.defs[disciplineId].name
            steps[#steps + 1] = { id = announceId, before = function()
                Player.markDisciplineAnnounced(hub.player, disciplineId)
                hub.player.announcingDiscipline = name
            end }
        end
    end

    return steps
end

-- Play a shop's pre-shelf scenes in sequence, then open the panel. Each step records its flag before
-- it plays and the batch saves once at the end, so a greeting or announcement never repeats across a
-- save/load. The chain is built by recursion over the step list -- Conversation.play is callback-based
-- and there is no other sequencer here.
local function launchVendor(building)
    local steps = vendorScenes(building)
    if #steps == 0 then launchPanel(building); return end

    local function playFrom(i)
        local step = steps[i]
        if not step then
            hub.player.announcingDiscipline = nil -- clear the token after the last scene
            Player.save()
            launchPanel(building)
            return
        end
        if step.before then step.before() end
        Conversation.play(step.id, function() playFrom(i + 1) end)
    end
    playFrom(1)
end

-- Activation seam handed to the building map. In free play it opens the clicked building's panel
-- (playing a vendor's one-time greeting first -- see launchVendor). During the first-visit coaching
-- (hubIntro == "coach") it does two things instead: it refuses every door but the coached one, and
-- when that one is opened it plays the flier scene (Rowan spotting the Colosseum's contract) BEFORE
-- the board appears -- then clears the flag, so the coaching runs once.
-- The system menu (settings / title screen / resume). Reached three ways -- the burger button, Esc,
-- and the gamepad's Start -- so no device has to know about the others.
--
-- It hands `hub` to the panel as the state to return to, which is what makes the settings screen come
-- back to the city instead of to the title screen.
local function openSystemMenu()
    if activePanel then return end -- one modal at a time; the open one owns the input
    local SystemMenu = require("ui.panels.system_menu")
    activePanel = SystemMenu.new({
        player = hub.player,
        returnTo = hub,
        onClose = dismissPanel,
    })
end

local function openPanel(building)
    if hub.player and hub.player.hubIntro == "coach" then
        if building.id ~= INTRO_BUILDING then return end
        hub.player.hubIntro = nil -- the lesson is spent the moment the board is opened
        Conversation.play("prologue_flier", function() launchPanel(building) end)
        return
    end
    launchVendor(building)
end

function hub.enter()
    require("models.sound").music("music.hub")
    -- The session's one player, carried across every hub visit. Rebuilding it here (as this
    -- once did, via Player.new) would discard gold, reputation, and everything bought.
    hub.player = Player.active or Player.start()
    -- Coming home rests the company: health and mana refill. Attrition lasts a quest, not forever.
    Player.restore(hub.player)
    activePanel = nil
    -- The town is the safe home a battle hands back to, so clear any screen effect the last fight left
    -- standing -- the defeat grey most of all -- rather than let it bleed into the city (ui/screen_fx).
    ScreenFx.reset()
    background = Sprite.load("assets/hub/city.png")
    -- The whole player, not just their prestige: some doors are opened by a quest rather than by
    -- getting richer (Building.list).
    map = BuildingMap.new(Building.list(hub.player), {
        onActivate = openPanel,
    })
    burger = BurgerButton.new(BURGER_X, BURGER_Y)

    -- First arrival at the capital (New Game only; the prologue set this flag -- states/prologue.lua).
    -- The guard scene plays over the city the player is now looking at, and on its close the intro
    -- moves to its coaching stage, where the Quest Board is the only door that opens (see openPanel and
    -- hub.draw). A loaded save never carries this flag, so its hub opens straight to free play.
    if hub.player.hubIntro == "arrival" then
        Conversation.play("prologue_arrival", function()
            hub.player.hubIntro = "coach"
        end)
        return -- nothing else opens over the arrival; there is no pending summary on a first visit
    end

    -- Just back from a won quest? Surface the reward + the company's level-ups, then clear the handoff
    -- so it shows once (states/game.lua stashed it on the player before switching here).
    if hub.player.pendingSummary then
        local Advancement = require("ui.panels.advancement")
        activePanel = Advancement.new({
            reward = hub.player.pendingSummary,
            onClose = function() activePanel = nil end,
        })
        hub.player.pendingSummary = nil
    end
end

function hub.update(dt)
    if activePanel then
        activePanel:update(dt)
    else
        map:update(dt)
    end
end

function hub.draw()
    local screenW = Scale.WIDTH
    local screenH = Scale.HEIGHT

    -- Background: draw the image scaled to the logical area if it loaded, else a
    -- solid fallback rect (bars are cleared to black, so no setBackgroundColor).
    if type(background) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(background, 0, 0,
            0, screenW / background:getWidth(), screenH / background:getHeight())
    else
        Theme.drawMount(screenW, screenH)
    end

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Hub", 0, 24, screenW, "center")

    map:draw()

    -- Drawn under any open panel (which dims the city), so the burger does not float over its own menu.
    if not activePanel then burger:draw() end

    -- The first-visit coach: a bubble pinned to the Quest Board while the intro is on its coaching
    -- stage and nothing is open over the city. Same widget the battle tutorial uses (ui/coach_bubble),
    -- so "click" stays device-honest -- a key cap for pad/keyboard, the plain verb for the mouse.
    if hub.player and hub.player.hubIntro == "coach" and not activePanel then
        local rect = introBuildingRect()
        if rect then
            local key = Locale.selectKey() -- "Enter" / "A", or nil on the mouse
            local text = key and "the Quest Board to find work."
                or "Click the Quest Board to find work."
            CoachBubble.draw(text, rect, { prefer = "below", key = key })
        end
    end

    if activePanel then
        activePanel:draw()
    end
end

function hub.mousemoved(x, y, dx, dy)
    if activePanel then
        activePanel:mousemoved(x, y)
    else
        burger:mousemoved(x, y)
        map:mousemoved(x, y)
    end
end

-- Hand over a clickable building (see ui/cursor.lua), arrow elsewhere. When a panel is open the
-- city behind it is inert, so defer to the panel's own cursorKind (every panel has one).
function hub:cursorKind(x, y)
    if activePanel then
        return activePanel.cursorKind and activePanel:cursorKind(x, y) or "arrow"
    end
    if burger:contains(x, y) then return "hand" end
    return map:mouseOverBuilding(x, y) and "hand" or "arrow"
end

function hub.mousepressed(x, y, button)
    if activePanel then
        activePanel:mousepressed(x, y, button)
    elseif burger:mousepressed(x, y, button) then
        openSystemMenu()
    else
        map:mousepressed(x, y, button)
    end
end

-- Only panels that scroll or drag define these; the city behind them has nothing to do with either.
function hub.mousereleased(x, y, button)
    if activePanel and activePanel.mousereleased then activePanel:mousereleased(x, y, button) end
end

function hub.wheelmoved(dx, dy)
    if activePanel and activePanel.wheelmoved then activePanel:wheelmoved(dx, dy) end
end

function hub.keypressed(key)
    if activePanel then
        activePanel:keypressed(key)
    elseif key == "escape" then
        -- Esc opens the menu rather than leaving the city outright, which is what it used to do: one
        -- keypress with no confirmation dropped the player back at the title screen, and the key every
        -- other screen in the game uses to back OUT of something here backed out of everything.
        openSystemMenu()
    else
        map:keypressed(key)
    end
end

function hub.gamepadpressed(joystick, button)
    if activePanel then
        activePanel:gamepadpressed(joystick, button)
    elseif button == "start" then
        openSystemMenu()
    else
        map:gamepadpressed(joystick, button)
    end
end

return hub
