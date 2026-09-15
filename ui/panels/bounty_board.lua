-- Bounty Board pop-up panel. Lists the postings the company can take today (left column) and what
-- the highlighted one is (right column). Choosing a row sets out.
--
--   local panel = BountyBoard.new({ player = p, onClose = fn })
--
-- THE ROW IS A POSTING, AND THE RIGHT-HAND COLUMN EXISTS TO NAME THE PIECE.
--
-- This panel is descended from the retired Quest Board (recovered from bedc7774) and inherits its
-- geometry, its three-input list and its item plates. What changed is what a row MEANS. That board
-- listed GROUNDS -- a day bought a whole place and every piece of work posted there stood on the map at
-- once -- so the dossier's job was to argue for one destination over another by listing everything
-- waiting on it. A bounty has one end and one reward, so the dossier's job is much narrower and much
-- more important: say what you are going to get, before you spend the day going for it.
--
-- WHICH IS WHY THE PIECE IS DRAWN AS AN OBJECT, not written as a line of text. It is the largest thing
-- in the column, it carries the real item's art and its real tooltip, and it sits under a caption that
-- says which body hands it over. A player deciding whether this trip is worth it is deciding whether
-- they want that, and a name in a sentence is not something you can want (docs/ui-style.md's rule that
-- a readout names its decision; [[concrete-object-beats-abstract-readout]]).
--
-- NOTHING HERE PROMISES A COMPANION. `rewardCharacter` is deliberately unread, exactly as the old board
-- left it: the board promises gear, and a body arriving is the outro's to earn.

local State = require("states")
local Menu = require("ui.menu")
local Bounty = require("models.bounty")
local Augment = require("models.augment")
local Material = require("models.material")
local Biome = require("models.biome")
local Item = require("models.item")
local ItemTooltip = require("ui.item_tooltip")
local CloseButton = require("ui.close_button")
local VendorIcons = require("ui.vendor_icons")
local Vendor = require("models.vendor")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")

local BountyBoard = {}
BountyBoard.__index = BountyBoard

-- Panel box geometry, centered in the 1280x720 logical space. Lifted from the board this replaces so
-- the two read as the same furniture to anyone who played both.
local BOX_W, BOX_H = 760, 520
local LIST_TOP = 92
local ROW_H, ROW_SPACING, MAX_VISIBLE = 48, 8, 6

-- The width a row's LABEL may occupy before it starts overprinting the value beside it: the button,
-- less ui/menu.lua's own inset at each end, less a gap. Held here rather than derived at the draw
-- because the row is built in rebuild() and the trim has to happen there, where the text is chosen.
local ROW_BUTTON_W = 280
local ROW_H_LABEL_W = ROW_BUTTON_W - 18 * 2 - 14

-- The piece plate. Bigger than the old board's 46px relic plates because there is exactly ONE of them
-- and it is the argument the whole column is making -- six small plates were a list of what a place
-- happened to pay, and this is the thing you are going for.
local PIECE = 64

-- The air under a block in the dossier. One number rather than per-call literals, because the column
-- measures itself before it draws and the two have to agree.
local GAP = 8

function BountyBoard.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BountyBoard)
    self.onClose = opts.onClose
    self.player = opts.player
    self.titleFont = Theme.display(30)
    self.headFont = Theme.display(20)
    self.bodyFont = Theme.body(16)
    self.capFont = Theme.body(12)

    self.boxX = (Scale.WIDTH - BOX_W) / 2
    self.boxY = (Scale.HEIGHT - BOX_H) / 2

    -- Two modes in one box: pick a posting, then say how dangerous to make it. See openStake.
    self.mode = "read"

    self:rebuild()

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- (Re)load the board and its menu.
--
-- A FINISHED POSTING IS NOT DRAWN AT ALL, greyed or otherwise -- Bounty.offered has already dropped
-- it. A control appears where it can be used, and spent work is not a control.
function BountyBoard:rebuild()
    self.offered = Bounty.offered(self.player)
    self.pieceCache = nil
    self.pieceFocus = nil

    local items = {}
    for _, entry in ipairs(self.offered) do
        -- THE TIER RIDES IN THE VALUE SLOT, label left and value right, the same shape a settings row
        -- wears. It says what the number is OF -- "Tier 2", never a bare 2 -- because a figure whose
        -- unit the player has to infer is one they read wrong once and stop trusting.
        --
        -- ...AND A HELD POSTING SAYS HOW MANY ARE LEFT, because that is the decision the row is really
        -- asking about. Taking one spends it; the last copy is the one where "press on or fall back on
        -- the opener" stops being rhetorical. A standing offer never runs out, so it says nothing --
        -- an infinite count drawn as a number would read as a quantity that could fall.
        local value = "Tier " .. tostring(entry.def.tier or 1)
        if not entry.standing then
            value = value .. "  x" .. tostring(entry.held or 0)
        end
        -- THE LABEL YIELDS TO THE VALUE, measured rather than hoped for. ui/menu.lua draws a setting
        -- row as label-left / value-right and does not trim either, so a long name simply prints
        -- THROUGH the tier -- which "The Opening Nobody Reads" did, on the first board that had seven
        -- houses on it. The value is the shorter and the more load-bearing of the two (it is the
        -- decision), so the name is what gives way.
        local room = ROW_H_LABEL_W - self.headFont:getWidth(value)
        items[#items + 1] = {
            label = Theme.ellipsize(entry.def.name or entry.id, self.headFont, room),
            value = value,
            action = function() self:openStake(entry) end,
        }
    end

    self.menu = Menu.new(items, {
        buttonWidth = ROW_BUTTON_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.26,
        font = self.headFont,
        maxVisible = MAX_VISIBLE,
    })
end

function BountyBoard:current()
    return self.offered[self.menu and self.menu.selected or 1]
end

-- ENTER ON A POSTING OPENS THE STAKE, it does not set out. The dossier column is replaced by the
-- augment list -- same box, same column, one panel in two modes -- so the decision about how dangerous
-- to make this fits the space the panel already has rather than opening a modal over a modal
-- ([[modal-fits-the-space-exits-first]]). Esc backs out to the dossier before it closes the board.
--
-- WHY IT IS A SEPARATE BEAT rather than rows under the piece: staking is a different question from
-- choosing, it is answered once the posting is picked, and a company with nothing to stake should never
-- have to scroll past it. The board asks "which", then "how hard".
function BountyBoard:openStake(entry)
    self.mode = "stake"
    self.stakeEntry = entry
    self.staked = {}
    self.stakeIndex = 1
    self.stakeList = {}
    for id, def in pairs(Augment.defs) do
        self.stakeList[#self.stakeList + 1] = { id = id, def = def }
    end
    -- Ordered by what it costs and then by id: a list that reordered itself between visits is a list
    -- nobody can learn, and `pairs` is unspecified.
    table.sort(self.stakeList, function(a, b)
        local ca, cb = Augment.weight(a.def), Augment.weight(b.def)
        if ca ~= cb then return ca < cb end
        return a.id < b.id
    end)
end

function BountyBoard:closeStake()
    self.mode = "read"
    self.stakeEntry, self.staked, self.stakeList = nil, nil, nil
end

-- How many copies of `id` are staked, and whether the stake has room for another.
function BountyBoard:stakedCount(id)
    local n = 0
    for _, s in ipairs(self.staked or {}) do if s == id then n = n + 1 end end
    return n
end

-- Toggle one augment on or off. Staking the same danger twice is legal and doubles it -- the cost
-- doubles with it -- so this ADDS up to the cap and a second press past the cap takes them all off,
-- which is the only way a player without a mouse can clear a row they cannot afford.
function BountyBoard:toggleStake(delta)
    local row = self.stakeList and self.stakeList[self.stakeIndex]
    if not row then return end
    if delta > 0 then
        if #self.staked >= Augment.MAX_STAKED then return end
        local trial = {}
        for i, s in ipairs(self.staked) do trial[i] = s end
        trial[#trial + 1] = row.id
        -- REFUSED RATHER THAN SHOWN RED. A stake the company cannot pay for is not a choice it has, and
        -- a control that appears where it cannot be used is the thing docs/ui-style.md forbids.
        if not Augment.affordable(self.player, trial) then return end
        self.staked = trial
    else
        for i = #self.staked, 1, -1 do
            if self.staked[i] == row.id then table.remove(self.staked, i) break end
        end
    end
end

-- SET OUT. There is nothing to assemble first: the whole roster marches, and which of them take the
-- field is chosen per battle in the deployment phase, over the actual board (docs/deployment.md).
--
-- The work's own `intro` plays first, over the frozen city -- it is authored to run before the company
-- leaves, and that is still exactly when it runs.
function BountyBoard:setOut(entry, staked)
    local quest = Bounty.stakedQuestFor(entry, self.player, staked)
    if not quest then return end

    -- TAKING IT SPENDS IT, and that happens HERE rather than on the way home -- the bounty is gone the
    -- moment the company walks out of the city, win or lose, which is the whole of what makes pressing
    -- on a bet (models/bounty.lua). Doing it at the payout instead would refund every failed run.
    --
    -- A refusal means the last copy went while this panel was open; rebuild rather than set out, so the
    -- row disappears instead of the board silently doing nothing.
    if not Bounty.spend(self.player, entry.id) then
        self:closeStake()
        self:rebuild()
        return
    end
    -- THE STAKE IS PAID AT THE SAME MOMENT, so a run that ends badly ends with it gone. Paid AFTER the
    -- posting, because the posting is the thing that can refuse.
    if staked and #staked > 0 and not Augment.pay(self.player, staked) then
        -- Somebody spent the materials elsewhere while this panel was open. The posting is already gone
        -- -- it was the first call -- so the honest thing is to go anyway, unaugmented, rather than
        -- swallow a bounty and refuse the trip.
        staked = nil
        quest = Bounty.questFor(entry, self.player)
    end
    require("models.player").save()

    local function begin()
        State.switch(require("states.game"), quest, nil, self.player)
    end

    if quest.intro then
        require("models.conversation").play(quest.intro, begin)
    else
        begin()
    end
end

function BountyBoard:close()
    if self.onClose then self.onClose() end
end

function BountyBoard:update(dt)
    self.menu:update(dt)
    -- A new posting brings a new piece, so neither the focus ring nor the instantiated item can survive
    -- the move.
    if self.lastSelected ~= self.menu.selected then
        self.lastSelected = self.menu.selected
        self.pieceFocus = nil
        self.pieceCache = nil
    end
end

-- The highlighted posting's piece, instantiated so the hover tooltip quotes the real thing -- its
-- stats, its ability, its flavour -- rather than a name. Memoized per row: instantiation copies the
-- whole blueprint and the dossier rebuilds every frame.
--
-- An id that has been renamed out of the data yields nil rather than crashing Item.instantiate, so a
-- stale reference reads as a missing plate instead of taking the city down.
function BountyBoard:piece()
    if self.pieceCache ~= nil then
        return self.pieceCache.item, self.pieceCache.id
    end
    local entry = self:current()
    local id = entry and Bounty.pieceOf(entry.def) or nil
    local item = (id and Item.defs[id]) and Item.instantiate(id) or nil
    self.pieceCache = { id = id, item = item }
    return item, id
end

function BountyBoard:pieceRect()
    return self.pieceRectCache
end

-- Is the mouse over the piece plate?
function BountyBoard:pieceHit(x, y)
    local r = self.pieceRectCache
    if not r then return false end
    x, y = x or self.mx, y or self.my
    if not (x and y) then return false end
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function BountyBoard:draw()
    -- Dim the city behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    -- Panel frame.
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Bounty Board", self.boxX, self.boxY + 24, BOX_W, "center")

    if #self.offered == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf("Nothing posted. Come back when the houses have work.",
            self.boxX + 40, self.boxY + BOX_H / 2, BOX_W - 80, "center")
    elseif self.mode == "stake" then
        -- The list is still drawn, dimmed, so the posting being staked stays on screen -- the question
        -- is "how dangerous should THIS be", and hiding what "this" is would make it unanswerable.
        self.menu:draw()
        self:drawStake()
    else
        self.menu:draw()
        self:drawDossier()
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    local hint
    if self.mode == "stake" then
        hint = InputMode.isGamepad()
            and "A: Stake / unstake    X: Set out    B: Back"
            or "Click / Enter: Stake    Backspace: Unstake    Tab: Set out    Esc: Back"
    else
        hint = InputMode.isGamepad()
            and "A: Choose    D-pad: Move    B: Close"
            or "Click a bounty / Enter: Choose    Wheel: Scroll    Click X / Esc: Close"
    end
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()

    -- The piece's tooltip, last of all so it floats over everything. Hung off the CURSOR like every
    -- other item hover in the game; a pad or keyboard focus has no cursor to hang from, so that one
    -- anchors on the plate instead. ItemTooltip clamps either to the screen.
    local item = self:piece()
    if item and self.pieceRectCache then
        if self:pieceHit() then
            ItemTooltip.draw(item, self.mx, self.my)
        elseif self.pieceFocus then
            local r = self.pieceRectCache
            ItemTooltip.draw(item, r.x + r.w, r.y - 12)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- WHAT THIS POSTING IS, in the order a player decides in: whose it is, where, how hard, who is at the
-- end, and what they give up. The piece is last because it is the one the eye should rest on.
function BountyBoard:drawDossier()
    local entry = self:current()
    self.pieceRectCache = nil
    if not entry then return end

    local def = entry.def
    local x = self.boxX + BOX_W * 0.46
    local w = BOX_W * 0.46
    local cy = self.boxY + LIST_TOP - 4
    local lineH = self.bodyFont:getHeight()

    -- The house, with its mark immediately left of its name. This is one of the two places the mark is
    -- seen beside the name it belongs to, and an hour from now the same shape stands alone on a tile
    -- out on the ground (ui/vendor_icons.lua, ui/overworld_map.lua) -- so this is where it is taught.
    local vendor = def.sponsor and Vendor.get(def.sponsor)
    local house = vendor and vendor.name or def.sponsor
    if house then
        love.graphics.setFont(self.bodyFont)
        local mark = lineH * 0.9
        local markW = VendorIcons.has(def.sponsor) and (mark + 6) or 0
        if markW > 0 then
            VendorIcons.draw(def.sponsor, x, cy + (lineH - mark) / 2, mark, mark,
                Theme.accentAmber[1], Theme.accentAmber[2], Theme.accentAmber[3])
        end
        Theme.set(Theme.accentAmber)
        love.graphics.print(Theme.ellipsize(house, self.bodyFont, w - markW), x + markW, cy)
        cy = cy + lineH + 2
    end

    -- The posting's name, on its own line and in the display face: it is the heading of this column.
    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.print(Theme.ellipsize(def.name or entry.id, self.headFont, w), x, cy)
    cy = cy + self.headFont:getHeight() + GAP

    love.graphics.setFont(self.bodyFont)

    -- WHERE, and HOW HARD, on one line each -- both are facts about the ground and both are read before
    -- the reward is looked at.
    local biome = Biome.get(def.ground)
    local groundName = (biome and biome.name) or def.ground
    if groundName then
        Theme.set(Theme.muted)
        love.graphics.print("Ground", x, cy)
        Theme.set(Theme.ink)
        love.graphics.printf(groundName, x, cy, w, "right")
        cy = cy + lineH + 4
    end

    -- THE COMPARISON IS THE POINT, not the number. A floor on its own is trivia; a floor beside the
    -- company's own level is the decision, and it goes red when the ground is above them -- which is
    -- the one thing this panel exists to warn about before a day is spent.
    local floor = Bounty.tierLevel(def)
    local ours = self:companyLevel()
    Theme.set(Theme.muted)
    love.graphics.print("Hardest fight", x, cy)
    Theme.set(ours < floor and Theme.accentWeapon or Theme.ink)
    love.graphics.printf(string.format("level %d, you are %d", floor, ours), x, cy, w, "right")
    cy = cy + lineH + GAP

    -- What the work is. Trimmed to what the column can hold rather than painted past the panel edge.
    local desc = def.description
    if desc then
        Theme.set(Theme.muted)
        local _, lines = self.bodyFont:getWrap(desc, w)
        love.graphics.printf(desc, x, cy, w, "left")
        cy = cy + lineH * math.min(#lines, 4) + GAP
    end

    -- WHO IS AT THE END. A bounty is a body standing somewhere, and this is the line that says so.
    local boss = Bounty.bossName(def)
    if boss then
        Theme.set(Theme.muted)
        love.graphics.print("At the end", x, cy)
        cy = cy + lineH
        Theme.set(Theme.accentWeapon)
        love.graphics.print(Theme.ellipsize(boss, self.bodyFont, w), x, cy)
        cy = cy + lineH + GAP
    end

    -- ...AND WHAT THEY GIVE UP. Drawn as the object rather than written as a name.
    local item, pieceId = self:piece()
    if pieceId then
        Theme.set(Theme.muted)
        love.graphics.print("It owes you", x, cy)
        cy = cy + lineH + 2
        self:drawPiece(item, pieceId, x, cy, w)
    end
end

-- THE STAKE. What the company may make this posting into, and what that costs.
--
-- Every row says the same three things in the same places: the danger's name, what it does to the
-- ground, and what it costs in stock. The totals sit at the bottom because they are what the player is
-- actually deciding -- a list of five dangers is not a decision until it says what THIS combination
-- comes to.
function BountyBoard:drawStake()
    local x = self.boxX + BOX_W * 0.46
    local w = BOX_W * 0.46
    local cy = self.boxY + LIST_TOP - 4
    local lineH = self.bodyFont:getHeight()

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print("Stake", x, cy)
    love.graphics.setFont(self.capFont)
    Theme.set(Theme.muted)
    love.graphics.printf(#(self.staked or {}) .. " of " .. Augment.MAX_STAKED, x, cy + 6, w, "right")
    cy = cy + self.headFont:getHeight() + GAP

    love.graphics.setFont(self.bodyFont)
    self.stakeRects = {}
    for i, row in ipairs(self.stakeList or {}) do
        local n = self:stakedCount(row.id)
        local focused = (self.stakeIndex == i)
        local rowH = lineH * 2 + 6
        self.stakeRects[i] = { x = x, y = cy, w = w, h = rowH }

        if focused then
            Theme.set(Theme.panel2)
            love.graphics.rectangle("fill", x - 4, cy - 2, w + 8, rowH, Theme.R, Theme.R)
        end

        -- A STAKED ROW WEARS THE GOLD, and an unstaked one does not. The count is drawn only when it is
        -- above one, because "x1" beside a thing that is either on or off says nothing.
        Theme.set(n > 0 and Theme.accentAmber or Theme.ink)
        local head = row.def.name or row.id
        if n > 1 then head = head .. "  x" .. n end
        love.graphics.print(Theme.ellipsize(head, self.bodyFont, w * 0.62), x, cy)

        -- What it costs, right-aligned on the same baseline, in the stock's own short form.
        local bits = {}
        for matId, count in pairs(row.def.cost or {}) do
            local mat = Material.get(matId)
            bits[#bits + 1] = count .. " " .. ((mat and mat.name) or matId)
        end
        table.sort(bits)
        love.graphics.setFont(self.capFont)
        Theme.set(Augment.affordable(self.player, { row.id }) and Theme.muted or Theme.accentWeapon)
        love.graphics.printf(table.concat(bits, ", "), x, cy + 2, w, "right")

        Theme.set(Theme.muted)
        love.graphics.print(Theme.ellipsize(row.def.description or "", self.capFont, w), x, cy + lineH + 2)
        love.graphics.setFont(self.bodyFont)

        cy = cy + rowH + 4
    end

    -- WHAT THE WHOLE STAKE COMES TO. The one reading the decision is actually made on.
    local t = Augment.totals(self.staked)
    cy = cy + GAP
    Theme.set(Theme.frame)
    love.graphics.rectangle("fill", x, cy, w, 1)
    cy = cy + GAP

    local danger = {}
    if t.levels > 0 then danger[#danger + 1] = "+" .. t.levels .. " levels" end
    if t.fights > 0 then danger[#danger + 1] = "+" .. t.fights .. " stops" end
    if t.guard > 0 then danger[#danger + 1] = "+" .. t.guard .. " at the end" end
    if t.elites > 0 then danger[#danger + 1] = "more elites" end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.print("It becomes", x, cy)
    Theme.set(#danger > 0 and Theme.accentWeapon or Theme.muted)
    love.graphics.printf(#danger > 0 and table.concat(danger, ", ") or "what it already is", x, cy, w, "right")
    cy = cy + lineH + 2

    local pays = {}
    if t.gold > 0 then pays[#pays + 1] = "+" .. math.floor(t.gold * 100) .. "% coin" end
    if t.drops > 0 then
        pays[#pays + 1] = "+" .. t.drops .. (t.drops == 1 and " posting" or " postings")
    end
    Theme.set(Theme.muted)
    love.graphics.print("It pays", x, cy)
    Theme.set(#pays > 0 and Theme.accentAmber or Theme.muted)
    love.graphics.printf(#pays > 0 and table.concat(pays, ", ") or "what it already pays", x, cy, w, "right")
    cy = cy + lineH + GAP + 4

    -- SET OUT AND BACK, AS REAL BUTTONS. The keyboard has Tab and Esc for these, but the project
    -- standard is that the game is fully playable with a mouse alone -- and a commit step reachable only
    -- from the keyboard is the exact shape of that rule being broken.
    self.stakeButtons = {}
    local bw, bh = (w - GAP) / 2, 34
    local function button(key, label, bx, primary)
        local rect = { x = bx, y = cy, w = bw, h = bh, key = key }
        self.stakeButtons[#self.stakeButtons + 1] = rect
        local hot = self.mx and self.mx >= rect.x and self.mx <= rect.x + rect.w
            and self.my and self.my >= rect.y and self.my <= rect.y + rect.h
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", rect.x, rect.y, bw, bh, Theme.R, Theme.R)
        if hot or primary then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame) end
        love.graphics.setLineWidth(primary and 2 or 1)
        love.graphics.rectangle("line", rect.x, rect.y, bw, bh, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)
        Theme.set((hot or primary) and Theme.accentAmber or Theme.ink)
        love.graphics.setFont(self.bodyFont)
        love.graphics.printf(label, rect.x, rect.y + (bh - self.bodyFont:getHeight()) / 2, bw, "center")
    end
    button("back", "Back", x, false)
    button("out", "Set out", x + bw + GAP, true)
end

-- The company's level, as the strongest body in it. A bounty is taken by the whole roster and the
-- deployment phase picks who stands, so the honest reading of "can we take this" is the best body
-- available rather than a mean that nobody on the board actually is.
function BountyBoard:companyLevel()
    local best = 1
    for _, char in ipairs((self.player and self.player.roster) or {}) do
        if (char.level or 1) > best then best = char.level or 1 end
    end
    return best
end

-- The piece: its art on a plate, its name beside it. The plate is focusable so a player without a
-- mouse can still reach the tooltip.
function BountyBoard:drawPiece(item, pieceId, x, cy, w)
    local rect = { x = x, y = cy, w = PIECE, h = PIECE }
    self.pieceRectCache = rect

    local focused = self.pieceFocus or self:pieceHit()
    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", rect.x, rect.y, PIECE, PIECE, 6, 6)
    if focused then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame, 0.7) end
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", rect.x, rect.y, PIECE, PIECE, 6, 6)
    love.graphics.setLineWidth(1)

    -- Art when the item has it, its initial on a plate when it does not -- the same fallback the
    -- inventory grid draws, so a piece with no sprite yet still reads as a thing you can hover.
    local sprite = item and item.sprite
    local label = (item and item.name) or pieceId
    if type(sprite) == "userdata" then
        local iw, ih = sprite:getDimensions()
        local scale = math.min((PIECE - 12) / iw, (PIECE - 12) / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, rect.x + PIECE / 2, rect.y + PIECE / 2, 0, scale, scale, iw / 2, ih / 2)
    else
        love.graphics.setFont(self.headFont)
        Theme.set(Theme.ink)
        love.graphics.printf(label:sub(1, 1):upper(), rect.x,
            rect.y + (PIECE - self.headFont:getHeight()) / 2, PIECE, "center")
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    local textX, textW = rect.x + PIECE + 10, w - PIECE - 10
    love.graphics.printf(Theme.ellipsize(label, self.bodyFont, textW), textX,
        rect.y + (PIECE - self.bodyFont:getHeight()) / 2, textW, "left")
end

-- ---------------------------------------------------------------------------
-- Input: mouse + keyboard + gamepad (project standard, docs/ui-style.md)
-- ---------------------------------------------------------------------------

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function BountyBoard:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    self.menu:mousemoved(x, y)
end

-- Hand over the close X, a bounty row, or the piece plate; arrow elsewhere. See ui/cursor.lua.
function BountyBoard:cursorKind(x, y)
    if self.mode == "stake" then
        local row, key = self:stakeHit(x, y)
        if row or key or self.closeButton:contains(x, y) then return "hand" end
        return "arrow"
    end
    if self.closeButton:contains(x, y) or self.menu:mouseOverItem(x, y) or self:pieceHit(x, y) then
        return "hand"
    end
    return "arrow"
end

function BountyBoard:wheelmoved(dx, dy)
    self.menu:wheelmoved(dx, dy)
end

-- What the pointer is over in stake mode: a row index, or a button key, or nothing.
function BountyBoard:stakeHit(x, y)
    for i, r in ipairs(self.stakeRects or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    for _, r in ipairs(self.stakeButtons or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return nil, r.key end
    end
    return nil
end

function BountyBoard:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        return self:close()
    end
    if not isInsideBox(self, x, y) then
        -- A click outside the panel dismisses the modal -- but in stake mode it backs out one step
        -- first, so a stray click cannot throw away a stake that has not been committed.
        if self.mode == "stake" then return self:closeStake() end
        return self:close()
    end

    if self.mode == "stake" then
        local row, key = self:stakeHit(x, y)
        if row then
            -- Clicking the row the cursor is already on toggles it; clicking another moves to it first,
            -- so a mouse never has to press twice to reach a row it is already pointing at.
            self.stakeIndex = row
            self:toggleStake(1)
        elseif key == "back" then
            self:closeStake()
        elseif key == "out" then
            local entry, staked = self.stakeEntry, self.staked
            self:closeStake()
            self:setOut(entry, staked)
        end
        return
    end

    self.menu:mousepressed(x, y, button)
end

-- Left/right toggles the piece plate's focus ring -- the only way a player without a mouse can read the
-- tooltip. It falls through to the menu when there is no piece, where the pair is a no-op anyway (a
-- bounty row carries no `adjust`).
function BountyBoard:togglePieceFocus()
    if not self.pieceRectCache then return false end
    self.pieceFocus = not self.pieceFocus
    return true
end

-- Move the stake cursor, wrapping. Its own walker rather than a second Menu, because the rows carry two
-- lines and a cost column and a Menu row is one line with one value.
function BountyBoard:moveStake(delta)
    local n = #(self.stakeList or {})
    if n == 0 then return end
    local i = (self.stakeIndex or 1) + delta
    if i < 1 then i = n elseif i > n then i = 1 end
    self.stakeIndex = i
end

function BountyBoard:keypressed(key)
    -- STAKE MODE OWNS THE WHOLE KEYBOARD while it is up, and Esc backs out of it rather than closing
    -- the board: a mode you can only leave by leaving the screen is a trap.
    if self.mode == "stake" then
        if key == "escape" then
            self:closeStake()
        elseif key == "up" or key == "w" then
            self:moveStake(-1)
        elseif key == "down" or key == "s" then
            self:moveStake(1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            self:toggleStake(1)
        elseif key == "backspace" or key == "delete" then
            self:toggleStake(-1)
        elseif key == "tab" then
            local entry, staked = self.stakeEntry, self.staked
            self:closeStake()
            self:setOut(entry, staked)
        end
        return
    end

    if key == "escape" then
        self:close()
    elseif (key == "left" or key == "a" or key == "right" or key == "d") and self:togglePieceFocus() then
    else
        self.menu:keypressed(key)
    end
end

function BountyBoard:gamepadpressed(joystick, button)
    if self.mode == "stake" then
        if button == "b" then
            self:closeStake()
        elseif button == "dpup" then
            self:moveStake(-1)
        elseif button == "dpdown" then
            self:moveStake(1)
        elseif button == "a" then
            self:toggleStake(1)
        elseif button == "y" then
            self:toggleStake(-1)
        elseif button == "x" then
            local entry, staked = self.stakeEntry, self.staked
            self:closeStake()
            self:setOut(entry, staked)
        end
        return
    end

    if button == "b" then
        self:close()
    elseif (button == "dpleft" or button == "dpright") and self:togglePieceFocus() then
    else
        self.menu:gamepadpressed(joystick, button)
    end
end

return BountyBoard
