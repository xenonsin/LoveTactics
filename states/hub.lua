-- Hub city state: the town screen reached from the main menu. Buildings are clickable hotspots over a
-- background image; clicking one opens a modal pop-up panel, or switches to a whole screen for the two
-- doors that are places rather than counters (the Gate, the Houses).
--
-- A PLAZA WITH THE GATE IN THE MIDDLE (models/building.lua's GRID). The stair is the reason the city
-- exists and everything else here is something you do before going down or because you came back up, so
-- it is drawn larger and the other seven cards ring it.
--
-- THE CITY GROWS AS THE COMPANY WORKS, and that is no longer prestige. The seven class shelves stand on
-- a board of their own and each opens at level 1 of its own class (models/building.lua); this board's
-- own cards open on the deeds that give them something to do -- the Houses on the first shelf to open,
-- the Cafe on the second floor, the Forge on the fourth, the Touchstone on the first thing nobody can
-- read. See the gate table in models/building.lua for the whole list and why there is one.
--
-- (An INN stood on this plaza too, opened by the first body carried up broken, and setting a bone was
-- the only thing it did. It was deleted with the toll it charged, and reaching this screen set every
-- bone for free instead. BOTH of those are now gone: the WARD stands where the Inn did, opened by the
-- same mark, and mending is a door you walk into rather than a doorstep you cross -- free if you rest
-- it off, paid if you want it today. See models/injury.lua's ward block for why that is not the Inn.)
--
-- THE PLAZA SAYS ONE THING, ONCE, AND REFUSES NOTHING (2026-09-23). This board carried a whole coach
-- for a pass -- a bubble on the first morning's door, another on every room the city grew afterwards,
-- and every other card turned down until the coached one had been walked into -- and the refusal is
-- what was wrong with it: pointing at one plate and shutting the other eight teaches the player that
-- the city is a corridor, on the one screen whose whole job is to be a place you choose in. So the
-- corridor is gone and stays gone (openPanel is one unconditional call, and tests/hub_doors_spec.lua
-- pins it).
--
-- WHAT CAME BACK IS THE POINTER WITHOUT THE RAIL, and it is one card on one morning: the Cathedral,
-- while Rowan is still carrying what the Champion did to her (`ward_card`, drawn in hub.draw). The
-- whole cut was tried and this is the hole it left. The company walks out of Act 0 three bodies deep
-- with one of them hurt, into a city where the only thing that says an injury is a thing you go and
-- ANSWER is inside the room that answers it -- so a player who does not open that door never learns
-- there was a door, and the very next thing the city asks for is an expedition of four
-- (models/descent.lua's PARTY_MAX). Every other lesson the plaza used to give had somewhere else to
-- live: the stair is named in Rowan's own words one beat earlier (conversation_prologue_arrival), and
-- a grown room says what it is for once you are in it. This one had nowhere, and it is the only one
-- back.
--
-- IT IS A BUBBLE AND NOT A STAGE. No door is refused, no press is swallowed, and walking past it costs
-- nothing but the morning -- the player may open all nine cards in any order with it up. What spends it
-- is the DEED, not the door (introAdvance): `player.hubIntro` runs "arrival" -> "ward" -> nil, and the
-- "ward" stage is the ledger both this bubble and the mending room read (see coachingMend,
-- teachInjuries and ui/panels/ward.lua). A flag cleared by opening a card would mark the lesson landed
-- for somebody who walked in, looked around and walked out again.
--
-- AND IT IS THE ONE LINE THE CITY FETCHES. The rest of the bag stays fielded by nobody --
-- `rift_card`, `new_door` and the deleted board's line (see the hint bag's own header for which and
-- why). A second bubble out here is the corridor coming back one card at a time.
--
-- THE LEDGER STAYED GONE. `player.seenDoors` -- which doors had been announced -- existed only to stop
-- a GROWN door being coached twice, and nothing coaches a grown door any more; models/building.lua's
-- block is still deleted. An old save may carry the field; nothing reads it.

local State = require("states")
local Player = require("models.player")
local Building = require("models.building")
local Sprite = require("models.sprite")
local BuildingMap = require("ui.building_map")
local BurgerButton = require("ui.burger_button")
local CoachBubble = require("ui.coach_bubble")  -- the plaza's one bubble; see the header
local TutorialNote = require("ui.panels.tutorial_note") -- the window that says what an injury IS
local Conversation = require("models.conversation")
local Class = require("models.class")
local Item = require("models.item")
local Identify = require("models.identify")
local Injury = require("models.injury")     -- what a dive broke, and this door-step is where it stops being true
local VendorVisit = require("models.vendor_visit") -- what a shop says before it shows you the shelf
local Counter = require("models.counter")    -- a house: the greeting, the desk, and the rooms behind it
local Offer = require("models.offer")        -- which of those rooms are open, and which have news in them
local Locale = require("models.locale")
local Scale = require("scale")
local ScreenFx = require("ui.screen_fx")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local CountMeter = require("ui.count_meter") -- Iselle's tally; parked, kept wired -- see the draw
local Descent = require("models.descent")    -- ...and what it reads, plus the mark that reveals it

-- The WINDOWS' words, and the PLAZA's. The city asks the second bag for exactly one line -- the first
-- morning's `ward_card` (see the header) -- and the Ward panel fetches its own two row bubbles from it.
local NOTES = "conversation_tutorial_notes"
local CITY = "conversation_tutorial_city"

local hub = {}

local titleFont = Theme.display(28)

-- THE RIFT'S PLATE CARRIES ONE NUMBER, and which number it is has changed with the premise.
--
-- The slot is right for the same reason it always was: this figure belongs to one hole in the ground
-- rather than to the screen, so it rides the card that hole is drawn on -- dead centre of the plaza,
-- already the one card drawn larger, and exactly where the eye is when the player is deciding whether
-- to press it.
--
-- WHAT STANDS THERE NOW IS THE MAP, not the tally: how deep the place goes for this company
-- (Descent.mapped, drawn in hub.draw). The swap is the pivot in one line -- the number under the Rift
-- stopped being how badly the company is doing and became how much of the rift it has drawn. The tally
-- is parked (Descent.COUNT_PARKED, docs/the-count.md) and this widget is kept built and ticked so that
-- lifting the flag brings it back with its arrival beat intact, which is what separates a park from a
-- deletion. Held at file scope for that beat (ui/count_meter.lua).
local countMeter = CountMeter.new()

local map           -- BuildingMap widget
local mapOpts       -- ...and the options it was built with, so the debug mint can rebuild it
local openDoors = {} -- the plaza as that map was laid out: id -> true per unlocked card. See refreshCity
local background    -- love Image, or a path string if the asset is missing
local activePanel   -- the open pop-up panel, or nil
local burger        -- BurgerButton widget: the mouse's way into the system menu

-- WHAT HAPPENED ON THE WAY HOME, said once, in the band under the title. Nil on an ordinary visit.
--
-- Today there is one sender: a rout (states/game.lua's onLoss stamps `player.pendingRout` and this
-- consumes it on the way in). It rides the PLAYER rather than a switch payload because this state takes
-- none -- every route into free play reaches it the same way, off Player.active -- which is the same
-- seam the post-quest report uses (`pendingSummary`).
--
-- A LINE, NOT A MODAL, and that is the register the message already had: it was drawn exactly this way
-- under the Gate's own title for as long as a beaten company woke there (states/gate.lua). A card that
-- has to be dismissed before the city can be touched would be charging a press for news that changes
-- nothing the player has to decide -- and the city already spends its arrival modal on the one report
-- that does (pendingSummary, below).
--
-- IT MUST FIT THE BAND, which is roughly 52px between the title and the plaza's top row
-- (Building.GRID.city.rows starts at 120): two lines of Theme.body(14) and no more. The senders keep
-- to that by writing short -- there is no growth here to cap, because nothing appends to this.
local notice

-- Close the open modal, ringing the "cancel" cue -- the shared way out of a building panel or the
-- system menu, so backing out sounds the same on mouse, keyboard and pad. Silent until the file
-- exists (models/sound.lua). The post-quest Advancement overlay does NOT use this: its dismissal is a
-- "continue" past a reward, not a cancel, and it rings its own cue as it opens.
-- Assigned below, once the door queue it feeds exists. Forward-declared because the way out of a panel
-- is written before it: see refreshCity.
local refreshCity

local function dismissPanel()
    Sound.play("ui.cancel")
    activePanel = nil
    -- STEPPING BACK ONTO THE SQUARE RE-READS THE SQUARE. A room can open a door from the inside now --
    -- declaring a class in the Roll puts the house that teaches it on the plaza (models/offer.lua's
    -- `declared` gate) -- and the Roll is a tab of the Armory, a panel drawn over this very city. The
    -- map's locked flags are decided when it is built, so without this the card the player just earned
    -- would not be there when they closed the panel they earned it in.
    refreshCity()
end

-- Where the burger sits. Top-LEFT: the title is centered and the right-hand side of the city is where
-- the eye goes for buildings, so the left corner is the one piece of chrome nothing else wants.
local BURGER_X, BURGER_Y = 18, 18

-- THE FIRST MORNING, WHICH IS ONE LEDGER READ IN TWO PLACES.
--
-- `player.hubIntro` runs "arrival" -> "ward" -> nil. The arrival is Rowan's scene, played over the city
-- the player is now looking at. The "ward" stage after it is the FACT the rest of the morning is built
-- on: the company walks out of Act 0 carrying Rowan's injury, and while that injury is unattended this
-- is still the first morning. Two surfaces ask it -- the bubble on the Cathedral's plate out here
-- (hub.draw), and the room behind that door, which uses it to teach itself (teachInjuries, and the row
-- bubble in ui/panels/ward.lua). One flag, so the plate and the room cannot disagree about which
-- morning it is.
--
-- IT IS SPENT BY THE DEED, NOT BY A DOOR, and that is the rule the bubble's return does not touch: a
-- flag cleared by opening a card would mark the lesson landed for somebody who walked in, looked around
-- and walked out again. The deed is "nobody is carrying an injury nobody has seen to" (mendingDone),
-- which either row of the Ward satisfies -- the bone set for gold, or the body laid up for nothing --
-- and resting has no purse test and no gate (models/injury.lua), so this can never strand a save.
--
-- WHAT WAS HERE AND IS STILL GONE. `INTRO_STAGES` was a table of coached cards with a door refusal
-- behind it, and three stages passed through it: `hire` (the Crossing's staked pull, retired with the
-- Crossing), the stair (retired because the arrival scene names the Rift one beat earlier, in Rowan's
-- own words) and the Cathedral. Only the third is back, and it is back as a bubble rather than as a
-- stage -- no table, no refusal, no queue of grown doors behind it. The other lines stay in the hint
-- bag, stamped and translated, fielded by nobody
-- (data/conversations/tutorial/conversation_tutorial_city.lua).

-- IS THE FIRST MORNING'S COACHING IN FORCE? True only while that stage is unspent, which is exactly
-- while somebody is still owed a mending.
--
-- READ TWICE, ON EITHER SIDE OF THE DOOR. Out here it puts the bubble on the Cathedral's plate; handed
-- to the room it rings a row, because the thing being pointed at in there is a ROW inside a modal and
-- only the modal knows where its rows landed. Neither surface owns the answer.
local function coachingMend()
    return hub.player ~= nil and hub.player.hubIntro == "ward"
end

-- THE CARD THE FIRST MORNING POINTS AT. Named here rather than at the two call sites so the plate and
-- the room behind it are one id -- and it is the house's, not the room's: the mending is a line on the
-- Cathedral's desk (data/buildings/cathedral.lua), so the plaza has no plate of its own to ring.
local MEND_DOOR = "cathedral"

-- Is there still an injury nobody has seen to? The Ward stage's deed, read off the one predicate the
-- panel reads too (models/injury.lua's Injury.unattended), so the city and the room cannot disagree
-- about whether the lesson has landed.
--
-- Either row of the Inn answers it -- the bone set for gold, or the body laid up for free -- even
-- though the bubble in there names only the paid one. Pinning the DEED to one of the two would turn a
-- recommendation into a rail, and would hand the free path a lock the room's whole legality rests on it
-- never having (models/injury.lua's ward block).
local function mendingDone()
    return #Injury.unattended(hub.player) == 0
end

-- BUILD THE BOARD, and remember what stood on it. `openDoors` is the plaza as the live map was laid
-- out -- id -> true for every card not locked -- and it is the only thing refreshCity can compare
-- against: BuildingMap keeps the cards it was handed, not the gates behind them.
local function buildMap()
    local list = Building.list(hub.player)
    openDoors = {}
    for _, b in ipairs(list) do
        if not b.locked then openDoors[b.id] = true end
    end
    map = BuildingMap.new(list, mapOpts)
end

-- HAS THE CITY GROWN SINCE THE BOARD WAS LAID OUT, and if so lay it out again.
--
-- Every other door in the city opens on a deed done somewhere else -- underground, or on the walk home
-- -- so a board built on entering the hub was built after everything that could change it. The Roll
-- broke that: it is a tab of a panel drawn over this city, and the class declared in it opens that
-- class's house (models/offer.lua's `declared` gate). A door earned inside a panel has to be able to
-- appear on the board behind it.
--
-- REBUILT ONLY WHEN SOMETHING ACTUALLY OPENED, because BuildingMap.new starts a fresh selection and a
-- board that re-seated the cursor every time a panel closed would be a control moving under the player's
-- hand for no reason.
refreshCity = function()
    if not (map and hub.player) then return end
    local grown = false
    for _, b in ipairs(Building.list(hub.player)) do
        if not b.locked and not openDoors[b.id] then grown = true; break end
    end
    if not grown then return end

    buildMap()
end

-- The hotspot rect of a card on the live board, or nil. Read off the map rather than off
-- Building.GRID, because the board is what the player is actually pressing and a card the gates left
-- off it has no rect at all -- which is the honest answer for a bubble that would otherwise hang over
-- a plate that is not there.
local function cardRect(id)
    for _, b in ipairs(map and map.buildings or {}) do
        if b.id == id then return { x = b.x, y = b.y, w = b.w, h = b.h } end
    end
    return nil
end

-- Every OTHER card on the board, for the bubble to keep off (ui/coach_bubble.lua's `avoid`). The plaza
-- is nine plates with narrow gutters, so a bubble placed by preference alone lands on a neighbour and
-- covers a name -- and on this screen the names are the whole content. Handing it the cards lets it
-- pick the side that hides the least.
local function otherCardRects(id)
    local rects = {}
    for _, b in ipairs(map and map.buildings or {}) do
        if b.id ~= id then rects[#rects + 1] = { x = b.x, y = b.y, w = b.w, h = b.h } end
    end
    return rects
end

-- PUT THE CURSOR ON THE COACHED CARD, ONCE, WHEN THE MORNING COMES INTO FORCE. The bubble wears a key
-- cap ("Enter", "A"), and that cap is a promise about what the key does -- but the board seats its own
-- selection wherever the layout put it, so without this the promised key opened some other house.
--
-- ONCE, AND THEN THE BOARD IS THE PLAYER'S. The old stage re-seated this on every arrow press and
-- every d-pad tick, which is how a pointer becomes a rail: the cursor could not be walked off the
-- coached plate at all. Here it is a starting position. Arrow away and the selection goes with you,
-- Enter opens what you walked to, and the bubble stays up saying what it said -- because what it is
-- pointing at has not stopped being true.
local function focusMendCard()
    if map and coachingMend() then map:selectById(MEND_DOOR) end
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
        -- Every class in the stash, roots included: the fold left one taxonomy (docs/class-fold.md),
        -- and a player filtering their kit wants "show me the knight things" every bit as much as
        -- "show me the ninja things". Before, only the earned half could be filtered on, because only
        -- the earned half had a field of its own.
        if item.class and Class.defs[item.class] then discSet[item.class] = true end
    end

    local types, archs, discs = {}, {}, {}
    for t in pairs(typeSet) do types[#types + 1] = t end
    for a in pairs(archSet) do archs[#archs + 1] = a end
    for d in pairs(discSet) do discs[#discs + 1] = d end
    table.sort(types)
    table.sort(archs)
    table.sort(discs, function(a, b)
        return (Class.displayName(a) or a) < (Class.displayName(b) or b)
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
            label = "Class", options = discs, selected = {},
            valueOf = function(item) return item.class end,
            format = function(id) return Class.displayName(id) or id end,
        }
    end
    return (#groups > 0) and groups or nil
end

-- BUILD A PANEL OVER THE CITY, whoever asked for it. Buildings and rooms name a module under
-- ui/panels/; anything without one falls back to the generic placeholder.
--
-- Two things open panels here and they used to be one: a plain door (the Armory), and a ROOM behind a
-- house's desk (models/counter.lua). A room is `{ panel, vendor }` -- and its vendor is not always its
-- house's, because a folded room kept its own counter (models/offer.lua): the Undercroft's desk opens
-- the town's shelf, the Lodge's opens the kitchen. So the vendor is a parameter rather than a field read
-- off the building, and everything else a panel might need is the same either way.
--
-- `onClose` is handed in for the same reason: a plain door's panel closes back to the city, and a room's
-- closes back to the desk it was chosen from.
local function newPanel(moduleName, vendorId, title, onClose)
    moduleName = moduleName or "placeholder"
    local ok, PanelModule = pcall(require, "ui.panels." .. moduleName)
    if not ok then
        PanelModule = require("ui.panels.placeholder")
    end
    local opened
    opened = PanelModule.new({
        title = title,
        prestige = hub.player and hub.player.prestige or 1,
        player = hub.player, -- forwarded so a launched quest knows the active party
        vendor = vendorId, -- the counter behind this room; nil for a panel that keeps none
        -- The Armory (Loadout) shelf gets a weapon-type / discipline filter over the stash; other
        -- buildings' panels ignore the field.
        filters = (moduleName == "party") and armoryFilters(hub.player) or nil,
        -- THE ARMORY IS WHERE THE BAG IS PACKED, and it is the natural home for it rather than a second
        -- job bolted onto a gear screen: the shelf is already here, the grids are already here, and
        -- deciding what a body carries and what the company carries are the same afternoon's work. The
        -- Gate gets the same switch, which makes it the LAST chance to change the bag rather than the
        -- only one (states/gate.lua).
        pool = (moduleName == "party") and "both" or nil,
        -- THE TACTICS TAB IS NOT THERE ON THE FIRST MORNING. It arrives when the first trip ends, by
        -- whichever exit comes first -- home to the city, or down onto floor two (Descent.tacticsUnlocked)
        -- -- because a rule list offered before the player has taken a turn is a shortcut past the thing
        -- being taught. The Auto button it drives waits one step longer still, for the window behind this
        -- tab to be read (Descent.autoUnlocked). The panel's own default is on, so this is the only place
        -- the city says otherwise.
        tactics = (moduleName ~= "party") or Descent.tacticsUnlocked(hub.player),
        -- The Ward's rows wear a coach bubble on the one morning somebody is standing in front of them
        -- not knowing an injury is a thing you go and answer. Every other panel ignores the field.
        coach = (moduleName == "ward") and coachingMend() or nil,
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
        -- THE ROLL SENDS A BODY TO ITS TRAINER (ui/class_editor.lua): the house that teaches the class
        -- being read, with its desk already open.
        --
        -- IT USED TO SWITCH STATES, because the seven shelves stood on a board of their own and walking
        -- to one meant leaving the city. They are cards on this plaza now, so the walk is a door on the
        -- screen the player is already looking at -- the panel shuts, and the house's counter opens over
        -- the same city. Nothing is switched and nothing has to come back.
        onVisitTrainer = function(houseId)
            activePanel = nil
            local target
            for _, b in ipairs(Building.list(hub.player)) do
                if b.id == houseId and not b.locked then target = b end
            end
            -- A shut house is not walked to. The button is drawn refused in that case
            -- (Building.houseForClass reports `open`), so this is a backstop rather than a path.
            if target then hub.openCounter(target) end
        end,
        onClose = onClose or dismissPanel,
    })

    -- A TAB'S WINDOW IS BEHIND THE TAB IT EXPLAINS, not in front of this door: the Loadout panel pips
    -- the unread tab and plays the lesson when it is pressed (ui/panels/party.lua's noteUnread /
    -- openNote, which Tactics and the Roll both go through), so the room opens on the screen the
    -- player pressed it for and the explanation arrives at the control being explained. Reading the
    -- Tactics one there is what puts the Armory's red dot below out, on the same ledger
    -- (Descent.tacticsTaught); the Roll's window lights no door, since nothing about the city grew.
    return opened
end

-- Open a plain door: one that is a whole screen, or one panel and nothing else. The Rift and the Armory
-- are the only two left -- every other room in the city is behind a desk (hub.openCounter).
local function launchPanel(building)
    -- A DOOR ONTO A WHOLE SCREEN rather than a pop-up over the city. The Rift is one
    -- (data/buildings/the_gate.lua): a stair and a look at the company is a place you go to, not a modal
    -- the city sits behind.
    --
    -- Player.active is set first because every screen the Rift leads to takes the company off it.
    if building.state then
        local ok, StateModule = pcall(require, "states." .. building.state)
        if ok and StateModule then
            Player.active = hub.player
            return State.switch(StateModule, { player = hub.player, run = hub.player.descentRun })
        end
    end
    activePanel = newPanel(building.panel, building.vendor, building.name, dismissPanel)
end

-- AN INJURY EXPLAINS ITSELF, ONCE, IN THE DOORWAY OF THE ROOM THAT ANSWERS IT.
--
-- The beat it lands on is the mending opening: the player has chosen that line off the Cathedral's
-- desk, the rows are one frame away, and what is missing is the rule -- that the band on the bar is
-- held back, that coming home does not lift it, and that there are two ways out priced against
-- different things.
--
-- IT RODE THE CATHEDRAL'S `intro` UNTIL THAT SCENE MOVED. Xin's scene is what the mending press hands
-- to now (data/buildings/cathedral.lua's introAfter) -- she sets the bone in it and asks to come off
-- the back of having done it -- so a window riding the end of it would be explaining the decision
-- after it had been taken. The lesson is taught where its answer lives, and the answer is the room.
--
-- A WINDOW, NOT A BUBBLE. "Rest is free and costs trips; gold costs gold and costs nothing else" is a
-- rule with a consequence, and a tail on a row cannot carry one (ui/panels/tutorial_note.lua draws that
-- line). The bubble's half of the job is next: it goes on one of the rows, inside the room, and says
-- only press (see coachingMend).
--
-- AND THE TWO DIVIDE THE WORK RATHER THAN REPEATING IT. This window teaches both ways out and ranks
-- neither, because the ranking is not a property of injuries -- it is a property of THIS morning, where
-- the company is three bodies deep and the stair wants four. So the window states the rule and the
-- bubble makes the call, which is also the only order in which the call can be argued for.
--
-- GATED ON THERE BEING AN INJURY rather than on the building, so it can never open onto nothing. Today
-- the Cathedral is the only house with an `intro` at all, so that gate and "is this the Inn's door" are
-- the same question -- but the honest one is the one about the lesson's subject, and it is the one that
-- stays true when the second house grows a scene.
--
-- NO LEDGER OF ITS OWN, and it still needs none. It is fired only while the first morning's stage is
-- unspent (coachingMend), and that stage is spent by the deed -- which the room now HOLDS the player
-- until they do (ui/panels/ward.lua's rail). So the window is reachable on exactly one opening of one
-- room, and a flag for "has it been read" would be a second thing that can disagree with the stage.
local function teachInjuries(go)
    if mendingDone() then return go() end
    activePanel = TutorialNote.new({
        title = Locale.line(NOTES, "injury_title"),
        body = Locale.line(NOTES, "injury_body"),
        onClose = function()
            activePanel = nil
            go()
        end,
    })
end

-- THE SEVEN COUNTERS. The house speaks, ends on a desk of rooms, and a room the player picks opens over
-- the city -- closing it comes back to the desk rather than to the plaza, so a player can set a bone,
-- read a find and browse the shelf without the door shutting between them (models/counter.lua).
--
-- A field on `hub` rather than a local, because onVisitTrainer above needs it and is written first.
function hub.openCounter(building)
    Counter.open(hub.player, building, function(room, onClosed)
        -- Closing a room rings the same cancel cue every panel in the city does (dismissPanel), but it
        -- does NOT go through dismissPanel: that is the way out to the plaza, and this is the way back
        -- to the desk. Same sound, different destination.
        local function show()
            activePanel = newPanel(room.panel, room.vendor, nil, function()
                Sound.play("ui.cancel")
                activePanel = nil
                onClosed()
            end)
        end
        -- ONE BEAT IN THE DOORWAY OF THE MENDING, on the one morning it is coached: the rule, before
        -- the rows it is about (see teachInjuries, which no-ops the moment nobody is owed one). Asked of
        -- the ROOM rather than of the house, because the lesson is about the injury and not about the
        -- Cathedral -- the day a second door sets a bone this still fires in the right place.
        if room.panel == "ward" and coachingMend() then return teachInjuries(show) end
        show()
    end, function()
        -- Walked out. The city is already underneath; nothing to switch back to.
        activePanel = nil
    end)
end

-- WALK THROUGH A DOOR, whichever kind it is.
--
-- A house is a COUNTER: the greeting, the desk, and a loop through the rooms behind it
-- (models/counter.lua, which also owns the one-time `intro` scene and the companion it grants -- that
-- block used to live here and moved with the rooms).
--
-- Everything else is a plain door. Two are left: the Rift, which is a whole screen, and the Armory,
-- which is one panel and keeps no shopkeeper.
local function launchVendor(building)
    if Counter.has(building) then return hub.openCounter(building) end
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

-- Activation seam handed to the building map: it opens the clicked building's panel, playing a
-- vendor's one-time greeting first (see launchVendor). EVERY card, every morning.
--
-- THE FIRST VISIT USED TO REFUSE ALL BUT THE CARD THE COACH POINTED AT, and that refusal is the half
-- of the old stage that did NOT come back with the bubble -- which is the whole of the 2026-09-23
-- restoration and the reason it is a restoration and not a revert (see the header). A guard in here --
-- on the coached morning, on a building id, on anything -- is the corridor returning, so this stays
-- one unconditional call; tests/hub_doors_spec.lua reads the body to keep it that way.
local function openPanel(building)
    launchVendor(building)
end

-- HAS THE MENDING BEEN SEEN TO? Asked every frame while the first morning's flag is still up, because
-- that is the only way this state can hear about it: the deed happens inside a panel, and a panel
-- reporting back up into whatever launched it would be a seam built for one lesson. Cheap -- a walk of
-- at most four bodies.
--
-- A save that somehow reaches the city with nobody hurt clears the flag on its first frame, which is
-- the backstop rather than an accident.
local function introAdvance()
    if not (hub.player and hub.player.hubIntro == "ward") then return end
    if not mendingDone() then return end
    hub.player.hubIntro = nil
    Player.save()
end

function hub.enter()
    require("models.sound").music("music.hub")
    -- The session's one player, carried across every hub visit. Rebuilding it here (as this
    -- once did, via Player.new) would discard gold, quest progress, and everything bought.
    -- The fallback takes a FREE SLOT rather than no slot at all. It should be unreachable -- every
    -- route into the city comes through the menu or the prologue, both of which start a player -- but
    -- an unstamped player writes to the legacy save.lua, which no slot list shows, so the failure mode
    -- of getting here without one used to be a campaign that saved into a file the player could never
    -- load again. A visible slot is the cheapest honest answer.
    hub.player = Player.active or Player.newSlot()
    -- REACHING THE CITY IS ITSELF A PIECE OF PROGRESS, and this is the only place it can be recorded:
    -- the town is the one screen every route into free play goes through -- the played prologue, the
    -- skip, and a save loaded from anywhere else. What it opens is the Armory's Roll tab, which is held
    -- back through Act 0 because nothing out there can answer it (Descent.classesUnlocked). Stamped
    -- before any panel is built, so the first visit's own Armory already has it.
    Descent.markCityReached(hub.player)
    -- ...and SEPARATELY, whether this arrival is a coming HOME: the same screen, asked of a company that
    -- has already been out (Player.expeditionsOut -- a floor descended or a bounty finished). That is
    -- the first half of the Tactics gate (Descent.tacticsUnlocked), and it can only be stamped here --
    -- the run is gone by the time the town is drawn, so nothing later can tell a first morning from a
    -- return. Persisted below with the rest of the visit's bookkeeping.
    if not Descent.returnedToCity(hub.player) and Player.expeditionsOut(hub.player) >= 1 then
        Descent.markReturnedToCity(hub.player)
        Player.save()
    end
    -- A run resumes into states.game, never here; reaching the hub means the quest is over, so drop any
    -- resumable-run autosave (states/game.lua). A backstop for exit paths that don't clear it themselves,
    -- and for a resume descriptor left unconsumed. Persist only when there was one, so an ordinary hub
    -- visit doesn't rewrite the save.
    if hub.player.activeRun or hub.player.resumeRun then
        hub.player.activeRun = nil
        hub.player.resumeRun = nil
        Player.save()
    end
    -- COMING HOME MAKES THE COMPANY WHOLE, and that is now both halves of it rather than one.
    --
    -- Health and mana refill (Player.restore) as they always have: attrition lasts a quest, not forever.
    -- THE TOWN NO LONGER SETS BONES ON THE DOORSTEP. It used to: Injury.clear stood here and an
    -- expedition's damage ended the moment the player was standing in the city, free and unasked. What
    -- replaced it is a room -- the Cathedral's mending (data/buildings/cathedral.lua) -- where it is
    -- still free (rest it off) and paying buys only speed. An injury that evaporates on arrival cannot be
    -- taught, cannot be decided about, and gave the door the tutorial now points at nothing to do.
    --
    -- The POOLS still refill here, and that half was never the injury's business: health and mana come
    -- back because attrition lasts a quest, and Player.restore fills against the injured ceiling rather
    -- than through it (models/injury.lua's healShare), so a body that is still hurt still reads as hurt.
    Player.restore(hub.player)
    activePanel = nil

    -- WHAT A ROUT ACTUALLY COST, said on the screen the company wakes up on -- which is this one now
    -- (states/game.lua's onLoss). One visit's worth: consumed here so it cannot greet the player a
    -- second time on the way back from the shops.
    --
    -- WHAT IT SAYS IS THAT LOSING TOOK NOTHING THEY OWNED, because that is the half no readout on any
    -- screen can say and the half a player most needs to hear straight after a wipe. The kit, the gold,
    -- the levels and the map are all still theirs (docs/the-count.md's law -- losing is never billed).
    --
    -- AND IT DOES NOT SAY WHERE THE PACK IS, on purpose. The trip's finds are lying on the floor they
    -- fell on (Descent.dropPack) and the Gate names them on EVERY visit, standing, in the warning
    -- colour (Descent.lostPacks, states/gate.lua's draw). A pack outlives the session that dropped it,
    -- so the one screen it is actionable from is the one that carries it permanently -- and repeating it
    -- here would put the load-bearing half of the sentence on the surface that forgets it.
    --
    -- SHORT ENOUGH FOR THE BAND, which is the constraint the declaration up top states. Sixty-seven
    -- characters at the widest floor number, drawn across 900px: one line, with the band's second one
    -- spare. Keeping the pack out of it is what buys that.
    --
    -- NO SAVE ON THE WAY PAST. The rout branch already wrote one (states/game.lua) and this field is
    -- not in the file at all, so persisting the clear would be rewriting the save to record nothing.
    notice = nil
    if hub.player.pendingRout then
        notice = "Routed on floor " .. hub.player.pendingRout ..
            ". The company came home with everything it owned."
        hub.player.pendingRout = nil
    end
    -- The town is the safe home a battle hands back to, so clear any screen effect the last fight left
    -- standing -- the defeat grey most of all -- rather than let it bleed into the city (ui/screen_fx).
    ScreenFx.reset()
    background = Sprite.load("assets/hub/city.png")
    -- The whole player, not just their prestige: some doors are opened by a quest rather than by
    -- getting richer (Building.list).
    mapOpts = {
        onActivate = openPanel,
        -- A DOOR WITH SOMETHING BEHIND IT WEARS THE RED DOT, and the question is asked of the rooms
        -- rather than of the card: a plate is the OR over what is waiting inside (models/offer.lua's
        -- Offer.anyNews), and the desk behind it marks the one line that news belongs to. Two readers,
        -- one call -- a mark raised on a looser question than the screen behind it clears on is a mark
        -- the player walks in, reads everything, walks out, and still cannot put out.
        --
        --   a shelf    wares a rung just opened, unlooked-at  (newStock, cleared in ui/panels/shop.lua)
        --   the Ward   somebody hurt and not yet seen to      (models/injury.lua, cleared by resting or paying)
        --   the rite   something the company owns is hexed    (models/curse.lua, cleared by the lift)
        --   the stone  a find nobody can read                 (models/identify.lua, cleared by reading it)
        --   the Armory items that arrived in the stash        (newItems, cleared in ui/panels/party.lua)
        --
        -- The first is a SIGHTING and clears on a look; the middle three are STATES the company is
        -- carrying and clear only when they are dealt with -- a dot that went out on the first glance
        -- would stop reminding the player at the exact moment they decided to deal with it next trip.
        badge = function(b)
            -- THE ARMORY carries two things: stash nobody has read, and a TAB nobody has met. The
            -- second is why this branch is an `or` -- Tactics unlocks on a trip ending, which may well
            -- have happened underground (floor two), so the door itself is the only thing that can say
            -- the room has grown a control since the player last stood in it. It clears when the window
            -- explaining it has been read (Descent.tacticsTaught), not on being seen: an unread feature
            -- is a thing you still have to look at. That same reading is what then puts Auto on the
            -- board (Descent.autoUnlocked), so this dot is the one errand standing between the unlock
            -- and the button.
            --
            -- It is the one door this function answers for ITSELF, because it is the one door with no
            -- counter behind it: a plain plate onto one panel, holding the stash rather than a shelf.
            if b.panel == "party" then
                return Player.hasNewStash(hub.player)
                    or (Descent.tacticsUnlocked(hub.player) and not Descent.tacticsTaught(hub.player))
            end
            -- EVERY OTHER PLATE IS THE OR OVER THE ROOMS BEHIND IT -- a body to mend, a hex to lift, a
            -- find nobody can read, a shelf with something on it nobody has looked at. Asked of
            -- models/offer.lua rather than answered here, because THE DESK ASKS THE SAME QUESTION: a
            -- counter marks the one line the news is behind (models/counter.lua's `news` context), and a
            -- door whose mark was derived separately from its own lines is how a plate ends up burning
            -- over a desk with nothing marked on it. This project has shipped that bug twice.
            return Offer.anyNews(hub.player, b)
        end,
    }
    buildMap()
    -- ...and, on the one morning the city has something to point at, the cursor starts on that plate.
    -- Here as well as at the arrival's close, because the first morning survives walking out of the
    -- city and back in: the player may leave the mending for a trip to the Gate and come home to it.
    focusMendCard()
    burger = BurgerButton.new(BURGER_X, BURGER_Y)

    -- The first visit to the hub (New Game only; the prologue set this flag -- states/prologue.lua).
    -- ONE SCENE: Rowan's, played over the city the player is now looking at.
    --
    -- IT IS NOT AN ARRIVAL. Act 0 is fought inside this same city (states/prologue.lua): the party
    -- does not travel here, so there is no gate to be processed through and no refugee column to join.
    -- `conversation_prologue_arrival` keeps the id and the slot, and what it now plays is the street
    -- after the breach is cleared -- Rowan closing the job, naming why it happened, and pointing at the
    -- Rift for the work and the coin.
    --
    -- IT USED TO BE TWO. A sponsor intercepted the party in the street straight afterwards, because the
    -- scene's lines sent them to the Adventurers' Guild and something had to overtake that decision
    -- before they reached the board. The scene names the Rift and points at it itself now, so there is
    -- nothing left to intercept.
    -- Iselle is at the top of the stair instead, and states/gate.lua plays her on the first visit there.
    --
    -- On its close the flag moves to "ward" -- the company walks out of Act 0 carrying an injury, and
    -- that is what the mending room reads to know it is teaching a first morning. It clears when the
    -- injury is seen to (introAdvance). A loaded save never carries this flag at all.
    if hub.player.hubIntro == "arrival" then
        Conversation.play("conversation_prologue_arrival", function()
            hub.player.hubIntro = "ward"
            -- The bubble goes up as this scene clears, so the cursor has to move with it: the flag was
            -- "arrival" when the board was seated a few lines above, and focusMendCard no-ops then.
            focusMendCard()
            Player.save()
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
    -- Ticked whatever is open: the tally's arrival is a beat the city plays on its own, and holding it
    -- behind a panel would mean a player who walked in and opened a shop came back to a mark already
    -- landed, which is the one thing the beat exists to stop.
    countMeter:update(dt)
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

    -- ...AND THE LAMPS GO OUT AS THE TALLY CLIMBS. Over the painted city and under everything else, so
    -- the place dims while the cards, the title and the tally itself stay legible on top of it. Three of
    -- the four bands do nothing mechanical (models/descent.lua's COUNT_BANDS); this is what they are
    -- for -- a player noticing the city is worse than it was without being told so.
    -- NO LONGER GATED ON A RUN BEING OPEN. It asked for `hub.player.descentRun` because the tally used
    -- to live on the run, so there was nothing to read without one -- which meant the city stopped
    -- dimming the moment an expedition ended, on exactly the morning the player is standing in it
    -- looking at what they left behind. The tally is the company's now (models/descent.lua's
    -- Descent.count) and the mark that gates it already answers the only question worth asking here.
    -- (PARKED WITH THE TALLY, Descent.COUNT_PARKED. The city dimmed as the count climbed; with nothing
    -- moving the number it would dim by exactly nothing forever, so the whole branch is skipped rather
    -- than left to compute a no-op every frame.)
    local dim = not Descent.COUNT_PARKED
        and Descent.everClimbedOut(hub.player) and CountMeter.cityDim(hub.player)
    if dim then
        Theme.set(Theme.mount, dim)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The City", 0, 24, screenW, "center")

    -- NO CLOCK UNDER THE TITLE, AND THAT IS THE SECOND TIME THIS LINE HAS COME OFF THE SCREEN.
    --
    -- It read "39 days remain", counting down to the fortieth expedition and the demon lord's landing.
    -- Both of those were the Quest Board's -- forty days were forty grounds bought off it -- and the
    -- board is retired. The deadline went with it (models/calendar.lua): the day is still a real unit,
    -- it still passes at the stair and over the Inn's counter, and it still mends bones. What it no
    -- longer is is a budget, so there is no balance to print.
    --
    -- WHAT THE PLAYER READS INSTEAD IS ON THE RIFT'S OWN PLATE, a few hundred pixels below this, and it
    -- is the better readout for the same reason it is the harder one to earn: the tally is a thing the
    -- company did rather than a thing the world is doing to them. Two countdowns on one screen, both
    -- claiming to be the end of the world, was the collision this deletion resolves.
    --
    -- ...WHICH IS WHY THE BAND IS FREE FOR THIS. A homecoming that had something happen on it says so
    -- here, for that visit only (see `notice`). It is a transient line where the clock was a permanent
    -- readout, so it is not the deleted thing coming back: nothing is counting down, and on the
    -- ordinary morning the band is as empty as the paragraph above leaves it.
    --
    -- IN THE AMBER, which is the accent the same sentence wore under the Gate's title when a beaten
    -- company still woke there -- the news family, not the warning one. What is actually costing the
    -- player something is the pack, and that is drawn at the Gate in accentWeapon where it can be
    -- acted on (states/gate.lua).
    if notice then
        love.graphics.setFont(Theme.body(14))
        Theme.set(Theme.accentAmber)
        love.graphics.printf(notice, screenW / 2 - 450, 72, 900, "center")
        love.graphics.setColor(1, 1, 1)
    end

    map:draw()

    -- ISELLE'S TALLY, over the Rift's plate. Drawn HERE rather than inside ui/building_map.lua so the
    -- widget stays generic: one building carrying a readout is not a reason for every card to learn
    -- about one. The rect comes off Building.GRID, which is the same source the card itself is
    -- positioned from, so the two cannot drift apart.
    --
    -- NOTHING BEFORE THE FIRST CLIMB-OUT. Not a threshold on the number -- the player's own act, which
    -- is the moment it becomes about something they did. Until then this card is exactly what it has
    -- always been (models/descent.lua's Descent.everClimbedOut, and the mark is one-way for the same
    -- reason the Inn's door is).
    -- THE PLATE SAYS HOW DEEP THE PLACE GOES FOR YOU, and it is the same slot the tally used to stand in
    -- (Descent.COUNT_PARKED took the meter off it). The swap is the premise in one line: the number
    -- under the Rift stopped being how badly the company is doing and became how much of the rift it
    -- has drawn -- the map book, on the door it was drawn behind (models/descent.lua's Descent.mapped).
    --
    -- SILENT UNTIL THERE IS A MAP. A company on its first trip has walked nothing, and "Mapped to floor
    -- 0" is a readout of an absence -- the first descent writes floor one and the line arrives with it.
    local mapped = Descent.mapped(hub.player)
    if mapped > 0 then
        local gate = Building.GRID.city.gate
        -- The meter's own phrase font and slot, so the plate reads at the size it always did
        -- (ui/count_meter.lua drew its band phrase at Theme.body(13) on this line).
        love.graphics.setFont(Theme.body(13))
        Theme.set(Theme.muted)
        love.graphics.printf("Mapped to floor " .. mapped .. " of " .. Descent.FLOORS,
            gate.x, 384, gate.w, "center")
        love.graphics.setColor(1, 1, 1)
    end

    -- Drawn under any open panel (which dims the city), so the burger does not float over its own menu.
    if not activePanel then burger:draw() end

    -- THE ONE THING THE PLAZA SAYS: where Rowan's injury gets answered, on the morning she is still
    -- carrying it (see the header, and coachingMend for what spends the morning). Same widget the Gate's
    -- descend row and the Ward's own rows wear (ui/coach_bubble.lua), so `{select}` stays device-honest
    -- -- a key cap for pad and keyboard, the plain verb for a pointer. The words are a hint bag entry
    -- rather than a string here, so the city's one instruction is stamped and translated like every
    -- other line the tutorial speaks, and resolving it at DRAW time is what lets the cap re-read the
    -- device in the player's hands mid-visit.
    --
    -- NOT OVER A PANEL, AND NOT OVER A SCENE. A conversation draws on top of the state rather than
    -- instead of it (main.lua's love.draw), so the city keeps rendering underneath -- without the
    -- second half of this guard the bubble sits behind Rowan's arrival, pointing at a door in the
    -- middle of the scene that is still explaining why there is a city.
    if coachingMend() and not activePanel and not Conversation.active then
        local rect = cardRect(MEND_DOOR)
        local text, key = Locale.coach(CITY, "ward_card")
        if rect and text then
            -- THE TITLE'S BAND IS NOT THE BUBBLE'S TO SIT IN, and it has to be said in `bounds` rather
            -- than in `avoid`: avoid is a score the placement search trades off, so a bubble that hides
            -- ten pixels of "The City" and nothing else still wins on points. Bounds is a floor -- a
            -- side that would land above the line is not a candidate at all -- and the search then
            -- takes the least-bad placement under the title instead.
            --
            -- It matters on exactly this card. The Cathedral sits in the plaza's top-middle slot, hard
            -- under the title, and a bubble pointing down at it from above is the placement the scorer
            -- likes best -- the plates to either side are ones it would rather not cover.
            local band = 24 + titleFont:getHeight() + 6
            CoachBubble.draw(text, rect, {
                prefer = "below",
                key = key,
                avoid = otherCardRects(MEND_DOOR),
                bounds = { x = 0, y = band, w = screenW, h = screenH - band },
            })
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
-- IT LIVES ON THE CITY rather than inside the counter, which is the opposite of where the Crossing
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
    buildMap()
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
