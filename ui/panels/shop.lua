-- Shop pop-up panel: a decluttered vendor screen with no member data on it. A prominent vendor
-- portrait sits on the left; the middle is a single Buy / Sell list; the right is a detail pane for
-- the highlighted row. It replaces the store half of the old unified Party screen (arranging gear
-- onto characters is the Armory's job, ui/panels/party.lua).
--
-- A vendor SELLS. Upgrading anything -- gear, abilities, consumable recipes -- happens at The Forge
-- (ui/panels/forge.lua), the city's one bench. This screen used to carry an Upgrade tab for abilities
-- and recipes, which meant the same `item.level` had two doors with two bills and two ceilings.
--
-- One list at a time means ONE focus zone, which is what makes this gamepad-friendly: D-pad moves the
-- row (the detail follows with no extra press), A buys/sells it, the shoulder buttons cycle
-- Buy<->Sell, B closes. No drag, no member targeting.
--
-- Buying puts a confirmation in front of the spend (Shop:buy) -- on the pad and the keyboard the
-- confirm button is also the one that walks the list, and gold is quest-work to earn back.
--
-- The detail pane closes with a GLOSSARY block (ui/glossary_panel.lua, gathered by
-- models/glossary.lua) defining every status the highlighted item can inflict and every keyword its
-- ability declares -- docked into the column rather than floating, since this pane is a column of
-- inline text and not a hover. It follows the selection like the rest of the detail, so it costs the
-- pad and the keyboard no extra press either.
--
--   local panel = Shop.new({ vendor = "colosseum", player = p, onClose = fn })

local Menu = require("ui.menu")
local QuantityPopup = require("ui.quantity_popup")
local Choice = require("ui.panels.choice") -- the generic yes/no modal, hosted here as the buy confirmation
local DebugMenu = require("ui.panels.debug_menu") -- the right-click item menu (development builds only)
local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip") -- printFlavor (sheared italic story line) + printDiscipline
local GlossaryPanel = require("ui.glossary_panel")
local Glossary = require("models.glossary")
local Vendor = require("models.vendor")
local Player = require("models.player")
local Quest = require("models.quest") -- sponsorProgress: how many of this vendor's quests are done (its standing)
local Item = require("models.item")
local Discipline = require("models.discipline") -- unlockedSet: gates a shelf's locked discipline cut
local Combat = require("models.combat")
local Sprite = require("models.sprite")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local VendorIcons = require("ui.vendor_icons") -- the house's mark: its stand-in portrait, and its sigil

local Shop = {}
Shop.__index = Shop

local BOX_W, BOX_H = 1000, 580
local ROW_H, ROW_SPACING, MAX_VISIBLE = 38, 6, 9
-- Matches ui/menu.lua's VALUE_PAD, so the path state on a section header lines up with the name Menu
-- prints on the other side of the same row.
local HEADER_PAD = 18

-- Buy and Sell, and nothing here upgrades: every ladder in the game is climbed at The Forge
-- (ui/panels/forge.lua), which is also the only screen that spends materials -- see the header of
-- models/vendor.lua for why that second door was closed, and note that a SERVICE is not it. A service
-- does not touch `item.level` and bills no materials; it is a house's own verb, which is a different
-- thing from a second bench.
--
-- Every house does these two. A house that declares a `service` gets a third tab after them, labelled
-- by the service itself -- see models/vendor.lua's Services block for why a city of identical shelves
-- is the thing that needed fixing. Per instance rather than a file constant, because which tabs exist
-- is now a property of the vendor rather than of the panel.
-- ERRANDS IS A LIST LIKE THE OTHER TWO, and that is why it is a mode rather than a corner of the Buy
-- pane. A shelf climbs a rung at a time and each rung is bought by doing a small piece of work for the
-- house (models/errand.lua) -- so "what does this house want" is exactly as much a thing you come here
-- to read as "what does it sell", and it belongs in the same segmented control with the same
-- shoulder-button cycle rather than tucked under the stock as a footnote.
local BASE_MODES = { "buy", "sell", "errands" }
local MODE_LABEL = { buy = "Buy", sell = "Sell", errands = "Errands" }

-- Detail accent per item type (matches ui/item_tooltip.lua).
local TYPE_COLOR = {
    weapon = { 0.789, 0.361, 0.354 },
    armor = { 0.391, 0.549, 0.812 },
    consumable = { 0.361, 0.671, 0.480 },
    ability = { 0.568, 0.414, 0.786 },
    utility = { 0.865, 0.707, 0.341 },
}
local DEFAULT_COLOR = { 0.85, 0.85, 0.9 }

-- Placeholder tint for a missing vendor portrait, keyed by the vendor's deadly sin.
local SIN_COLOR = {
    wrath = { 0.52, 0.22, 0.22 }, gluttony = { 0.30, 0.44, 0.26 }, greed = { 0.50, 0.42, 0.18 },
    sloth = { 0.28, 0.34, 0.46 }, envy = { 0.22, 0.44, 0.38 }, lust = { 0.46, 0.26, 0.44 },
    pride = { 0.40, 0.28, 0.52 },
}
local SIN_DEFAULT = { 0.26, 0.28, 0.36 }

local TARGET_LABEL = { enemy = "Enemy", ally = "Ally", self = "Self", tile = "Tile" }

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Shop.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Shop)
    self.onClose = opts.onClose
    self.player = opts.player
    self.vendorId = opts.vendor
    self.def = Vendor.get(self.vendorId) or {}
    self.title = self.def.name or opts.title or "Shop"
    self.mode = "buy"
    -- Which sections the player has folded open or shut BY HAND, keyed by section (see sectionKey).
    -- Only explicit toggles live here: a key the player has never touched stays nil and takes the
    -- default from Shop:isFolded, so a path unlocked mid-session opens on its own rather than staying
    -- shut because it happened to be locked the first time the shelf was built.
    self.folded = {}

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(18)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)
    -- One step below `small`, for the glossary block at the foot of the detail column: it is reference
    -- text under the stats rather than a stat, and the smaller face is what lets three definitions fit
    -- in the room between the stat block and the price.
    self.glossFont = Theme.body(12)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.vendorSprite = self.def.sprite and Sprite.load(self.def.sprite) or nil

    -- Columns: vendor (left) | list (middle) | detail (right).
    self.vendorX = self.boxX + 24
    self.vendorY = self.boxY + 64
    self.vendorW = 260
    self.listLeft = self.vendorX + self.vendorW + 24
    self.listW = 300
    self.detailX = self.listLeft + self.listW + 24
    self.detailY = self.boxY + 112
    self.detailW = self.boxX + BOX_W - 24 - self.detailX

    -- This house's tabs: Buy, Sell, Errands, and its service if it has one.
    self.modes = { BASE_MODES[1], BASE_MODES[2], BASE_MODES[3] }
    self.service = self.def.service
    if self.service then
        self.modes[#self.modes + 1] = self.service.id
        MODE_LABEL[self.service.id] = self.service.label or "Service"
    end

    -- Mode selector segments above the list.
    self.modeY = self.boxY + 66
    self.modeH = 30
    self.segRects = {}
    local segW = self.listW / #self.modes
    for i, m in ipairs(self.modes) do
        self.segRects[m] = { x = self.listLeft + (i - 1) * segW, y = self.modeY, w = segW, h = self.modeH }
    end

    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- Every section of the Buy list FOLDS, and the player works the fold: a header is a real row that
-- takes the cursor, and Enter / A / a click on it opens or shuts the stock under it.
--
-- A path the player has not unlocked yet starts SHUT, which is the only reason the fold exists. Its
-- stock is unbuyable to the last row, and a shelf lists every path its house touches -- so with
-- everything open a vendor runs 9 to 13 screens deep with 67 to 104 dead rows in it (the Arcanum was
-- the worst: 110 rows, 104 of them locked). The header already carries the useful reading: the path's
-- name, its shape, what it needs and how much stock waits behind it.
--
-- But shut is a DEFAULT, not a verdict. The locked stock is the whole argument for earning the path,
-- and a player who wants to see what the Ninja road actually buys them can open it and read every
-- greyed row -- which is why this is a fold and not the flat hide it started as. An unlocked path
-- starts open; either can be worked the other way and stays that way for as long as the shop is open.
local BASE_KEY = "__base" -- the vendor's own shelf, which is not a discipline

local function sectionKey(disciplineId) return disciplineId or BASE_KEY end

-- Is this section shut right now? The player's own toggle wins; absent one, a locked path is shut and
-- everything else is open.
function Shop:isFolded(disciplineId)
    local explicit = self.folded[sectionKey(disciplineId)]
    if explicit ~= nil then return explicit end
    return disciplineId ~= nil and not Discipline.isUnlocked(self.player, disciplineId)
end

-- Open a shut section or shut an open one, then rebuild. `selectKey` asks refresh to put the cursor
-- back on THIS header afterwards: folding changes how many rows sit above it, so the plain
-- restore-by-index would leave the selection somewhere else entirely. `selectReveal` asks it to pull
-- the header to the top of the window as well, which only an OPENING needs -- a section opened on the
-- last visible line would otherwise unfold entirely below the fold and read as having done nothing.
function Shop:toggleSection(disciplineId)
    local key = sectionKey(disciplineId)
    self.folded[key] = not self:isFolded(disciplineId)
    self.selectKey, self.selectReveal = key, not self.folded[key]
    self:refresh()
end

-- The Buy list, banded per discipline and ordered by how many quests each row asks for. The vendor's
-- own base shelf (items with no discipline) leads under a class-named header; the discipline cuts
-- follow, each its own section -- this house's own subclasses first, then the crossings it shares with
-- other houses, and within each of those two blocks in the order the player unlocks them: by the fewest
-- quests the section gates on, then name. Within a section rows climb by quests required, then price, then
-- name, so the ladder reads top-to-bottom. A section HEADER is a Menu row that draws as a band and
-- folds its section (Menu:drawHeader); self.rows carries a matching `{ header = true }` entry at the
-- same index so the two stay aligned for the detail pane and the locked overlay. A vendor with no unlocked discipline
-- stock shows no headers at all -- a single base section needs no banner -- so the plain shelf looks
-- exactly as it did.
-- THE ERRANDS TAB: what this house has asked for, and WHERE IT IS.
--
-- The floor number is the whole reason this list exists. An errand is seated on one particular floor of
-- the descent (models/errand.lua), and a player who has to remember which one is doing bookkeeping the
-- game could have done for them -- so every row leads with it.
--
-- THIS HOUSE'S ONLY, because this is its shop and its shelf they open. Another house's work is legible
-- at that house's counter, which is also where the stock it buys is.
--
-- Rows are not selectable: there is nothing to press. An errand is taken on when the house asks for it
-- (states/hub.lua's vendorScenes) rather than accepted off a list, so this is a readout, and `locked`
-- is what stops the list widget offering a Take button over a row that has none.
function Shop:buildErrandRows()
    local Errand = require("models.errand")
    local open = Errand.open(self.player)

    for _, e in ipairs(open) do
        if e.def and e.def.sponsor == self.vendorId then
            self.rows[#self.rows + 1] = {
                errand = e,
                label = "Floor " .. e.floor .. "  -  " .. (e.def.name or e.id),
                locked = true,
            }
        end
    end

    if #self.rows == 0 then
        -- WHY there is nothing here, which is three different situations and only one of them is "done".
        -- A house with nothing to ask reads identically to one you have not been deep enough for, and
        -- the player can do something about exactly one of those.
        local done = Errand.done(self.player, self.vendorId)
        local nextId = Errand.next(self.player, self.vendorId)
        local text
        if not nextId then
            text = "You have run everything this house has to ask for."
        else
            text = "Nothing outstanding. They will ask again once you have been as deep as floor "
                .. Errand.floorFor(self.player, self.vendorId) .. "."
        end
        -- Not rows. A Menu row is one line of a fixed height (ui/menu.lua) and this is a sentence --
        -- put through the list it wrapped inside its own plate and printed straight over the tally
        -- underneath it. The panel already has a place for prose with nothing behind it: the empty
        -- state, which wraps and stacks (Shop:draw).
        self.errandNote = text
        self.errandTally = done > 0
            and (done .. (done == 1 and " errand run for them." or " errands run for them."))
            or nil
    end
end

function Shop:buildBuyRows()
    local groups, order = {}, {}
    local stock = Vendor.stock(self.vendorId, self.shelfRung, self.player.recipes,
        Discipline.unlockedSet(self.player), Discipline.levelSet(self.player))
    for _, entry in ipairs(stock) do
        -- Instantiate at the item's recipe tier, so its name (+n) and stats reflect what's bought.
        local item = Item.instantiate(entry.id, nil, entry.level)
        local key = entry.discipline or false -- false == the base shelf, not a discipline
        local g = groups[key]
        if not g then
            g = { rows = {}, minUnlock = entry.unlockQuests,
                name = entry.discipline and (Discipline.displayName(entry.discipline) or entry.discipline)
                    or (Item.classDisplayName(self.def.class) or "General") }
            groups[key], order[#order + 1] = g, key
        end
        g.minUnlock = math.min(g.minUnlock, entry.unlockQuests)
        g.discipline = entry.discipline
        g.arity = entry.discipline and Discipline.arity(entry.discipline) or 0
        g.open = (g.open or 0) + (entry.locked and 0 or 1)
        -- Stock a quest opened and the player has not looked at yet wears the red dot (Player.markNew).
        -- A shelf runs dozens of rows deep and the reward panel names at most four of them, so without
        -- this the player is told that something new is here and then left to find it by reading.
        local isNew = not entry.locked and Player.isNew(self.player, Player.NEW_STOCK, entry.id)
        if isNew then g.isNew = true end -- so a shut section still shows there is something under it
        g.rows[#g.rows + 1] = {
            item = item, entry = entry,
            label = item.name .. "  -  " .. (entry.locked and "locked" or (entry.price .. "g")),
            locked = entry.locked,
            isNew = isNew,
        }
    end

    table.sort(order, function(a, b)
        if (a == false) ~= (b == false) then return a == false end -- base shelf always leads
        local ga, gb = groups[a], groups[b]
        -- This house's own subclasses before any crossing. Arity IS the distinction (models/discipline.lua):
        -- one parent is a path OUT OF this class, two is a path shared with another house. The single-parent
        -- cuts are what a player standing in this shop can earn from here, so they read as one block under
        -- the base shelf instead of being scattered through the crossings by gate depth.
        if ga.arity ~= gb.arity then return ga.arity < gb.arity end
        if ga.minUnlock ~= gb.minUnlock then return ga.minUnlock < gb.minUnlock end
        return ga.name < gb.name
    end)

    local banded = #order > 1 -- a lone base section needs no header
    for _, key in ipairs(order) do
        local g = groups[key]
        table.sort(g.rows, function(r1, r2)
            if r1.entry.unlockQuests ~= r2.entry.unlockQuests then return r1.entry.unlockQuests < r2.entry.unlockQuests end
            if r1.entry.price ~= r2.entry.price then return r1.entry.price < r2.entry.price end
            return r1.item.name < r2.item.name
        end)
        -- Folded shut, a section shows its header and nothing else (see the note above buildBuyRows on
        -- why a locked path starts that way). Guarded on `banded`: a shelf with no header to open again
        -- must never be able to fold its only section into nothing.
        --
        -- Note that a lock is not what hides a row -- the fold is. A row held by nothing worse than this
        -- house's quest count stays visible inside an OPEN section: "complete 2 more" is a near thing
        -- worth showing, and it is the near things that pull.
        local folded = banded and self:isFolded(g.discipline)
        if banded then
            self.rows[#self.rows + 1] = {
                header = true, label = g.name, key = sectionKey(g.discipline), discipline = g.discipline,
                meta = self:pathMeta(g.discipline), blurb = self:sectionBlurb(g.discipline),
                count = (g.open or 0) .. " / " .. #g.rows,
                open = g.open or 0, total = #g.rows, collapsed = folded,
                -- Only while SHUT: an open section shows the dots on the rows themselves, and two
                -- marks for one piece of news reads as two pieces of news.
                isNew = folded and g.isNew or nil,
            }
        end
        if not folded then
            for _, r in ipairs(g.rows) do self.rows[#self.rows + 1] = r end
        end
    end
end

-- What a section header says about the PATH it bands, beside its name: the shape of the discipline and
-- where the player stands in it. Nil for the base shelf, which is not a path and has nothing to stand in.
--
--   "rogue path  -  technique 14"      an unlocked subclass, and how far it has been grown
--   "rogue x mage  -  locked"          a crossing not yet earned
--
-- This is what turns the Buy list into a progression tracker without a second screen. The shelf was
-- ALREADY banded by discipline and ALREADY ordered by gate depth -- the ladder was there and only the
-- rungs were labelled. Every path a house touches is a section here whether or not it is open, so the
-- list reads as "what this house can eventually teach me", with the locked stock under each heading
-- showing exactly what earning it buys. A tree screen names the node; this names the node and shows
-- the payload, which is the thing the player actually wants.
-- What the section IS, under the shape line: the class's or the discipline's own blurb -- its identity
-- and the mechanic it is built on (Item.classDescription / Discipline.description).
--
-- The shelf was banded and gated and counted and could still not answer the first question a player
-- asks of a heading they have never seen: what is a Warden, and what would having one do for me? A
-- LOCKED path collapses to its header, so this pane is the only room that question has -- "Knight x
-- Hunter, locked, 5 pieces of stock" names the price of a thing it never describes. The blurb is what
-- makes the ladder worth climbing rather than merely legible.
function Shop:sectionBlurb(disciplineId)
    if disciplineId then return Discipline.description(disciplineId) end
    return Item.classDescription(self.def.class)
end

function Shop:pathMeta(disciplineId)
    if not (disciplineId and Discipline.defs[disciplineId]) then return nil end

    local parents = Discipline.parents(disciplineId)
    local names = {}
    for _, c in ipairs(parents) do names[#names + 1] = Item.classDisplayName(c) or c end
    -- Arity IS the distinction (models/discipline.lua): one parent is a subclass, two is a crossing.
    local shape = (#names >= 2) and (names[1] .. " x " .. names[2]) or ((names[1] or "?") .. " path")

    if Discipline.isUnlocked(self.player, disciplineId) then
        return shape .. "  -  technique " .. Discipline.technique(self.player, disciplineId)
    end

    -- A locked path collapses to this header, so the header is the ONLY place its requirement can be
    -- read -- Menu steps over a header, which means the detail pane's lockReason never renders for one.
    -- Name the house when the player is ONE path away, because that is the case they can act on today.
    -- Two away, `shape` has already named both halves and a second clause would only make the line
    -- long enough to collide with the count.
    local missing = Discipline.missingParents(self.player, disciplineId)
    if #missing == 1 then
        local house = Vendor.get(Vendor.forClass(missing[1]))
        if house and house.name then return shape .. "  -  needs " .. house.name end
    end
    return shape .. "  -  locked"
end

-- Rebuild self.rows + the Menu for the current mode. Called on open, on mode switch, and after every
-- transaction so newly unlocked stock / spent gold / changed stash is reflected without reopening.
function Shop:refresh()
    local selected = self.menu and self.menu.selected or 1
    -- The scroll window is carried over as well as the selection. A rebuild that kept only the
    -- selection put the row back under the cursor but at whatever line scrollToSelection could reach
    -- it from -- so buying something forty rows down threw the list back to the top and dragged the
    -- window forward until the row scraped in at the bottom edge. A purchase changes no row's index;
    -- the list must not appear to move at all. `setMode` drops the menu first, so a mode switch still
    -- starts at the top.
    local scroll = self.menu and self.menu.scroll or 0
    self.questsDone = Quest.sponsorProgress(self.player, self.vendorId)
    -- What the SHELF reads, one below the standing above it: the opener bought the door this panel is
    -- being drawn inside, not a band of stock (Quest.shelfRung). The two are kept apart here rather than
    -- collapsed because the header still reports errands run, and that is the honest count.
    self.shelfRung = Quest.shelfRung(self.player, self.vendorId)
    self.rows = {}
    self.errandNote, self.errandTally = nil, nil

    if self.mode == "buy" then
        self:buildBuyRows()
    elseif self.mode == "fence" then
        self:buildFenceRows()
    elseif self.mode == "errands" then
        self:buildErrandRows()
    else -- sell
        for i, item in ipairs(self.player.stash or {}) do
            local value = Vendor.sellValue(item)
            local qty = (item.quantity or 1) > 1 and ("  x" .. item.quantity) or ""
            self.rows[#self.rows + 1] = {
                item = item, index = i, value = value,
                label = (item.name or "?") .. "  -  " .. (value > 0 and (value .. "g") or "--") .. qty,
                locked = value <= 0,
            }
        end
    end

    local items = {}
    for i, row in ipairs(self.rows) do
        if row.header then
            -- A header with an `action` is a fold Menu will let the cursor land on (ui/menu.lua).
            items[#items + 1] = { label = row.label, header = true, collapsed = row.collapsed,
                isNew = row.isNew, action = function() self:toggleSection(row.discipline) end }
        else
            items[#items + 1] = { label = row.label, isNew = row.isNew,
                action = function() self:activateRow(self.rows[i]) end }
        end
    end
    self.menu = Menu.new(items, {
        buttonWidth = self.listW,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + 112,
        centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu.scroll = scroll -- scrollToSelection below clamps it and only nudges it if it has to
    -- Just folded a section: land on THAT header rather than on whatever row inherited its index.
    if self.selectKey then
        for i, row in ipairs(self.rows) do
            if row.header and row.key == self.selectKey then
                self.menu.selected = i
                if self.selectReveal then self.menu:scrollTopTo(i) end
                break
            end
        end
        self.selectKey, self.selectReveal = nil, nil
    end
    -- A fold header takes the cursor now, so there is nothing here to step past. Kept because it is
    -- what guarantees the invariant -- the selection sits on a row that can be activated -- and the
    -- panel does not decide alone which rows Menu considers selectable.
    self.menu:clampSelectable()
    self.menu:scrollToSelection()
    -- Compute row rects now so the first draw/click works before the first update() tick.
    self.menu:layout()
end

function Shop:hasRows() return self.rows and #self.rows > 0 end

function Shop:setMode(mode)
    self.mode = mode
    self.swapFrom = nil -- leaving the fence puts down whatever was being traded
    self.menu = nil
    self:refresh()
end

function Shop:cycleMode(delta)
    local idx = 1
    for i, m in ipairs(self.modes) do if m == self.mode then idx = i end end
    self:setMode(self.modes[(idx - 1 + delta) % #self.modes + 1])
end

-- ---------------------------------------------------------------------------
-- The Fence (the Undercroft's service)
-- ---------------------------------------------------------------------------

-- TWO STEPS IN ONE LIST, rather than a modal over a modal. Step one lists what the fence will take;
-- picking a row swaps the same list for what it will give back, with a Back row at the top. The
-- alternative -- a chooser popup -- was rejected because the number of offers is not small or fixed
-- (ui/panels/choice.lua tops out at a handful of options) and because the detail column is the whole
-- reason this reads: the player needs to compare what they are giving up against what they would get,
-- and both are ordinary item rows with ordinary tooltips when they live in the same list.
function Shop:buildFenceRows()
    local recipes = self.player.recipes
    local unlocked, levels = Discipline.unlockedSet(self.player), Discipline.levelSet(self.player)

    if not self.swapFrom then
        for i, item in ipairs(self.player.stash or {}) do
            local offers = Vendor.swapOffers(self.vendorId, item, self.shelfRung, recipes, unlocked, levels)
            local fee = Vendor.swapFee(item)
            -- An item with nothing to trade for is LISTED AND GREYED rather than hidden, for the same
            -- reason the shelf greys a locked row: a stash entry that silently vanishes from a tab reads
            -- as a bug, and "nothing of its worth is on this shelf yet" is a real answer that points at
            -- the quest ladder. The reason lands in the detail column via fenceLockReason.
            self.rows[#self.rows + 1] = {
                item = item, index = i, offers = offers, fee = fee,
                label = (item.name or "?") .. "  -  " .. (#offers > 0 and (fee .. "g") or "--"),
                locked = #offers == 0 or not fee,
            }
        end
        return
    end

    -- Step two: what the fence will hand back for the piece already on the counter.
    self.rows[#self.rows + 1] = { back = true, label = "< Back" }
    for _, entry in ipairs(self.swapFrom.offers or {}) do
        -- `item` is the blueprint, as on a Buy row: it is what the detail column, the sprite and the
        -- glossary all read, so an offer row must carry it or picking one shows a blank pane.
        self.rows[#self.rows + 1] = {
            item = Item.defs[entry.id], entry = entry, swapTo = entry,
            label = (entry.name or "?") .. "  -  " .. (entry.price or 0) .. "g",
        }
    end
end

-- Why the fence will not take this piece. Read by the detail column, so a greyed row explains itself
-- rather than merely refusing.
function Shop:fenceLockReason(row)
    local item = row.item
    if not item then return "Nothing to trade." end
    if Item.isBound(item) then return "Bound to its bearer. Not yours to trade, whatever it is worth." end
    if not item.price then return "Never had a price. Nobody will take it, here least of all." end
    return "Nothing of its worth on this shelf yet -- run more of this house's line and come back."
end

-- Do the trade: the piece on the counter leaves the stash, its replacement arrives, the fee is paid.
--
-- The fee is checked BEFORE anything moves, so a player short of coin is told no rather than walked
-- through a swap that half-happens. Nothing else can fail after that point: the offer list was built
-- from unlocked stock, and Item.instantiate cannot decline.
function Shop:swap(row)
    local from, to = self.swapFrom, row.swapTo
    if not (from and to) then return end
    local fee = from.fee or 0
    if (self.player.gold or 0) < fee then
        self:setMsg("The fee is " .. fee .. "g. You have " .. (self.player.gold or 0) .. "g.", false)
        return
    end

    self.player.gold = (self.player.gold or 0) - fee
    -- Remove the traded piece by IDENTITY, not by the index the row was built with: the stash can be
    -- reordered by anything that ran since (a sale on the other tab, a stack merging), and an index
    -- that has gone stale would quietly fence the wrong item.
    for i, it in ipairs(self.player.stash or {}) do
        if it == from.item then table.remove(self.player.stash, i) break end
    end
    local got = Item.instantiate(to.id, 1, to.level or 0)
    table.insert(self.player.stash, got)
    Player.save()

    self.swapFrom = nil
    self.menu = nil
    self:refresh()
    self:setMsg("Traded " .. (from.item.name or "?") .. " for " .. (got.name or "?")
        .. "  (-" .. fee .. "g)", true)
end

function Shop:setMsg(text, ok) self.message, self.messageOk = text, ok end

function Shop:close()
    self.itemDebug = nil -- a context menu never outlives the panel it was opened over
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- Transactions
-- ---------------------------------------------------------------------------

function Shop:activateRow(row)
    if not row then return end
    if self.mode == "buy" then
        self:buy(row)
    elseif self.mode == "errands" then
        -- A READOUT, NOT A SHELF. An errand is taken on when the house asks for it in person
        -- (states/hub.lua's vendorScenes), so there is nothing on these rows to press -- and the
        -- `locked` they carry is the panel's own flag, which the list widget never sees (ui/menu.lua
        -- only steps over a bare header), so the cursor does land here and the press must be answered.
        -- Falling through to the sell branch is what it used to do, and it sold a row with no item.
        if row.errand then
            self:setMsg("They ask for this in person. There is nothing to take on here.", false)
        end
    elseif self.mode == "fence" then
        if row.back then
            self.swapFrom = nil; self.menu = nil; self:refresh()
        elseif row.swapTo then
            self:swap(row)
        elseif row.locked then
            self:setMsg(self:fenceLockReason(row), false)
        else
            self.swapFrom = row
            self.menu = nil
            self:refresh()
            -- Land on the first OFFER, not on the Back row that leads the list. Back is a way out
            -- rather than a thing, so it has no detail card -- opening step two with the cursor on it
            -- shows an empty pane at the exact moment the player most wants to compare what they are
            -- giving up against what they would get.
            if self.rows[2] then
                self.menu.selected = 2
                self.menu:scrollToSelection()
            end
            self:setMsg("For " .. (row.item.name or "?") .. ", the fence offers:", true)
        end
    else
        self:sell(row)
    end
end

-- Why a greyed shelf row is not yet buyable. A discipline row is held by its own gate quest, which no
-- amount of this house's ordinary quests will open -- so that reason LEADS when the discipline is still
-- locked, and only a plain quest-count row falls back to "complete N more of this house's quests".
--
-- The Buy list collapses a fully-locked path to its header (buildBuyRows), so the first branch below is
-- not normally reachable FROM the shelf any more -- Shop:pathMeta says the same thing, compressed, on
-- the header instead. It is kept whole because it is the complete answer to the question and the panel
-- is not the only thing that decides which rows exist: Vendor.stock still returns that stock, and a
-- future caller (or a change to the collapse rule) must not silently fall through to "Locked."
function Shop:lockReason(entry)
    if entry.discipline and not Discipline.isUnlocked(self.player, entry.discipline) then
        -- A CROSSING names the parent path still missing, and the house that teaches it. "Unlock the
        -- Ninja path first" is true and useless -- it restates the lock. Naming the Arcanum turns it
        -- into somewhere to go, which is the only reason a locked row is worth showing at all.
        local missing = Discipline.missingParents(self.player, entry.discipline)
        local parts = {}
        for _, class in ipairs(missing) do
            local house = Vendor.get(Vendor.forClass(class))
            local label = (Item.classDisplayName(class) or class):lower() .. " path"
            parts[#parts + 1] = house and (label .. " (" .. house.name .. ")") or label
        end
        if #parts > 0 then
            return "Locked: needs a " .. table.concat(parts, " and a ") .. "."
        end
        -- Parents held (or a subclass, which has none): what stands in the way is its own gate quest.
        local def = Discipline.defs[entry.discipline]
        local gate = def and (def.requiredQuests or {})[1]
        local quest = gate and Quest.defs[gate]
        local name = Discipline.displayName(entry.discipline) or entry.discipline
        if quest and quest.name then
            return "Locked: complete \"" .. quest.name .. "\" to open the " .. name .. " path."
        end
        return "Locked: the " .. name .. " path is not open yet."
    end
    -- The deepest cut: the path is open, but this piece asks that you have actually GROWN into it.
    if entry.unlockLevel and Discipline.level(self.player, entry.discipline) < entry.unlockLevel then
        local name = Discipline.displayName(entry.discipline) or entry.discipline
        return "Locked: grow " .. name .. " to level " .. entry.unlockLevel .. "."
    end
    local remaining = (entry.unlockQuests or 0) - (self.shelfRung or 0)
    if remaining > 0 then
        local quests = remaining == 1 and "quest" or "quests"
        return "Locked: complete " .. remaining .. " more of this house's " .. quests .. "."
    end
    return "Locked."
end

-- Buying ASKS first. A shelf row is one press away from the cursor on every input device -- and on the
-- pad and the keyboard, confirm is the same button that moves you around the list -- so the old
-- straight-through buy meant a stray Enter spent gold that takes quests to earn back, with a sell-back
-- at a fraction of the price as the only undo. The question names the item and the price and stops
-- there: the purse is already on screen behind it, and the two buttons need no explaining.
--
-- Affordability is settled BEFORE the question is asked. Being walked through a confirmation and only
-- then told no is a worse answer than being told no on the press.
function Shop:buy(row)
    local entry = row.entry
    if entry.locked then
        self:setMsg(self:lockReason(entry), false)
        return
    end
    local gold = self.player.gold or 0
    if gold < entry.price then
        self:setMsg("Not enough gold.", false)
        return
    end
    local item = Item.instantiate(entry.id, nil, entry.level)
    self.confirm = Choice.new({
        title = "Confirm Purchase",
        prompt = (item.name or "?") .. "  -  " .. entry.price .. " gold",
        options = {
            { label = "Buy", accent = { 0.42, 0.80, 0.62 },
                cb = function() self.confirm = nil; self:commitBuy(entry) end },
            { label = "Cancel", accent = { 0.78, 0.52, 0.50 },
                cb = function() self.confirm = nil end },
        },
        onClose = function() self.confirm = nil end,
    })
end

function Shop:commitBuy(entry)
    if not Player.spendGold(self.player, entry.price) then
        self:setMsg("Not enough gold.", false)
        return
    end
    local item = Item.instantiate(entry.id, nil, entry.level)
    Player.addToStash(self.player, item)
    -- Unseen in the stash until looked at, exactly like a granted reward: the message below says it is
    -- in the stash, and the dot is what makes that findable once the stash is sixty rows long. (An
    -- inventory RESHUFFLE never marks -- see Player.markNew -- so only arrivals dot.)
    Player.markNew(self.player, Player.NEW_STASH, entry.id)
    Player.save()
    self:setMsg(item.name .. " bought. It is in your stash.", true)
    self:refresh()
end

function Shop:sell(row)
    local item = row.item
    local value = Vendor.sellValue(item)
    if value <= 0 then
        self:setMsg((item.name or "That") .. " can't be sold here.", false)
        return
    end
    if Item.isStackable(item) and (item.quantity or 1) > 1 then
        self.quantityPopup = QuantityPopup.new({
            max = item.quantity, value = item.quantity,
            title = "Sell how many?", label = item.name,
            onConfirm = function(n) self.quantityPopup = nil; self:commitSell(item, value, n) end,
            onCancel = function() self.quantityPopup = nil end,
        })
        return
    end
    self:commitSell(item, value, 1)
end

function Shop:commitSell(item, value, n)
    n = math.max(1, math.min(n, item.quantity or 1))
    item.quantity = (item.quantity or 1) - n
    if item.quantity <= 0 then
        for i, it in ipairs(self.player.stash or {}) do
            if it == item then Player.takeFromStash(self.player, i) break end
        end
    end
    Player.addGold(self.player, value * n)
    Player.save()
    self:setMsg("Sold " .. n .. "x " .. (item.name or "item") .. " for " .. (value * n) .. "g.", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function Shop:update(dt)
    -- The confirmation owns everything while it is up, the analog stick included -- Menu:update reads
    -- the stick directly, so leaving it ticking would let the list scroll under the question.
    if self.confirm then return end
    if self.quantityPopup then self.quantityPopup:update(dt) return end
    if self:hasRows() then
        self.menu:update(dt)
        self:seeSelectedRow()
    end
end

-- The selected row is the row being READ -- the detail pane on the right is showing it in full -- so
-- landing on it is what clears its unseen dot, whether the cursor got there by mouse, key or pad.
-- Checked here rather than at each of those input paths for exactly that reason, and it costs nothing
-- while the selection sits on a row with no mark (Player.seeNew is a table lookup, and only a real
-- clearing writes a save).
function Shop:seeSelectedRow()
    local row = self.rows and self.rows[self.menu.selected]
    if not (row and row.isNew and row.entry) then return end
    row.isNew = false
    local menuItem = self.menu.items[self.menu.selected]
    if menuItem then menuItem.isNew = nil end
    if Player.seeNew(self.player, Player.NEW_STOCK, row.entry.id) then Player.save() end
end

function Shop:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    self:drawVendor()
    self:drawModeSelector()
    if self:hasRows() then
        self.menu:draw()
        self:drawHeaderMeta()
        self:drawLockedOverlay()
        self:drawDetail()
    else
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        local empty = "Your stash is empty."
        if self.mode == "buy" then
            empty = "Nothing for sale."
        elseif self.mode == "fence" then
            -- Two different emptinesses, and saying "your stash is empty" for the second would be a
            -- lie: a company can be carrying plenty and simply have nothing this shelf can match.
            empty = self.swapFrom and "Nothing of its worth on this shelf." or "Nothing here to trade."
        elseif self.mode == "errands" then
            empty = self.errandNote or empty
        end
        local y = self.boxY + 200
        love.graphics.printf(empty, self.listLeft, y, self.listW, "center")
        -- The tally sits under the sentence, so it has to start below however many lines that sentence
        -- actually took -- the floor number can push it to two.
        if self.errandTally then
            local _, wrapped = self.bodyFont:getWrap(empty, self.listW)
            y = y + #wrapped * self.bodyFont:getHeight() + 10
            love.graphics.printf(self.errandTally, self.listLeft, y, self.listW, "center")
        end
    end

    self:drawFooter()
    self.closeButton:draw()
    if self.quantityPopup then self.quantityPopup:draw() end
    if self.confirm then self.confirm:draw() end
    if self.itemDebug then self.itemDebug:draw() end -- last: it is modal over everything above
    love.graphics.setColor(1, 1, 1)
end

function Shop:drawVendor()
    local x, y, w = self.vendorX, self.vendorY, self.vendorW
    local h = self.boxY + BOX_H - 44 - y
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)

    local portraitH = h - 92
    local pad = 12
    local px, py, pw, ph = x + pad, y + pad, w - pad * 2, portraitH - pad * 2
    if type(self.vendorSprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = self.vendorSprite:getDimensions()
        local scale = math.min(pw / sw, ph / sh)
        love.graphics.draw(self.vendorSprite, px + pw / 2, py + ph / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        -- NO PORTRAIT YET, so the plate stands in for one -- and what it carries is the HOUSE'S OWN MARK
        -- (ui/vendor_icons.lua), the same shape that stands on this house's work out on the ground.
        --
        -- It carried the name's first LETTER before, which was the closest thing this panel had to a bug
        -- you could look straight at: six of the seven houses are "The something", so six shops in a row
        -- showed a big "T". The mark tells them apart, and it is the one place a player is standing
        -- still, looking at a shelf, with the house's name printed above -- which is where a mark that
        -- has to be recognised on a 32px tile gets learned.
        local tint = SIN_COLOR[self.def.sin] or SIN_DEFAULT
        love.graphics.setColor(tint[1], tint[2], tint[3])
        love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
        local mark = math.min(pw, ph) * 0.52
        if not VendorIcons.draw(self.vendorId, px + (pw - mark) / 2, py + (ph - mark) / 2, mark, mark,
                Theme.ink[1], Theme.ink[2], Theme.ink[3]) then
            love.graphics.setFont(self.titleFont)
            Theme.set(Theme.ink)
            love.graphics.printf((self.def.name or "?"):sub(1, 1), px, py + ph / 2 - 20, pw, "center")
        end
    end

    local ty = y + portraitH + 2
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print(self.player.gold .. " gold", x + 12, ty)
    Theme.set(Theme.ink)
    -- Standing here is purely a count of this house's quests you have finished; the "N more to unlock"
    -- detail lives on each locked row instead, so this line stays short and never wraps into the
    -- description below. A vendor with no shelf of its own (the Cafe) runs no quest line and shows
    -- nothing -- though it does not open this panel at all any more (ui/panels/cafe.lua).
    if self.def.sells ~= false then
        love.graphics.printf("Errands run: " .. (self.questsDone or 0), x + 12, ty + 22, w - 24, "left")
    end
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(self.def.description or "", x + 12, ty + 44, w - 24, "left")
end

function Shop:drawModeSelector()
    love.graphics.setFont(self.bodyFont)
    for _, m in ipairs(self.modes) do
        local r = self.segRects[m]
        local active = (self.mode == m)
        Theme.set(active and Theme.panel or Theme.panel2)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(active and 1.5 or 1)
        Theme.set(active and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)
        Theme.set(active and Theme.accentAmber or Theme.muted)
        love.graphics.printf(MODE_LABEL[m], r.x, r.y + r.h / 2 - 10, r.w, "center")
    end
end

-- The path state on each section header, drawn beside the name Menu:drawHeader already printed: the
-- shape and standing on the right, the open/total count hard right. An overlay rather than a longer
-- label because a header carries one string through Menu, and packing three columns into it with
-- spaces does not hold under a proportional face -- the same reason drawLockedOverlay paints over the
-- menu's own rects instead of asking Menu to know about locked rows.
function Shop:drawHeaderMeta()
    love.graphics.setFont(self.smallFont)
    for i, row in ipairs(self.rows) do
        local slot = self.menu.items[i]
        if row.header and slot and slot.x then
            local ty = slot.y + slot.h / 2 - self.smallFont:getHeight() / 2
            local right = slot.x + slot.w - HEADER_PAD
            if row.count then
                Theme.set(Theme.muted)
                local cw = self.smallFont:getWidth(row.count)
                love.graphics.print(row.count, right - cw, ty)
                right = right - cw - 16
            end
            if row.meta then
                -- Steel, not amber: the header's NAME is the earned thing and already wears the accent
                -- (Menu:drawHeader). This is the reading beside it, and two golds on one line would
                -- flatten the distinction the theme keeps between "live" and "structure".
                Theme.set(Theme.cursor)
                local mw = self.smallFont:getWidth(row.meta)
                love.graphics.print(row.meta, math.max(slot.x + HEADER_PAD, right - mw), ty)
            end
        end
    end
end

-- Menu has no disabled row, so grey the locked/unsellable/maxed ones by painting over them.
function Shop:drawLockedOverlay()
    for i, row in ipairs(self.rows) do
        local slot = self.menu.items[i]
        if row.locked and slot and slot.x then
            Theme.set(Theme.mount, 0.6)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, Theme.R, Theme.R)
        end
    end
end

-- What the detail column says while the cursor sits on a section header instead of an item. A shut
-- section has no rows to select, so this is the only room left to say what is behind it: the shape of
-- the path, how much of its stock is actually buyable, and what is holding the rest. Without it the
-- right third of the screen would go blank the moment the fold did its job.
function Shop:drawSectionDetail(row)
    local x, y, w = self.detailX, self.detailY, self.detailW
    love.graphics.setFont(self.headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(row.label or "", x, y, w, "left")

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    -- The base shelf is not a path and pathMeta gives it nothing; say what it is instead of nothing.
    love.graphics.printf(row.meta or "this house's own rack", x, y + 26, w, "left")

    -- What the thing IS, leading in ink: the reading the player came for (Shop:sectionBlurb). The stock
    -- count drops to muted small underneath it -- it is bookkeeping about the section, not the section.
    local sy = y + 52
    if row.blurb then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf(row.blurb, x, sy, w, "left")
        local _, lines = self.bodyFont:getWrap(row.blurb, w)
        sy = sy + #lines * self.bodyFont:getHeight() + 12
    end

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local stock = (row.total == 1) and "1 piece" or (row.total .. " pieces")
    love.graphics.printf(stock .. " of stock, " .. row.open .. " of it open to you.", x, sy, w, "left")

    local ty = self.boxY + BOX_H - 96
    if row.discipline and not Discipline.isUnlocked(self.player, row.discipline) then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(self:lockReason({ discipline = row.discipline }), x, ty - 44, w, "left")
    end
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local press = InputMode.isGamepad() and "A" or "Enter"
    love.graphics.printf(press .. ": " .. (row.collapsed and "open this section" or "close this section"),
        x, ty, w, "left")
end

function Shop:drawDetail()
    local row = self.rows[self.menu.selected]
    if not row then return end
    if row.header then self:drawSectionDetail(row) return end
    -- The fence's Back row is a navigation control rather than a thing, so it has no item and nothing
    -- to describe. Guarded here rather than by giving it a dummy item, which would put a blank card in
    -- the detail column and read as a broken row.
    if row.back then return end
    local item = row.item
    if not item then return end
    local x, y, w = self.detailX, self.detailY, self.detailW
    local accent = TYPE_COLOR[item.type] or DEFAULT_COLOR

    -- The item's own art sits top-right of the pane; the header and description wrap in the column to
    -- its left (textW). Stock without art (or under headless) keeps the full width, exactly as before.
    local SPR = 64
    local spr = Sprite.load(item.sprite)
    local hasSprite = type(spr) == "userdata"
    local textW = hasSprite and (w - SPR - 12) or w
    if hasSprite then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = spr:getDimensions()
        local scale = math.min(SPR / sw, SPR / sh)
        love.graphics.draw(spr, x + w - SPR / 2, y + SPR / 2, 0, scale, scale, sw / 2, sh / 2)
    end

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(accent[1], accent[2], accent[3])
    love.graphics.printf(item.name or "?", x, y, textW, "left")
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf((item.type or "item"):upper(), x, y + 26, textW, "left")
    -- The discipline this item falls under, opposite its type on the same line. It is the shelf's own
    -- answer to "why is this here and not on the open rack": a priced row in the locked deeper cut
    -- names the discipline that unlocked it, and a multiclass row names the one that put it on THIS
    -- vendor's shelf rather than the other parent's. Most stock carries none and the line stays bare.
    ItemTooltip.printDiscipline(item, x, y + 26, textW, self.smallFont)

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    local desc = item.description or ""
    love.graphics.printf(desc, x, y + 48, textW, "left")
    -- Where the mechanical block picks up: right under the description (or the sprite, whichever runs
    -- lower), not at a fixed row -- a one-line description no longer leaves a gap before the stats.
    local _, descLines = self.bodyFont:getWrap(desc, textW)
    local descBottom = y + 48 + #descLines * self.bodyFont:getHeight()
    local contentTop = math.max(descBottom, hasSprite and (y + SPR) or descBottom) + 12

    -- The story line reads last, just above the glossary (docs/item-text.md): in buy/sell it sits under
    -- the stat block, drawn there below.
    local function drawFlavor(fy)
        if item.flavor and item.flavor ~= "" then
            return ItemTooltip.printFlavor(item.flavor, x, fy, w, self.bodyFont)
        end
        return 0
    end

    -- Quick stats. The item's primary stat -- the one magnitude that defines it (armor's defense, a
    -- blade's Power), quoted at its current level -- leads the block for ANY item, armor included.
    local sy = contentTop
    love.graphics.setFont(self.smallFont)
    local function statLine(label, value, valueColor)
        Theme.set(Theme.muted)
        love.graphics.print(label, x, sy)
        local vc = valueColor or Theme.ink
        love.graphics.setColor(vc[1], vc[2], vc[3])
        love.graphics.printf(value, x, sy, w, "right")
        sy = sy + 20
    end
    local ab = item.activeAbility
    -- A dry-run against a zero-stat caster surfaces a healing ability's restored amount by the Power.
    local out = ab and Combat.abilityOutput(nil, item)
    local primaryValue, primaryLabel = Item.primaryStat(item)
    if primaryValue then statLine(primaryLabel, tostring(primaryValue), { 0.95, 0.72, 0.48 }) end
    if out and out.heal > 0 then statLine("Heal", "+" .. out.heal, { 0.55, 0.90, 0.58 }) end
    if ab then
        if ab.target then statLine("Target", TARGET_LABEL[ab.target] or ab.target) end
        statLine("Range", tostring(ab.range or 1))
        if ab.speed then statLine("Speed", tostring(ab.speed)) end
        -- One line however many pools it draws on: the shelf is comparing weapons, not budgeting a
        -- turn, so "4 mana + 5 stamina" is the useful shape here (the in-battle tooltip splits them).
        local costs = Item.costs(ab)
        if #costs > 0 then
            local parts = {}
            for _, c in ipairs(costs) do parts[#parts + 1] = c.amount .. " " .. c.stat end
            statLine("Cost", table.concat(parts, " + "))
        end
    end

    -- The story line closes the mechanical block, sat just above the glossary that follows it.
    local flavorH = drawFlavor(sy + 6)
    if flavorH > 0 then sy = sy + 6 + flavorH end

    -- What the shelf otherwise never says: every status this thing can inflict and every keyword its
    -- ability declares, defined in the room between the stat block and the price. This column has no
    -- "Applies" row of its own -- unlike the in-battle tooltip -- so for a shopper the glossary is the
    -- ONLY place a weapon admits it burns. It sizes itself to the gap and spends a "+n more" on
    -- anything that will not fit, rather than running over the transaction line below.
    local glossY = sy + 10
    local glossMaxH = (self.boxY + BOX_H - 96) - 12 - glossY
    local entries = Glossary.forItem(item, nil, out or false)
    if #entries > 0 and glossMaxH > 0 then
        love.graphics.setColor(0.30, 0.33, 0.40, 0.8)
        love.graphics.line(x, glossY - 6, x + w, glossY - 6)
        GlossaryPanel.drawColumn(entries, x, glossY, w, glossMaxH,
            { nameFont = self.smallFont, descFont = self.glossFont, capFont = self.glossFont })
    end

    -- The transaction line for this mode.
    love.graphics.setFont(self.bodyFont)
    local ty = self.boxY + BOX_H - 96
    if self.mode == "buy" then
        if row.entry.locked then
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf(self:lockReason(row.entry), x, ty, w, "left")
        else
            love.graphics.setColor(0.95, 0.85, 0.55)
            love.graphics.printf("Price: " .. row.entry.price .. " gold", x, ty, w, "left")
        end
    elseif self.mode == "fence" then
        -- Step one names the FEE, step two names what the trade actually costs and gives, because
        -- those are the two different questions the player is asking at those two moments.
        if row.swapTo then
            love.graphics.setColor(0.7, 0.85, 0.7)
            love.graphics.printf("Trade " .. (self.swapFrom.item.name or "?") .. " for this  -  "
                .. (self.swapFrom.fee or 0) .. " gold", x, ty, w, "left")
        elseif row.locked then
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf(self:fenceLockReason(row), x, ty, w, "left")
        else
            love.graphics.setColor(0.95, 0.85, 0.55)
            love.graphics.printf("Fee: " .. (row.fee or 0) .. " gold  -  "
                .. #(row.offers or {}) .. " on offer", x, ty, w, "left")
        end
    else
        if row.value > 0 then
            love.graphics.setColor(0.7, 0.85, 0.7)
            love.graphics.printf("Sell value: " .. row.value .. " gold each", x, ty, w, "left")
        else
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf("Cannot be sold here.", x, ty, w, "left")
        end
    end
end

function Shop:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    Theme.set(Theme.muted)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    -- The tab-cycle key is named after what it actually cycles: at a house with a service the strip has
    -- three tabs, and a hint reading "Buy/Sell" tells the player the third one is unreachable from the
    -- keyboard, which it is not.
    -- Three base tabs now (Buy, Sell, Errands), so the shoulder cycle is never a two-way toggle and the
    -- hint never names a pair.
    local cycle = "switch list"
    local hint = InputMode.isGamepad()
        and ("A: confirm    LB/RB: " .. cycle .. "    D-pad: scroll    B: close")
        or ("Enter: confirm    Tab: " .. cycle .. "    Wheel: scroll    Esc: close")
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- The item debug menu (development builds only)
-- ---------------------------------------------------------------------------

-- Open the debug context menu on the shelf row under the pointer. Returns true when one opened.
-- A LOCKED row counts: what it stands on is a blueprint like any other, and "why can I not buy this
-- yet" is one of the questions the menu's grade page exists to answer -- so the lookup goes through
-- Menu:indexAt, which does not care whether the row can be activated.
function Shop:openItemDebug(x, y)
    if not self:hasRows() then return false end
    local i = self.menu:indexAt(x, y)
    local row = i and self.rows[i]
    if not row or not row.item then return false end
    local menu = DebugMenu.forItem({
        x = x, y = y,
        item = row.item,
        onClose = function() self.itemDebug = nil end,
        -- A reload changes the name and the price the row's LABEL was built from, so the shelf is
        -- rebuilt rather than left reading yesterday's figures.
        refresh = function() self:refresh() end,
    })
    if not menu then return false end
    self.itemDebug = menu
    return true
end

function Shop:mousemoved(x, y)
    if self.itemDebug then self.itemDebug:mousemoved(x, y) return end
    if self.confirm then self.confirm:mousemoved(x, y) return end
    if self.quantityPopup then self.quantityPopup:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    if self:hasRows() then self.menu:mousemoved(x, y) end
end

-- Hand over the close X, the Buy/Sell mode tabs, or any item row; arrow elsewhere. When the
-- sell-quantity popup is open it owns the pointer. See ui/cursor.lua.
function Shop:cursorKind(x, y)
    if self.itemDebug then return self.itemDebug:cursorKind(x, y) end
    if self.confirm then return self.confirm:cursorKind(x, y) end
    if self.quantityPopup then return self.quantityPopup:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    for _, m in ipairs(self.modes) do
        if pointIn(self.segRects[m], x, y) then return "hand" end
    end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function Shop:wheelmoved(dx, dy)
    if self.itemDebug then self.itemDebug:wheelmoved(dx, dy) return end
    if self.confirm then return end -- the list must not scroll out from under the question
    if self.quantityPopup then self.quantityPopup:wheelmoved(dy) return end
    if self:hasRows() then self.menu:wheelmoved(dx, dy) end
end

function Shop:mousepressed(x, y, button)
    if self.itemDebug then self.itemDebug:mousepressed(x, y, button) return end
    if self.confirm then self.confirm:mousepressed(x, y, button) return end
    if self.quantityPopup then self.quantityPopup:mousepressed(x, y, button) return end
    if button == 2 then self:openItemDebug(x, y) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, m in ipairs(self.modes) do
        if pointIn(self.segRects[m], x, y) then self:setMode(m) return end
    end
    if self:hasRows() then
        self.menu:mousepressed(x, y, button)
        -- Keep the detail/selection in sync even if the click missed a row.
        return
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function Shop:keypressed(key)
    if self.itemDebug then self.itemDebug:keypressed(key) return end
    if self.confirm then self.confirm:keypressed(key) return end
    if self.quantityPopup then self.quantityPopup:keypressed(key) return end
    if key == "escape" then self:close()
    elseif key == "tab" then self:cycleMode(1)
    elseif key == "left" or key == "a" then self:cycleMode(-1)
    elseif key == "right" or key == "d" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:keypressed(key) end
end

function Shop:gamepadpressed(joystick, button)
    if self.itemDebug then self.itemDebug:gamepadpressed(joystick, button) return end
    if self.confirm then self.confirm:gamepadpressed(joystick, button) return end
    if self.quantityPopup then self.quantityPopup:gamepadpressed(joystick, button) return end
    if button == "b" then self:close()
    elseif button == "leftshoulder" then self:cycleMode(-1)
    elseif button == "rightshoulder" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:gamepadpressed(joystick, button) end
end

return Shop
