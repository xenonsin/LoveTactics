-- THE ROLL, as a column of the Armory: what this body IS, and every class it could become.
--
-- The class ledger was written every fight (Growth.classOf, Class.classLevel), persisted through
-- every save, and shown to nobody until this existed. It had its own door on the plaza for a while --
-- The Roll, the card under the Gate -- and that was one card too many for one question about a body:
-- the Armory is already the screen you open to ask what a member of the company is carrying, and what
-- it IS belongs on the same rail rather than across the square. So this is a COLUMN EDITOR
-- (see Party:columnEditor), a third view of one member beside Loadout and Tactics, and the portrait
-- rail is the roster it used to draw for itself.
--
-- TWO COLUMNS, and each answers one question:
--
--   WHAT   every class in the game, grouped under the base class it hangs off: the ones open to this
--          body by name, level and rung, and the ones still shut by the requirement that opens them.
--   WHY    the highlighted class in full -- what the path is, what it grows, and what this body has
--          done in it.
--
-- IT IS A LIST, NOT A LATTICE, and that is a decision rather than a shortcut. Forty-five classes across
-- seven parents with twenty-one crossings between them is a real graph, and drawn as one at 1280x720
-- it is a plate of spaghetti nobody can read a number off. FFT's own version of this screen is a list
-- too, for the same reason: what a player actually does here is compare one class's level against the
-- rung above it, and a list puts those two numbers on one line.
--
-- A LOCKED CLASS STANDS IN THE LIST UNNAMED. It holds the place it will take and carries the one thing
-- worth knowing about it while it is shut: what opens it. "Requires Knight lvl 3" is a direction the
-- player can act on this afternoon; the NAME is the thing the work is for, so the name is the half
-- withheld. A count per house ("3 more open further along") named neither, and a greyed-out tree names
-- everything -- this is the middle. Every path is on the list, every shut one is a job you can read
-- straight off its row, and none of them is spoiled.
--
-- AN UNNAMED ROW IS NOT PICKABLE. The cursor steps over it and the mouse will not take it, because
-- selecting a row opens the detail column on it -- the name, the blurb, the lineage, which is exactly
-- what the row is holding back.
--
-- A MULTICLASS IS FILED UNDER BOTH ITS PARENTS. Shopping both shelves is literally how you build one
-- (models/vendor.lua says the same about its stock), so hiding it under one parent would make half the
-- crossings invisible to a player reading down the other.
--
-- CHANGING CLASS IS THE ONE ACT HERE, and it is free and reversible. `growthBy` is gone and nothing is
-- re-apportioned when you switch (models/growth.lua) -- levels already credited are never revisited --
-- so changing your mind costs the levels ahead of you, never the ones behind. That is what makes the
-- choice one the player can afford to make early.
--
-- THE VERB IS "CHANGE", NOT "DECLARE", and that is FFT's answer rather than ours. FFT has no ceremony
-- around this at all: you open the list, you put the cursor on a job, you press confirm, and the unit
-- is that job from then on -- no cost, no cooldown, no oath. "Declare" was inventing a rite for an act
-- that has none, and a word the player has to learn before pressing the only button on the screen.

local Theme = require("ui.theme")
local ProgressBar = require("ui.progress_bar")
local Building = require("models.building")
local Class = require("models.class")
local Growth = require("models.growth")
local Item = require("models.item")
local InputMode = require("input_mode")

local ClassEditor = {}
ClassEditor.__index = ClassEditor

local ROW_H = 30
local BUTTON_H = 34
local BUTTON_GAP = 8

-- The stats a growth table may buy, in the order the character sheet prints them, so a player moving
-- between the two readouts reads the same rows in the same places (ui/panels/party.lua's STAT_ROWS).
local GROWTH_ROWS = {
    { key = "health", label = "HP" },
    { key = "mana", label = "MP" },
    { key = "stamina", label = "SP" },
    { key = "damage", label = "Attack" },
    { key = "magicDamage", label = "Magic" },
    { key = "defense", label = "Defense" },
    { key = "magicDefense", label = "M.Def" },
    { key = "movement", label = "Move" },
    { key = "speed", label = "Speed" },
}

-- The sheet's forecast palette and glyph, kept identical here on purpose: this is the same statement
-- about the same body in a second place, and a second green would read as a second meaning. See
-- ANNOT_PENDING in ui/panels/party.lua for why a forecast is a transition and never a signed figure.
local ANNOT_PENDING = { 0.48, 0.74, 0.51 }
local ARROW = "→"

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The seven root classes, in a fixed order. Class.roots() is keyed by id and `pairs` over it is
-- unspecified, so a list that reordered itself between two openings of the same panel would read as a
-- bug -- and this is a screen the player learns the shape of.
local function classOrder()
    local out = {}
    for id in pairs(Class.roots()) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- Every crossing that names `class` as one of its two parents.
local function crossingsOf(class)
    local out = {}
    for id, def in pairs(Class.defs) do
        if Class.arity(id) == 2 then
            for _, p in ipairs(Class.parents(id)) do
                if p == class then out[#out + 1] = id end
            end
        end
    end
    table.sort(out)
    return out
end

-- The deepest rung a class asks of any parent -- what it costs to reach, as one number. It is what the
-- shut rows are ordered on: a name is the usual sort key and a shut row has no name, so alphabetical
-- would be an order the player cannot see and the group would read as a shuffled pile.
local function gateLevel(id)
    local deepest = 0
    for _, need in pairs((Class.defs[id] or {}).requires or {}) do
        deepest = math.max(deepest, need)
    end
    return deepest
end

-- What hangs off `class` for THIS body: the ids it has opened and the ids it has not, both in list
-- order -- the open ones by name, the shut ones cheapest first. One reader for both surfaces that ask -- the rows and the lineage diagram -- because they draw
-- the same fact twice and a second copy of the rule is a second place for it to be wrong.
local function childrenOf(class, char)
    local open, shut = {}, {}
    local function take(ids)
        for _, id in ipairs(ids) do
            if char and Class.isUnlocked(char, id) then
                open[#open + 1] = id
            else
                shut[#shut + 1] = id
            end
        end
    end
    local subs = Class.subclassesOf(class)
    table.sort(subs)
    take(subs)
    take(crossingsOf(class))
    -- Cheapest first, so the group reads as the ladder it is: the next thing this body can open is the
    -- row directly under the ones it already has. Ties break on the id, which is invisible but total --
    -- a pile that reordered itself between two openings of the same panel would read as a bug.
    table.sort(shut, function(a, b)
        local ga, gb = gateLevel(a), gateLevel(b)
        if ga ~= gb then return ga < gb end
        return a < b
    end)
    return open, shut
end

-- WHAT OPENS A CLASS THIS BODY CANNOT HAVE YET, in the words of the ladder it is standing on: every
-- class named in `requires`, at the level it is wanted. This is the whole of the row that is drawn in
-- place of a locked class's name, and the only thing it is told.
--
-- IT NAMES THE LEVELS AND STOPS THERE, though a crossing is also gated on holding a subclass of each
-- parent (Class.isUnlocked). That second rule is not dropped, it is implied: the cheapest subclass in
-- every house opens at 3, and no crossing asks less than 5 of a parent -- so a body that meets the
-- levels has met the subclass rule on the way past. A second clause would be a line the player can
-- never fail.
local function lockLabel(id)
    local requires = (Class.defs[id] or {}).requires or {}
    local parts = {}
    for _, parent in ipairs(Class.parents(id)) do
        parts[#parts + 1] = Item.classDisplayName(parent) .. " lvl " .. tostring(requires[parent] or 0)
    end
    if #parts == 0 then return nil end
    return "Requires " .. table.concat(parts, " + ")
end

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- Every class this body may stand in, flattened into drawable rows: each base class, then whichever of
-- its subclasses and crossings this body has opened.
--
-- THE BASE CLASS IS ITS OWN GROUP HEADING. It used to be two rows -- a chrome caption reading
-- "ALCHEMIST" and, directly under it, a pickable row reading "Alchemist" -- which spent a third of the
-- list saying every name twice and left the caption looking like the thing you clicked. One row: the
-- rule above it and the face it is set in do the group, the level and bar on it do the row.
--
-- Built fresh per body rather than once per panel, because every number on a row -- level, progress --
-- is a question about ONE character, and a cached list would answer it about whoever was on the rail
-- when the tab was first opened.
function ClassEditor:buildRows()
    self.rows = {}
    local char = self.char

    local function entry(id, kind, parent)
        local held, needed, level = 0, 0, 0
        if char then held, needed, level = Class.classProgress(char, id) end

        -- A CROSSING CARRIES ITS OTHER PARENT ON THE ROW. It is filed under both (see the note up top),
        -- so the half a player is not currently reading down is the half the list would otherwise never
        -- print -- and it is the whole difference between this row and the subclass above it.
        local cross
        if kind == "multiclass" then
            for _, p in ipairs(Class.parents(id)) do
                if p ~= parent then cross = Item.classDisplayName(p) end
            end
        end

        self.rows[#self.rows + 1] = {
            id = id, kind = kind, parent = parent, cross = cross,
            name = kind == "class" and Item.classDisplayName(id) or Class.displayName(id),
            level = level, held = held, needed = needed,
        }
    end

    -- A place on the list for a class this body has not opened, holding its requirement and nothing
    -- else. It carries no name and no id: everything downstream reads a row by asking what it IS, and
    -- an unnamed row that quietly knew its own id is one careless field away from printing it.
    local function shutEntry(id, parent)
        self.rows[#self.rows + 1] = {
            kind = "shut", parent = parent, locked = lockLabel(id),
            level = 0, held = 0, needed = 0,
        }
    end

    for _, class in ipairs(classOrder()) do
        local open, shut = childrenOf(class, char)

        -- A base class is never gated itself -- everyone may be a knight -- so it is always the named,
        -- pickable head of its group, whatever is still shut underneath it.
        entry(class, "class", nil)

        for _, id in ipairs(open) do
            entry(id, Class.arity(id) == 2 and "multiclass" or "subclass", class)
        end
        for _, id in ipairs(shut) do
            shutEntry(id, class)
        end
    end

    if not self:isSelectable(self.cursor) then
        self.cursor = 0
        self:step(1)
    end
    self:scrollToCursor()
end

-- Every named row is a class the body may stand in, so the only unpickable rows are the unnamed ones
-- (see the header): picking a row opens the detail column on it, and there is nothing to open. Kept as
-- one reader because the cursor, the mouse and `step` all ask this, and the mouse asks it about an
-- index that may not exist.
function ClassEditor:isSelectable(i)
    local row = i and self.rows[i]
    return row ~= nil and row.kind ~= "shut"
end

function ClassEditor:currentRow()
    return self.rows[self.cursor]
end

-- Move the cursor by `dir`. Stops at the ends rather than wrapping: this list runs deep and a wrap from
-- the bottom to the top reads as the cursor lost.
function ClassEditor:step(dir)
    local i = self.cursor or 0
    for _ = 1, #self.rows do
        i = i + dir
        if i < 1 then i = 1 end
        if i > #self.rows then i = #self.rows end
        if self:isSelectable(i) then
            self.cursor = i
            self:scrollToCursor()
            return
        end
        if (dir < 0 and i == 1) or (dir > 0 and i == #self.rows) then break end
    end
end

function ClassEditor:visibleRows()
    return math.max(1, math.floor((self.h - 30) / ROW_H))
end

function ClassEditor:scrollToCursor()
    local span = self:visibleRows()
    self.scroll = self.scroll or 0
    if self.cursor < self.scroll + 1 then self.scroll = self.cursor - 1 end
    if self.cursor > self.scroll + span then self.scroll = self.cursor - span end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - span)))
end

-- ---------------------------------------------------------------------------

function ClassEditor.new(opts)
    local self = setmetatable({}, ClassEditor)
    self.x, self.y, self.w, self.h = opts.x, opts.y, opts.w, opts.h
    self.fonts = opts.fonts
    -- The company, for the one question on this tab that is not about the body in front of it: a house
    -- opens on the ROSTER's level in its class (Building.houseForClass), because a shelf is the town's
    -- and not one member's.
    self.player = opts.player
    -- WHO CAN ACTUALLY WALK THERE. The trainer button is a door in the city, so it is offered only by
    -- the host that has a city to open -- the Armory (states/hub.lua). The same panel opens on the
    -- overworld and under a battle's deployment, where the town is a day's march away and a button
    -- onto it would be a control that never works.
    self.onVisitTrainer = opts.onVisitTrainer

    -- Split: the class list on the left, the highlighted class in full on the right. The same
    -- proportion the rule editor next door uses, so a tab change does not re-cut the column.
    self.listX = self.x
    self.listW = math.floor(self.w * 0.56)
    self.detailX = self.listX + self.listW + 20
    self.detailW = self.w - self.listW - 20
    self.listY = self.y + 24

    self.cursor = 1
    self.scroll = 0
    self.rows = {}
    self.rowRects = {}

    self:setChar(opts.char)
    return self
end

function ClassEditor:setChar(char)
    self.char = char
    self.cursor = 1
    self.scroll = 0
    self.hoverRow, self.hoverChange = nil, nil
    self:buildRows()
end

-- ---------------------------------------------------------------------------
-- Changing class
-- ---------------------------------------------------------------------------

-- Can this body take the highlighted class as its own? Only an opened class can be highlighted at all
-- (a shut row is unnamed and unpickable), so the only refusal left is the one it is already standing in.
function ClassEditor:canChange()
    local row = self:currentRow()
    if not (row and self.char) then return false end
    return row.id ~= Growth.classOf(self.char)
end

function ClassEditor:changeClass()
    if not self:canChange() then return false end
    self.char.declaredClass = self:currentRow().id
    return true
end

-- ---------------------------------------------------------------------------
-- The trainer
-- ---------------------------------------------------------------------------

-- THE HOUSE BEHIND THE HIGHLIGHTED CLASS -- where it is taught, sold and climbed. Asked of the ROOT the
-- row hangs off rather than of the row: the seven houses are the seven base classes, and a subclass or
-- a crossing is shelved by the parent whose group it is drawn under (models/vendor.lua).
--
-- Nil when this panel was not opened somewhere a player can walk out of, which is the same condition
-- the button draws on -- one reader, so the offer and the act can never disagree about whether there
-- is a town.
function ClassEditor:trainer()
    if not self.onVisitTrainer then return nil end
    local row = self:currentRow()
    if not row then return nil end
    return Building.houseForClass(row.kind == "class" and row.id or row.parent, self.player)
end

-- Walk to it. The host owns everything past this point -- shutting the panel, crossing to the square,
-- playing the house's greeting -- because a widget that knew how to switch states would be a seam built
-- for one room.
function ClassEditor:visitTrainer()
    local house = self:trainer()
    if not (house and house.open) then return false end
    self.onVisitTrainer(house.id, house.class)
    return true
end

-- The floor every readout in the detail column stops at: the top of the button stack under it. One
-- reader, because the stack is one plate tall on the overworld and two in the city, and a blurb that
-- measured itself against a guess at that would run under the buttons on exactly one of them.
function ClassEditor:changeY()
    return self.y + self.h - BUTTON_H - 22
end

function ClassEditor:buttonsTop()
    if self:trainer() then return self:changeY() - BUTTON_H - BUTTON_GAP end
    return self:changeY()
end

-- ---------------------------------------------------------------------------
-- Column-editor contract (see Party:columnEditor)
-- ---------------------------------------------------------------------------

-- One region, so Tab has nothing of its own to walk: the host is told the walk is over on the first
-- press and takes the focus back out to the rail.
function ClassEditor:cycleRegion()
    return false
end

function ClassEditor:isFirstRegion()
    return true
end

function ClassEditor:navigate(dc, dr)
    -- Left/right has nothing to change on a row: the list is the only axis here, and crossing left back
    -- to the rail is the host's business (Party:navigate reads isFirstRegion).
    local _ = dc
    if dr ~= 0 then self:step(dr) end
end

function ClassEditor:confirm()
    self:changeClass()
end

-- THE TAB'S SECOND ACT, on the seam the rule editor next door already uses for its own (F / X, routed
-- by Party:keypressed). A second verb needs a second button on every device, and this one is free on
-- both: the roll has no rule to enable, which is what F does on the other column editor.
function ClassEditor:altConfirm()
    self:visitTrainer()
end

function ClassEditor:cancel()
    return false -- nothing here is held open, so Esc belongs to the panel
end

function ClassEditor:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function ClassEditor:mousemoved(x, y)
    self.hoverRow = nil
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then self.hoverRow = i break end
    end
    self.hoverChange = hit(self.changeRect, x, y)
    self.hoverTrainer = hit(self.trainerRect, x, y)
end

function ClassEditor:wheelmoved(dy)
    local span = self:visibleRows()
    self.scroll = math.max(0, math.min(self.scroll - dy, math.max(0, #self.rows - span)))
end

function ClassEditor:mousepressed(x, y)
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then
            self.cursor = i
            return true
        end
    end
    if hit(self.changeRect, x, y) then
        self:changeClass()
        return true
    end
    -- A shut trainer's plate still swallows the click. It is drawn, so it is a thing the mouse lands
    -- on; letting the press fall through to the panel behind it would read as the panel misbehaving
    -- rather than as the door being shut.
    if hit(self.trainerRect, x, y) then
        self:visitTrainer()
        return true
    end
    return false
end

function ClassEditor:cursorKind(x, y)
    if hit(self.changeRect, x, y) then return "hand" end
    -- The hand appears over an OPEN door only. A shut trainer's plate is a notice, and a pointer that
    -- turned into a hand over it would promise a press that does nothing.
    if hit(self.trainerRect, x, y) then
        local house = self:trainer()
        return (house and house.open) and "hand" or "arrow"
    end
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then return "hand" end
    end
    return "arrow"
end

function ClassEditor:prompts()
    local pad = InputMode.isGamepad()
    local out = {}
    local function add(glyph, label) out[#out + 1] = { glyph = glyph, label = label } end
    add(pad and "D-pad" or "Up/Down", "Pick class")
    -- The one verb, offered only where it is legal: a body already standing in the highlighted class
    -- has nothing to press, and a prompt for it would read as the press having failed.
    if self:canChange() then add(pad and "A" or "Enter", "Change class") end
    -- Same rule for the walk: the prompt stands while the door does. A shut house keeps its plate on
    -- the column, because the plate is what says how to open it -- but there is nothing to press.
    local house = self:trainer()
    if house and house.open then add(pad and "X" or "F", "Class trainer") end
    return out
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function levelColor(level)
    if level >= Class.CLASS_LEVEL_CAP then return Theme.accentAmber end
    if level > 0 then return Theme.ink end
    return Theme.muted
end

function ClassEditor:drawList(focused)
    local x, y, w = self.listX, self.listY, self.listW
    local small, body = self.fonts.small, self.fonts.body

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    love.graphics.print("CLASSES", x, self.y)
    love.graphics.printf("LEVEL", x, self.y, w, "right")

    local span = self:visibleRows()
    self.rowRects = {}

    for i = self.scroll + 1, math.min(#self.rows, self.scroll + span) do
        local row = self.rows[i]
        local ry = y + (i - self.scroll - 1) * ROW_H
        self.rowRects[i] = { x = x, y = ry, w = w, h = ROW_H - 2 }

        local base = row.kind == "class"
        -- The rule that used to belong to the caption row, moved onto the class it captioned: it opens
        -- the group rather than closing the one above, so it goes over the row, not under it.
        if base and i > 1 then
            Theme.set(Theme.frame)
            love.graphics.line(x, ry - 3, x + w, ry - 3)
        end

        -- AN EMPTY SLOT, AND IT LOOKS LIKE ONE. A shut class gets the same rectangle every other row
        -- stands in -- so the list shows the whole ladder at its true length from the first morning --
        -- but drawn as an outline on the stock rather than a filled plate, and never with the cursor's
        -- edge: it is a place waiting to be taken, not a control refusing to be pressed.
        if row.kind == "shut" then
            Theme.set(Theme.frame, 0.35)
            love.graphics.rectangle("line", x + 24, ry, w - 24, ROW_H - 2, 3, 3)
            love.graphics.setFont(small)
            Theme.set(Theme.muted, 0.75)
            love.graphics.print(Theme.ellipsize(row.locked or "Requires more", small, w - 24 - 20),
                x + 34, ry + 7)
        else
            local on = i == self.cursor
            if on then
                Theme.plate(x, ry, w, ROW_H - 2, 3, Theme.panel)
                Theme.set(focused and Theme.cursor or Theme.frame)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            end

            -- TWO INDENTS, NOT THREE. A crossing used to sit one step further in than a subclass, and
            -- that step was a lie the eye believes instantly: indentation means descent, so "Apothecary"
            -- under "Poisoner" read as a leaf of Poisoner. It is not -- both are earned straight off the
            -- base class above them, one from a single parent and one from two, and they are the same
            -- rung. So depth says rank, and a crossing says what it is with the name of its OTHER
            -- parent instead, in the shape the shop and the lineage strip both use ("x Priest").
            local indent = base and 10 or 24
            -- The one tail a named row carries: a crossing's other parent. What is still shut behind a
            -- house used to be counted here and is not counted anywhere now -- it is standing in the list
            -- in its own rows, which is a better answer than a number was.
            local tail = row.cross and ("  x " .. row.cross)
            local tailW = tail and small:getWidth(tail) or 0

            Theme.set(levelColor(row.level))
            -- Set in the display face, which is what is left of the caption: a base class is the head of
            -- its group and reads as one without a row of its own to say so.
            local font, name = Theme.fitText(base and Theme.display or Theme.body, row.name,
                w - indent - 90 - tailW, 15, 12)
            love.graphics.setFont(font)
            love.graphics.print(name, x + indent, ry + 5)

            if tail then
                love.graphics.setFont(small)
                Theme.set(Theme.muted)
                love.graphics.print(tail, x + indent + font:getWidth(name),
                    ry + 5 + font:getHeight() - small:getHeight())
            end

            if self.char and Growth.classOf(self.char) == row.id then
                Theme.set(Theme.accentAmber)
                love.graphics.setFont(body)
                love.graphics.print("*", x + 2, ry + 5)
            end

            love.graphics.setFont(small)
            Theme.set(levelColor(row.level))
            love.graphics.printf(tostring(row.level), x, ry + 6, w - 10, "right")
            -- The bar is the rung, not the career: how far into the level it is standing on. At the cap
            -- there is no span left, so it draws full rather than empty.
            local frac = row.needed > 0 and (row.held / row.needed) or 1
            ProgressBar.draw(x + w - 74, ry + 11, 44, 5, frac, 1,
                { color = row.level >= Class.CLASS_LEVEL_CAP and Theme.accentAmber or Theme.cursor })
        end
    end

    if #self.rows > span then
        love.graphics.setFont(small)
        Theme.set(Theme.muted, 0.5)
        love.graphics.printf(string.format("%d / %d", math.min(#self.rows, self.scroll + span), #self.rows),
            x, y + span * ROW_H + 4, w, "right")
    end
end

-- ---------------------------------------------------------------------------
-- The lineage strip
-- ---------------------------------------------------------------------------

-- WHERE THE HIGHLIGHTED CLASS SITS, drawn rather than said. The list carries the ladder in its
-- indentation, which is enough to sort forty-five rows and not enough to answer "earned from WHAT" --
-- and for a crossing the list cannot answer it at all, because a crossing is filed under BOTH its
-- parents and a player reading down one column never learns there is another.
--
-- THE PICTURE PEOPLE REMEMBER FROM FFT IS NOT IN FFT. Its job screen is a list exactly like the one to
-- the left of this; the branching chart everybody pictures lives in the manual and in twenty years of
-- guides. So this is that chart, cut to the ONE lineage in front of you rather than all forty-five at
-- once -- which is also the only reason it can be drawn at 1280x720 without becoming the plate of
-- spaghetti the header comment refuses.
--
-- THE LADDER IS TWO DEEP, and that is what keeps it bounded: a root has children and no parents, an
-- earned class has parents and no children. One side is always empty, so the strip is never more than
-- a node, a fan, and a tail -- there is no case where it grows a third rank.
local LINE_H = 20
local LINEAGE_MAX = 5 -- fan rows before the rest is counted instead of named

local function arrowHead(x, y)
    love.graphics.polygon("fill", x, y - 3, x + 5, y, x, y + 3)
end

-- One name on the strip. A DOT MARKS A SOURCE AND AN ARROW MARKS A DESTINATION, so a node that is
-- being pointed at takes no dot of its own -- two marks a glyph apart on the same name read as one
-- fussy ornament rather than as two halves of a sentence.
local function lineageNode(text, x, y, w, color, font, level, dot)
    love.graphics.setFont(font)
    Theme.set(color)
    local tx = x + 6
    if dot then
        love.graphics.circle("fill", x + 4, y + 7, 3)
        tx = x + 12
    end
    love.graphics.print(Theme.ellipsize(text, font, w - (tx - x) - 4 - (level and 20 or 0)), tx, y)
    if level then
        Theme.set(Theme.muted)
        love.graphics.printf(tostring(level), x, y, w, "right")
    end
end

-- The left column hugs its widest name rather than taking a fixed share: every name on that side is a
-- root class ("Alchemist", "Mage"), and a column cut to the pane instead of to the words leaves a hand's
-- width of nothing between a name and the line that is supposed to be leaving it.
local function leftColumn(font, w, names)
    local widest = 0
    for _, n in ipairs(names) do widest = math.max(widest, font:getWidth(n)) end
    return math.min(math.floor(w * 0.5), widest + 26)
end

function ClassEditor:drawLineage(row, x, y, w)
    local small, char = self.fonts.small, self.char

    -- The strip yields rather than drawing through the button: a blurb runs as long as it runs, and
    -- the two readouts under this one (where the body stands, what the class grows) are numbers the
    -- decision is made against, where this is the shape around them.
    local avail = math.floor(((self:buttonsTop() - 24) - y) / LINE_H)
    if avail < 2 then return y end

    local parents = Class.parents(row.id)
    if #parents > 0 then
        -- AN EARNED CLASS: its parents feed into it. Two lines converging on one node is the whole
        -- statement a crossing has to make, and the list next door cannot make it at all.
        local n = math.min(#parents, 2)
        local names = {}
        for i = 1, n do names[i] = Item.classDisplayName(parents[i]) end
        local leftW = leftColumn(small, w, names)
        local midX = x + leftW + 12
        local rightX = x + leftW + 30

        local cy = y + ((n - 1) * LINE_H) / 2
        for i = 1, n do
            local py = y + (i - 1) * LINE_H
            lineageNode(names[i], x, py, leftW, Theme.ink, small, nil, true)
            Theme.set(Theme.frame)
            love.graphics.line(x + leftW - 6, py + 7, midX, py + 7)
            love.graphics.line(midX, py + 7, midX, cy + 7)
        end
        Theme.set(Theme.frame)
        love.graphics.line(midX, cy + 7, rightX - 6, cy + 7)
        Theme.set(Theme.accentAmber)
        arrowHead(rightX - 6, cy + 7)
        lineageNode(row.name, rightX, cy, w - (rightX - x), Theme.accentAmber, small)
        return y + n * LINE_H + 12
    end

    -- A ROOT: what it opens, fanned out. Same reading as the rows below its header, so what this adds
    -- is the OTHER parent of each crossing -- the half of a crossing the list is structurally unable to
    -- print, since it files the same class under two houses and shows one at a time.
    -- ONLY WHAT IS OPEN IS FANNED. What is shut is named nowhere, here least of all: this strip draws
    -- names, and a name is the one thing a shut class does not give up (see the header). The list is
    -- where those stand, as their requirement.
    local open = childrenOf(row.id, char)
    local fan = {}
    local cap = math.min(LINEAGE_MAX, avail)
    local shown = math.min(#open, math.max(0, cap))
    if #open > shown then shown = math.max(0, shown - 1) end
    for i = 1, shown do fan[#fan + 1] = { id = open[i] } end
    if #open > shown then fan[#fan + 1] = { tail = (#open - shown) .. " more open" } end
    if #fan == 0 then return y end

    local m = #fan
    local leftW = leftColumn(small, w, { row.name })
    local midX = x + leftW + 12
    local rightX = x + leftW + 30
    local rightW = w - (rightX - x)

    local cy = y + ((m - 1) * LINE_H) / 2
    lineageNode(row.name, x, cy, leftW, Theme.accentAmber, small, nil, true)
    Theme.set(Theme.frame)
    love.graphics.line(x + leftW - 6, cy + 7, midX, cy + 7)
    love.graphics.line(midX, y + 7, midX, y + (m - 1) * LINE_H + 7)

    for i, r in ipairs(fan) do
        local ry = y + (i - 1) * LINE_H
        Theme.set(Theme.frame)
        love.graphics.line(midX, ry + 7, rightX - 6, ry + 7)
        if r.id then
            arrowHead(rightX - 6, ry + 7)
            local label = Class.displayName(r.id)
            for _, p in ipairs(Class.parents(r.id)) do
                -- The shop writes a crossing the same way ("rogue x mage"), so a player meets one
                -- shape for the idea whether they are reading a shelf or a ladder.
                if p ~= row.id then label = label .. "  x " .. Item.classDisplayName(p) end
            end
            local level = char and select(3, Class.classProgress(char, r.id)) or nil
            lineageNode(label, rightX, ry, rightW, Theme.ink, small, level)
        else
            love.graphics.setFont(small)
            Theme.set(Theme.muted)
            love.graphics.print(r.tail, rightX + 6, ry)
        end
    end
    return y + m * LINE_H + 12
end

-- A stat's own figure on this body, gear left out: growth is baked into the base number
-- (models/growth.lua bakes into `.max` for a resource pool), so the base is the figure the gain
-- actually lands on and the only one the arrow below can honestly point away from.
local function baseStat(char, key)
    local value = char and char.stats and char.stats[key]
    if type(value) == "table" then return value.max end
    if type(value) == "number" then return value end
    return nil
end

-- WHAT STANDING IN THIS CLASS BUYS, PER LEVEL. Every class has a table of its own
-- (data/growth/<id>.lua, one file per class, whole numbers and no RNG) and models/growth.lua applies it
-- whole at every level-up, so this is not an estimate of the coming level -- it is the table that gets
-- applied, read straight off the same def.
--
-- It is the number the choice on this screen is actually made against. Everything else in the column
-- says what a class IS; a level in the wrong house is the only thing here the player cannot take back,
-- and until this was drawn it was the one figure the screen did not print.
--
-- WRITTEN AS A TRANSITION, never as "+6". The sheet next door learned that the hard way: a signed
-- figure parked beside a value is the universal "this is buffed right now" idiom, and a permanent one
-- reads as a bonus already in effect. "70 → 76" can only mean what it says.
--
-- STATS THAT DO NOT GROW ARE NOT DRAWN. A growth table lists only what it buys -- a mage's `damage` is
-- absent and that is correct rather than a gap -- so a full nine rows would be four fifths zeroes on
-- every class, and the shape of a house would be buried in them. What is drawn IS the shape.
function ClassEditor:drawGrowth(id, x, y, w)
    local def, char = Growth.defs[id], self.char
    if not (def and char) then return y end
    local small = self.fonts.small

    -- THE BODY'S OWN POINTS ARE FOLDED IN, not shown beside. What this readout promises is what the
    -- next level does to the numbers on the left, and a figure that quietly excluded the two points
    -- this particular body adds every level would be wrong on every row it touched. The comparison
    -- between classes survives it untouched: a personal table is the same constant under every row on
    -- the list, so what still differs between two of them is exactly the class.
    local personal = Growth.personal(char)
    if personal then
        local merged = {}
        for stat, amount in pairs(def) do merged[stat] = amount end
        for stat, amount in pairs(personal) do merged[stat] = (merged[stat] or 0) + amount end
        def = merged
    end

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    Theme.printTracked("GROWTH PER LEVEL IN THIS CLASS", x, y, w, 1)
    y = y + 18

    local colW = w / 2
    local n = 0
    for _, row in ipairs(GROWTH_ROWS) do
        local gain = def[row.key] or 0
        local from = baseStat(char, row.key)
        if gain > 0 and from then
            local cx = x + (n % 2) * colW
            Theme.set(Theme.muted)
            love.graphics.print(row.label, cx, y)

            -- Right-aligned as one unit, exactly as the sheet's forecast is: the two figures and the
            -- arrow between them are one reading, and splitting the alignment would let the eye take
            -- the target for a column of its own.
            local text = from .. " " .. ARROW .. " " .. (from + gain)
            love.graphics.setColor(ANNOT_PENDING)
            love.graphics.printf(text, cx, y, colW - 12, "right")

            n = n + 1
            if n % 2 == 0 then y = y + 20 end
        end
    end
    if n % 2 == 1 then y = y + 20 end

    -- ...and it says whose points are in there. Folding them in silently would leave a player who
    -- compares this screen against a generic of the same house reading a discrepancy with no name on
    -- it -- and the whole reason a companion carries a table is so that she is legibly not the
    -- generic. Named, not itemized: the figures above are the answer, this is the footnote.
    if personal then
        local parts = {}
        for _, row in ipairs(GROWTH_ROWS) do
            local amount = personal[row.key]
            if amount then parts[#parts + 1] = "+" .. amount .. " " .. row.label end
        end
        love.graphics.setFont(small)
        Theme.set(Theme.muted, 0.75)
        love.graphics.printf(string.format("Includes %s's own %s, kept in any class.",
            char.name or "this body", table.concat(parts, " and ")), x, y, w, "left")
        y = y + small:getHeight() + 4
    end

    return y + 6
end

-- WHAT STANDING HERE DOES TO THE CLIMB, which is the other half of the choice and the half that used
-- to be invisible. Growth is slow and cumulative; this is the rule that makes the badge matter to the
-- next action (Class.TECHNIQUE_DECLARED_SHARE, and Combat.awardTechnique for the split itself).
--
-- IT IS SAID IN THE NUMBERS IT IS ACTUALLY MADE OF, in plain words. "Your declared class earns
-- technique faster" is a sentence a player cannot plan against; "each action earns 2: 1 for this class,
-- 1 for the class of the item used" is one they can. The figures are read off the constants rather than
-- typed, so a retune moves the sentence with the rule instead of leaving prose that used to be true.
--
-- Yields when the pane is short, exactly as the lineage strip above it does: what a class GROWS and
-- where this body STANDS are the two readouts the decision cannot be made without, and this is the
-- explanation that goes with them.
function ClassEditor:drawTechniqueRule(row, x, y, w)
    local small = self.fonts.small
    local per, share = Class.TECHNIQUE_PER_ACTION, Class.TECHNIQUE_DECLARED_SHARE
    if share <= 0 then return y end

    -- The split first, then the case where both halves land on the same class, because that case is
    -- the one a player reads as an exception unless it is stated. Both sentences are arithmetic on the
    -- same two constants -- no metaphor for the player to translate before they can plan.
    local text = string.format(
        "Each action earns %d technique: %d for this class, %d for the class of the item used. "
        .. "Using this class's own items earns all %d here.", per, share, per - share, per)

    local _, lines = small:getWrap(text, w)
    local h = small:getHeight() * math.max(1, #lines)
    -- Measured against the BUTTON STACK's own top edge (see drawDetail), not a guess at it: the strip
    -- above reserved an extra two dozen pixels it did not need, and the first thing that cost was this
    -- line going silently missing on a pane that had room for it.
    if y + h > self:buttonsTop() - 6 then return y end

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    love.graphics.printf(text, x, y, w, "left")
    return y + h + 10
end

function ClassEditor:drawDetail()
    local x, y, w = self.detailX, self.y, self.detailW
    local row, char = self:currentRow(), self.char
    self.changeRect, self.trainerRect = nil, nil
    if not row then return end
    local small, body = self.fonts.small, self.fonts.body

    local font, name = Theme.fitText(Theme.display, row.name, w, 18, 13)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.print(name, x, y)

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    local kindLabel = row.kind == "class" and "Base class"
        or row.kind == "subclass" and ("Subclass of " .. Item.classDisplayName(row.parent))
        or "Crossing"
    love.graphics.print(kindLabel, x, y + 26)

    local ty = y + 50

    -- What the path IS. A class collapses to a name and a number everywhere else in the game; this is
    -- the one screen with room to say why anyone would want it.
    local blurb = row.kind ~= "class" and Class.description(row.id) or Item.classDescription(row.id)
    if type(blurb) == "string" then
        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        love.graphics.printf(blurb, x, ty, w, "left")
        local _, lines = small:getWrap(blurb, w)
        ty = ty + small:getHeight() * math.max(1, #lines) + 14
    end

    Theme.set(Theme.frame)
    love.graphics.line(x, ty, x + w, ty)
    ty = ty + 12

    -- Where it sits on the ladder, before anything about this particular body: the shape is a fact
    -- about the class, and the numbers under it are facts about the member standing in front of it.
    ty = self:drawLineage(row, x, ty, w)

    -- This body's standing on it, as a transition rather than a bare figure: what the next rung costs
    -- is the number a player is actually deciding against.
    if char then
        love.graphics.setFont(body)
        Theme.set(Theme.ink)
        love.graphics.print((char.name or "?") .. ": " .. row.name .. " " .. tostring(row.level), x, ty)
        ty = ty + 22

        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        if row.level >= Class.CLASS_LEVEL_CAP then
            love.graphics.print("Mastered.", x, ty)
            ty = ty + 22
        else
            love.graphics.print(string.format("%d / %d to %d", row.held, row.needed, row.level + 1), x, ty)
            ProgressBar.draw(x, ty + 18, w, 6, row.needed > 0 and row.held / row.needed or 0, 1,
                { color = Theme.cursor })
            ty = ty + 40
        end

        ty = self:drawGrowth(row.id, x, ty, w)
        ty = self:drawTechniqueRule(row, x, ty, w)

        if Growth.classOf(char) == row.id then
            love.graphics.setFont(small)
            Theme.set(Theme.accentAmber)
            love.graphics.print("Standing here. This is what is being applied.", x, ty)
        end
    end

    -- THE OTHER DOOR OUT OF THIS COLUMN: the house where this class is taught, sold and climbed. It
    -- stands above the act, because changing class is what you do HERE and the trainer is where you go
    -- next.
    --
    -- AND IT IS DRAWN SHUT, which is the one greyed plate on this tab and deliberately the exception to
    -- the rule under it. A house that has not opened is not refusing the press, it is naming the level
    -- that opens it -- "Unlock trainer at Knight lvl 1" is the only place in the game that sentence is
    -- said on the class's own screen, and it is said to the player who is standing there deciding
    -- whether to climb. Take the plate away and the gate is invisible until the door appears.
    local house = self:trainer()
    if house then
        local by = self:buttonsTop()
        self.trainerRect = { x = x, y = by, w = w, h = BUTTON_H }
        Theme.plate(x, by, w, BUTTON_H, 4, (house.open and self.hoverTrainer) and Theme.panel or Theme.panel2)
        Theme.set(Theme.frame, house.open and 1 or 0.4)
        love.graphics.rectangle("line", x, by, w, BUTTON_H, 4, 4)
        love.graphics.setFont(body)
        if house.open then
            Theme.set(Theme.ink)
            love.graphics.printf("Go to Class Trainer", x, by + 9, w, "center")
        else
            -- The class is named because it is not the class on the row: a subclass is taught at its
            -- parent's house, so "lvl 1" alone would read as a level in the thing being looked at.
            Theme.set(Theme.muted, 0.55)
            love.graphics.printf(string.format("Unlock trainer at %s lvl %d",
                Item.classDisplayName(house.class) or house.class, house.need or 1), x, by + 9, w, "center")
        end
    end

    -- THE ONE ACT ON THIS TAB, and it draws only where it is legal: a body already standing in this
    -- class has nothing to press. A greyed plate would be a control that is never pressable pretending
    -- to be one that is -- where the trainer's plate above is not a control at all while it is shut.
    if self:canChange() then
        local by = self:changeY()
        self.changeRect = { x = x, y = by, w = w, h = BUTTON_H }
        Theme.plate(x, by, w, BUTTON_H, 4, self.hoverChange and Theme.panel or Theme.panel2)
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("line", x, by, w, BUTTON_H, 4, 4)
        love.graphics.setFont(body)
        love.graphics.printf("Change to " .. row.name, x, by + 9, w, "center")
    end
end

function ClassEditor:draw(focused)
    self:drawList(focused ~= false)
    self:drawDetail()
    love.graphics.setColor(1, 1, 1)
end

return ClassEditor
