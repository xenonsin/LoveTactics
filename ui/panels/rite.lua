-- THE RITE: the Cathedral's other room, and the mending with an item where the body goes.
--
-- See models/curse.lua for what a curse is and data/buildings/cathedral.lua for why this room stands in
-- this house. In one line: the same two ways out the Ward offers, because it is the same law underneath
-- (docs/the-count.md) -- LIFT is gold and the hex is off before you leave, LEAVE is free and costs the
-- trips the piece spends on the altar. Gold buys speed and never relief.
--
-- SO THIS PANEL IS ui/panels/ward.lua's TWIN, deliberately and almost line for line. Two rows per
-- afflicted thing rather than one row that opens a chooser; the free row always drawn and the paid row
-- only when the purse can cover it; the ones already being worked on listed underneath, not actionable,
-- because they are the bill for a choice already made. A player who has learned the Ward has learned
-- this room, and every difference between the two would be a difference they have to notice.
--
-- WHAT IS DIFFERENT, AND WHY. There are exactly three.
--
--   THE HEX IS NAMED ON THE PAID ROW. A bone is a bone -- the Ward never has to say which -- but a curse
--   is a thing with a name, a sentence and a price of its own, and the price is only readable as fair
--   beside the name. "Lift The Anchor -- 400g" is a decision; "Lift the curse -- 400g" is a toll.
--
--   THE BEARER IS NAMED WHEN THERE IS ONE. A hexed piece in a grid is a body walking around hurt by it;
--   a hexed piece in the stash is a problem the player has already parked. Both belong in the list --
--   the room should finish the job either way -- but they are not the same urgency, and the name is the
--   cheapest way to say which is which.
--
--   A ROW CAN BE ABOUT A PIECE THAT CANNOT BE PUT DOWN. That is the whole point of the room and it needs
--   no special case here: Curse.commit takes the item off whatever grid it is in, because a bind holds
--   against the player and not against the priests.
--
-- NO COACH. The Ward's first morning is scripted -- Rowan is carried up broken by the end of Act 0, so
-- the room knows it is teaching a first morning and holds the player until the bone is answered -- and
-- nothing in this game hexes anything on a schedule. The first curse arrives when the rift deals one,
-- so the teaching is the door appearing on the plaza the morning after it lands (models/offer.lua's
-- GATES.cursed) plus the tooltip on the piece.

local CloseButton = require("ui.close_button")
local Curse = require("models.curse")
local Keeper = require("ui.keeper") -- the city's keeper pane: face or mark, name, line
local Menu = require("ui.menu")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local Sound = require("models.sound")

local Rite = {}
Rite.__index = Rite

-- Wider than the Ward's 820 because the rows carry two names apiece where its carry one -- the piece
-- (with its bearer) and the hex on it. The keeper's column is the same width in both, so all 140 of the
-- extra pixels go to the rows, which is where the reading happens. Still well inside the 1280 logical
-- width with a gutter either side, so the city reads behind it as every other modal's does.
local BOX_W, BOX_H = 960, 420
local ROW_W, ROW_H = 600, 40
local PAD = 24

-- WHERE THE ROWS START, AND HOW LITTLE IS LEFT UNDER THEM. Named rather than typed twice, because the
-- altar list below the rows is positioned off the same arithmetic and the two collided the first time:
-- the Ward anchors its resting list to the BOX's foot, which is fine while its rows never reach that far
-- and is a pile-up here, where two rows per hexed piece fills the column much faster.
--
-- SO THE BAND IS RESERVED AND THE ROWS ARE CAPPED TO WHAT IS LEFT (Rite:visibleRows). The list under the
-- rows is the growing thing that must not be dropped, and the menu is the grower that scrolls -- which
-- is the right way round: a row that scrolled off is still reachable, and an altar line that got covered
-- is a piece the player owns with nothing on screen saying where it went.
local ROWS_TOP = 120          -- relative to boxY
local FOOTER_H = 52           -- the "Esc to close" line plus its air
local ALTAR_LINE = 20         -- one line of the altar list
local ALTAR_MAX = 3           -- ...and at most this many before it folds into "+N more"

function Rite.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Rite)
    self.player = opts.player
    self.onClose = opts.onClose
    -- The house behind this room (models/offer.lua hands it down): the Cathedral.
    self.vendorId = opts.vendor
    self.titleFont = Theme.display(30)
    self.bodyFont = Theme.body(17)
    self.rowFont = Theme.body(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    -- The keeper's column down the left, and the rows in what is left. Every room behind a desk holds
    -- the person the desk introduced (ui/keeper.lua); this one is the Cathedral's, same as the Ward's.
    self.keeperX = self.boxX + PAD
    self.keeperY = self.boxY + 64
    self.keeperH = BOX_H - 64 - PAD
    self.colX = self.keeperX + Keeper.W + PAD
    self.colW = self.boxX + BOX_W - PAD - self.colX

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self:rebuild()
    return self
end

-- What to call the piece in a row. The bearer's name when it is in somebody's grid, because a hex on a
-- body walking around with it is a different fact from a hex on something shelved -- and because the
-- player's question at this counter is "which of my four is carrying that", not "which of my items".
--
-- THE ARTICLE COMES OFF UNDER A POSSESSIVE, which is one line and is the difference between "Rowan's
-- Hexbinder's Cord" and "Rowan's The Hexbinder's Cord". Roughly a fifth of the catalogue is named with
-- a leading article, so this is not a special case for one item.
local function pieceLabel(entry)
    local name = entry.item.name or "that piece"
    if entry.char then
        return (entry.char.name or entry.char.id) .. "'s " .. (name:gsub("^The ", ""))
    end
    return name
end

-- The altar list, capped: at most ALTAR_MAX lines, then one more saying how many did not fit. A company
-- that has committed six pieces is a real state and a list that simply kept growing would walk down over
-- the footer and off the box -- so it folds rather than being dropped, which is the rule for any band
-- that has to share a column with something else.
function Rite:altarLines()
    local rites = Curse.rites(self.player)
    local out = {}
    for i, entry in ipairs(rites) do
        if i > ALTAR_MAX then
            out[#out + 1] = string.format("...and %d more on the altar", #rites - ALTAR_MAX)
            break
        end
        out[#out + 1] = string.format("%s is on the altar  -  %d descents left",
            entry.item.name or "A piece", entry.left or 0)
    end
    return out
end

-- How many rows the menu may show, given what the altar list is taking. Everything under the rows is
-- reserved FIRST and the menu gets what is left, never the other way round -- see the constants above.
function Rite:visibleRows()
    local band = #self:altarLines() * ALTAR_LINE
    local room = BOX_H - ROWS_TOP - FOOTER_H - band
    return math.max(2, math.floor((room + 8) / (ROW_H + 8)))
end

-- The rows, rebuilt after every press: lifting a hex takes both of that piece's rows off the list and
-- committing one takes the piece out of the company entirely, so the menu the player is looking at is
-- stale the instant either one lands.
function Rite:rebuild()
    local p = self.player
    local items = {}
    for _, entry in ipairs(Curse.kit(p)) do
        local item = entry.item
        local fee = Curse.fee(item)
        -- THE PAID ROW DISAPPEARS WHEN THE PURSE IS SHORT rather than greying out -- a control appears
        -- only where it is legal, and the purse is on the header, so the player is never left guessing
        -- which of the two facts stopped them. The Ward's own rule, kept.
        if (p.gold or 0) >= fee then
            items[#items + 1] = {
                kind = "lift",
                -- Label left, price right (Menu's setting-row shape), because a column of prices is
                -- read by scanning the prices -- the same way the Ward's two rows are read against each
                -- other. A `sub` line would have carried the bearer instead, but the widget takes a
                -- `value` or a `sub` and never both, and the price is the half a decision is made on.
                label = string.format("Lift %s from %s", Curse.name(item), pieceLabel(entry)),
                value = string.format("%dg", fee),
                action = function()
                    if Curse.pay(p, item) then Sound.play("ui.confirm") end
                    self:rebuild()
                end,
            }
        end
        items[#items + 1] = {
            kind = "commit",
            label = string.format("Leave %s to the rite", pieceLabel(entry)),
            value = string.format("%d descents", Curse.RITE_DESCENTS),
            action = function()
                if Curse.commit(p, item) then Sound.play("ui.confirm") end
                self:rebuild()
            end,
        }
    end
    self.items = items
    self.menu = #items > 0 and Menu.new(items, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = 8,
        startY = self.boxY + ROWS_TOP,
        -- The rows centre on their own COLUMN, not on the screen -- the keeper's pane holds the left of
        -- the box. Same split the Ward makes.
        centerX = self.colX + self.colW / 2,
        font = self.rowFont,
        maxVisible = self:visibleRows(),
    }) or nil
end

function Rite:close()
    if self.onClose then self.onClose() end
end

function Rite:update(dt) if self.menu then self.menu:update(dt) end end

function Rite:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    -- Centred on the ROWS' column, not on the box: a title centred on the whole panel sits over the gap
    -- between the keeper's pane and the rows and reads as a slip rather than as the heading of anything.
    love.graphics.printf("The Rite", self.colX, self.boxY + 26, self.colW, "center")

    -- The purse, on the header, because one of the two prices is in gold and the other is not -- so the
    -- number that decides which rows exist has to be readable without closing the panel.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.printf(string.format("%dg", (self.player and self.player.gold) or 0),
        self.boxX, self.boxY + 66, BOX_W - 24, "right")

    Keeper.draw(self.vendorId, self.keeperX, self.keeperY, Keeper.W, self.keeperH, {
        nameFont = self.bodyFont,
        title = "The Rite",
        line = false, -- the pane runs to the foot of the box; there is no room under it for a line
    })

    if self.menu then
        self.menu:draw()
    else
        Theme.set(Theme.ink)
        love.graphics.printf("Nothing you are carrying is cursed.",
            self.colX, self.boxY + 150, self.colW, "center")
    end

    -- What is on the altar, and for how much longer. Below the rows rather than mixed among them: these
    -- are not choices, they are the bill for choices already made -- the Ward's resting list, exactly.
    --
    -- ANCHORED UNDER THE ROWS RATHER THAN TO THE BOX'S FOOT, which is where the Ward puts its own and is
    -- what collided here: two rows per hexed piece fills the column, and a band pinned to the bottom
    -- ended up drawn over the last row and the menu's own scroll chevron. The rows are capped to leave
    -- this band its space (Rite:visibleRows), so the two can no longer reach each other.
    local altar = self:altarLines()
    if #altar > 0 then
        local rows = self.menu and self:visibleRows() or 0
        local y = self.boxY + ROWS_TOP + rows * (ROW_H + 8) + 14
        Theme.set(Theme.muted)
        love.graphics.setFont(self.bodyFont)
        for _, line in ipairs(altar) do
            love.graphics.printf(line, self.colX, y, self.colW, "left")
            y = y + ALTAR_LINE
        end
    end

    Theme.set(Theme.muted)
    love.graphics.setFont(self.bodyFont)
    love.graphics.printf(InputMode.pick("B to close", "Tap X to close", "Click X, or Esc to close"),
        self.colX, self.boxY + BOX_H - 34, self.colW, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function Rite:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self.menu then self.menu:mousemoved(x, y) end
end

function Rite:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self.menu and self.menu.cursorKind then return self.menu:cursorKind(x, y) end
    return "arrow"
end

function Rite:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) or not isInsideBox(self, x, y) then
        self:close()
        return
    end
    if self.menu then self.menu:mousepressed(x, y, button) end
end

function Rite:keypressed(key)
    if key == "escape" then self:close(); return end
    if self.menu then self.menu:keypressed(key) end
end

function Rite:gamepadpressed(joystick, button)
    if button == "b" then self:close(); return end
    if self.menu then self.menu:gamepadpressed(joystick, button) end
end

return Rite
