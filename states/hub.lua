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
-- it off, paid if you want it today. See models/wound.lua's ward block for why that is not the Inn.)
--
-- SO A FRESH SAVE ARRIVES AT TWO DOORS -- the Armory and the stair -- and the first visit is coached
-- through one of them: go down (INTRO_STAGES below).
--
-- ...AND EVERY DOOR AFTER THOSE THREE IS COACHED THE SAME WAY, on the morning it appears -- the same
-- bubble on the card, wearing the blueprint's own sentence about what the room is for, and every other
-- card refused until it has been walked into. A card that quietly stops being locked is a feature
-- delivered by not being mentioned. See `coachNextDoor` and models/building.lua's seenDoors block.

local State = require("states")
local Player = require("models.player")
local Building = require("models.building")
local Sprite = require("models.sprite")
local BuildingMap = require("ui.building_map")
local BurgerButton = require("ui.burger_button")
local CoachBubble = require("ui.coach_bubble")
local TutorialNote = require("ui.panels.tutorial_note") -- ...and the window that says what a wound IS
local Conversation = require("models.conversation")
local Class = require("models.class")
local Vendor = require("models.vendor")  -- hasMarkedStock: the unread half of a shop's dot
local Market = require("models.market")  -- hasUnread: the one shop whose dot is not a shelf question
local Item = require("models.item")
local Curse = require("models.curse")        -- what the company is carrying that the rite would lift
local Identify = require("models.identify")
local Wound = require("models.wound")     -- what a dive broke, and this door-step is where it stops being true
local VendorVisit = require("models.vendor_visit") -- what a shop says before it shows you the shelf
local Counter = require("models.counter")    -- a house: the greeting, the desk, and the rooms behind it
local Offer = require("models.offer")        -- ...and which of those rooms are open yet
local Locale = require("models.locale")
local Scale = require("scale")
local ScreenFx = require("ui.screen_fx")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local CountMeter = require("ui.count_meter") -- Iselle's tally; parked, kept wired -- see the draw
local Descent = require("models.descent")    -- ...and what it reads, plus the mark that reveals it

-- The plaza's coaching words, as a hint bag rather than strings in this file
-- (data/conversations/tutorial/conversation_tutorial_city.lua; models/locale.lua's Locale.coach).
local CITY = "conversation_tutorial_city"
-- ...and the WINDOWS' words, which are a different bag because they are a different kind of teaching:
-- a bubble points at a control, a window explains a feature (ui/panels/tutorial_note.lua).
local NOTES = "conversation_tutorial_notes"

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
local function dismissPanel()
    Sound.play("ui.cancel")
    activePanel = nil
end

-- Where the burger sits. Top-LEFT: the title is centered and the right-hand side of the city is where
-- the eye goes for buildings, so the left corner is the one piece of chrome nothing else wants.
local BURGER_X, BURGER_Y = 18, 18

-- THE FIRST-VISIT TUTORIAL, WHICH IS ONE DOOR AND IT GOES DOWN.
--
-- `player.hubIntro` runs "arrival" -> "coach" -> nil. The arrival is the guard's scene played over the
-- city; the coach is a bubble on the Rift with every other card refused until it has been walked into.
--
--   coach   the Rift, where Rowan has just sent them (conversation_prologue_arrival). The stair
--           itself is coached on the far side of that door, by a bubble on the descend row
--           (states/gate.lua) -- this stage only gets them through it.
--
-- ONE DOOR, AND THE CITY IS ARRANGED TO AGREE WITH IT. A tutorial that coaches one card while eight
-- others stand open is a tutorial arguing with the board it is drawn on, so the plaza opens on TWO cards
-- -- the Armory and the stair -- and every other room arrives on the deed that gives it a job
-- (models/building.lua's gate block). The Market and the Houses were the last two to move: both were
-- standing open on the first morning, and both now wait for the first descent, so the one screen a new
-- player is looking at has the hole in the ground and nothing else worth pressing.
--
-- IT WAS THE BOUNTY BOARD FOR A PASS, and the round trip is the thing to read rather than either end of
-- it. The board took this stage when the campaign became posted work, then lost it when the campaign
-- became a distance run and the board's card was deleted outright.
--
-- THE CAMPAIGN IS NEITHER OF THOSE NOW. It is one rift the company MAPS and re-enters at the stair it
-- opened (models/descent.lua's Descent.keepFloor and Descent.entryFloor) -- so the stair keeps this
-- stage for a third reason, and a better one than "it is the only door": it is the door you will keep
-- coming back through.
--
-- AND THE BOARD IS PARKED AGAIN (2026-09-18), so the stair is the only door in fact and not just in
-- emphasis. It came back for a pass as side work on the houses' square and went for a reason the round
-- trip above never reached: its seven postings are the seven quests models/errand.lua already seats on
-- floors of the rift, and taking one up here handed over that house's companion without a floor being
-- walked. See docs/bounties.md.
--
-- AND IT PUTS A THREE-TIME-STALE SEAM BACK IN AGREEMENT. `conversation_prologue_arrival` is Rowan
-- sending the player to the RIFT, by name, in her own words, and it is the last thing said before this
-- bubble appears. For one pass the scene pointed at a stair and the bubble pointed at a board. They
-- point at the same door again, and the STALE banner on that scene is gone rather than re-aimed.
--
-- THERE WAS A `hire` STAGE BEFORE THIS ONE, and it coached the Crossing: the sponsor's staked voucher,
-- a rigged first pull that dealt Saber, and a lesson in what a pull looked like. The Crossing is retired
-- and there is no pull to teach, so the arrival hands straight to the Rift -- and the companion who
-- fills the expedition is met where she belongs, standing on floor one (models/descent.lua's
-- Descent.SCRIPTED_COMPANION, which is Gyeom; the company already holds three walking out of Act 0, and
-- Saber is dealt by the roll like the rest). The old stage is why
-- `stage.hire` is still read below: a stage that names a hire is spent by the body JOINING rather than
-- by the door being opened, and the rule is kept for whatever is coached that way next.
--
-- (The Gate stage was the Quest Board before that, which is cut outright. Coaching a door the city no
-- longer has would leave the arrival pointing at nothing and the bubble anchored to a rect that is not
-- there -- which is the failure both retirements had to be walked through.)
-- The words are a hint bag (data/conversations/tutorial/conversation_tutorial_city.lua) rather than a
-- string here, so the one instruction the first morning gives is stamped and translated like every
-- other line the tutorial speaks. A stage names the LINE; hub.draw resolves it at draw time, which is
-- also what lets its {select} re-read the device in the player's hands mid-visit.
local INTRO_STAGES = {
    -- THE MENDING FIRST, AND THE STAIR SECOND. The player arrives carrying Rowan's wound off the Champion
    -- (models/combat.lua's Combat.spendScriptedFell), so the first thing the city can usefully say is where
    -- that gets dealt with -- and the room is where Xin is, so the coached door hands over a companion
    -- as well as a lesson. Sending them down the hole first would coach the stair to a company that is
    -- short a body and does not yet know there was anything to do about it.
    --
    -- IT IS THE CATHEDRAL'S CARD NOW, and that is the fold rather than a change of mind: the Inn stood on
    -- the plaza as a door of its own, and it is a line on that house's desk (data/buildings/cathedral.lua).
    -- The house is standing open on this one morning for exactly that room and nothing else -- its shelf
    -- waits on a priest level nobody has -- so the card the coach points at still opens onto the mending
    -- and only the mending, which is what the bubble promises.
    --
    -- It is also the only order the wound ITSELF allows. That room exists because somebody is hurt
    -- (`wound`), and the wound now survives the walk into town -- so on this one morning the city has a
    -- door that is both new and urgent, which is exactly what the coach grammar is for.
    --
    -- AND IT IS SPENT BY THE DEED, NOT BY THE DOOR. `mend` says so, and it is the same field shape the
    -- retired hall stage used (`hire`, still read below) for the same reason: opening a door is not
    -- learning what is behind it. This stage held for one pass on the press alone, and what that
    -- bought was a player who walked into the Cathedral, met Xin, said "nothing today" at the desk and
    -- walked back out into a city that thought the lesson had landed -- carrying the wound, with the
    -- one room that answers it now just another card among nine.
    --
    -- The deed is "nobody is carrying a wound nobody has seen to" (mendingDone), which either row of
    -- the Inn satisfies: the bone set for gold, or the body laid up for nothing. It is always
    -- reachable -- resting has no purse test and no gate (models/wound.lua) -- so this can hold the
    -- stair without ever being a lock, which is the only condition under which a stage may be spent
    -- on a deed at all.
    --
    -- THE DEED IS WIDER THAN THE INSTRUCTION, ON PURPOSE. The bubble inside the room names ONE row --
    -- the paid one, because resting benches Rowan for the descent the city is about to ask four bodies
    -- for (ui/panels/ward.lua's header argues it) -- and this clears on either. That gap is the whole
    -- difference between a recommendation and a rail: a player who reads the window, disagrees, and
    -- rests has understood the room better than one who pressed the ringed row, and a stage that held
    -- the plaza against them would be punishing the only evidence that the lesson landed.
    ward = {
        building = "cathedral",
        line = "ward_card",
        mend = true,
    },
    coach = {
        building = "the_gate",
        line = "rift_card",
    },
}

-- The stage the intro is on, or nil in free play -- which is every visit after the first, and every
-- visit at all on a loaded save.
local function introStage()
    return hub.player and INTRO_STAGES[hub.player.hubIntro] or nil
end

-- Is there still a wound nobody has seen to? The Ward stage's deed, read off the one predicate the
-- panel reads too (models/wound.lua's Wound.unattended), so the city and the room cannot disagree
-- about whether the lesson has landed.
--
-- Either row of the Inn answers it -- the bone set for gold, or the body laid up for free -- even
-- though the bubble in there names only the paid one. Pinning the DEED to one of the two would turn a
-- recommendation into a rail, and would hand the free path a lock the room's whole legality rests on it
-- never having (models/wound.lua's ward block).
local function mendingDone()
    return #Wound.unattended(hub.player) == 0
end

-- THE DOORS THE CITY HAS GROWN SINCE THE PLAYER LAST STOOD IN IT, and the one currently being coached.
--
-- `doorQueue` is filled once per hub entry from models/building.lua (board order, so a morning that
-- opened two of them coaches them in the order they are read); `coachedDoor` is the stage synthesized
-- for the one in hand. Both are rebuilt on every enter, so nothing here survives a visit it did not
-- belong to.
--
-- A GROWN DOOR IS COACHED EXACTLY AS THE FIRST VISIT'S TWO ARE, and nothing more. There was a pop-up
-- here for an afternoon -- a card naming the room, saying what it was for, with one button that armed
-- the bubble -- and it was wrong for a reason worth keeping written down: the city already HAS a grammar
-- for "press this and here is why", and it is a bubble pinned to the card. A modal in front of it is a
-- second thing to dismiss before reaching the first, it covers the very plate it is talking about, and
-- it made a new door a bigger event than the stair the whole game is about. So the sentence the pop-up
-- carried moved into the bubble, where the Crossing's has always been.
local doorQueue = {}
local coachedDoor  -- an INTRO_STAGES-shaped stage for a new door, or nil

-- A grown door's whole bubble, in the shape INTRO_STAGES writes by hand: the card's name with its
-- article normalized ("The Forge" -> "the Forge", "Cafe" -> "the Cafe", so a name already carrying one
-- does not get two), then the blueprint's own sentence saying what the room is for.
--
-- It is the {door} token of the `new_door` line, which is what puts the press in front of it -- which
-- is why it opens lowercase and carries no verb of its own.
--
-- THE NAME AND THE SENTENCE ARE STILL ENGLISH, and this is the one place in the tutorial where that is
-- true: both come off the building blueprint (data/buildings/*.lua), which the extraction pipeline does
-- not reach yet. The frame around them translates; the room's own words wait on blueprint extraction.
local function doorText(b)
    local bare = (b.name or "door"):gsub("^[Tt]he%s+", "")
    local text = "the " .. bare .. "."
    if b.description and b.description ~= "" then text = text .. " " .. b.description end
    return text
end

-- Whichever card the city is refusing every other door on behalf of: the first visit's stage, or a
-- newly grown door. One reader, so openPanel and hub.draw cannot disagree about which is in force.
--
-- The intro WINS while it is running, and it has to: it is coaching the hall and the stair, which are
-- two of the three doors a fresh save opens with -- and those three are seeded as already-shown
-- precisely so this queue is empty until the company comes back up from a floor (Building.seedSeen).
local function coachedStage()
    return introStage() or coachedDoor
end

-- Put the keyboard/pad cursor on the card being coached. The bubble wears a key cap ("Enter", "A"), and
-- that cap is a promise about what the key does -- but the map's own selection starts wherever the board
-- put it, so the promised key activated some other card, the gate refused it, and the one instruction on
-- the screen did nothing. Called wherever a stage comes into force, and it is why hub.mousemoved stops
-- letting the pointer drag the selection while one is: the highlighted card and the coached card must be
-- the same card for as long as the bubble is up.
local function focusCoachedCard()
    local stage = coachedStage()
    if stage and map then map:selectById(stage.building) end
end

-- Take the next grown door off the queue and coach it: a bubble on its card, every other card refused
-- until it has been walked into.
--
-- Does nothing while the first visit is running, so the sponsor's two coached doors are never competing
-- with a third. The guard reads `hubIntro` itself rather than introStage(), because the intro has a
-- stage the table does not name: "arrival" is the two scenes playing over the city, and it would
-- otherwise read as free play.
--
-- Deliberately NOT guarded on `activePanel`. A bubble is drawn by hub.draw only when nothing is open
-- over the city, so a door coached while the post-quest summary is still up simply waits behind it --
-- which is the right order without needing a callback to sequence it.
local function coachNextDoor()
    if coachedDoor or (hub.player and hub.player.hubIntro) then return end
    local b = table.remove(doorQueue, 1)
    if not b then return end
    coachedDoor = { building = b.id, line = "new_door", door = true, doorText = doorText(b) }
    focusCoachedCard()
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

-- Every OTHER card on the board, for the bubble to keep off (ui/coach_bubble.lua's `avoid`). The plaza
-- is nine plates with narrow gutters, so a bubble placed by preference alone lands on a neighbour and
-- covers a name -- and on this screen the names are the whole content. Handing it the cards lets it pick
-- the side that hides the least, which on a top-row card is the empty band above the ring.
local function otherCardRects(stage)
    local rects = {}
    for _, b in ipairs(map and map.buildings or {}) do
        if b.id ~= stage.building then
            rects[#rects + 1] = { x = b.x, y = b.y, w = b.w, h = b.h }
        end
    end
    return rects
end

local function titleCase(s) return (s:gsub("^%l", string.upper)) end

-- IS THE INN'S OWN COACHING IN FORCE? True only while the first morning's Ward stage is unspent, which
-- (see INTRO_STAGES.ward) is exactly while somebody is still owed a mending. Handed to the room rather
-- than drawn from here, because the thing being pointed at is a ROW inside a modal and only the modal
-- knows where its rows landed -- the same division of labour the plaza's own bubble keeps with the
-- building map.
local function coachingMend()
    local stage = introStage()
    return stage ~= nil and stage.mend == true
end

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
        -- THE TACTICS TAB IS NOT THERE ON THE FIRST MORNING. It arrives when the first trip ends, by
        -- whichever exit comes first -- home to the city, or down onto floor two (Descent.tacticsUnlocked)
        -- -- because a rule list offered before the player has taken a turn is a shortcut past the thing
        -- being taught. The Auto button it drives waits one step longer still, for the window behind this
        -- tab to be read (Descent.autoUnlocked). The panel's own default is on, so this is the only place
        -- the city says otherwise.
        tactics = (moduleName ~= "party") or Descent.tacticsUnlocked(hub.player),
        -- The Inn's rows wear the coach bubble on the one morning the city is holding the plaza until
        -- one of them is pressed (INTRO_STAGES.ward). Every other panel ignores the field.
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
        -- The tutorial's staked pull plays its beats in full. It is the only pull in the game that
        -- cannot be skipped, and it is the one teaching what a pull looks like (INTRO_STAGES.hire).
        hold = hub.player and hub.player.hubIntro == "hire",
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

-- A WOUND EXPLAINS ITSELF, ONCE, IN THE DOORWAY OF THE ROOM THAT ANSWERS IT.
--
-- The beat it lands on is the end of the Cathedral's `intro` -- the scene Xin joins out of
-- (models/counter.lua's afterIntro, which exists for this). That is the exact moment the player has
-- everything the lesson needs and nothing that explains it: a healer who just walked into the company
-- because somebody is hurt, a wound on a body they watched go down at the end of Act 0, and a desk one
-- press away with a line on it about mending. What is missing is the rule -- that the band on the bar
-- is held back, that coming home does not lift it, and that there are two ways out priced against
-- different things.
--
-- A WINDOW, NOT A BUBBLE. "Rest is free and costs trips; gold costs gold and costs nothing else" is a
-- rule with a consequence, and a tail on a row cannot carry one (ui/panels/tutorial_note.lua draws that
-- line). The bubble's half of the job is next: it goes on one of the rows, inside the room, and says
-- only press (see coachingMend).
--
-- AND THE TWO DIVIDE THE WORK RATHER THAN REPEATING IT. This window teaches both ways out and ranks
-- neither, because the ranking is not a property of wounds -- it is a property of THIS morning, where
-- the company is three bodies deep and the stair wants four. So the window states the rule and the
-- bubble makes the call, which is also the only order in which the call can be argued for.
--
-- GATED ON THERE BEING A WOUND rather than on the building, so it can never open onto nothing. Today
-- the Cathedral is the only house with an `intro` at all, so that gate and "is this the Inn's door" are
-- the same question -- but the honest one is the one about the lesson's subject, and it is the one that
-- stays true when the second house grows a scene.
--
-- NO LEDGER OF ITS OWN. The intro scene fires exactly once, ever, off `flags.intro_<id>`, and this
-- rides it -- which is the whole reason the seam was put there rather than on the desk. A second flag
-- for "has the window been read" would be a second thing that can disagree with the first.
local function teachWounds(go)
    if mendingDone() then return go() end
    activePanel = TutorialNote.new({
        title = Locale.line(NOTES, "wound_title"),
        body = Locale.line(NOTES, "wound_body"),
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
        activePanel = newPanel(room.panel, room.vendor, nil, function()
            Sound.play("ui.cancel")
            activePanel = nil
            onClosed()
        end)
    end, function()
        -- Walked out. The city is already underneath; nothing to switch back to.
        activePanel = nil
    end, {
        -- One beat between a house's first-visit scene and its desk, and the only house that has one
        -- is the Cathedral (see teachWounds). `go` is the hand-back this owes the counter.
        afterIntro = teachWounds,
    })
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

-- Activation seam handed to the building map. In free play it opens the clicked building's panel,
-- playing a vendor's one-time greeting first (see launchVendor). While the first-visit tutorial is
-- running it refuses every door but the one the current stage coaches (INTRO_STAGES).
local function openPanel(building)
    local stage = coachedStage()
    if stage then
        if building.id ~= stage.building then return end
        -- A NEWLY GROWN DOOR IS SPENT BY BEING WALKED INTO, which is the same rule the hire stage below
        -- keeps and for the same reason: the ledger records a door as SHOWN, and a lesson satisfied by
        -- reading the bubble over it would mark the room learned by somebody who never saw inside it.
        --
        -- Recorded and saved here rather than on the panel's close, because two of these doors open a
        -- whole SCREEN (the Markets) and never close a panel at all -- there is no later moment that
        -- every door passes through.
        if stage.door then
            Building.markSeen(hub.player, building.id)
            Player.save()
            coachedDoor = nil
            -- ...and through launchVendor, not launchPanel: every grown door but the Armory is a house
            -- with a shopkeeper behind it, and their greeting and desk are the first thing that should
            -- happen inside the room the player was just sent to (models/counter.lua).
            launchVendor(building)
            return
        end
        -- SPENT BY THE DEED, NOT BY THE DOOR -- and only the Gate's stage can be spent on the door,
        -- because opening the Gate IS leaving the city. A stage that names a deed (`hire`, `mend`) is
        -- spent by introAdvance when the deed lands, so a player who walks in, looks around and walks
        -- out is coached back to the room rather than left in a city that thinks the lesson landed.
        --
        -- THE CATHEDRAL HANDS ON TO THE STAIR rather than ending the intro, and it does that from
        -- introAdvance for the reason above: two doors are coached on the first morning now (see
        -- INTRO_STAGES), and a stage that cleared here would leave the Rift -- the door the whole mode
        -- is behind -- uncoached on the one visit that teaches the city.
        if not (stage.hire or stage.mend) then
            hub.player.hubIntro = nil
        end
        -- No scene between the COACH and the door. The flier was Rowan spotting the Colosseum's contract
        -- ON the Quest Board -- a beat about a board that is retired (models/building.lua's RETIRED), so
        -- playing it here would have her read a notice off a wall the city does not have. The guard said
        -- everything this moment needs to say, and the sponsor is waiting on the other side of the door.
        --
        -- BUT THE ROOM'S OWN SCENE STILL PLAYS, so this goes through launchVendor like every other door
        -- on the board. It called launchPanel directly while the only stage here was the hall's -- a
        -- room with nothing to say on the way in -- and the Ward inheriting that path swallowed its
        -- `intro` and the companion the scene `grants`: the one coached door that hands over a body
        -- was the one door that skipped the code which hands one over. Xin simply never appeared.
        -- The Gate is unaffected: it keeps neither `intro` nor `vendor`, so launchVendor is its
        -- launchPanel.
        launchVendor(building)
        return
    end
    launchVendor(building)
end

-- Has the coached deed been done? Asked every frame while the intro is on a stage that names one --
-- `hire` (a body joining) or `mend` (a wound seen to). Cheap -- a walk of at most four bodies -- and
-- it is the only way this state can hear about either: both happen inside a panel, and a panel
-- reporting back up into whatever launched it would be a seam built for one lesson.
--
-- A stage whose deed is ALREADY done when it comes into force clears on the first frame, and that is
-- the backstop rather than an accident: the Ward stage is handed on by the arrival scene, and a save
-- that somehow reaches the city with nobody hurt would otherwise be held at a card whose room has
-- nothing in it -- a coached door onto a desk with no line on it.
local function introAdvance()
    local stage = introStage()
    if not stage then return end
    local done
    if stage.hire then
        done = false
        for _, char in ipairs((hub.player and hub.player.roster) or {}) do
            if char.id == stage.hire then done = true break end
        end
    elseif stage.mend then
        done = mendingDone()
    end
    if not done then return end
    hub.player.hubIntro = "coach"
    Player.save()
    -- The bubble moves to the stair on this frame, so the cursor under it has to as well --
    -- otherwise the coached card and the highlighted card are two different cards until the
    -- player happens to touch something (see focusCoachedCard).
    focusCoachedCard()
end

-- IS THERE SOMETHING ON THIS HOUSE'S SHELF NOBODY HAS READ -- the dot half of a shop's plate.
--
-- Asked THROUGH THE SHELF'S OWN GATES (Quest.shelfGates) and not of the catalogue. A mark can be laid
-- on a ware sitting rungs above where the company is standing -- and the shop draws no unseen dot on a
-- row it cannot sell, on purpose. So a plate asking only "does this house SELL a marked ware" lit for
-- stock the shop will not mark, the player read the whole rack, and the dot was still burning when they
-- walked out. The gate makes the door ask exactly what the rack answers, and the mark keeps: it lights
-- this plate on the day the ladder reaches the row, which is the only announcement a shelf opened by a
-- class level gets.
--
-- The worst offender was DISCOVERY -- every ware carried out of the rift was marked, which was most of
-- a trip's haul. That is gone at the source rather than gated here: finding a thing opens no counter
-- line any more, so Player.markFound stamps the ledger and marks nothing.
--
-- `models.quest` inline rather than at the top of the file, the way models/vendor.lua's grade lookup is:
-- a new top-level require reorders `pairs` over the registry, which is enough on its own to redden a
-- spec that has nothing to do with this screen.
local function unreadShelf(player, vendorId)
    if not (player and vendorId and player.newStock) then return false end
    local gates = require("models.quest").shelfGates(player, vendorId)
    return Vendor.hasMarkedStock(vendorId, player.newStock, gates)
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
    -- THE TOWN NO LONGER SETS BONES ON THE DOORSTEP. It used to: Wound.clear stood here and an
    -- expedition's damage ended the moment the player was standing in the city, free and unasked. What
    -- replaced it is a room -- the Cathedral's mending (data/buildings/cathedral.lua) -- where it is
    -- still free (rest it off) and paying buys only speed. A wound that evaporates on arrival cannot be
    -- taught, cannot be decided about, and gave the door the tutorial now points at nothing to do.
    --
    -- The POOLS still refill here, and that half was never the wound's business: health and mana come
    -- back because attrition lasts a quest, and Player.restore fills against the wounded ceiling rather
    -- than through it (models/wound.lua's healShare), so a body that is still hurt still reads as hurt.
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
        --
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
            -- is: the Crossing declares a vendor id to keep a keeper (a portrait, a name, a
            -- greeting) without keeping a shelf, so the branch below would take it, ask a shelf
            -- question about a house that stocks nothing, and answer false forever.
            --
            -- A STATE rather than a sighting. The shelf dots below go out when the goods have been
            -- READ; this one cannot -- a token is not news, it is something you are still holding, and
            -- a dot that cleared on the first look would stop reminding the player at the exact moment
            -- they decided to spend it later. It goes out when the purse empties, which is the same
            -- line the errand branch draws (cleared by being TAKEN ON, not by being seen).
            -- THERE IS NO WOUND DOT, and there is no door for it to sit on. The Inn is gone with the
            -- ledger it charged for (models/wound.lua): a dive's wounds end the moment the company is
            -- standing in a town, so by the time this board is drawn there is never anybody carrying
            -- one and a dot here could only ever be dark.
            --
            -- A SHELF WITH SOMETHING ON IT NOBODY HAS READ. The dot used to carry two halves -- this
            -- house is asking for work, or it is holding wares you have not seen -- and the asking half
            -- is gone with the errands. What is left is the shelf, which clears on being read
            -- (Player.seeNew) rather than on being acted on.
            -- THE MARKET IS ASKED OF ITS COUNTER, not of its shelf, and it is the one door that has
            -- to be. `sellsAll` makes the shelf question below answer yes for every ware in the game
            -- (models/vendor.lua's Vendor.sells), so this plate lit for every discovery the company
            -- carried home -- two dozen wares the counter is not showing, and therefore a dot with
            -- nothing behind the door that could clear it. Market.hasUnread asks the standing rack.
            -- A HOUSE'S DOT IS THE OR OVER THE ROOMS BEHIND IT, because a mark behind a door is a mark
            -- nobody sees. A card carries its own shelf AND whatever it took in from the plaza, and
            -- those can have different counters -- the Undercroft's desk opens the town's shelf beside
            -- the fence's own (models/offer.lua) -- so this walks the offers rather than asking the
            -- building's single `vendor`.
            --
            -- Only OPEN rooms count. A dot for a room the desk will not offer yet is a dot with nothing
            -- behind the door that could clear it, which is the exact failure the Market's branch below
            -- was written for.
            for _, offer in ipairs(Offer.list(hub.player, b)) do
                -- SOMETHING THE COMPANY IS CARRYING IS HEXED (models/curse.lua). The Touchstone's dot
                -- wearing the Cathedral's colours, and for the identical argument: a curse is not NEWS,
                -- it is a thing you are still carrying around, so this is a STATE rather than a
                -- sighting. It goes out when the last hex is lifted or committed to the rite, never on
                -- being looked at -- a dot that cleared on the first glance would stop reminding the
                -- player at the exact moment they decided to deal with it after the next trip.
                --
                -- ASKED OF THE ROOM rather than of the building, so it cannot light before the rite is
                -- on the desk: a dot for a room the counter will not offer yet is a dot with nothing
                -- behind the door that could clear it, which is the failure the Market's branch below
                -- was written for.
                if offer.open and offer.panel == "rite" and Curse.count(hub.player) > 0 then
                    return true
                end
                if offer.open and offer.vendor then
                    -- THE MARKET IS ASKED OF ITS COUNTER, not of its shelf, and it is the one room that
                    -- has to be. `sellsAll` makes the shelf question answer yes for every ware in the
                    -- game (models/vendor.lua's Vendor.sells), so this plate lit for every discovery the
                    -- company carried home -- two dozen wares the counter is not showing. Market.hasUnread
                    -- asks the standing rack.
                    if offer.vendor == Market.ID then
                        if Market.hasUnread(hub.player) then return true end
                    elseif unreadShelf(hub.player, offer.vendor) then
                        return true
                    end
                end
            end
            -- A door that keeps a shelf but declares no rooms (nothing does today, but the Armory's
            -- shape is one blueprint away from it).
            if b.vendor and not b.offers then
                if b.vendor == Market.ID then return Market.hasUnread(hub.player) end
                return unreadShelf(hub.player, b.vendor)
            end
            -- THE ARMORY carries two things: stash nobody has read, and a TAB nobody has met. The
            -- second is why this branch is an `or` -- Tactics unlocks on a trip ending, which may well
            -- have happened underground (floor two), so the door itself is the only thing that can say
            -- the room has grown a control since the player last stood in it. It clears when the window
            -- explaining it has been read (Descent.tacticsTaught), not on being seen, for the same
            -- reason the voucher's does: an unread feature is a thing you still have to look at. That
            -- same reading is what then puts Auto on the board (Descent.autoUnlocked), so this dot is
            -- the one errand standing between the unlock and the button.
            if b.panel == "party" then
                return Player.hasNewStash(hub.player)
                    or (Descent.tacticsUnlocked(hub.player) and not Descent.tacticsTaught(hub.player))
            end
            return false
        end,
    }
    map = BuildingMap.new(Building.list(hub.player), mapOpts)
    burger = BurgerButton.new(BURGER_X, BURGER_Y)

    -- WHAT THE CITY GREW WHILE THE COMPANY WAS BELOW (models/building.lua's seenDoors block). The ledger
    -- is created on the first look at the city and records everything already open, so this comes back
    -- empty on the first visit -- and empty on the first visit of a save written before any of this
    -- existed, whose company has been using those rooms for hours.
    --
    -- ABOVE THE ARRIVAL BRANCH, which returns early: a stale queue or a stale coached door left over
    -- from a previous visit would otherwise still be in force behind the sponsor's scene. Seeding here
    -- is also the honest place for it -- the first look at the city is this line, not the one after the
    -- conversation that plays over it.
    if not Building.seeded(hub.player) then
        Building.seedSeen(hub.player)
        Player.save()
    end
    doorQueue = Building.unannounced(hub.player)
    coachedDoor = nil
    -- The first visit's own stages are already in force at this point (they live on the save, not on
    -- the queue), so the cursor is lined up with the hall or the stair the same way a grown door's is.
    focusCoachedCard()

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
    -- On its close the intro moves to its first coaching stage -- the WARD, because the company walks
    -- out of Act 0 carrying a wound and that is the door the city grew to answer it. The Ward hands on
    -- to the stair when it is walked into (see openPanel). A loaded save never carries this flag, so its
    -- hub opens straight to free play.
    if hub.player.hubIntro == "arrival" then
        Conversation.play("conversation_prologue_arrival", function()
            hub.player.hubIntro = "ward"
            Player.save()
        end)
        return -- nothing else opens over the arrival; there is no pending summary on a first visit
    end

    -- The door the city grew while the company was below, coached from here on. It needs no sequencing
    -- against the summary below: a bubble is only drawn over a clear city, so it waits behind the
    -- summary on its own and is standing there when the player closes it.
    coachNextDoor()

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
    -- The next door waiting behind the one just walked through, coached as soon as the last is spent.
    -- Asked here rather than hooked onto the panel's close for the reason openPanel gives: a door that
    -- opens a whole SCREEN never closes a panel, so there is no one seam every door passes through.
    -- coachNextDoor refuses on its own while one is already in hand, so this is a cheap no-op on almost
    -- every frame.
    coachNextDoor()
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

    -- The coach: a bubble pinned to whichever card the current stage is about, while nothing is open
    -- over the city. Same widget the battle tutorial uses (ui/coach_bubble), so "click" stays
    -- device-honest -- a key cap for pad/keyboard, the plain verb for the mouse. Two things put a stage
    -- in force -- the first visit's two doors, and a door the city has just grown -- and this draws
    -- either without knowing which (coachedStage).
    -- ...AND WHILE NOTHING IS BEING SAID OVER IT EITHER. A scene draws on top of the state rather than
    -- instead of it (main.lua's love.draw), so the city keeps rendering underneath -- and the Ward hands
    -- the intro on to the stair the moment its door is pressed, which is one scene BEFORE the player is
    -- done with the room. Without this the stair's bubble sits behind Xin's first words, pointing at
    -- the door after the one being walked into.
    local stage = coachedStage()
    if stage and not activePanel and not Conversation.active then
        local rect = introBuildingRect(stage)
        if rect then
            -- Both stages carry a line id, not a sentence: coachLine resolves it for the device in
            -- hand ("Enter" / "A" as a cap, or the plain verb on a pointer), and a grown door's own
            -- name arrives as the {door} token (see doorText).
            local text, key = Locale.coach(CITY, stage.line, { door = stage.doorText })
            if text then
                -- THE TITLE'S BAND IS NOT THE BUBBLE'S TO SIT IN, and it has to be said in `bounds`
                -- rather than in `avoid`: avoid is a score the placement search trades off, so a
                -- bubble that hides ten pixels of "The City" and nothing else still wins on points.
                -- Bounds is a floor -- a side that would land above the line is not a candidate at
                -- all -- and the search then takes the least-bad placement under the title instead.
                --
                -- It matters on exactly one card, which is why it was not needed until now: the Ward
                -- sits in the plaza's top-middle slot, hard under this line, and a bubble pointing
                -- down at it from above is the placement the scorer likes best (the cards to either
                -- side are plates it would rather not cover). Every other coached door has a whole
                -- row over it.
                local band = 24 + titleFont:getHeight() + 6
                CoachBubble.draw(text, rect, {
                    prefer = "below",
                    key = key,
                    avoid = otherCardRects(stage),
                    bounds = { x = 0, y = band, w = screenW, h = screenH - band },
                })
            end
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
        -- The pointer does NOT drag the selection off a coached card. Hover-selects everywhere else so
        -- all three inputs stay in sync (BuildingMap:mousemoved), but while a bubble is up the
        -- highlighted card and the card its key cap promises must be the same one -- and every other
        -- card is refused anyway, so highlighting one is a press the board is about to turn down.
        -- The mouse can still CLICK any card: BuildingMap:mousepressed finds it by rect, not by
        -- selection.
        if not coachedStage() then map:mousemoved(x, y) end
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
        -- A REFUSED PRESS GIVES THE HIGHLIGHT BACK. BuildingMap selects whatever was clicked before it
        -- activates, so a click on a card the coach is refusing lit that card and left the bubble
        -- pointing at another -- two cards claiming to be the live one. A no-op when the press landed on
        -- the coached card, because spending the stage is what clears it.
        focusCoachedCard()
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
    map = BuildingMap.new(Building.list(hub.player), mapOpts)
    -- ...and re-asked, so the Touchstone this just opened announces itself here exactly as it would on
    -- the walk up from the floor that found the piece. Without it the mint would open a card silently
    -- and the one path that can reach this feature on demand would be the one path that skips it.
    doorQueue = Building.unannounced(hub.player)
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
        focusCoachedCard() -- arrows may not walk the cursor off a coached card; see hub.mousemoved
    end
end

function hub.gamepadpressed(joystick, button)
    if activePanel then
        activePanel:gamepadpressed(joystick, button)
    elseif button == "start" then
        openSystemMenu()
    else
        map:gamepadpressed(joystick, button)
        focusCoachedCard() -- the d-pad may not walk the cursor off a coached card either
    end
end

return hub
