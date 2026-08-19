-- Hub city state: the town screen reached from the main menu. Buildings are clickable hotspots over a
-- background image; clicking one opens a modal pop-up panel, or switches to a whole screen for the two
-- doors that are places rather than counters (the Gate, the Markets).
--
-- A PLAZA WITH THE GATE IN THE MIDDLE (models/building.lua's GRID). The stair is the reason the city
-- exists and everything else here is something you do before going down or because you came back up, so
-- it is drawn larger and the other seven cards ring it.
--
-- THE CITY GROWS AS THE COMPANY WORKS, and that is no longer prestige. The shelves moved onto the market
-- board and each opens on the first errand its house posts on a descent floor (models/errand.lua); this
-- board's own cards open on the deeds that give them something to do -- the Inn on the first wound, the
-- Markets on the first house, the Cafe on the second floor, the Forge on the fourth. See the gate table
-- in models/building.lua for the whole list and why there is one.
--
-- SO A FRESH SAVE ARRIVES AT THREE DOORS, and the first visit is coached through two of them: hire
-- somebody, then go down (INTRO_STAGES below).

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
local Identify = require("models.identify")
local Voucher = require("models.voucher") -- the vouchers the floors hand up, and the pull that spends one
local Wound = require("models.wound")     -- what a body carries up; the Inn's dot and the Inn's whole offer
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
local mapOpts       -- ...and the options it was built with, so the debug mint can rebuild it
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

-- THE FIRST-VISIT TUTORIAL, WHICH IS TWO DOORS AND IN THIS ORDER.
--
-- `player.hubIntro` runs "arrival" -> "hire" -> "coach" -> nil, and each stage coaches exactly one card
-- and refuses every other. The order is the loop stated as two clicks:
--
--   hire    the Hiring Hall. The player is NOT on the board -- every body that walks down the stair is
--           somebody hired here or found on a floor -- so a company of two going down a stair that has
--           already swallowed four companies is the first thing to fix, and the sponsor has already paid
--           for the fix (models/voucher.lua's Voucher.stake plants the voucher before the city opens).
--           Spent by the hire actually joining rather than by the panel being opened: a lesson satisfied
--           by looking at a room teaches looking at rooms.
--   coach   the Gate, where the sponsor has just sent them (conversation_prologue_sponsor).
--
-- THE HALL GOES FIRST because the Gate is one-way. A player coached straight down the stair takes the
-- prologue's two bodies onto floor one, and the room that would have fixed that is a card they were told
-- not to press. Teaching the hire first also teaches what the hall IS, which is the one building in the
-- city whose stock a player has to understand to use it: it fills from the floors, not from a shelf.
--
-- The Gate stage was the Quest Board, which is retired (models/building.lua's RETIRED). Coaching a door
-- the city no longer has would have left the arrival pointing at nothing and the coach bubble anchored
-- to a rect that does not exist.
local INTRO_STAGES = {
    hire  = {
        building = "hiring_hall",
        -- WHO THE SPONSOR'S VOUCHER CALLS, named here rather than in the model because which body opens
        -- the game is a content decision and models/voucher.lua has no opinion about content. Saber is a
        -- free agent of the sand who fights for its own sake and belongs to no house, which makes her
        -- the one companion who can answer a hired room on day one without a story having to explain
        -- why (data/characters/character_saber.lua).
        --
        -- THE FIRST PULL IS RIGGED AND EVERY GAME IN THIS GENRE RIGS IT. What the player is being taught
        -- here is what a pull LOOKS like -- the light, the tell, the body landing whole -- and a lesson
        -- delivered by a roll would teach a different thing to every player and occasionally teach
        -- nothing at all. Voucher.stake plants both halves: the voucher in the purse and the name the
        -- next pull will deal whatever the bands say.
        hire = "character_saber",
        text = "the Hero's Rift. The sponsor has paid for one crossing already.",
    },
    coach = {
        building = "the_gate",
        text = "the Rift. The sponsor is waiting.",
    },
}

-- The stage the intro is on, or nil in free play -- which is every visit after the first, and every
-- visit at all on a loaded save.
local function introStage()
    return hub.player and INTRO_STAGES[hub.player.hubIntro] or nil
end

-- The hotspot rect of the building this stage coaches, read off the live map, or nil. The coach bubble
-- anchors to this (ui/coach_bubble.lua).
local function introBuildingRect(stage)
    for _, b in ipairs(map and map.buildings or {}) do
        if b.id == stage.building then
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
    local opened
    opened = PanelModule.new({
        title = building.name,
        prestige = hub.player and hub.player.prestige or 1,
        player = hub.player, -- forwarded so a launched quest knows the active party
        vendor = building.vendor, -- vendor id, for buildings that are shops
        -- The Armory (Loadout) shelf gets a weapon-type / discipline filter over the stash; other
        -- buildings' panels ignore the field.
        filters = (moduleName == "party") and armoryFilters(hub.player) or nil,
        -- THE HIRING HALL HANDS THE SCREEN OVER MID-VISIT. A pull opens a reveal
        -- (ui/panels/hire_reveal.lua) that owns the whole screen, and the hall goes back UNDER it
        -- rather than beside it -- so this state swaps `activePanel` for the reveal and swaps the hall
        -- back when the reveal closes. Two fields rather than one callback with a flag, because the
        -- second half runs after an animation the first half knows nothing about.
        --
        -- Written here rather than inside the hall for the reason introAdvance gives one screen down: a
        -- panel that reached up into whatever launched it would be a seam built for one room. What the
        -- hall does is hand over a panel object and say nothing about where it goes.
        onReveal = function(panel) activePanel = panel end,
        onRevealClosed = function() activePanel = opened end,
        -- WHERE THE CROSSING HAPPENS. The reveal tears open the descent's own card rather than
        -- floating in the middle of the screen, and only this state knows where that card is drawn --
        -- the panel is handed a getter rather than a rect, because the map is rebuilt on every hub
        -- entry and a rect captured at open would be a stale one after a resize.
        riftRect = function()
            for _, b in ipairs(map and map.buildings or {}) do
                if b.id == "the_gate" then return { x = b.x, y = b.y, w = b.w, h = b.h } end
            end
            return nil
        end,
        -- The tutorial's staked pull plays its beats in full. It is the only pull in the game that
        -- cannot be skipped, and it is the one teaching what a pull looks like (INTRO_STAGES.hire).
        hold = hub.player and hub.player.hubIntro == "hire",
        onClose = dismissPanel,
    })
    activePanel = opened
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

-- Activation seam handed to the building map. In free play it opens the clicked building's panel,
-- playing a vendor's one-time greeting first (see launchVendor). While the first-visit tutorial is
-- running it refuses every door but the one the current stage coaches (INTRO_STAGES).
local function openPanel(building)
    local stage = introStage()
    if stage then
        if building.id ~= stage.building then return end
        -- SPENT BY THE DEED, NOT BY THE DOOR -- and only the Gate's stage can be spent on the door,
        -- because opening the Gate IS leaving the city. The hall's stage is spent by the hire joining
        -- the company (see introAdvance), so a player who walks in, reads her card and walks out is
        -- coached back to the room rather than left in a city that thinks the lesson landed.
        if not stage.hire then hub.player.hubIntro = nil end
        -- No scene between the coach and the door any more. The flier was Rowan spotting the
        -- Colosseum's contract ON the Quest Board -- a beat about a board that is retired
        -- (models/building.lua's RETIRED), so playing it here would have her read a notice off a wall
        -- the city does not have. The sponsor said everything this moment needs to say, one screen ago.
        launchPanel(building)
        return
    end
    launchVendor(building)
end

-- Has the coached deed been done? Asked every frame while the intro is on a stage that names a hire.
-- Cheap -- a walk of at most four bodies -- and it is the only way this state can hear about it: the
-- join happens inside the hall's own panel, and a panel reporting back up into whatever launched it
-- would be a seam built for one lesson.
local function introAdvance()
    local stage = introStage()
    if not (stage and stage.hire) then return end
    for _, char in ipairs((hub.player and hub.player.roster) or {}) do
        if char.id == stage.hire then
            hub.player.hubIntro = "coach"
            Player.save()
            return
        end
    end
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
    mapOpts = {
        onActivate = openPanel,
        -- A door behind which something unlooked-at is waiting wears the red dot. The advancement
        -- panel names the house once, on the way home; the dot is what still says so three screens
        -- later, and it goes out as soon as the goods have been read (Player.seeNew).
        --
        --   a shop     wares a quest put on its shelf   (newStock, cleared in ui/panels/shop.lua)
        --   the Armory items that arrived in the stash  (newItems, cleared in ui/panels/party.lua)
        --   the Hall   a hiring voucher, unspent        (models/voucher.lua, cleared by spending it)
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
            -- SOMETHING IN THE SATCHEL NOBODY HAS READ (models/identify.lua). Asked BEFORE the vendor
            -- branch, and that order is the whole of this entry: the Touchstone declares a vendor id
            -- without keeping a shelf (data/vendors/touchstone.lua), so the branch below would take it,
            -- ask a shelf question about a house that stocks nothing, and answer false forever.
            --
            -- A STATE rather than a sighting, for the reason the voucher note below gives at length: an
            -- unread piece is not news, it is something you are still carrying, and a dot that cleared
            -- on the first look would stop reminding the player at the exact moment they decided to read
            -- it later. It goes out when the last husk is read or sold, not when it is seen.
            if b.panel == "touchstone" then return Identify.count(hub.player) > 0 end
            -- A TOKEN IN THE PURSE, asked BEFORE the vendor branch for the same reason the Touchstone
            -- is: the Hero's Rift declares a vendor id to keep a keeper (a portrait, a name, a
            -- greeting) without keeping a shelf, so the branch below would take it, ask a shelf
            -- question about a house that stocks nothing, and answer false forever.
            --
            -- A STATE rather than a sighting. The shelf dots below go out when the goods have been
            -- READ; this one cannot -- a token is not news, it is something you are still holding, and
            -- a dot that cleared on the first look would stop reminding the player at the exact moment
            -- they decided to spend it later. It goes out when the purse empties, which is the same
            -- line the errand branch draws (cleared by being TAKEN ON, not by being seen).
            if b.panel == "hiring" then return Voucher.count(hub.player) > 0 end
            -- A BODY THAT CAME UP BROKEN (models/wound.lua). Asked BEFORE the vendor branch for the
            -- third time on this board: the Inn declares a vendor id to keep a keeper without keeping a
            -- shelf (data/vendors/inn.lua), so the branch below would take it, ask a shelf question
            -- about a house that stocks nothing, and answer false forever.
            --
            -- THE PLAINEST STATE DOT OF THE THREE, and the one the city most owes the player. A wound
            -- is carried into every fight after it and nothing underground undoes one, so a company
            -- that walks out of the plaza with three of them broken has made the descent harder in a
            -- way no screen out here would otherwise mention. It goes out when the last bone is set --
            -- by a night here, or by the Cafe's mend list -- and never on a sighting: a wound looked at
            -- is still a wound, and a dot that cleared on the first glance would stop reminding the
            -- player at the exact moment they decided they could not afford it yet.
            if b.panel == "inn" then return #Wound.wounded(hub.player) > 0 end
            if b.vendor then
                local deepest = hub.player.descentRun and hub.player.descentRun.cleared or 0
                if Errand.offered(hub.player, b.vendor, deepest) then return true end
                return Vendor.hasMarkedStock(b.vendor, hub.player.newStock)
            end
            if b.panel == "party" then return Player.hasNewStash(hub.player) end
            return false
        end,
    }
    map = BuildingMap.new(Building.list(hub.player), mapOpts)
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
                -- HER TERMS, MADE GOOD BEFORE THE SCENE HAS CLOSED. "I pay for the people you hire" is
                -- the first clause of the deal the party just took, so the voucher she paid for is in
                -- the purse by the time they turn round and look at the city. Staked here rather than
                -- at the prologue's start because it is THIS scene that promises it, and a voucher
                -- waiting in a city the party has not reached yet is a promise kept early.
                Voucher.stake(hub.player, INTRO_STAGES.hire.hire)
                hub.player.hubIntro = "hire"
                Player.save()
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
    introAdvance()
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

    -- The first-visit coach: a bubble pinned to whichever card the current stage is about, while nothing
    -- is open over the city. Same widget the battle tutorial uses (ui/coach_bubble), so "click" stays
    -- device-honest -- a key cap for pad/keyboard, the plain verb for the mouse.
    local stage = introStage()
    if stage and not activePanel then
        local rect = introBuildingRect(stage)
        if rect then
            local key = Locale.selectKey() -- "Enter" / "A", or nil on the mouse
            local text = key and stage.text or ("Click " .. stage.text)
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

-- MINT AN UNIDENTIFIED PIECE, for development only. 1-8 put one in the satchel found at that many
-- circles down, so the Touchstone's reading can be driven at any depth band on demand.
--
-- IT LIVES ON THE CITY rather than inside the counter, which is the opposite of where the Hero's Rift
-- keeps its own mint row -- and the reason is the door. The Touchstone does not appear until the company
-- is carrying something nobody can name (models/identify.lua's Identify.everFound), so a mint button
-- inside it could only ever be pressed by somebody who no longer needed it. The first one has to come
-- from outside the room.
--
-- The honest way to see a +8 reading is to reach the bottom of the rift, and tuning an animation you can
-- only reach after an hour of play is tuning it blind. `Debug.enabled` is the build constant, not a
-- runtime flag: a shipping build has no key here and no line saying there is one.
local function debugMintUnidentified(n)
    if not require("models.debug").enabled then return end
    local ids = {}
    for id, def in pairs(Item.defs) do
        if Identify.canSeal(def) then ids[#ids + 1] = id end
    end
    if #ids == 0 then return end
    table.sort(ids) -- a stable pool, so the same key twice is not the same piece by accident of hashing
    local floor = math.min(15, math.max(1, n * 2))
    Identify.grant(hub.player, ids[love.math.random(#ids)], floor)
    Player.save()
    -- The card is not on the plaza until the satchel says it should be, and the locked flags are decided
    -- when the map is built -- so the map has to be rebuilt for the new door to appear.
    map = BuildingMap.new(Building.list(hub.player), mapOpts)
end

function hub.keypressed(key)
    if activePanel then
        activePanel:keypressed(key)
    elseif key:match("^[1-8]$") then
        debugMintUnidentified(tonumber(key))
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
