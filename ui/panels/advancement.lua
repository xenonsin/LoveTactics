-- "Company Advancement" overlay: the post-quest summary, opened by the hub on entry whenever a quest
-- was just completed (states/hub.lua consumes player.pendingSummary). It surfaces the reward table
-- Quest.complete builds -- gold, the run's forging haul, what the quest handed over, and what it put
-- on its sponsor's shelf.
--
-- IT NO LONGER REPORTS LEVEL-UPS, and the hole that left is what the calendar bar fills.
--
-- This panel was built around them: prestige levelled the whole roster at the payout, and the bar
-- underneath showed the climb toward the next one so that a quest which levelled nobody -- most of
-- them -- still read as progress. Both halves went at once. A body earns its own level in the
-- fighting now and is told so there (models/experience.lua), and prestige does not exist
-- (models/calendar.lua). `reward.advancement` comes back empty every time.
--
-- So the bar is the CALENDAR, which is a better answer to the question it was always really asking.
-- An expedition always spends a day, whatever it found -- the one reading that can never come back
-- empty, and under a deadline the one that matters most.
--
-- Modal, owned by the hub (mirrors ui/panels/encounter.lua): the state forwards input while it is
-- open, and it closes via the X button, Enter, Esc, or gamepad B/A. Three-input + mouse-only. A long
-- roster scrolls (wheel / up-down / D-pad).
--
--   local panel = Advancement.new({ reward = questRewardTable, onClose = fn })

local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local Growth = require("models.growth")
local Discipline = require("models.discipline")
local Material = require("models.material")

local Advancement = {}
Advancement.__index = Advancement

local BOX_W = 560
local ROW_H = 46

-- Everything above the level-up list (title, rewards, the section heading) and everything below it (the
-- footer prompt). The box is sized to its CONTENT between them: a quest that levelled nobody is a short
-- panel rather than a tall one with a hole in it, which matters now that most quests are exactly that.
--
-- IT WAS 54PX TALLER, AND A BAR LIVED IN THE DIFFERENCE. See SECTION_Y.
local HEAD_H, FOOT_H = 151, 56
local MAX_ROWS = 6

-- The two boxed sections that sit between the reward header and the level-up list, stacked in this
-- order and each costing no height at all on a quest that has none of it:
--
--   "Items gained"                 what the quest HANDED OVER (reward.received) -- named, because they
--                                  are already in the stash and the panel is the only place they are
--                                  announced (battle loot and chests get their own reveal en route).
--   "New items unlocked at <shop>" what the quest put on its sponsor's SHELF (reward.unlockedStock) --
--                                  counted but deliberately NOT named: the campaign loop is "run a
--                                  house's quest, then spend at the shelf it opened", so the player is
--                                  told which shop moved and reads the goods at the shop itself.
local SEC_HEAD_H = 22 -- a section heading ("Items gained", "New items unlocked at <shop>")
local SEC_ROW_H = 19  -- one plain text row under a heading (the "+N more" line)
local SEC_TOP_PAD = 10 -- clearance above a section
local SEC_PAD = 12    -- gap between a section and whatever sits under it
local GAIN_MAX_ROWS = 4

-- A gained row carries the item's ICON, so it is taller than a text row: the name alone asks the
-- player to remember what "The Drowned Censer" looked like when they next open the Armory, and the
-- icon is what they will actually be scanning that stash for. Hovering the row opens the item's full
-- sheet (ui/item_tooltip.lua), which is the only way to read what the thing DOES without walking to
-- the Armory first.
local GAIN_ROW_H = 28
local GAIN_ICON = 22

-- Where the first section starts, as an offset from the box top: just below the reward header, which is
-- also where "The company grows" sits when there is no section at all (hence the shared number).
--
-- TWO BARS HAVE STOOD IN THE 54PX THIS RECLAIMS, and the second is worth recording because the first
-- one's deletion is what invented it. It was a PRESTIGE step -- a level cost several prestige while a
-- quest paid one, so most quests levelled nobody and the bar was the only thing that said the company
-- had advanced at all. Prestige went; the DAY took the slot, on the argument that an expedition always
-- spends one, so it was the reading that could never come back empty. Then the deadline went too
-- (models/calendar.lua) and a bar that fills toward nothing is a bar that promises an end it cannot
-- deliver -- "He comes" over a campaign nobody is counting down to.
--
-- SO THE SLOT IS CLOSED RATHER THAN REFILLED A THIRD TIME. What is left on this panel is what the run
-- actually handed over, and the empty-list line below says where the levels went. A third number
-- invented to keep a rectangle occupied is how the first two got here.
local SECTION_Y = 123

-- Stat display names + a stable order, matching the Loadout panel's sheet (ui/panels/party.lua).
local STAT_LABEL = {
    health = "HP", mana = "MP", stamina = "SP",
    damage = "Attack", magicDamage = "Magic",
    defense = "Defense", magicDefense = "M.Def",
    movement = "Move", speed = "Speed",
}
local STAT_ORDER = { "health", "mana", "stamina", "damage", "magicDamage", "defense", "magicDefense", "movement", "speed" }

local function classLabel(class)
    if not class then return "" end
    return Discipline.displayName(class) or (class:gsub("^%l", string.upper))
end

-- How a level-up's gains were apportioned, in words: "as Knight 52% · Mage 48%", or plainly "as Knight"
-- when one house took the whole level. `shares` is Growth.resolve's own apportionment
-- (models/growth.lua), so this reports what actually happened rather than re-deriving it.
--
-- A level is a BLEND now -- every house cast since the last one gets its share, instead of the leader
-- taking all of it and the rest being discarded -- so naming only the leader would under-report most
-- level-ups on this screen. Trimmed to the top three: a busy character can touch more houses than a
-- row has width for, and the tail is rounding.
local function sharesText(entry)
    local shares = entry.shares
    if not shares then return "as " .. classLabel(entry.class) end

    local ranked = {}
    for key, share in pairs(shares) do
        if share > 0 then ranked[#ranked + 1] = { key = key, share = share } end
    end
    if #ranked <= 1 then return "as " .. classLabel(entry.class) end

    table.sort(ranked, function(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.key < b.key
    end)

    local parts = {}
    for i = 1, math.min(3, #ranked) do
        -- Rounded for reading, so the printed percentages can sum to 99 or 101. Naming the split is the
        -- job here; the arithmetic that matters already happened in Growth.applyLevelBlend.
        parts[#parts + 1] = classLabel(ranked[i].key)
            .. " " .. tostring(math.floor(ranked[i].share * 100 + 0.5)) .. "%"
    end
    return "as " .. table.concat(parts, " · ")
end

-- "+3 Magic, +5 MP" from a { stat = amount } gains table, in the sheet's stat order.
local function gainsText(gains)
    local parts = {}
    for _, stat in ipairs(STAT_ORDER) do
        local amount = gains and gains[stat]
        if amount and amount ~= 0 then
            parts[#parts + 1] = "+" .. amount .. " " .. (STAT_LABEL[stat] or stat)
        end
    end
    return table.concat(parts, ", ")
end

-- How much room the two sections take, and what goes in them, from the reward table alone -- font-free
-- so the sizing can be read (and tested) without a window:
--
--   gained / gainRows / gainMore / gainH   the items the quest handed over, capped to GAIN_MAX_ROWS
--                                          with the overflow spoken as a "+N more" line
--   stock / stockH                         the sponsor shelf it opened, one heading whatever the count
--   sectionsH                              the two stacked, which is what the box grows by
function Advancement.sections(reward)
    local s = {}

    -- What the quest handed over: the item instances Quest.complete granted into the stash. A long
    -- haul truncates rather than growing the box without limit -- the Armory is where the whole stash
    -- is read, and those rows wear the unseen dot until they are.
    s.gained = reward.received or {}
    s.gainH, s.gainRows, s.gainMore = 0, 0, 0
    if #s.gained > 0 then
        s.gainRows = math.min(#s.gained, GAIN_MAX_ROWS)
        s.gainMore = #s.gained - s.gainRows
        s.gainH = SEC_TOP_PAD + SEC_HEAD_H + s.gainRows * GAIN_ROW_H
            + (s.gainMore > 0 and SEC_ROW_H or 0) + SEC_PAD
    end

    -- The shelf this quest opened, as { vendor = shop name, items = { { name, price }, ... } }. A quest
    -- that opened nothing carries nil and the section costs no height at all.
    local stock = reward.unlockedStock
    s.stock = (type(stock) == "table" and stock.items and #stock.items > 0) and stock or nil
    -- One heading, whatever the size of the haul: the section is a pointer to a shop, not a catalogue,
    -- so its height does not move with the item count.
    s.stockH = s.stock and (SEC_TOP_PAD + SEC_HEAD_H + SEC_PAD) or 0

    s.sectionsH = s.gainH + s.stockH
    return s
end

function Advancement.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Advancement)
    self.reward = opts.reward or {}
    self.onClose = opts.onClose
    self.entries = self.reward.advancement or {}
    self.scroll = 0 -- first visible entry index - 1

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(18)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)

    for k, v in pairs(Advancement.sections(self.reward)) do self[k] = v end

    -- One row minimum, so the "no one levelled" line has somewhere to sit. The roster list is also
    -- what YIELDS when the sections above it are tall: a full haul plus an opened shelf plus six
    -- level-ups is taller than 720, and the list is the part that already scrolls, so it gives up
    -- rows rather than letting the box run off the screen.
    self.headH = HEAD_H + self.sectionsH
    local room = math.floor((Scale.HEIGHT - 40 - self.headH - FOOT_H) / ROW_H)
    self.visible = math.max(1, math.min(#self.entries, MAX_ROWS, room))
    self.boxH = self.headH + self.visible * ROW_H + FOOT_H

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    -- List viewport: below the reward header, above the footer prompt. Sized from
    -- `visible` above rather than the other way round, so the box wraps the rows instead of the rows
    -- being fitted into a fixed box.
    self.listX = self.boxX + 24
    self.listY = self.boxY + self.headH
    self.listW = BOX_W - 48
    self.listH = self.visible * ROW_H

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- Hit rects for the gained rows, laid out once here so drawGained and the hover test can never
    -- disagree about where a row is. Mouse-only, like the loot cards on the victory panel: this is a
    -- summary you read and close, so the tooltip stays out of the keyboard/pad path (up/down keep
    -- scrolling the roster).
    self.gainRects = {}
    local gainRowsY = self.boxY + SECTION_Y + SEC_TOP_PAD + SEC_HEAD_H
    for i = 1, self.gainRows do
        self.gainRects[i] = {
            x = self.listX - 6, y = gainRowsY + (i - 1) * GAIN_ROW_H,
            w = self.listW + 12, h = GAIN_ROW_H,
        }
    end
    self.hoverGain = nil
    self.mx, self.my = 0, 0

    -- The company grew: ring the level-up cue as the overlay opens, but only when there is actually an
    -- advancement to celebrate (a quest with no level-ups shows "No advancement this time" in silence).
    if #self.entries > 0 then require("models.sound").play("quest.levelup") end
    return self
end

function Advancement:close()
    if self.onClose then self.onClose() end
end

function Advancement:maxScroll()
    return math.max(0, #self.entries - self.visible)
end

function Advancement:scrollBy(delta)
    self.scroll = math.max(0, math.min(self:maxScroll(), self.scroll + delta))
end

-- The one-line reward header: gold and the forging stock the run banked -- the caches the
-- party walked to, plus the salvage the objective itself left behind (models/spoils.lua). The
-- materials used to be granted in silence here, which made the whole detour economy a number that
-- changed somewhere off screen; naming them is the only place a finished run says what it mined.
-- Sorted by name so the same haul always reads the same way (`pairs` would reshuffle it every quest).
function Advancement:rewardLine()
    local r = self.reward
    local parts = {}
    if (r.gold or 0) > 0 then parts[#parts + 1] = r.gold .. " gold" end

    local mats = {}
    for id, count in pairs(r.materials or {}) do
        if (count or 0) > 0 then
            local def = Material.get(id)
            mats[#mats + 1] = ((def and def.name) or id) .. " x" .. count
        end
    end
    table.sort(mats)
    if #mats > 0 then parts[#parts + 1] = table.concat(mats, ", ") end

    -- NOTHING ELSE GOES ON THIS LINE. It used to also name the houses a DESCENT banked standing with,
    -- from a `standing` table of vendor -> circles that a descent's extraction once returned here.
    -- Two things ended that. A run's account is drawn by Descent.account off its own `circles` field
    -- and never reaches this overlay, and `standing` on a quest reward is a NUMBER -- the company's
    -- finished-quest count (models/quest.lua) -- so the surviving loop was walking `pairs` over an
    -- integer and taking the panel down on every completed quest. The sponsor this quest advanced is
    -- named in its own section below, which is the only standing a quest earns.
    return table.concat(parts, "    ")
end

function Advancement:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    -- Named by whatever earned the overlay. A descent is not a quest and must not announce itself as
    -- one -- it walks out of a hole having cleared circles, not off a board having finished an errand
    -- (models/descent.lua's extract). A quest passes no title and keeps the wording it always had.
    love.graphics.printf(self.reward.title or "Quest Complete", self.boxX, self.boxY + 22, BOX_W, "center")

    -- Reward header. Fitted rather than drawn at a fixed size: a run that emptied four caches names
    -- four materials on this line, and the fix for that is a smaller native face, never a scaled one.
    local line = self:rewardLine()
    local font = Theme.fitText(Theme.display, line, BOX_W - 48, 18, 12)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.printf(line, self.boxX + 24, self.boxY + 66, BOX_W - 48, "center")

    -- A companion who just joined outranks every other line on this panel: gold and new stock change
    -- what you can buy, a recruit changes who you field. So it sits highest, in the brightest colour
    -- the box uses, while the shelf gets its own section below the bar.
    local joined = self.reward.recruited
    if joined then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.95, 0.7)
        love.graphics.printf(tostring(joined.name or "A companion") .. " joins the company",
            self.boxX + 24, self.boxY + 92, BOX_W - 48, "center")
    end

    self:drawGained()
    self:drawStock()

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.muted)
    love.graphics.print("The company grows", self.listX, self.boxY + SECTION_Y + self.sectionsH)

    self:drawList()
    self:drawFooter()

    self.closeButton:draw()

    -- The hovered item's full sheet, last so it sits over the panel it hangs off.
    local hovered = self.hoverGain and self.gained[self.hoverGain]
    if hovered and InputMode.isMouse() then
        ItemTooltip.draw(hovered, self.mx, self.my, Scale.WIDTH)
    end
    love.graphics.setColor(1, 1, 1)
end

-- "Items gained" -- what the quest itself handed over (reward.received: a general's relic, whatever a
-- sponsor pays in kind), already sitting in the stash by the time this panel opens. Named, unlike the
-- shelf below it: these are owned, not offered, and this panel is their only announcement -- loot picked
-- up on the map got its chest reveal en route, but a quest's own reward arrived in silence and the
-- player had to go find it in a sixty-row stash to learn what it was.
--
-- Each row is icon + name + kind, and hovering one opens the item's full sheet. A name on its own
-- announced that something arrived without ever saying what it was worth carrying: the icon is what
-- the player will recognise in the stash later, and the tooltip is the only chance to read the thing
-- before deciding whether the Armory is the next door.
function Advancement:drawGained()
    if self.gainH == 0 then return end

    local x, w = self.listX, self.listW
    local y = self.boxY + SECTION_Y + SEC_TOP_PAD

    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", x - 6, y - 6, w + 12,
        self.gainH - SEC_TOP_PAD - SEC_PAD + 12, Theme.R, Theme.R)

    local n = #self.gained
    local count = n == 1 and "1 item" or (n .. " items")
    local countW = self.smallFont:getWidth(count) + 12
    local font, head = Theme.fitText(Theme.body, "Items gained", w - countW, 15, 12)
    love.graphics.setFont(font)
    Theme.set(Theme.accentAmber)
    love.graphics.print(head, x, y)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(count, x, y + 2, w, "right")

    local ry = y + SEC_HEAD_H
    for i = 1, self.gainRows do
        local item = self.gained[i]
        local rect = self.gainRects[i]
        if self.hoverGain == i then
            Theme.set(Theme.slot, 0.8)
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, Theme.R, Theme.R)
        end

        self:drawGainIcon(item, x, ry + (GAIN_ROW_H - GAIN_ICON) / 2)
        local tx = x + GAIN_ICON + 10

        -- The kind is what says where the thing goes -- a weapon to a grid, a consumable to the pack --
        -- so it holds its width and the name steps down a size to fit (never a scaled font).
        local kind = classLabel(item.type)
        local kindW = kind ~= "" and self.smallFont:getWidth(kind) + 12 or 0
        local avail = w - (tx - x) - kindW
        local font, name = Theme.fitText(Theme.body, item.name or "?", avail, 14, 11)
        love.graphics.setFont(font)
        Theme.set(Theme.ink)
        love.graphics.print(name, tx, ry + (GAIN_ROW_H - font:getHeight()) / 2)
        if kind ~= "" then
            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted)
            love.graphics.printf(kind, x, ry + (GAIN_ROW_H - self.smallFont:getHeight()) / 2, w, "right")
        end
        ry = ry + GAIN_ROW_H
    end

    if self.gainMore > 0 then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.print("+" .. self.gainMore .. " more in the stash", x, ry)
    end
end

-- One gained item's icon, GAIN_ICON square with its top-left at (x, y). A missing image falls back to
-- the name's initial on a plate, the same convention every other icon in the game uses -- art lands
-- incrementally here (models/sprite.lua returns the path string when the file is not there yet).
function Advancement:drawGainIcon(item, x, y)
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(GAIN_ICON / sw, GAIN_ICON / sh)
        love.graphics.draw(sprite, x + GAIN_ICON / 2, y + GAIN_ICON / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", x, y, GAIN_ICON, GAIN_ICON, 4, 4)
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.printf((item.name or "?"):sub(1, 1), x,
            y + GAIN_ICON / 2 - self.smallFont:getHeight() / 2, GAIN_ICON, "center")
    end
end

-- "New items unlocked at the Colosseum Armory -- 2 items": that this quest moved that shelf, and how
-- much of it. The panel used to say only that stock had appeared *somewhere*, which left the player to
-- go door-knocking for it; naming the shop is what makes the quest read as the thing that bought the
-- goods. The goods themselves stay unnamed -- reading them is what the visit to the shop is for. Sits
-- directly under the reward header: what the company earned, then where it may now spend, then who grew.
function Advancement:drawStock()
    if not self.stock then return end

    local x, w = self.listX, self.listW
    -- Stacked under the "Items gained" section, which is nothing at all on a quest that gave none.
    local y = self.boxY + SECTION_Y + self.gainH + SEC_TOP_PAD

    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", x - 6, y - 6, w + 12,
        self.stockH - SEC_TOP_PAD - SEC_PAD + 12, Theme.R, Theme.R)

    -- "New items unlocked at <shop>" spelled out: "New at <shop>" read as a place rather than as an
    -- event, and the whole point of the line is that a quest just PUT something on that shelf. The
    -- count keeps its width and the heading steps down a size to fit beside it (never a scaled font).
    local n = #self.stock.items
    local count = n == 1 and "1 item" or (n .. " items")
    local countW = self.smallFont:getWidth(count) + 12
    local font, head = Theme.fitText(Theme.body,
        "New items unlocked at " .. tostring(self.stock.vendor or "the sponsor's shop"),
        w - countW, 15, 12)
    love.graphics.setFont(font)
    Theme.set(Theme.accentAmber)
    love.graphics.print(head, x, y)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(count, x, y + 2, w, "right")
end

function Advancement:drawList()
    if #self.entries == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.62, 0.7)
        -- The ordinary case now, and permanently: levels are earned in the fighting and announced
        -- there, so this list is empty on every quest. Rather than a denial, say where they went --
        -- a player who reads "no advancement" after a won expedition will believe it.
        love.graphics.printf("Levels are earned in the fighting, and were paid out where they were won.",
            self.listX, self.listY + 8, self.listW, "left")
        return
    end

    local last = math.min(#self.entries, self.scroll + self.visible)
    for i = self.scroll + 1, last do
        local entry = self.entries[i]
        local y = self.listY + (i - self.scroll - 1) * ROW_H
        self:drawEntry(entry, self.listX, y, self.listW, ROW_H - 6)
    end

    -- Overflow chevrons when the roster is taller than the viewport.
    if #self.entries > self.visible then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.64, 0.75, self.scroll > 0 and 0.9 or 0.2)
        love.graphics.printf("^", self.listX, self.listY - 14, self.listW, "center")
        love.graphics.setColor(0.6, 0.64, 0.75, self.scroll < self:maxScroll() and 0.9 or 0.2)
        love.graphics.printf("v", self.listX, self.listY + self.listH + 2, self.listW, "center")
    end
end

function Advancement:drawEntry(entry, x, y, w, h)
    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)

    local char = entry.char or {}
    local ps = h - 8
    local px, py = x + 4, y + 4

    -- Portrait (sprite, or the name's initial as a fallback -- same convention as party.lua).
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 9, ps, "center")
    end

    local tx = px + ps + 12

    -- Name + "Lv X -> Y" + the class it grew as, on the top line.
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.print(char.name or "?", tx, y + 5)

    local levelText = "Lv " .. tostring(entry.fromLevel) .. " -> " .. tostring(entry.toLevel)
    love.graphics.setColor(0.6, 0.85, 0.6)
    love.graphics.printf(levelText, x, y + 5, w - 10, "right")

    -- How the level was apportioned + the stat gains, on the second line. The split can run long on a
    -- character who plays three houses, so it is fitted rather than left to overrun the gains beside it.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.75, 0.7, 0.5)
    local gt = gainsText(entry.gains)
    local gainW = self.smallFont:getWidth(gt)
    local classText = Theme.ellipsize(sharesText(entry), self.smallFont,
        math.max(60, w - (tx - x) - gainW - 20))
    love.graphics.print(classText, tx, y + 24)

    love.graphics.setColor(0.72, 0.78, 0.86)
    local classW = self.smallFont:getWidth(classText)
    love.graphics.print(gt, tx + classW + 10, y + 24)
end

function Advancement:drawFooter()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.6, 0.63, 0.7)
    -- Show the glyph for the device last used: pad button only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad() and "A to continue" or "Enter / Click X to continue"
    love.graphics.printf(hint, self.boxX, self.boxY + self.boxH - 30, BOX_W, "center")
end

function Advancement:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    self.hoverGain = nil
    for i, r in ipairs(self.gainRects) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self.hoverGain = i
            break
        end
    end
end

-- Hand over the close X (the only button; the rest is a summary). See ui/cursor.lua.
function Advancement:cursorKind(x, y)
    return self.closeButton:contains(x, y) and "hand" or "arrow"
end

function Advancement:wheelmoved(_, dy)
    if dy ~= 0 then self:scrollBy(-dy) end
end

function Advancement:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    -- A click anywhere outside the box dismisses it too (it is a summary, nothing to lose).
    if x < self.boxX or x > self.boxX + BOX_W or y < self.boxY or y > self.boxY + self.boxH then
        self:close()
    end
end

function Advancement:keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" or key == "space" then
        self:close()
    elseif key == "up" or key == "w" then self:scrollBy(-1)
    elseif key == "down" or key == "s" then self:scrollBy(1)
    end
end

function Advancement:gamepadpressed(_, button)
    if button == "b" or button == "a" or button == "start" then
        self:close()
    elseif button == "dpup" then self:scrollBy(-1)
    elseif button == "dpdown" then self:scrollBy(1)
    end
end

return Advancement
