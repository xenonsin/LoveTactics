-- THE WARD'S COUNTER: the two ways out of an injury, one row each, per hurt body.
--
-- See data/buildings/cathedral.lua for what this room is and models/injury.lua's ward block for why it is
-- allowed to charge for anything at all. In one line: REST is free forever and TREAT buys only speed,
-- so the gold is priced against impatience rather than against injury.
--
-- TWO ROWS PER BODY RATHER THAN ONE ROW THAT OPENS A CHOOSER. A body carried out three times is three
-- separate decisions and the interesting one is where paying stops being worth it -- so both prices sit
-- on screen beside each other, on every body, all the time. A chooser would hide the comparison one
-- click deep and make "mend everybody" the obvious press.
--
-- A ROW THAT CANNOT BE PRESSED IS NOT DRAWN AS A ROW. Treat disappears when the purse is short rather
-- than greying, because a control appears only where it is legal -- and the purse is on the header, so
-- the player is never left guessing which of the two facts stopped them.
--
-- AND ON ONE MORNING THE ROOM IS A RAIL. The first injury in the game is Rowan's, taken by script at
-- the end of Act 0, and the host flags that morning off `player.hubIntro` (states/hub.lua's
-- coachingMend). The city outside says nothing about it -- the plaza's coach bubbles are cut -- so
-- this room is the whole of the lesson: the window that opened the door said what an injury IS and why
-- there are two ways out of one, and what is left is the press, which is a bubble's job and not a
-- window's -- so the host hands this panel a `coach` flag and the bubble goes on a row.
--
-- IT NAMES THE PAID ROW AND IT IS THE ONLY ROW THERE. A coached room that still offered the other way
-- out was a recommendation, and the first morning is the one morning the two are not equal (see the
-- paragraph below) -- so on this one visit the rail is real: the coached row is the only row built,
-- the panel cannot be closed until it is pressed, and what the press hands to is the scene the healer
-- who sets the bone walks out of (data/buildings/cathedral.lua's `introAfter`).
--
-- THE FREE PATH IS STILL TAUGHT, one beat earlier and by the surface that can carry a rule: the window
-- in the doorway states both ways out and ranks neither (states/hub.lua's teachInjuries). What this room
-- withholds for one morning is the PRESS, not the fact -- the rest row is back on the next trip, and
-- every trip after that is the shrug the paragraph below argues for.
--
-- THE FIRST MORNING IS THE ONE MORNING THE TWO ARE NOT EQUAL, which is why the instruction is allowed
-- to pick. Resting benches Rowan for Injury.REST_DESCENTS trips, and the very next thing the city asks
-- for is an expedition of four (models/descent.lua's PARTY_MAX) out of a company that has three bodies
-- in it. A coach that shrugged here would be teaching a player who cannot yet know what a short company
-- costs to walk down as one -- and the injury they were laying up was the whole reason the room opened.
-- Every trip after this one the player has the window's rule and the two prices side by side, and the
-- shrug is correct from then on.
--
-- THE CURSOR GOES WHERE THE BUBBLE POINTS, and that is not decoration: the bubble wears a key cap, and
-- the cap is a promise about what that key does. The same rule states/hub.lua's focusCoachedCard keeps
-- on the plaza, kept here against the menu.
--
-- A PURSE THAT CANNOT COVER IT falls back to the free row, bubble and cursor together, and says so in
-- its own words rather than pointing at a row it is not describing. Unreachable in the campaign as it
-- stands -- the company walks out of Act 0 with 250g against a 40g bone -- and written anyway, because
-- this room holds the player until somebody is seen to, so a bubble that pointed at nothing the day
-- that figure moved would leave the lesson unfinishable rather than merely unhelpful.
--
-- THE RESTING ARE LISTED AND NOT ACTIONABLE. They are the cost of the free path made visible: four
-- bodies go down, and a name sitting in this list is a name that is not among them. Without the list
-- the deployment picker is simply short a body for a reason the player chose two screens ago.

local CloseButton = require("ui.close_button")
local CoachBubble = require("ui.coach_bubble")
local Keeper = require("ui.keeper") -- the city's keeper pane: face or mark, name, line
local Menu = require("ui.menu")
local Scale = require("scale")
local InputMode = require("input_mode")
local Locale = require("models.locale")
local Theme = require("ui.theme")
local Sound = require("models.sound")
local Injury = require("models.injury")

-- The bubble's words, in the same hint bag the plaza's own coaching lives in, so the one instruction
-- this room gives is stamped and translated like every other thing the tutorial says
-- (data/conversations/tutorial/conversation_tutorial_city.lua).
local CITY = "conversation_tutorial_city"

local Ward = {}
Ward.__index = Ward

-- 560 wide until the keeper arrived. The pane's column is ADDED to the box rather than taken out of
-- the middle of it: the rows are the room and two prices sitting side by side is the whole content of
-- the decision (see the header), so they keep every pixel they had.
local BOX_W, BOX_H = 820, 420
local ROW_W, ROW_H = 470, 40
local PAD = 24

function Ward.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Ward)
    self.player = opts.player
    self.onClose = opts.onClose
    -- The house behind this room (models/offer.lua hands it down): the Cathedral.
    self.vendorId = opts.vendor
    -- Nil for every ordinary visit. The host only sets it while the first morning's stage is unspent
    -- (states/hub.lua's coachingMend), so this panel never has to ask what a tutorial is.
    self.coach = opts.coach
    self.titleFont = Theme.display(30)
    self.bodyFont = Theme.body(17)
    self.rowFont = Theme.body(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    -- The keeper's column down the left, and the rows in what is left. Every room behind a desk holds
    -- the person the desk introduced (ui/keeper.lua); this one is the Cathedral's.
    self.keeperX = self.boxX + PAD
    self.keeperY = self.boxY + 64
    self.keeperH = BOX_H - 64 - PAD
    self.colX = self.keeperX + Keeper.W + PAD
    self.colW = self.boxX + BOX_W - PAD - self.colX

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self:rebuild()
    return self
end

-- The rows, rebuilt after every press: treating drops an injury and resting takes a body off the list
-- entirely, so the menu the player is looking at is stale the instant either one lands.
function Ward:rebuild()
    local p = self.player
    local items = {}
    for _, entry in ipairs(Injury.injured(p)) do
        local char, n = entry.char, entry.count
        local name = char.name or char.id
        if (p.gold or 0) >= Injury.TREAT_COST then
            items[#items + 1] = {
                charId = char.id,
                kind = "treat",
                label = string.format("Set %s's bone  -  %dg", name, Injury.TREAT_COST),
                action = function()
                    if Injury.treat(p, char.id) then Sound.play("ui.confirm") end
                    self:rebuild()
                end,
            }
        end
        items[#items + 1] = {
            charId = char.id,
            kind = "rest",
            label = string.format("Rest %s  -  %d descents", name, n * Injury.REST_DESCENTS),
            action = function()
                if Injury.rest(p, char.id) > 0 then Sound.play("ui.confirm") end
                self:rebuild()
            end,
        }
    end
    self.items = items

    -- THE RAIL, BUILT RATHER THAN ENFORCED. On the coached morning the row the coach names is the only
    -- row in the room: a rest row drawn beside it and refused on press would be a dead control, and a
    -- control appears only where it is legal. Narrowed AFTER the full list is built, because
    -- coachIndex is what picks the row and it reads the whole list to pick it.
    --
    -- AND THE PRESS CLOSES THE ROOM. The deed is the whole of what this visit is for, and what is
    -- waiting on the far side of it is the scene the healer sets the bone in (models/counter.lua's
    -- introAfter) -- so the room hands back to the desk on its own rather than leaving the player
    -- looking at a panel with nothing left in it. Asked through coachIndex again rather than off the
    -- press's own return, so the one predicate the city, the ring and the rail all read stays one.
    local railed = self.coach and self:coachIndex()
    if railed then
        local row = items[railed]
        local press = row.action
        row.action = function()
            press()
            if not self:coachIndex() then self:close() end
        end
        items = { row }
        self.items = items
    end

    self.menu = #items > 0 and Menu.new(items, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = 8,
        startY = self.boxY + 120,
        -- The rows centre on their own COLUMN, not on the screen. Those were the same point until the
        -- keeper's pane took the left of the box.
        centerX = self.colX + self.colW / 2,
        font = self.rowFont,
        maxVisible = 5,
    }) or nil
    -- The promised key activates the promised row. Asked after the menu is built and on every rebuild,
    -- because the row it names moves as rows are spent -- and it is a no-op on every uncoached visit,
    -- which is all of them but one.
    local coached = self.menu and self:coachIndex()
    if coached then
        self.menu.selected = coached
        self.menu:scrollToSelection()
    end
end

-- THE ROW THE COACH IS POINTING AT: its index, or nil when there is nobody owed a mending or this visit
-- is not being coached.
--
-- The BODY is read through models/injury.lua's Injury.unattended, which is the same call the city's own
-- deed is decided by -- so the ring goes out on exactly the press that spends the stage, rather than on
-- a second opinion about what "seen to" means.
--
-- THE PAID ROW IF THERE IS ONE, else that body's free row (see the header for both halves of why).
-- Split from coachRect so the SELECTION can be put on the same row the bubble names without laying the
-- menu out first -- a rect does not exist until Menu:update has run, and the cursor has to be right on
-- the frame the panel opens.
function Ward:coachIndex()
    if not self.coach then return nil end
    local entry = Injury.unattended(self.player)[1]
    if not entry then return nil end
    local fallback
    for i, item in ipairs(self.items) do
        if item.charId == entry.char.id then
            if item.kind == "treat" then return i, entry, "treat" end
            fallback = fallback or i
        end
    end
    if fallback then return fallback, entry, "rest" end
    return nil
end

-- ...and that row as a rect for the bubble to hang off. Nil before the menu has been laid out (the
-- rects are filled in Menu:update, so a panel drawn on the frame it was rebuilt on has none yet and
-- simply draws no bubble that frame).
function Ward:coachRect()
    local i, entry, kind = self:coachIndex()
    local item = i and self.items[i]
    if not (item and item.x) then return nil end
    return { x = item.x, y = item.y, w = item.w, h = item.h }, entry.char.name or entry.char.id, kind
end

-- IS THE ROOM HELD? True only while the coached morning still has a row owed -- so it goes false on the
-- press that spends it, and the close that press asks for is allowed through. Every refusal below is
-- written against this rather than against `coach`, which is what keeps an injury that somehow cannot be
-- answered from locking a player inside a panel: no coached row, no rail.
function Ward:railed()
    return self.coach ~= nil and self:coachIndex() ~= nil
end

function Ward:close()
    if self:railed() then return end
    if self.onClose then self.onClose() end
end

function Ward:update(dt) if self.menu then self.menu:update(dt) end end

function Ward:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    -- The house's desk calls this room the Inn and so does this panel (data/buildings/cathedral.lua
    -- explains why the FILE is still ward.lua). One name, two surfaces, and they have to agree.
    --
    -- Centred on the ROWS' column, not on the box: the keeper's pane holds the left of the panel and a
    -- title centred on the whole thing sits over the gap between the two, reading as a slip rather
    -- than as the heading of anything.
    love.graphics.printf("Inn", self.colX, self.boxY + 26, self.colW, "center")

    -- The purse, on the header, because one of the two prices is in gold and the other is not -- so the
    -- number that decides which rows exist has to be readable without closing the panel.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.printf(string.format("%dg", (self.player and self.player.gold) or 0),
        self.boxX, self.boxY + 66, BOX_W - 24, "right")

    Keeper.draw(self.vendorId, self.keeperX, self.keeperY, Keeper.W, self.keeperH, {
        nameFont = self.bodyFont,
        title = "Inn",
        line = false, -- the pane runs to the foot of the box; there is no room under it for a line
    })

    if self.menu then
        self.menu:draw()
    else
        Theme.set(Theme.ink)
        love.graphics.printf("Nobody here is hurt.", self.colX, self.boxY + 150, self.colW, "center")
    end

    -- Who is lying up, and for how much longer. Below the rows rather than mixed among them: these are
    -- not choices, they are the bill for choices already made.
    local resting = Injury.resters(self.player)
    if #resting > 0 then
        local y = self.boxY + BOX_H - 74 - (#resting - 1) * 20
        Theme.set(Theme.muted)
        love.graphics.setFont(self.bodyFont)
        for _, r in ipairs(resting) do
            love.graphics.printf(string.format("%s is resting  -  %d descents left",
                r.char.name or r.char.id, r.left), self.colX, y, self.colW, "left")
            y = y + 20
        end
    end

    -- THE WAY OUT IS NOT DRAWN WHILE THERE IS NOT ONE. A held room keeps neither the X nor the line
    -- under the rows that names it: a control appears only where it is legal, and an X that answers
    -- nothing reads as a panel that has stopped listening rather than as one that is waiting.
    if not self:railed() then
        Theme.set(Theme.muted)
        love.graphics.setFont(self.bodyFont)
        love.graphics.printf(InputMode.pick("B to close", "Tap X to close", "Click X, or Esc to close"),
            self.colX, self.boxY + BOX_H - 34, self.colW, "center")

        self.closeButton:draw()
    end

    -- The coach, over everything the panel drew.
    --
    -- ABOVE the row, and KEPT OFF THE OTHER ROWS by name. The bubble points at one row and talks about
    -- the other one in the same breath -- "resting mends it too" -- so a box parked over "Rest Rowan"
    -- would be hiding the very thing it is comparing against. Below the coached row IS the other row,
    -- so the preference is inverted from the plaza's and the rows go in `avoid` as well: preference
    -- only breaks ties, and the band over the rows is empty here (the purse is right-aligned and the
    -- bubble is centred on a row), so this scores clean and lands there.
    --
    -- Bounded to the panel rather than to the screen, so the instruction stays inside the modal it is
    -- about instead of hanging over a city the player cannot touch while this is open.
    local rect, who, kind = self:coachRect()
    if rect then
        local text, key = Locale.coach(CITY, kind == "rest" and "mend_rest" or "mend_row", { who = who })
        if text then
            local others = {}
            for _, item in ipairs(self.items) do
                if item.x and not (item.x == rect.x and item.y == rect.y) then
                    others[#others + 1] = { x = item.x, y = item.y, w = item.w, h = item.h }
                end
            end
            CoachBubble.draw(text, rect, {
                prefer = "above",
                key = key,
                avoid = others,
                bounds = { x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H },
            })
        end
    end

    love.graphics.setColor(1, 1, 1)
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function Ward:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self.menu then self.menu:mousemoved(x, y) end
end

function Ward:cursorKind(x, y)
    if not self:railed() and self.closeButton:contains(x, y) then return "hand" end
    if self.menu and self.menu.cursorKind then return self.menu:cursorKind(x, y) end
    return "arrow"
end

function Ward:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- A held room has one live control in it. The X is not drawn and the click-outside that closes
    -- every other panel in the city does nothing either -- both of them would be a way out of a
    -- lesson the plaza is going to send the player straight back into (states/hub.lua's introAdvance).
    if self:railed() then
        if self.menu then self.menu:mousepressed(x, y, button) end
        return
    end
    if self.closeButton:mousepressed(x, y, button) or not isInsideBox(self, x, y) then
        self:close()
        return
    end
    if self.menu then self.menu:mousepressed(x, y, button) end
end

function Ward:keypressed(key)
    if key == "escape" then self:close(); return end
    if self.menu then self.menu:keypressed(key) end
end

function Ward:gamepadpressed(joystick, button)
    if button == "b" then self:close(); return end
    if self.menu then self.menu:gamepadpressed(joystick, button) end
end

return Ward
