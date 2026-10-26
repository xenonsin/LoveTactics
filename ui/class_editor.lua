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
-- THREE COLUMNS, and each answers one question:
--
--   WHERE  the seven houses and nothing else, each with the level this body holds in it and what it
--          has open. Seven rows, so this column never scrolls and never moves.
--   WHAT   one house's shelf: the base class, the cuts of it this body has opened, and the ones still
--          shut by the requirement that opens them.
--   WHY    the highlighted class in full -- what the path is, what it grows, and what this body has
--          done in it.
--
-- THE HOUSES COLUMN IS WHAT THE LIST USED TO SCROLL PAST. Forty-five classes under seven parents,
-- with every crossing filed under BOTH of them, is sixty-six rows -- and on a body just hired,
-- fifty-nine of those are shut rows carrying nothing but the requirement that opens them. Thirteen
-- fit the column. So the ladder was five screens of grey, and the shape of a house -- which is the
-- thing the player is actually choosing between -- was the one thing that could not be seen at once.
-- Cutting the houses out into a column of their own puts the whole game on screen in seven rows and
-- leaves the second column holding one house at a time, which fits without scrolling at all.
--
-- A HOUSE ROW SAYS THE LEVEL AND NOTHING ELSE. It carried a count of what stands open behind it for a
-- while ("2 open, 6 ahead"), which was defensible -- a count in front of rows that are one keypress
-- away is not the count this file's header refuses, the one offered INSTEAD of the rows -- but it was
-- a second line of small grey figures on every row of the column you read first, answering a question
-- the next column answers better, by name. The rows are the answer; the house is just the door.
--
-- IT IS A LIST, NOT A LATTICE, and that is a decision rather than a shortcut. Forty-five classes across
-- seven parents with twenty-one crossings between them is a real graph, and drawn as one at 1280x720
-- it is a plate of spaghetti nobody can read a number off. FFT's own version of this screen is a list
-- too, for the same reason: what a player actually does here is compare one class's level against the
-- rung above it, and a list puts those two numbers on one line.
--
-- A LOCKED CLASS STANDS IN THE LIST NAMED. It holds the place it will take and carries both halves of
-- what a player wants off it: WHAT it is, and what opens it. The name was withheld for a while -- a
-- shut row printed its gate and nothing else, on the theory that the name is the thing the work is for
-- and so the thing to keep back. That is a good rule for a reward and a bad one for a DESTINATION:
-- "Knight 5 + Rogue 5" is a price with nothing named on the other side of it, and a player deciding
-- which house to climb this afternoon is choosing between names. The shop's shelf names the same paths
-- on the same gates (ui/panels/shop.lua), so the two screens now say one thing.
--
-- A SHUT ROW IS STILL NOT PICKABLE. The cursor steps over it and the mouse will not take it: what
-- selecting a row does is open the detail column -- the blurb, the lineage, the growth table, every
-- figure of which is about a class this body HAS. The row says what it is and what it costs, which is
-- the whole of what can be true about it yet.
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
local Player = require("models.player") -- packOpen (town only), the seal count, the first free seal
local Locale = require("models.locale") -- the coach line's catalog seam
local InputMode = require("input_mode")

-- THE UNLOCK CEREMONY (agent C's card, ui/levelup_card.lua). Required softly: the tab works without it,
-- the unlock simply plays no card.
local okCard, LevelupCard = pcall(require, "ui.levelup_card")
if not okCard then LevelupCard = nil end
local okGift, GiftCard = pcall(require, "ui.gift_card")
if not okGift then GiftCard = nil end

local ClassEditor = {}
ClassEditor.__index = ClassEditor

local ROW_H = 30
-- One line -- the name and its level -- and deliberately NOT the shelf's ROW_H: the two columns share
-- a top edge, so equal rows would line house i up with class i and draw a pairing that does not exist.
local HOUSE_ROW_H = 34
local COL_GAP = 20
-- The shelf's left gutter: the step an earned class hangs off its base. It held each row's gate as a
-- bare integer until 2026-10-26; a shut row carries its gate as a pill on the right now ("Fighter 3",
-- or "Ready" once it can be unlocked), so the gutter is indent and nothing else.
local GUTTER_W = 30
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

-- ---------------------------------------------------------------------------
-- What a class looks like before you take it (the 2026-10-26 pass)
-- ---------------------------------------------------------------------------
--
-- THE TAB USED TO SELL NOTHING. Everything a player gets for a class -- the stat boost, the ability
-- the unlock hands over, the gear its house deals -- was shown on the unlock card AFTER the choice, and
-- the screen in front of the choice was a ledger of greyed names and gate numbers. The pieces below
-- put those three things on the screen before the press: the same data the ceremony reads
-- (Class.boostFor, Class.giftFor) and the real shelf (Item.defs by `class`), so a preview can never
-- promise what the unlock does not give.

local function rootOf(id)
    if not id or Class.isRoot(id) then return id end
    return Class.parents(id)[1]
end

-- EACH ROOT WEARS ITS HOUSE'S COLOUR AND MARK (ui/vendor_icons.lua), so the seven houses stop reading as
-- one grey list: a bar on the house row, the band under the detail's name, the crest on a first-pick
-- card. They are the colours and marks the counters already title themselves with, so a player meets
-- one identity per house rather than a second palette made up for this tab. A subclass or a crossing
-- wears its first parent's.
local VendorIcons = require("ui.vendor_icons")
local function houseVendor(id)
    local root = rootOf(id)
    return root and require("models.vendor").forClass(root) or nil
end

local colorCache = {}
local function crestColor(id)
    local root = rootOf(id) or ""
    if colorCache[root] == nil then
        local r, g, b = VendorIcons.color(houseVendor(id))
        colorCache[root] = r and { r, g, b } or false
    end
    return colorCache[root] or Theme.frame
end

-- WHAT A CLASS'S SHELF OPENS ON: the first pieces filed under it, lowest rung first and weapons
-- before abilities before kit inside a rung, because "what will I be swinging" is the first question.
-- Read off Item.defs by `class` -- the same field the vendor shelves on -- and instanced once per class
-- (for the sprite and the hover card), so the preview is the real shelf rather than a list kept beside it.
local SHELF_ORDER = { weapon = 1, ability = 2, armor = 3, utility = 4, consumable = 5 }
local SHELF_MAX = 8
local shelfCache = {}

local function shelfPreview(id)
    if not id then return {} end
    local cached = shelfCache[id]
    if cached then return cached end
    local defs = {}
    for itemId, def in pairs(Item.defs) do
        if def.class == id and SHELF_ORDER[def.type] then defs[#defs + 1] = { id = itemId, def = def } end
    end
    table.sort(defs, function(a, b)
        local la, lb = a.def.unlockLevel or 0, b.def.unlockLevel or 0
        if la ~= lb then return la < lb end
        local ta, tb = SHELF_ORDER[a.def.type], SHELF_ORDER[b.def.type]
        if ta ~= tb then return ta < tb end
        return a.id < b.id
    end)
    cached = {}
    for i = 1, math.min(#defs, SHELF_MAX) do cached[i] = Item.instantiate(defs[i].id) end
    shelfCache[id] = cached
    return cached
end

-- THE CREST: drawn art when it exists (a root's `crest` path, data/classes/<id>.lua -- `. art-report`
-- counts the missing ones), and until then the house's own mark in its colour.
local function drawCrest(id, x, y, w, h, alpha)
    local root = rootOf(id)
    local def = root and Class.defs[root]
    local color = crestColor(id)
    Theme.set(color, 0.2 * (alpha or 1))
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    local img = def and def.crest and require("models.sprite").load(def.crest)
    if type(img) == "userdata" then
        love.graphics.setColor(1, 1, 1, alpha or 1)
        local sw, sh = img:getDimensions()
        local s = math.min((h - 6) / sw, (h - 6) / sh)
        love.graphics.draw(img, x + w / 2, y + h / 2, 0, s, s, sw / 2, sh / 2)
        return
    end
    local size = h - 10
    VendorIcons.draw(houseVendor(id), x + (w - size) / 2, y + 5, size, size, color[1], color[2], color[3], alpha or 1)
end

-- One item's icon in a square, its sprite fitted inside or its initial where the art is missing.
local function drawItemIcon(item, x, y, size, ring, font)
    Theme.fill(Theme.panel2, x, y, size, size, 4)
    local sprite = item and item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local s = math.min((size - 6) / sw, (size - 6) / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, s, s, sw / 2, sh / 2)
    elseif font then
        love.graphics.setFont(font)
        Theme.set(Theme.muted)
        love.graphics.printf(((item and item.name) or "?"):sub(1, 1), x, y + (size - font:getHeight()) / 2, size, "center")
    end
    Theme.set(ring or Theme.frame)
    love.graphics.rectangle("line", x, y, size, size, 4, 4)
end

-- A row of stat gains as chips ("+4 HP"), in the sheet's stat order, wrapping inside `w`. Returns the y
-- under the last line. `dry` measures without drawing, so a block can ask whether it fits first.
local function drawChips(stats, x, y, w, font, dry)
    local h = font:getHeight() + 4
    local cx, cy, any = x, y, false
    for _, row in ipairs(GROWTH_ROWS) do
        local v = stats and stats[row.key]
        if v and v > 0 then
            any = true
            local text = "+" .. v .. " " .. row.label
            local cw = font:getWidth(text) + 12
            if cx > x and cx + cw > x + w then cx, cy = x, cy + h + 4 end
            if not dry then
                love.graphics.setColor(ANNOT_PENDING[1], ANNOT_PENDING[2], ANNOT_PENDING[3], 0.16)
                love.graphics.rectangle("fill", cx, cy, cw, h, h / 2, h / 2)
                love.graphics.setColor(ANNOT_PENDING)
                love.graphics.setFont(font)
                love.graphics.print(text, cx + 6, cy + 2)
            end
            cx = cx + cw + 4
        end
    end
    return any and (cy + h) or y
end

-- Two stat tables with the same figures? (A root's boost IS one level of its growth.)
local function sameStats(a, b)
    if not (a and b) then return false end
    for k, v in pairs(a) do if (b[k] or 0) ~= v then return false end end
    for k, v in pairs(b) do if (a[k] or 0) ~= v then return false end end
    return true
end

-- "a Fighter", "an Alchemist".
local function withArticle(name)
    return ((name or ""):match("^[AEIOUaeiou]") and "an " or "a ") .. (name or "")
end

-- A block's caption, LEFT-aligned over the block it heads (Theme.printTracked centres in the width it
-- is handed, so it is handed exactly the tracked word).
local function caption(text, x, y, w, font)
    love.graphics.setFont(font)
    Theme.set(Theme.accentAmber, 0.9)
    Theme.printTracked(text, x, y, font:getWidth(text) + (#text - 1), 1)
    return y + font:getHeight() + 6
end

-- A checklist mark, drawn rather than typed: a tick for met, an empty ring for not yet. `cy` is the
-- line's middle.
local function checkMark(x, cy, met)
    if met then
        love.graphics.setColor(ANNOT_PENDING)
        love.graphics.setLineWidth(2)
        love.graphics.line(x, cy, x + 3, cy + 3, x + 9, cy - 4)
        love.graphics.setLineWidth(1)
    else
        Theme.set(Theme.muted)
        love.graphics.circle("line", x + 4, cy, 4)
    end
end

-- The seven root classes, in a fixed order. Class.roots() is keyed by id and `pairs` over it is
-- unspecified, so a list that reordered itself between two openings of the same panel would read as a
-- bug -- and this is a screen the player learns the shape of.
-- THE NOVICE STANDS FIRST, above the seven: it is where every body starts and every root is unlocked
-- from (Class.canUnlock), so it heads the rail as the trunk the houses branch off.
local function classOrder()
    local out = {}
    for id in pairs(Class.roots()) do out[#out + 1] = id end
    table.sort(out)
    for id in pairs(Class.defs) do
        if Class.isStarter(id) then table.insert(out, 1, id) end
    end
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
-- shut rows are ordered on, in preference to their names: what a player reads a shut group for is what
-- to climb NEXT, and cheapest-first is that order -- alphabetical would scatter the near ones through
-- the far ones and the group would read as a pile.
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

-- WHAT OPENS A CLASS THIS BODY CANNOT HAVE YET, split into the two halves the row draws in different
-- places: the level wanted in the house whose shelf this is, and -- for a crossing -- the OTHER house
-- and the level wanted there.
--
-- THE WORD "REQUIRES" IS GONE, AND SO IS THE HOUSE'S OWN NAME. Every gate under a house is a level in
-- that house, so a shelf of nine rows used to print "Requires Knight lvl" nine times and vary one
-- integer; sixty-six rows of that was most of what the screen said. The column is captioned with the
-- house now, and the integer stands in a gutter of its own, which is a column the eye can run down.
-- What is left on the row is the only part that differs between two shut rows: the second house.
--
-- IT NAMES THE LEVELS AND STOPS THERE, though a crossing is also gated on holding a subclass of each
-- parent (Class.isUnlocked). That second rule is not dropped, it is implied: the cheapest subclass in
-- every house opens at 3, and no crossing asks less than 6 of a parent -- so a body that meets the
-- levels has met the subclass rule on the way past. A second clause would be a line the player can
-- never fail.
local function lockParts(id, house)
    local requires = (Class.defs[id] or {}).requires or {}
    local gate = requires[house]
    local tail
    for _, parent in ipairs(Class.parents(id)) do
        if parent ~= house then
            tail = "+ " .. Item.classDisplayName(parent) .. " " .. tostring(requires[parent] or 0)
        end
    end
    return gate, tail
end

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- THE SEVEN HOUSES, which is the whole game in seven rows. Every figure on one is about the ROOT
-- rather than about what hangs off it -- the level this body holds in it -- because the choice this
-- column is for is which house to read, not which class to take. What the house has open is the next
-- column's answer, drawn row by row with the classes' own names on (see drawHouses).
function ClassEditor:buildHouses()
    self.houses = {}
    for _, id in ipairs(classOrder()) do
        local held, needed, level = 0, 0, 0
        if self.char then held, needed, level = Class.classProgress(self.char, id) end
        self.houses[#self.houses + 1] = {
            id = id, name = Item.classDisplayName(id),
            level = level, held = held, needed = needed,
        }
    end
end

function ClassEditor:currentHouse()
    return self.houses and self.houses[self.house]
end

-- Is the body standing in this house? A crossing hangs off two of them and is marked on BOTH, which is
-- the same answer the shelf gives about where it is sold (models/vendor.lua).
function ClassEditor:standsIn(houseId)
    local declared = self.char and Growth.classOf(self.char)
    if not declared then return false end
    if declared == houseId then return true end
    for _, parent in ipairs(Class.parents(declared)) do
        if parent == houseId then return true end
    end
    return false
end

-- Every class on ONE house's shelf, flattened into drawable rows: the base class, then whichever of
-- its subclasses and crossings this body has opened, then the ones it has not.
--
-- THE BASE CLASS IS ITS OWN GROUP HEADING. It used to be two rows -- a chrome caption reading
-- "ALCHEMIST" and, directly under it, a pickable row reading "Alchemist" -- which spent a third of the
-- list saying every name twice and left the caption looking like the thing you clicked. One row: the
-- rule above it and the face it is set in do the group, the level and bar on it do the row.
--
-- Built fresh per body rather than once per panel, because every number on a row -- level, progress --
-- is a question about ONE character, and a cached list would answer it about whoever was on the rail
-- when the tab was first opened. Rebuilt again on every house change, for the same reason.
function ClassEditor:buildRows()
    self.rows = {}
    local char = self.char
    local house = self:currentHouse()
    if not house then return end

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

        -- An opened row keeps the gate that opened it, so the gutter reads as one ladder rather than as
        -- a column that only fills in below the standing. A base class is ungated and has none.
        local gate = parent and (lockParts(id, parent))

        self.rows[#self.rows + 1] = {
            id = id, kind = kind, parent = parent, cross = cross, gate = gate,
            name = kind == "class" and (Item.classDisplayName(id) or Class.displayName(id))
                or Class.displayName(id),
            level = level, held = held, needed = needed,
            -- A base class is no longer held from the first morning: it is unlocked per body like
            -- everything else (Class.isUnlocked), so its row can stand shut under its own name.
            unlocked = (char and Class.isUnlocked(char, id)) or false,
        }
    end

    -- A place on the list for a class this body has not opened: its name, and what opens it. It carries
    -- no id, which is not the same withholding the name used to be -- an id is how the panel asks
    -- questions ABOUT a body's standing in a class (the detail column, the growth table, the change
    -- press), and every one of those is a question this row has no answer to.
    local function shutEntry(id, parent)
        local gate, tail = lockParts(id, parent)
        local held, needed, level = 0, 0, 0
        if char then held, needed, level = Class.classProgress(char, id) end
        self.rows[#self.rows + 1] = {
            id = id, kind = "shut", parent = parent, gate = gate, locked = tail,
            name = Class.displayName(id) or id,
            level = level, held = held, needed = needed, unlocked = false,
        }
    end

    local class = house.id
    local open, shut = childrenOf(class, char)

    -- A base class is never gated itself -- everyone may be a knight -- so it is always the named,
    -- pickable head of its shelf, whatever is still shut underneath it.
    entry(class, "class", nil)

    for _, id in ipairs(open) do
        entry(id, Class.arity(id) == 2 and "multiclass" or "subclass", class)
    end
    for _, id in ipairs(shut) do
        shutEntry(id, class)
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
-- A SHUT ROW IS PICKABLE NOW, which reverses the header's rule on purpose: a class is unlocked per body
-- with a deed and a Charter Seal, so the detail column has something true to say about a shut class --
-- what it asks, how far this body is toward it, and the Unlock press once it is met.
function ClassEditor:isSelectable(i)
    local row = i and self.rows[i]
    return row ~= nil and row.id ~= nil
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
    -- The panel's growth peek (G / left stick, Party:growthPeeking): while it is on, the growth chips
    -- give way to the transitions they add up to ("+4 (62 → 66)"). Hover does the same for the mouse.
    self.growthPeeking = opts.growthPeeking
    self.previewRects = {}
    self.cardRects = {}

    -- Three columns across what the Armory gives this tab: the houses, one house's shelf, and the
    -- highlighted class in full. FIXED WIDTHS rather than shares, because the first two are sized by
    -- what they hold -- seven house names, and one shelf of class names -- and only the last one has
    -- any use for whatever is left over.
    self.houseX, self.houseW = self.x, 216
    self.listX = self.houseX + self.houseW + COL_GAP
    self.listW = 300
    self.detailX = self.listX + self.listW + COL_GAP
    self.detailW = self.x + self.w - self.detailX
    self.listY = self.y + 24

    self.house = 1
    -- Which column the keyboard is in. It opens on the houses, because that is the first question the
    -- screen asks and the one the second column is an answer to.
    self.region = "houses"
    self.cursor = 1
    self.scroll = 0
    self.rows = {}
    self.houses = {}
    self.rowRects = {}
    self.houseRects = {}

    self:setChar(opts.char)
    return self
end

-- OPEN ON WHAT THE BODY ALREADY IS, which is the one row on this screen the player did not have to
-- go looking for.
--
-- The tab used to open on house 1, row 1 -- the Alchemist's base class -- for every body on the
-- roster, so a Knight reading their own ladder arrived on somebody else's shelf and had to find
-- themselves before the screen said anything about them. That is a whole column of navigation spent
-- before the first question ("what am I now") is even answered, and it is answered by a cursor.
--
-- BOTH COLUMNS MOVE, because the house is half the answer: a crossing hangs off two shelves and a
-- subclass off one, so the row cannot be reached without opening the shelf it is filed under first.
-- A crossing takes whichever of its parents comes first in the rail's order -- either is correct, and
-- the row itself carries the other (buildRows' `cross`).
--
-- FAILS SOFT AND STAYS PUT. A classless body (the avatar before it declares -- Growth.NEUTRAL_CLASS),
-- a class with no house on the rail, a row that is somehow not selectable: each leaves the cursor
-- exactly where it was, which is the old behaviour and a perfectly readable screen.
function ClassEditor:focusCurrent()
    local declared = self.char and Growth.classOf(self.char)
    if not (declared and self.houses) then return end

    local function houseIndex(id)
        for i, h in ipairs(self.houses) do if h.id == id then return i end end
        return nil
    end
    local idx = houseIndex(declared)
    if not idx then
        for _, parent in ipairs(Class.parents(declared)) do
            idx = idx or houseIndex(parent)
        end
    end
    if not idx then return end

    self.house = idx
    self:buildRows()
    for i, row in ipairs(self.rows) do
        if row.id == declared and self:isSelectable(i) then
            self.cursor = i
            self:scrollToCursor()
            return
        end
    end
end

function ClassEditor:setChar(char)
    self.char = char
    self.card, self.pendingGift = nil, nil
    if char then Class.grandfather(char) end
    self.cursor = 1
    self.scroll = 0
    self.hoverRow, self.hoverHouse, self.hoverChange = nil, nil, nil
    self:buildHouses()
    self:buildRows()
    -- ...and then onto the body itself. After the two builds rather than instead of them: focusCurrent
    -- reads the house rail it is choosing from, and re-builds the row list once it has moved.
    self:focusCurrent()
    -- THE FIRST PICK NEVER OPENS ON THE NOVICE, the one class it cannot choose: it opens on the first
    -- of the seven cards.
    if self:firstPick() then self:pickCard(1) end
end

-- ---------------------------------------------------------------------------
-- The first pick: seven cards instead of the ledger
-- ---------------------------------------------------------------------------
--
-- THE AVATAR'S FIRST CLASS IS CHOSEN FROM A SPREAD, not from the three columns. The ledger opened on
-- the Novice -- the one class the pick cannot take -- with a houses column of eight identical grey
-- names, a shelf of one row, and a detail pane about Novice growth; the only call to action was a coach
-- line in the corner. The seven roots stand side by side as cards now, each showing what it pays and
-- what it starts you with, and the picked one opens underneath with its gear.
--
-- IT IS A VIEW OVER THE SAME STATE, not a second flow. A card is a house: picking one opens that house
-- and puts the cursor on its base class, so the press, the unlock, the free-pick rule and the two cards
-- that play after are all the ledger's own, unchanged. Once the pick is spent (Class.pickOwed) the tab
-- is the ledger again.
function ClassEditor:firstPick()
    return self.char ~= nil and self.player ~= nil and not self:readOnly()
        and Class.pickOwed(self.player, self.char) == true
end

-- The house indices the cards stand for: every root on the rail, in the rail's order.
function ClassEditor:cardHouses()
    local out = {}
    for i, house in ipairs(self.houses or {}) do
        if Class.isRoot(house.id) then out[#out + 1] = i end
    end
    return out
end

function ClassEditor:cardIndex()
    for i, idx in ipairs(self:cardHouses()) do
        if idx == self.house then return i end
    end
    return nil
end

function ClassEditor:pickCard(i)
    local cards = self:cardHouses()
    if #cards == 0 then return end
    i = math.max(1, math.min(#cards, i))
    self:setHouse(cards[i])
    self.region = "classes"
    self.cursor = 1 -- the base class heads every shelf (buildRows)
    self:scrollToCursor()
end

-- Open a house's shelf. The cursor goes back to the top of it rather than holding its index across the
-- change: the row that was under it belonged to the house being left, and a cursor that stayed put
-- would land on an unrelated class of the same depth.
function ClassEditor:setHouse(i)
    i = math.max(1, math.min(#self.houses, i))
    if i == self.house then return end
    self.house = i
    self.cursor = 1
    self.scroll = 0
    self:buildRows()
end

function ClassEditor:stepHouse(dir)
    self:setHouse((self.house or 1) + dir)
end

-- ---------------------------------------------------------------------------
-- Changing class
-- ---------------------------------------------------------------------------

-- Can this body take the highlighted class as its own? Only an opened class can be highlighted at all
-- (a shut row is named but unpickable), so the only refusal left is the one it is already standing in.
-- UNDERGROUND THE TAB IS READ-ONLY: class changes and unlocks happen in town (Player.packOpen, the flag
-- the Loadout reads for the bag). Everything still draws; nothing presses.
function ClassEditor:readOnly()
    return self.player ~= nil and Player.packOpen(self.player)
end

function ClassEditor:canChange()
    local row = self:currentRow()
    if not (row and row.id and self.char) or self:readOnly() then return false end
    if not Class.isUnlocked(self.char, row.id) then return false end
    return row.id ~= Growth.classOf(self.char)
end

function ClassEditor:changeClass()
    if not self:canChange() then return false end
    Class.grandfather(self.char) -- the class being left stays this body's
    self.char.declaredClass = self:currentRow().id
    return true
end

-- May the highlighted class be unlocked right now: met (Class.canUnlock), a seal in hand, in town.
function ClassEditor:canUnlock()
    local row = self:currentRow()
    if not (row and row.id and self.char and self.player) then return false end
    return Class.unlockBlock(self.player, self.char, row.id) == nil
end

-- Spend a seal, make the class this body's, and play the ceremony. Returns true on an unlock.
-- `ClassEditor.onUnlocked(char, classId, giftId)`, when a host sets it, hears every unlock.
function ClassEditor:unlockClass()
    if not self:canUnlock() then return false end
    local id = self:currentRow().id
    local ok, gift = Class.unlock(self.player, self.char, id)
    if not ok then return false end
    self.lastGift = gift
    -- The gift's card waits behind the stat card and takes its slot when that one is dismissed
    -- (ClassEditor:update); with no stat card to wait behind it plays at once.
    self.pendingGift = gift and { id = gift, classId = id } or nil
    if LevelupCard and LevelupCard.showUnlock then
        local okShow, card = pcall(LevelupCard.showUnlock, self.char, id, Class.boostFor(id) or {})
        if okShow then self.card = card end
    end
    if not self.card then self:nextCard() end
    if ClassEditor.onUnlocked then ClassEditor.onUnlocked(self.char, id, gift) end
    local keepHouse, keepCursor = self.house, self.cursor
    self:buildHouses()
    self.house = keepHouse
    self:buildRows()
    for i, row in ipairs(self.rows) do
        if row.id == id then self.cursor = i break end
    end
    if not self:isSelectable(self.cursor) then self.cursor = keepCursor end
    self:scrollToCursor()
    return true
end

-- THE FIRST PICK'S COACH LINE, while Rowan's recommendation is still owed to the body on this tab
-- (Class.pickOwed). It replaced the free first seal Rowan used to hand over at Novice 1 (2026-10-23):
-- the avatar's first class is chosen, not earned, so there is nothing for a seal to buy.
-- PLACEHOLDER COPY for the author.
function ClassEditor:pickCoach()
    if not Class.pickOwed(self.player, self.char) then return nil end
    return Locale.get("ui.class_editor.first_pick",
        "Rowan put your name to the guild. Pick your first class: it costs nothing.")
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
--
-- `open` is the CARD's own gate now, not a shelf's (models/building.lua), so this offer and the walk it
-- ends in are asking the one question: is the house on the plaza.
function ClassEditor:trainer()
    if not self.onVisitTrainer then return nil end
    local row = self:currentRow()
    if not row then return nil end
    -- Not until the class is held: a door the player cannot use yet, on a class they cannot stand in
    -- yet, was a greyed plate in the way of the one press that matters.
    if not (self.char and row.id and Class.isUnlocked(self.char, row.id)) then return nil end
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

-- Two regions now, so Tab walks them: houses, then the shelf, then out. Returning false is how the
-- host is told the walk ran off its end (Party:cycleEditorRegion), and the region is put back to the
-- first on the way out so the next entry starts where the screen's first question is.
function ClassEditor:cycleRegion()
    if self:firstPick() then return false end -- one row of cards: Tab walks straight off it
    if self.region == "houses" then
        self.region = "classes"
        return true
    end
    self.region = "houses"
    return false
end

function ClassEditor:isFirstRegion()
    if self.card then return false end -- the ceremony holds the tab: no walking off it to the rail
    -- On the spread, left off the first card is the rail's, as left off the houses column is.
    if self:firstPick() then return (self:cardIndex() or 1) == 1 end
    return self.region == "houses"
end

function ClassEditor:navigate(dc, dr)
    if self.card then return end
    -- Left/right crosses between the two columns. Pushing left off the houses is the host's business:
    -- that is the edge of the editor, and it leads back to the portrait rail (Party:navigate reads
    -- isFirstRegion), which is why this only handles the crossing it owns.
    if dc > 0 and self.region == "houses" then self.region = "classes" return end
    if self:firstPick() then
        local d = dc ~= 0 and dc or dr
        if d ~= 0 then self:pickCard((self:cardIndex() or 1) + d) end
        return
    end
    if dc < 0 and self.region == "classes" then self.region = "houses" return end
    if dr == 0 then return end
    if self.region == "houses" then self:stepHouse(dr) else self:step(dr) end
end

-- Confirm means "the thing this column is for". On the houses that is opening the shelf, which is what
-- a press on a row of doors should do; on the shelf it is the one act on the tab.
-- On a shut class that is met, confirm is the Unlock; on an unlocked one it is the Change. The two are
-- never offered on the same row, so one button carries both.
function ClassEditor:confirm()
    if self.card then self.card:press() return end
    if self.region == "houses" then
        self.region = "classes"
        return
    end
    if self:canUnlock() then self:unlockClass() return end
    self:changeClass()
end

-- THE TAB'S SECOND ACT, on the seam the rule editor next door already uses for its own (F / X, routed
-- by Party:keypressed). A second verb needs a second button on every device, and this one is free on
-- both: the roll has no rule to enable, which is what F does on the other column editor.
function ClassEditor:altConfirm()
    if self.card then self.card:press() return end
    self:visitTrainer()
end

-- Esc / B: the ceremony eats it (a press reveals, the next dismisses); otherwise nothing here is held
-- open, so it belongs to the panel.
function ClassEditor:cancel()
    if self.card then self.card:press() return true end
    return false
end

-- Raw input, for a host that forwards it (the card swallows everything while it is up).
function ClassEditor:keypressed(key)
    if self.card then return self.card:keypressed(key) end
    return false
end

function ClassEditor:gamepadpressed(joystick, button)
    if self.card then return self.card:gamepadpressed(joystick, button) end
    return false
end

-- The ceremony's second beat: the item the unlock handed over (ui/gift_card.lua), or nothing.
function ClassEditor:nextCard()
    local gift = self.pendingGift
    self.pendingGift = nil
    self.card = nil
    if gift and GiftCard then
        local ok, card = pcall(GiftCard.new, gift.id, { classId = gift.classId, char = self.char })
        if ok then self.card = card end
    end
end

function ClassEditor:update(dt)
    if self.card then
        self.card:update(dt)
        if self.card.done then self:nextCard() end
    end
end

function ClassEditor:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function ClassEditor:mousemoved(x, y)
    if self.card then return true end
    self.mx, self.my = x, y
    self.hoverCard, self.hoverPreview = nil, nil
    for i, r in pairs(self.cardRects) do
        if hit(r, x, y) then self.hoverCard = i break end
    end
    for _, r in ipairs(self.previewRects) do
        if hit(r, x, y) then self.hoverPreview = r break end
    end
    self.hoverUnlock = hit(self.unlockRect, x, y)
    self.hoverRow, self.hoverHouse = nil, nil
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then self.hoverRow = i break end
    end
    for i, r in pairs(self.houseRects) do
        if hit(r, x, y) then self.hoverHouse = i break end
    end
    self.hoverChange = hit(self.changeRect, x, y)
    self.hoverTrainer = hit(self.trainerRect, x, y)
end

function ClassEditor:wheelmoved(dy)
    if self.card then return true end
    local span = self:visibleRows()
    self.scroll = math.max(0, math.min(self.scroll - dy, math.max(0, #self.rows - span)))
end

function ClassEditor:mousepressed(x, y, button)
    if self.card then
        self.card:mousepressed(x, y, button or 1)
        return true
    end
    if hit(self.unlockRect, x, y) then
        self:unlockClass()
        return true
    end
    -- A preview icon pins its card on a press, which is how a finger -- no hover -- reads one.
    for _, r in ipairs(self.previewRects) do
        if hit(r, x, y) then
            self.pinnedPreview = (self.pinnedPreview and self.pinnedPreview.item == r.item) and nil or r
            return true
        end
    end
    self.pinnedPreview = nil
    for i, r in pairs(self.cardRects) do
        if hit(r, x, y) then
            self:pickCard(i)
            return true
        end
    end
    -- A house opens on the press that picks it: there is no second click for "open", because the shelf
    -- beside it is already the thing a player clicked the house to see.
    for i, r in pairs(self.houseRects) do
        if hit(r, x, y) then
            self.region = "houses"
            self:setHouse(i)
            return true
        end
    end
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then
            self.region = "classes"
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
    if self.card then return "arrow" end
    if hit(self.changeRect, x, y) or hit(self.unlockRect, x, y) then return "hand" end
    for _, r in pairs(self.cardRects) do
        if hit(r, x, y) then return "hand" end
    end
    for _, r in ipairs(self.previewRects) do
        if hit(r, x, y) then return "hand" end
    end
    -- The hand appears over an OPEN door only. A shut trainer's plate is a notice, and a pointer that
    -- turned into a hand over it would promise a press that does nothing.
    if hit(self.trainerRect, x, y) then
        local house = self:trainer()
        return (house and house.open) and "hand" or "arrow"
    end
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then return "hand" end
    end
    for _, r in pairs(self.houseRects) do
        if hit(r, x, y) then return "hand" end
    end
    return "arrow"
end

function ClassEditor:prompts()
    local pad = InputMode.isGamepad()
    local out = {}
    local function add(glyph, label) out[#out + 1] = { glyph = glyph, label = label } end
    if self.card then
        add(pad and "A" or "Enter", "Continue")
        return out
    end
    if self:firstPick() then
        add(pad and "D-pad" or "Left/Right", "Pick class")
        local row = self:currentRow()
        if self:canUnlock() and row then add(pad and "A" or "Enter", "Choose " .. row.name) end
        return out
    end
    if self.region == "houses" then
        add(pad and "D-pad" or "Up/Down", "Pick house")
        add(pad and "A" or "Enter", "Open house")
        return out
    end
    add(pad and "D-pad" or "Up/Down", "Pick class")
    add("Left", "Houses")
    -- The one verb, offered only where it is legal: a body already standing in the highlighted class
    -- has nothing to press, and a prompt for it would read as the press having failed.
    if self:canUnlock() then add(pad and "A" or "Enter", "Unlock class")
    elseif self:canChange() then add(pad and "A" or "Enter", "Change class") end
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

-- THE SEVEN HOUSES. ONE LINE TO A ROW: the house's name, and the level this body holds in it.
--
-- The row used to carry a second line -- "2 open · 6 ahead", how much of the house's shelf stands
-- unlocked -- and it is gone. It was a count standing in front of rows that are one keypress away and
-- drawn one at a time in the next column, where they say the same thing with their own names on: a
-- player who wants to know what a house has open opens it. What the column is FOR is choosing which
-- house to read, and the level is the only figure that question is decided on.
function ClassEditor:drawHouses(focused)
    local x, y, w = self.houseX, self.listY, self.houseW
    local small = self.fonts.small

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    Theme.printTracked("HOUSES", x, self.y, w, 1)

    self.houseRects = {}
    for i, house in ipairs(self.houses) do
        local ry = y + (i - 1) * HOUSE_ROW_H
        self.houseRects[i] = { x = x, y = ry, w = w, h = HOUSE_ROW_H - 4 }

        local on = i == self.house
        if on then
            Theme.plate(x, ry, w, HOUSE_ROW_H - 4, 3, Theme.panel)
            -- Steel while the keyboard is in this column, bronze once it has moved on: the house stays
            -- picked either way, and the ring is the only thing that says which column a press lands in.
            Theme.set(focused and Theme.cursor or Theme.frame)
            love.graphics.rectangle("line", x, ry, w, HOUSE_ROW_H - 4, 3, 3)
        elseif i == self.hoverHouse then
            Theme.set(Theme.frame, 0.5)
            love.graphics.rectangle("line", x, ry, w, HOUSE_ROW_H - 4, 3, 3)
        end

        local plateH = HOUSE_ROW_H - 4

        -- The house's own colour, a bar at the row's left edge: seven houses, seven marks.
        if Class.isRoot(house.id) then
            Theme.set(crestColor(house.id), 0.9)
            love.graphics.rectangle("fill", x + 2, ry + 6, 3, plateH - 12)
        end

        -- The mark the shelf uses for the class being applied, put on the house that teaches it.
        if self:standsIn(house.id) then
            Theme.set(Theme.accentAmber)
            love.graphics.circle("fill", x + 8, ry + plateH / 2, 3)
        end

        -- One line, centred in the plate: the name and the level are the whole row now, so they sit on
        -- the row's own middle rather than on the top line of a pair.
        Theme.set(levelColor(house.level))
        local font, name = Theme.fitText(Theme.display, house.name, w - 60, 16, 12)
        love.graphics.setFont(font)
        love.graphics.print(name, x + 16, ry + (plateH - font:getHeight()) / 2)

        love.graphics.setFont(small)
        Theme.set(levelColor(house.level))
        love.graphics.printf(tostring(house.level), x, ry + (plateH - small:getHeight()) / 2, w - 8, "right")
    end
end

function ClassEditor:drawList(focused)
    local x, y, w = self.listX, self.listY, self.listW
    local small, body = self.fonts.small, self.fonts.body
    local house = self:currentHouse()

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    -- The column is one house's shelf now, so it is captioned with the house rather than with the word
    -- CLASSES -- which was true of a list holding all forty-five and is a caption on nothing here.
    Theme.printTracked(string.upper(house and house.name or "CLASSES"), x, self.y, w, 1)
    love.graphics.printf("LEVEL", x, self.y, w, "right")

    local span = self:visibleRows()
    self.rowRects = {}

    for i = self.scroll + 1, math.min(#self.rows, self.scroll + span) do
        local row = self.rows[i]
        local ry = y + (i - self.scroll - 1) * ROW_H
        self.rowRects[i] = { x = x, y = ry, w = w, h = ROW_H - 2 }

        local base = row.kind == "class"
        -- AN EMPTY SLOT, AND IT LOOKS LIKE ONE. A shut class gets the same rectangle every other row
        -- stands in -- so the list shows the whole ladder at its true length from the first morning --
        -- but drawn as an outline on the stock rather than a filled plate, and never with the cursor's
        -- edge: it is a place waiting to be taken, not a control refusing to be pressed.
        if row.kind == "shut" then
            -- READY, or WHAT OPENS IT, on the right where an opened row keeps its level. A row this body
            -- can unlock now is lit (an amber edge and "Ready"); any other carries its gate as a pill --
            -- "Fighter 3", "Fighter 6 + Priest 6" -- instead of a bare integer in the gutter.
            local ready = self.char and (Class.canUnlock(self.char, row.id)
                or Class.isFreePick(self.player, self.char, row.id))
            Theme.set(ready and Theme.accentAmber or Theme.frame, ready and 0.8 or 0.35)
            love.graphics.rectangle("line", x + GUTTER_W, ry, w - GUTTER_W, ROW_H - 2, 3, 3)
            if i == self.cursor then
                Theme.set(focused and Theme.cursor or Theme.frame)
                love.graphics.rectangle("line", x + GUTTER_W, ry, w - GUTTER_W, ROW_H - 2, 3, 3)
            end

            local pill
            if ready then
                pill = "Ready"
            elseif row.gate then
                pill = (house and house.name or "") .. " " .. tostring(row.gate)
                    .. (row.locked and (" " .. row.locked) or "")
            end
            love.graphics.setFont(small)
            local pillW = pill and (small:getWidth(pill) + 12) or 0
            if pill then
                local px, ph = x + w - pillW - 6, small:getHeight() + 2
                local py = ry + (ROW_H - 2 - ph) / 2
                if ready then
                    Theme.set(Theme.accentAmber, 0.18)
                    love.graphics.rectangle("fill", px, py, pillW, ph, ph / 2, ph / 2)
                    Theme.set(Theme.accentAmber)
                else
                    Theme.set(Theme.frame, 0.6)
                    love.graphics.rectangle("line", px, py, pillW, ph, ph / 2, ph / 2)
                    Theme.set(Theme.muted, 0.85)
                end
                love.graphics.print(pill, px + 6, py + 1)
            end

            local nameFont, shutName = Theme.fitText(Theme.body, row.name or "", w - GUTTER_W - pillW - 24, 15, 12)
            love.graphics.setFont(nameFont)
            Theme.set(ready and Theme.ink or Theme.muted, 0.9)
            love.graphics.print(shutName, x + GUTTER_W + 10, ry + 5)
        else
            local on = i == self.cursor
            -- A CLASS THIS BODY HOLDS IS A CARD; ONE IT DOES NOT IS AN EMPTY SLOT. The base class always
            -- takes this branch, held or not, and a held class at level 0 levels its ink to muted --
            -- so without a surface of its own, "free to change into" and "still shut" read the same.
            -- The card is the row inset every panel uses; an unheld base class wears the shut row's
            -- outline, the same empty slot as everything below it that it has not opened either.
            if row.unlocked then
                Theme.fill(Theme.panel2, x, ry, w, ROW_H - 2, 3)
                Theme.set(Theme.hairline)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            else
                Theme.set(Theme.frame, 0.35)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            end
            if on then
                Theme.set(focused and Theme.cursor or Theme.frame)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            end

            -- TWO INDENTS, NOT THREE. A crossing used to sit one step further in than a subclass, and
            -- that step was a lie the eye believes instantly: indentation means descent, so "Apothecary"
            -- under "Poisoner" read as a leaf of Poisoner. It is not -- both are earned straight off the
            -- base class above them, one from a single parent and one from two, and they are the same
            -- rung. So depth says rank, and a crossing says what it is with the name of its OTHER
            -- parent instead, in the shape the shop and the lineage strip both use ("x Priest").
            --
            -- The step is the gutter itself now: an earned class hangs off a gate and its name starts
            -- where the gate column ends, while the base class has no gate and stands to the left of it.
            local indent = base and 10 or (GUTTER_W + 10)
            -- The one tail a named row carries: a crossing's other parent. What is still shut behind a
            -- house is counted on the house's own row in the column to the left, which is a place a
            -- count can stand without standing instead of the rows it counts.
            local tail = row.cross and ("  x " .. row.cross)
            local tailW = tail and small:getWidth(tail) or 0

            -- A held name is never muted, level 0 or not: muted is the shut rows' ink.
            Theme.set(row.unlocked and row.level < Class.CLASS_LEVEL_CAP and Theme.ink
                or row.unlocked and Theme.accentAmber or Theme.muted, row.unlocked and 1 or 0.9)
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
    -- ONLY WHAT IS OPEN IS FANNED. Not because a shut class is unnameable here -- the list beside this
    -- names every one of them -- but because a fan is a picture of what this body HAS made of a house,
    -- and every node on it carries a level. The shut ones are counted on the house row and named in
    -- full on the list, which is the place that can also say what opens them.
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
-- THE GAIN LEADS AND THE TRANSITION FOLLOWS IT, in parentheses: "+6 (70 → 76)". The sheet next door
-- writes a forecast as a bare transition because a signed figure parked beside a value is the
-- universal "this is buffed right now" idiom, and a permanent gain must not read as a bonus already
-- in effect -- but the figure a player COMPARES BETWEEN CLASSES is the gain itself, and making them
-- subtract two numbers on every row to get it is work the screen can do for them. The parenthesis is
-- what keeps the old reading away: a signed number followed by the two values it is the difference of
-- cannot be mistaken for a live modifier, because it shows its own arithmetic.
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

            -- Right-aligned as one unit, exactly as the sheet's forecast is: the gain and the
            -- transition it is the difference of are one reading, and splitting the alignment would
            -- let the eye take either half for a column of its own.
            local text = "+" .. gain .. " (" .. from .. " " .. ARROW .. " " .. (from + gain) .. ")"
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
-- next action (Class.techniqueFor): standing in a class is the only way to learn it.
--
-- IT IS SAID IN THE NUMBERS IT IS ACTUALLY MADE OF, in plain words. "Your declared class earns
-- technique faster" is a sentence a player cannot plan against; "each action earns 2 technique for
-- Ninja" is one they can. The figures are read off the constant rather than typed, so a retune moves
-- the sentence with the rule instead of leaving prose that used to be true.
--
-- Yields when the pane is short, exactly as the lineage strip above it does: what a class GROWS and
-- where this body STANDS are the two readouts the decision cannot be made without, and this is the
-- explanation that goes with them.
function ClassEditor:drawTechniqueRule(row, x, y, w)
    local small = self.fonts.small
    -- The rule for THIS row's class, named, in the same sentence the party sheet prints
    -- (Class.techniqueRule).
    local text = Class.techniqueRule(row.id)

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

-- WHAT A SHUT CLASS ASKS OF THIS BODY, three lines: the level gate (met or not), the deed with its
-- counter and bar, and the seal. Each line is amber once met, so the row reads as a checklist.
function ClassEditor:drawRequirement(row, x, y, w)
    local small, char = self.fonts.small, self.char
    y = caption("TO UNLOCK", x, y, w, small) + 2

    -- A tick or an empty ring before each line, drawn rather than typed: "+ / -" read as a diff.
    local function line(text, met)
        checkMark(x, y + small:getHeight() / 2, met)
        Theme.set(met and Theme.ink or Theme.muted)
        love.graphics.setFont(small)
        love.graphics.print(text, x + 16, y)
        y = y + small:getHeight() + 4
    end

    -- THE FIRST PICK ASKS NOTHING. Rowan's recommendation stands in for the whole checklist, and
    -- printing the deed under it would read as a requirement the pick then ignores.
    if Class.isFreePick(self.player, char, row.id) then
        line("Rowan's recommendation (free)", true)
        return y + 8
    end

    -- The level half: Novice 1 for a root, the parents' levels for an earned class.
    local gate
    if Class.isRoot(row.id) then
        gate = (Class.displayName(Growth.NEUTRAL_CLASS) or "Novice") .. " 1"
    else
        local parts = {}
        for _, parent in ipairs(Class.parents(row.id)) do
            parts[#parts + 1] = (Item.classDisplayName(parent) or parent) .. " "
                .. tostring(((Class.defs[row.id] or {}).requires or {})[parent] or 0)
        end
        gate = table.concat(parts, " + ")
        if Class.arity(row.id) >= 2 then gate = gate .. ", and a subclass of each" end
    end
    line(gate, Class.levelGateMet(char, row.id))

    -- The deed, with its counter. A crossing has none.
    local held, needed, label = Class.deedProgress(char, row.id)
    if label then
        line(string.format("%s (%d / %d)", label, math.min(held, needed), needed), held >= needed)
        ProgressBar.draw(x + 16, y - 2, w - 16, 4, needed > 0 and math.min(1, held / needed) or 1, 1,
            { color = held >= needed and Theme.accentAmber or Theme.cursor })
        y = y + 6
    end

    local seals = self.player and Player.materialCount(self.player, Class.SEAL_ID) or 0
    line(string.format("1 Charter Seal (%d held)", seals), seals > 0)
    return y + 8
end

-- ---------------------------------------------------------------------------
-- The previews: what a class gives, before it is taken
-- ---------------------------------------------------------------------------

-- THE ONE ACT, drawn as the primary control it is: filled in the accent, dark ink on it. Every other
-- plate on the tab is an outline, so the press the screen exists for is the one that looks pressable.
local function primaryButton(x, y, w, h, text, font, hover)
    Theme.set(Theme.accentAmber, hover and 1 or 0.86)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(0.11, 0.10, 0.08)
    love.graphics.setFont(font)
    love.graphics.printf(text, x, y + (h - font:getHeight()) / 2, w, "center")
end


-- The ability the unlock would hand THIS body, or nil: roots only, once per body (char.giftsTaken),
-- and never for a class it already holds -- the same three conditions Class.unlock checks, so the
-- preview cannot name a gift the press will not give.
local giftCache = {}
function ClassEditor:giftPreview(id)
    local char = self.char
    if not (id and char and Class.isRoot(id)) or Class.isUnlocked(char, id) then return nil end
    if (char.giftsTaken or {})[id] then return nil end
    local giftId = Class.giftFor(char, id)
    if not (giftId and Item.defs[giftId]) then return nil end
    giftCache[giftId] = giftCache[giftId] or Item.instantiate(giftId)
    return giftCache[giftId]
end

-- An icon that opens the full item card on hover, or on a press (a finger has no hover).
function ClassEditor:previewIcon(item, x, y, size)
    local r = { x = x, y = y, w = size, h = size, item = item }
    self.previewRects[#self.previewRects + 1] = r
    local on = (self.hoverPreview and self.hoverPreview.item == item)
        or (self.pinnedPreview and self.pinnedPreview.item == item)
    drawItemIcon(item, x, y, size, on and Theme.accentAmber or Theme.frame, self.fonts.small)
end

-- "YOU START WITH": the gift, its icon, its name and the line it describes itself in. Returns y; draws
-- nothing (and returns y unchanged) where there is no gift or no room above `floor`.
function ClassEditor:drawGiftBlock(id, x, y, w, floor)
    local item = self:giftPreview(id)
    if not item then return y end
    local small, body = self.fonts.small, self.fonts.body
    local ICON = 38
    if y + small:getHeight() + 6 + ICON > floor then return y end
    y = caption("YOU START WITH", x, y, w, small)
    self:previewIcon(item, x, y, ICON)
    love.graphics.setFont(body)
    Theme.set(Theme.ink)
    love.graphics.print(item.name or "?", x + ICON + 10, y)
    local desc = item.description
    if type(desc) == "string" then
        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        local tw = w - ICON - 10
        local _, lines = small:getWrap(desc, tw)
        local keep = math.max(1, math.min(#lines, 2))
        love.graphics.printf(table.concat(lines, " ", 1, keep) .. (#lines > keep and "..." or ""),
            x + ICON + 10, y + body:getHeight() + 1, tw, "left")
    end
    return y + ICON + 12
end

-- "WHILE YOU'RE A X", and what every level in it adds. A root's boost IS one level of its growth, so
-- there the two collapse into one row with a line saying so; an earned class pays double while
-- selected (Class.boostFor) and shows both. The body's own points are said as a footnote, as before.
-- While the growth peek is on (or the mouse is over the block) the per-level row gives way to the
-- transitions it adds up to, the old table.
function ClassEditor:drawBoostBlock(id, x, y, w, floor)
    local char = self.char
    local small = self.fonts.small
    local boost = Class.boostFor(id)
    local growth = Growth.defs[id]
    if not (boost or growth) then return y end

    local name = Class.displayName(id) or id
    local same = sameStats(boost, growth)
    local personal = char and Growth.personal(char)
    local capH = small:getHeight() + 6

    -- Measured first: the block yields whole rather than drawing half a sentence.
    local need = capH + (boost and (drawChips(boost, x, 0, w, small, true)) or 0) + 4
    if same then need = need + small:getHeight() + 4
    elseif growth then need = need + capH + drawChips(growth, x, 0, w, small, true) + 4 end
    if personal then need = need + small:getHeight() + 4 end
    if y + need > floor then return y end

    local top = y
    local peek = (self.growthPeeking and self.growthPeeking())
        or (self.mx and self.boostRect and hit(self.boostRect, self.mx, self.my))
    if peek and char then
        if boost and not same then
            y = caption("WHILE YOU'RE " .. string.upper(withArticle(name)), x, y, w, small)
            y = drawChips(boost, x, y, w, small) + 8
        end
        y = self:drawGrowth(id, x, y, w)
    else
        if boost then
            y = caption("WHILE YOU'RE " .. string.upper(withArticle(name)), x, y, w, small)
            y = drawChips(boost, x, y, w, small) + 4
        end
        if same then
            love.graphics.setFont(small)
            Theme.set(Theme.muted)
            love.graphics.print("...and the same again for every level you gain in it.", x, y)
            y = y + small:getHeight() + 4
        elseif growth then
            y = caption("EVERY LEVEL IN " .. string.upper(name), x, y, w, small)
            y = drawChips(growth, x, y, w, small) + 4
        end
        if personal and char then
            local parts = {}
            for _, row in ipairs(GROWTH_ROWS) do
                if personal[row.key] then parts[#parts + 1] = "+" .. personal[row.key] .. " " .. row.label end
            end
            love.graphics.setFont(small)
            Theme.set(Theme.muted, 0.75)
            love.graphics.print(string.format("Plus %s's own %s a level, in any class.", char.name or "this body",
                table.concat(parts, " and ")), x, y)
            y = y + small:getHeight() + 4
        end
    end
    self.boostRect = { x = x, y = top, w = w, h = y - top }
    return y + 8
end

-- "THE COLOSSEUM SELLS": the first pieces on the class's shelf, each opening its item card.
function ClassEditor:drawShelfBlock(id, x, y, w, floor)
    local items = shelfPreview(id)
    if #items == 0 then return y end
    local small = self.fonts.small
    local ICON, GAP = 34, 6
    if y + small:getHeight() + 6 + ICON > floor then return y end
    local house = Building.houseForClass(rootOf(id), self.player)
    local where = (house and house.name) and string.upper(house.name) or "ITS HOUSE"
    y = caption(where .. " SELLS", x, y, w, small)
    local fit = math.max(1, math.floor((w + GAP) / (ICON + GAP)))
    for i = 1, math.min(#items, fit) do
        self:previewIcon(items[i], x + (i - 1) * (ICON + GAP), y, ICON)
    end
    return y + ICON + 12
end

-- The item card for whichever preview is hovered or pinned, over everything else on the tab.
function ClassEditor:drawPreviewTip()
    local r = self.hoverPreview or self.pinnedPreview
    if not (r and r.item) then return end
    local ok, ItemTooltip = pcall(require, "ui.item_tooltip")
    if not ok then return end
    ItemTooltip.draw(r.item, r.x + r.w + 6, r.y, self.x + self.w, nil, self.char)
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
    -- The house's colour under the name: whose class this is, at a glance.
    Theme.set(crestColor(row.id))
    love.graphics.rectangle("fill", x, y + font:getHeight() + 1, math.min(w, font:getWidth(name) + 10), 3)

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    local kindLabel = Class.isStarter(row.id) and "Starting class"
        or row.kind == "class" and "Base class"
        or row.kind == "shut" and (Class.arity(row.id) >= 2 and "Crossing"
            or ("Subclass of " .. Item.classDisplayName(row.parent)))
        or row.kind == "subclass" and ("Subclass of " .. Item.classDisplayName(row.parent))
        or "Crossing"
    love.graphics.print(kindLabel, x, y + 30)

    local ty = y + 54

    -- WHERE THE BODY IS STANDING, said beside the name it is standing in. It used to sit at the foot of
    -- this column, under the growth table and the technique rule -- a long way from the thing it is a
    -- fact about, and on a row with a long blurb it was pushed off the pane entirely.
    if char and Growth.classOf(char) == row.id then
        local here = (char.name or "?") .. "'s Current Class"
        Theme.set(Theme.accentAmber)
        if small:getWidth(kindLabel) + 10 + small:getWidth(here) <= w then
            love.graphics.print(here, x + small:getWidth(kindLabel) + 10, y + 30)
        else
            love.graphics.print(here, x, ty)
            ty = ty + small:getHeight() + 4
        end
    end

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

    -- WHAT UNLOCKS IT, for a class this body does not hold yet: the level gate, the deed with its
    -- counter, and the seal. Ahead of everything else, because on a shut row it is the question.
    local held = char and row.id and Class.isUnlocked(char, row.id)
    if char and row.id and not held then
        ty = self:drawRequirement(row, x, ty, w)
    end

    -- WHAT IT GIVES: the ability the unlock hands over, what standing in it pays, and the first gear
    -- its house sells. Each yields whole above the buttons rather than drawing under them.
    local floor = self:buttonsTop() - 8
    ty = self:drawGiftBlock(row.id, x, ty, w, floor)
    ty = self:drawBoostBlock(row.id, x, ty, w, floor)
    ty = self:drawShelfBlock(row.id, x, ty, w, floor)

    -- This body's standing on it, as a transition rather than a bare figure: what the next rung costs
    -- is the number a player is actually deciding against. ONLY ON A CLASS IT HOLDS: "Fighter 0,
    -- 0 / 28 to 1" and the technique sentence said nothing about a class the body cannot stand in yet.
    if held and ty + 62 <= floor then
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

        ty = self:drawTechniqueRule(row, x, ty, w)
    end

    -- Where it sits on the ladder, last: the shape around the numbers, and the first thing to give way.
    ty = self:drawLineage(row, x, ty, w)

    -- THE OTHER DOOR OUT OF THIS COLUMN: the house where this class is taught, sold and climbed. It
    -- stands above the act, because changing class is what you do HERE and the trainer is where you go
    -- next.
    --
    -- AND IT IS DRAWN SHUT, which is the one greyed plate on this tab and deliberately the exception to
    -- the rule under it. A house that has not opened is not refusing the press, it is naming what opens
    -- it -- said on the class's own screen, to the player standing there deciding whether to climb.
    -- Take the plate away and the gate is invisible until the door appears.
    --
    -- AND WHAT IT NAMES IS THE PLATE DIRECTLY BELOW IT. It used to read "Unlock trainer at Knight lvl 1",
    -- quoting a `classLevel` gate on the shelf -- a gate deleted when the shelf was ungated, which left
    -- this branch unreachable and the plate above it permanently live, so the Roll offered a walk to a
    -- house the city was not showing and the press did nothing (models/building.lua's houseForClass).
    -- What opens a house now is the company taking up a class it shelves (models/offer.lua's `declared`
    -- gate), and the act that does it is the Change button one plate down. So the shut plate names THAT,
    -- which is the difference between a wall and a direction: a number to grind became a press to make.
    --
    -- The house is named rather than the class, because the class is already on the row and the house
    -- may not be -- a subclass is taught at its parent's door.
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
            -- The house's shelf opens on the city's schedule; unlocking its root class pulls it a trip
            -- sooner (models/offer.lua). Flat copy: what opens it, nothing more.
            Theme.set(Theme.muted, 0.55)
            love.graphics.printf((house.name or "This house") .. " opens on a later trip",
                x, by + 9, w, "center")
        end
    end

    -- THE UNLOCK, in the Change button's place: the two are never both legal on one row.
    self.unlockRect = nil
    if self:canUnlock() then
        local by = self:changeY()
        self.unlockRect = { x = x, y = by, w = w, h = BUTTON_H }
        primaryButton(x, by, w, BUTTON_H, Class.isFreePick(self.player, char, row.id) and ("Choose " .. row.name)
            or ("Unlock " .. row.name .. " (1 seal)"), body, self.hoverUnlock)
    elseif self:readOnly() and row.id then
        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        love.graphics.printf("Classes change in town.", x, self:changeY() + 9, w, "center")
    end

    -- THE ONE ACT ON THIS TAB, and it draws only where it is legal: a body already standing in this
    -- class has nothing to press. A greyed plate would be a control that is never pressable pretending
    -- to be one that is -- where the trainer's plate above is not a control at all while it is shut.
    if self:canChange() then
        local by = self:changeY()
        self.changeRect = { x = x, y = by, w = w, h = BUTTON_H }
        primaryButton(x, by, w, BUTTON_H, "Change to " .. row.name, body, self.hoverChange)
    end
end

-- THE SPREAD (see "The first pick" above): a title, Rowan's line, the seven roots as cards, and the
-- picked one opened underneath -- what it is and what it starts you with on the left, what it pays and
-- what its house sells on the right, and the press.
local CARD_GAP = 8
local CREST_H = 46

function ClassEditor:drawFirstPick(focused)
    local x, y, w = self.x, self.y, self.w
    local small, body = self.fonts.small, self.fonts.body
    local tiny = self.fonts.tiny or small
    self.unlockRect, self.changeRect, self.trainerRect = nil, nil, nil
    self.rowRects, self.houseRects = {}, {}

    local title = Theme.display(24)
    love.graphics.setFont(title)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(Locale.get("ui.class_editor.first_pick_title", "Choose your first class"), x, y, w, "center")
    local ty = y + title:getHeight() + 2
    local coach = self:pickCoach()
    if coach then
        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        love.graphics.printf(coach, x, ty, w, "center")
        ty = ty + small:getHeight() + 10
    end

    -- The cards.
    local cards = self:cardHouses()
    local n = math.max(1, #cards)
    local cw = math.floor((w - CARD_GAP * (n - 1)) / n)
    local picked = self:cardIndex()
    -- One height for the row, set by the tallest chip block (a mage pays five stats, a fighter three),
    -- with the gift line under the chips rather than pinned to a foot they could run into.
    local nameH = Theme.display(18):getHeight()
    local chipsH = 0
    for _, idx in ipairs(cards) do
        chipsH = math.max(chipsH, drawChips(Class.boostFor(self.houses[idx].id), 0, 0, cw - 16, tiny, true))
    end
    local CARD_H = 6 + CREST_H + 10 + nameH + 4 + chipsH + 6 + tiny:getHeight() + 10
    for i, idx in ipairs(cards) do
        local house = self.houses[idx]
        local cx = x + (i - 1) * (cw + CARD_GAP)
        local r = { x = cx, y = ty, w = cw, h = CARD_H }
        self.cardRects[i] = r
        local on, hov = i == picked, i == self.hoverCard
        Theme.plate(cx, ty, cw, CARD_H, 5, on and Theme.panel or Theme.panel2)
        Theme.set(on and (focused and Theme.cursor or Theme.accentAmber) or Theme.frame, (on or hov) and 1 or 0.5)
        love.graphics.rectangle("line", cx, ty, cw, CARD_H, 5, 5)

        -- The crest: drawn art, or the house's mark in its colour.
        drawCrest(house.id, cx + 6, ty + 6, cw - 12, CREST_H, on and 1 or 0.75)

        local iy = ty + 6 + CREST_H + 10
        local nf, nm = Theme.fitText(Theme.display, house.name, cw - 12, 18, 12)
        love.graphics.setFont(nf)
        Theme.set(on and Theme.ink or Theme.muted)
        love.graphics.print(nm, cx + 8, iy)
        iy = iy + nameH + 4

        drawChips(Class.boostFor(house.id), cx + 8, iy, cw - 16, tiny)

        local gift = self:giftPreview(house.id)
        if gift then
            love.graphics.setFont(tiny)
            Theme.set(Theme.muted)
            local text = Theme.ellipsize("Starts with " .. (gift.name or "?"), tiny, cw - 16)
            love.graphics.print(text, cx + 8, iy + chipsH + 6)
        end
    end

    -- The picked card, opened.
    local row = self:currentRow()
    if not row then return end
    local dy = ty + CARD_H + 16
    local bottom = y + self.h
    local leftW = math.floor(w * 0.52)
    local rx, rw = x + leftW + 24, w - leftW - 24

    local nf, nm = Theme.fitText(Theme.display, row.name, leftW, 24, 16)
    love.graphics.setFont(nf)
    Theme.set(Theme.ink)
    love.graphics.print(nm, x, dy)
    Theme.set(crestColor(row.id))
    love.graphics.rectangle("fill", x, dy + nf:getHeight() + 1, math.min(leftW, nf:getWidth(nm) + 10), 3)
    local ly = dy + nf:getHeight() + 12

    local blurb = Item.classDescription(row.id) or Class.description(row.id)
    if type(blurb) == "string" then
        love.graphics.setFont(body)
        Theme.set(Theme.ink, 0.9)
        love.graphics.printf(blurb, x, ly, leftW, "left")
        local _, lines = body:getWrap(blurb, leftW)
        ly = ly + body:getHeight() * math.max(1, #lines) + 14
    end
    self:drawGiftBlock(row.id, x, ly, leftW, bottom)

    local by = bottom - BUTTON_H
    local ry = self:drawBoostBlock(row.id, rx, dy, rw, by - 10)
    self:drawShelfBlock(row.id, rx, ry, rw, by - 10)
    if self:canUnlock() then
        self.unlockRect = { x = rx, y = by, w = rw, h = BUTTON_H }
        primaryButton(rx, by, rw, BUTTON_H, "Become " .. withArticle(row.name), body, self.hoverUnlock)
    end
end

function ClassEditor:draw(focused)
    -- Only the column the keyboard is actually in wears the steel ring. Both columns keep their
    -- selection drawn -- a house stays picked while the cursor is off reading its shelf -- so the ring
    -- is the one thing on the tab that says where the next press lands.
    local on = focused ~= false
    -- Rebuilt every frame by whatever draws them, so a rect from the other layout is never hit.
    self.previewRects, self.cardRects = {}, {}
    if self:firstPick() then
        self:drawFirstPick(on)
    else
        self:drawHouses(on and self.region == "houses")
        self:drawList(on and self.region == "classes")
        self:drawDetail()
    end
    -- A pinned card belongs to an icon still on screen; one that scrolled or switched away lets go.
    if self.pinnedPreview then
        local still = false
        for _, r in ipairs(self.previewRects) do
            if r.item == self.pinnedPreview.item then still = true break end
        end
        if not still then self.pinnedPreview = nil end
    end
    if self.hoverPreview then
        local still = false
        for _, r in ipairs(self.previewRects) do
            if r.item == self.hoverPreview.item and r.x == self.hoverPreview.x then still = true break end
        end
        if not still then self.hoverPreview = nil end
    end
    self:drawPreviewTip()
    love.graphics.setColor(1, 1, 1)
    -- THE CEREMONY, LAST, over the whole frame. The Armory forwards no update to a column editor, so the
    -- card is ticked here off the frame's own delta.
    if self.card then
        self:update(love.timer and love.timer.getDelta and love.timer.getDelta() or 0)
        if self.card then self.card:draw() end
        love.graphics.setColor(1, 1, 1)
    end
end

return ClassEditor
