-- Hub city state: the town screen reached from the main menu. Buildings are clickable hotspots over a
-- background image; clicking one opens a modal pop-up panel, or switches to a whole screen for the two
-- doors that are places rather than counters (the Gate, the Markets).
--
-- A PLAZA WITH THE GATE IN THE MIDDLE (models/building.lua's GRID). The stair is the reason the city
-- exists and everything else here is something you do before going down or because you came back up, so
-- it is drawn larger and the other seven cards ring it.
--
-- The city grows as its doors are opened, and that is no longer prestige: the shelves moved onto the
-- market board and each opens on the first errand its house posts on a descent floor
-- (models/errand.lua). Nothing on THIS board waits on anything except the Dueling Grounds.

local State = require("states")
local Player = require("models.player")
local Building = require("models.building")
local Sprite = require("models.sprite")
local BuildingMap = require("ui.building_map")
local BurgerButton = require("ui.burger_button")
local CoachBubble = require("ui.coach_bubble")
local Conversation = require("models.conversation")
local Discipline = require("models.discipline")
local Errand = require("models.errand")   -- the small work a house asks for before it opens a rung
local Item = require("models.item")
local Vendor = require("models.vendor")
local VendorVisit = require("models.vendor_visit") -- what a shop says before it shows you the shelf
local Locale = require("models.locale")
local Scale = require("scale")
local ScreenFx = require("ui.screen_fx")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local Calendar = require("models.calendar") -- the days-remaining line under the title

local hub = {}

local titleFont = Theme.display(28)
-- The days-remaining line. Theme.body rather than Theme.display: it is a standalone numeral, and the
-- display face is Alegreya with OLD-STYLE figures, so its digits sit at x-height and "3" hangs below
-- the baseline (see ui/theme.lua).
local dayFont = Theme.body(16)

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

-- The building the first-visit tutorial points the newcomer at: the Gate, where the sponsor who cut in
-- front of the Adventurers' Guild has just sent them (conversation_prologue_sponsor).
--
-- It was the Quest Board, which is retired (models/building.lua's RETIRED). Coaching a door the city no
-- longer has would have left the arrival pointing at nothing and the coach bubble anchored to a rect
-- that does not exist.
local INTRO_BUILDING = "the_gate"

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
--
-- Every door in the city is a pop-up over the town, and there is no longer a seam for one that opens a
-- whole SCREEN instead. The Draft Yard was the only building that used it (`state = "draft"`), and Draft
-- is chosen at the title screen now (states/menu.lua) rather than from the city -- so the branch went
-- with the card. A future mode belongs on the title screen beside it, not on this map.
local function launchPanel(building)
    -- A DOOR ONTO A WHOLE SCREEN rather than a pop-up over the city. The Gate is one
    -- (data/buildings/the_gate.lua): the inn, the store, the hiring hall and the stair are a place you
    -- go to, not a modal the city sits behind.
    --
    -- `state` has been on the building blueprint and in Building.list for a while with nothing reading
    -- it; this is the reader. Player.active is set first because every screen the gate leads to takes
    -- the company off it.
    if building.state then
        local ok, StateModule = pcall(require, "states." .. building.state)
        if ok and StateModule then
            Player.active = hub.player
            return State.switch(StateModule, { player = hub.player, run = hub.player.descentRun })
        end
    end
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

-- Play a shop's pre-shelf scenes -- the greeting, any discipline announcement, the house's next ask --
-- and then open its panel. All of it lives in models/vendor_visit.lua now: the shelves moved onto their
-- own board (states/markets.lua) and two screens open shop doors, so the sequencing is one copy with two
-- callers rather than ninety duplicated lines that can disagree about what a house asked for.
--
-- A building with no vendor has nothing to say and opens straight away.
local function launchVendor(building)
    if not building.vendor then launchPanel(building); return end
    VendorVisit.play(hub.player, building.vendor, function() launchPanel(building) end)
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
        hub.player.hubIntro = nil -- the lesson is spent the moment the Gate is opened
        -- No scene between the coach and the door any more. The flier was Rowan spotting the
        -- Colosseum's contract ON the Quest Board -- a beat about a board that is retired
        -- (models/building.lua's RETIRED), so playing it here would have her read a notice off a wall
        -- the city does not have. The sponsor said everything this moment needs to say, one screen ago.
        launchPanel(building)
        return
    end
    launchVendor(building)
end

function hub.enter()
    require("models.sound").music("music.hub")
    -- The session's one player, carried across every hub visit. Rebuilding it here (as this
    -- once did, via Player.new) would discard gold, quest progress, and everything bought.
    hub.player = Player.active or Player.start()
    -- A run resumes into states.game, never here; reaching the hub means the quest is over, so drop any
    -- resumable-run autosave (states/game.lua). A backstop for exit paths that don't clear it themselves,
    -- and for a resume descriptor left unconsumed. Persist only when there was one, so an ordinary hub
    -- visit doesn't rewrite the save.
    if hub.player.activeRun or hub.player.resumeRun then
        hub.player.activeRun = nil
        hub.player.resumeRun = nil
        Player.save()
    end
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
        -- A door behind which something unlooked-at is waiting wears the red dot. The advancement
        -- panel names the house once, on the way home; the dot is what still says so three screens
        -- later, and it goes out as soon as the goods have been read (Player.seeNew).
        --
        --   a shop     wares a quest put on its shelf   (newStock, cleared in ui/panels/shop.lua)
        --   the Armory items that arrived in the stash  (newItems, cleared in ui/panels/party.lua)
        --
        -- The Armory is the non-vendor door onto the Party panel -- it holds the stash rather than a
        -- shelf, which is exactly the difference the two ledgers draw.
        --   a house    a request it is ready to make       (models/errand.lua, cleared by walking in)
        --
        -- THE THIRD ONE IS THE ONE THE CITY MOST NEEDS. A shelf climbs a rung at a time and each rung is
        -- bought by running an errand, but the house only ASKS when you open its door -- so a company
        -- that came up from floor eight and did not think to call on the Bastion would never learn it
        -- had work. The dot is what makes "somebody wants something" visible from the street, which is
        -- the one thing a city of seven counters cannot say any other way.
        --
        -- Cleared by being ASKED rather than by a flag of its own: `Errand.offered` stops answering the
        -- moment the errand is taken on (vendorScenes accepts it on the way to the shelf), so the dot
        -- goes out for the same reason the others do -- the thing it was pointing at has been seen.
        badge = function(b)
            if b.vendor then
                local deepest = hub.player.descentRun and hub.player.descentRun.cleared or 0
                if Errand.offered(hub.player, b.vendor, deepest) then return true end
                return Vendor.hasMarkedStock(b.vendor, hub.player.newStock)
            end
            if b.panel == "party" then return Player.hasNewStash(hub.player) end
            return false
        end,
    })
    burger = BurgerButton.new(BURGER_X, BURGER_Y)

    -- First arrival at the capital (New Game only; the prologue set this flag -- states/prologue.lua).
    -- TWO SCENES BACK TO BACK, and the second is the hinge of the whole game.
    --
    -- The guard's arrival plays over the city the player is now looking at, and it ends with the party
    -- deciding to register at the Adventurers' Guild -- which is where this used to hand off to the
    -- Quest Board and forty days of contracts. Somebody gets to them first: a sponsor with a hole under
    -- the north quarter and nobody willing to go into it (conversation_prologue_sponsor).
    --
    -- An INTERCEPTION rather than a rewrite of the guard's lines. The arrival scene is authored, tagged
    -- and translated; the honest way to change what game this is was to have the party's decision
    -- overtaken rather than edited. The board is still there in the fiction. They never reach it.
    --
    -- On its close the intro moves to its coaching stage, where the Gate is the only door that opens
    -- (see openPanel and hub.draw). A loaded save never carries this flag, so its hub opens straight to
    -- free play.
    if hub.player.hubIntro == "arrival" then
        Conversation.play("conversation_prologue_arrival", function()
            Conversation.play("conversation_prologue_sponsor", function()
                hub.player.hubIntro = "coach"
            end)
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
        -- Optional: a static card (the Choice-based Hiring Hall and Inn) has nothing to tick.
        if activePanel.update then activePanel:update(dt) end
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

    -- THE CLOCK, under the title. A cost the player cannot see is not a cost they can weigh, and the
    -- day is now the scarcest thing they have -- every expedition spends one whether it goes well or
    -- badly (models/calendar.lua), so it belongs on the screen where expeditions are chosen from.
    --
    -- Phrased as what is LEFT rather than as what has been used. "Day 12 of 40" is a progress bar and
    -- reads as accomplishment; "28 days remain" is a deadline and reads as pressure, which is the
    -- thing this number is for. The last week turns amber, and the final day says so in words.
    --
    -- PARKED WITH THE CAMPAIGN IT COUNTED. The forty days were the Quest Board's deadline: every
    -- expedition spent one, and the number was on this screen because expeditions were chosen from it.
    -- The board is retired (models/building.lua's RETIRED) and the one door out of the city goes down a
    -- stair that spends no days, so a countdown here would be pressure from a clock nothing reads.
    --
    -- Left in place rather than deleted, exactly like the board itself: models/calendar.lua is
    -- untouched, and bringing the campaign back is deleting this `if false` and the RETIRED entry.
    if false then
        local left = Calendar.remaining(hub.player)
        local text
        if Calendar.isOver(hub.player) then text = "He has come"
        elseif left <= 1 then text = "The last day"
        else text = left .. " days remain" end
        love.graphics.setFont(dayFont)
        Theme.set(left <= 7 and Theme.accentWeapon or Theme.muted)
        love.graphics.printf(text, 0, 62, screenW, "center")
    end

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
            local text = key and "the Gate. The sponsor is waiting."
                or "Click the Gate. The sponsor is waiting."
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
