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
-- the only thing it did. It is deleted with the toll it charged: a wound lasts the expedition now and
-- reaching this screen ends it, free -- see models/wound.lua and the Wound.clear in hub.enter.)
--
-- SO A FRESH SAVE ARRIVES AT THREE DOORS, and the first visit is coached through two of them: hire
-- somebody, then go down (INTRO_STAGES below).
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
local Conversation = require("models.conversation")
local Class = require("models.class")
local Vendor = require("models.vendor")  -- hasMarkedStock: the unread half of a shop's dot
local Item = require("models.item")
local Identify = require("models.identify")
local Wound = require("models.wound")     -- what a dive broke, and this door-step is where it stops being true
local VendorVisit = require("models.vendor_visit") -- what a shop says before it shows you the shelf
local Locale = require("models.locale")
local Scale = require("scale")
local ScreenFx = require("ui.screen_fx")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local CountMeter = require("ui.count_meter") -- Iselle's tally, on the Rift's plate
local Descent = require("models.descent")    -- ...and what it reads, plus the mark that reveals it

local hub = {}

local titleFont = Theme.display(28)

-- ISELLE'S TALLY, drawn on the Rift's own plate rather than under the title. The day counter that used
-- to sit centred in the header did so because expeditions were chosen from a board and the clock
-- belonged to the screen; this number belongs to one hole in the ground, so it rides the card that hole
-- is drawn on -- dead centre of the plaza, already the one card drawn larger, and exactly where the eye
-- is when the player is deciding whether to press it. It is the only clock the city keeps now. Held at
-- file scope so the arrival beat fires on a real change rather than on every visit (ui/count_meter.lua).
local countMeter = CountMeter.new()

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
-- THERE WAS A `hire` STAGE BEFORE THIS ONE, and it coached the Crossing: the sponsor's staked voucher,
-- a rigged first pull that dealt Saber, and a lesson in what a pull looked like. The Crossing is retired
-- and there is no pull to teach, so the arrival now hands straight to the Rift. Saber is earned at the
-- Colosseum's own work like every other companion.
local INTRO_STAGES = {
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
-- hub.draw composes "Click " in front of the whole thing, which is why it opens lowercase.
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
    coachedDoor = { building = b.id, text = doorText(b), door = true }
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
-- own board (states/houses.lua) and two screens open shop doors, so the sequencing is one copy with two
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
            -- ...and through launchVendor, not launchPanel: three of the grown doors keep a shopkeeper
            -- (the Inn, the Cafe, the Touchstone) whose one-time greeting is the first thing that
            -- should happen inside the room the player was just sent to.
            launchVendor(building)
            return
        end
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
            -- The bubble moves to the stair on this frame, so the cursor under it has to as well --
            -- otherwise the coached card and the highlighted card are two different cards until the
            -- player happens to touch something (see focusCoachedCard).
            focusCoachedCard()
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
    -- COMING HOME MAKES THE COMPANY WHOLE, and that is now both halves of it rather than one.
    --
    -- Health and mana refill (Player.restore) as they always have: attrition lasts a quest, not forever.
    -- And every bone the dive broke is set, free (models/wound.lua's Wound.clear) -- a wound is a
    -- condition of the expedition it was taken on, and this is where the expedition ends. BEFORE the
    -- restore, so the refill fills against the whole body rather than against the wounded ceiling and
    -- the player is not left looking at a bar that stops short for a reason no longer on the sheet.
    Wound.clear(hub.player)
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
            if b.vendor then
                return Vendor.hasMarkedStock(b.vendor, hub.player.newStock)
            end
            -- The Houses card carries the OR of the seven behind it (states/houses.lua draws the same
            -- dot per shelf in there): a mark behind a door behind a door is a mark nobody sees.
            if b.state == "houses" then
                for _, house in ipairs(Building.list(hub.player, { district = "houses" })) do
                    if not house.locked
                        and Vendor.hasMarkedStock(house.vendor, hub.player.newStock) then return true end
                end
                return false
            end
            if b.panel == "party" then return Player.hasNewStash(hub.player) end
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
                -- HER TERMS USED TO BE MADE GOOD HERE -- "I pay for the people you hire" bought a staked
                -- voucher before the party had turned round to look at the city. There is nothing to
                -- spend it at now, so the arrival hands straight to the Rift.
                --
                -- The sponsor's scene still makes that promise in its prose. It wants rewriting, or she
                -- is offering to pay for a thing the city no longer sells.
                hub.player.hubIntro = "coach"
                Player.save()
            end)
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
    local dim = Descent.everClimbedOut(hub.player) and CountMeter.cityDim(hub.player)
    if dim then
        Theme.set(Theme.mount, dim)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Hub", 0, 24, screenW, "center")

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
    if Descent.everClimbedOut(hub.player) then
        local gate = Building.GRID.city.gate
        countMeter:draw(gate.x, 384, gate.w, hub.player)
    end

    -- Drawn under any open panel (which dims the city), so the burger does not float over its own menu.
    if not activePanel then burger:draw() end

    -- The coach: a bubble pinned to whichever card the current stage is about, while nothing is open
    -- over the city. Same widget the battle tutorial uses (ui/coach_bubble), so "click" stays
    -- device-honest -- a key cap for pad/keyboard, the plain verb for the mouse. Two things put a stage
    -- in force -- the first visit's two doors, and a door the city has just grown -- and this draws
    -- either without knowing which (coachedStage).
    local stage = coachedStage()
    if stage and not activePanel then
        local rect = introBuildingRect(stage)
        if rect then
            local key = Locale.selectKey() -- "Enter" / "A", or nil on the mouse
            local text = key and stage.text or ("Click " .. stage.text)
            CoachBubble.draw(text, rect, { prefer = "below", key = key, avoid = otherCardRects(stage) })
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
